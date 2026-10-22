import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/supabase_providers.dart';
import '../parent/parent_providers.dart' show officialBrandingProvider;
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';

// ============================================================ data

/// Everything the Principal manages for the public website and the
/// official documents. All of it is limited to the Principal's own
/// school by database policies.
class PnWebsiteRepository {
  final SupabaseClient _c;
  PnWebsiteRepository(this._c);

  String get _uid => _c.auth.currentUser!.id;

  // ---- statistics
  Future<List<Map<String, dynamic>>> statistics(String schoolId) async {
    final rows = await _c.from('school_statistics').select().eq('school_id', schoolId).order('display_order', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, int>> liveCounts(String schoolId) async {
    try {
      final res = await _c.rpc('landing_live_stats', params: {'p_school_id': schoolId});
      if (res is Map) return res.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    } catch (_) {}
    return {};
  }

  Future<void> saveStatistic(String schoolId, {String? id, required Map<String, dynamic> data}) async {
    if (id == null) {
      await _c.from('school_statistics').insert({...data, 'school_id': schoolId});
    } else {
      await _c.from('school_statistics').update({...data, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    }
  }

  Future<void> deleteStatistic(String id) => _c.from('school_statistics').delete().eq('id', id);

  // ---- announcements
  Future<List<Map<String, dynamic>>> announcements(String schoolId) async {
    final rows = await _c.from('announcements').select().eq('school_id', schoolId).order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveAnnouncement(String schoolId, {String? id, required Map<String, dynamic> data}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    if (id == null) {
      await _c.from('announcements').insert({...data, 'school_id': schoolId, 'published_by': _uid});
    } else {
      await _c.from('announcements').update({...data, 'updated_at': now}).eq('id', id);
    }
  }

  Future<void> deleteAnnouncement(String id) => _c.from('announcements').delete().eq('id', id);

  // ---- events
  Future<List<Map<String, dynamic>>> events(String schoolId) async {
    final rows = await _c.from('school_events').select().eq('school_id', schoolId).order('event_date', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveEvent(String schoolId, {String? id, required Map<String, dynamic> data}) async {
    if (id == null) {
      await _c.from('school_events').insert({...data, 'school_id': schoolId});
    } else {
      await _c.from('school_events').update({...data, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    }
  }

  Future<void> deleteEvent(String id) => _c.from('school_events').delete().eq('id', id);

  // ---- letterhead and stamps
  static const docTypes = ['letterhead', 'principal_stamp', 'proprietor_stamp', 'discipline_master_stamp'];

  Future<Map<String, Map<String, dynamic>>> documents(String schoolId) async {
    final rows = await _c.from('school_assets').select().eq('school_id', schoolId).eq('is_active', true).inFilter('asset_type', docTypes);
    final out = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      out[r['asset_type'] as String] = Map<String, dynamic>.from(r);
    }
    return out;
  }

  Future<void> uploadDocument(String schoolId, {required String type, required Uint8List bytes, required String ext}) async {
    final rnd = Random.secure();
    final token = List.generate(10, (_) => rnd.nextInt(36).toRadixString(36)).join();
    final path = '$schoolId/documents/${type}_$token.$ext';
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    await _c.storage.from('school-branding').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
    final url = _c.storage.from('school-branding').getPublicUrl(path);

    final existing = await _c.from('school_assets').select().eq('school_id', schoolId).eq('asset_type', type).eq('is_active', true).maybeSingle();
    final data = {'file_name': '$type.$ext', 'file_url': url, 'mime_type': mime, 'file_size': bytes.length};
    if (existing != null) {
      await _c.from('school_assets').update({...data, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', existing['id'] as String);
      await _removeObject(existing['file_url'] as String?);
    } else {
      await _c.from('school_assets').insert({...data, 'school_id': schoolId, 'asset_type': type, 'is_active': true});
    }
  }

  Future<void> removeDocument(Map<String, dynamic> row) async {
    await _c.from('school_assets').update({'is_active': false, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', row['id'] as String);
    await _removeObject(row['file_url'] as String?);
  }

  Future<void> _removeObject(String? url) async {
    if (url == null) return;
    const marker = '/school-branding/';
    final i = url.indexOf(marker);
    if (i < 0) return;
    try {
      await _c.storage.from('school-branding').remove([Uri.decodeComponent(url.substring(i + marker.length).split('?').first)]);
    } catch (_) {}
  }
}

final pnWebsiteRepositoryProvider = Provider<PnWebsiteRepository>((ref) => PnWebsiteRepository(ref.watch(supabaseClientProvider)));

// ============================================================ shared bits

String _two(int n) => n.toString().padLeft(2, '0');
String _hm(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';
String _dt(DateTime d) => '${pDate(d)}  ${_two(d.hour)}:${_two(d.minute)}';
DateTime? _parseDay(dynamic v) {
  if (v == null) return null;
  final p = DateTime.tryParse(v.toString());
  return p == null ? null : DateTime(p.year, p.month, p.day);
}

/// Small helper: a page that loads a list, shows loading/error/empty
/// states and can reload itself.
class _Loader<T> extends StatefulWidget {
  final AppStrings strings;
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function() reload) builder;
  const _Loader({super.key, required this.strings, required this.load, required this.builder});

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return PrError(error: _error!, strings: widget.strings, onRetry: () {
        setState(() => _loading = true);
        _run();
      });
    }
    return widget.builder(context, _data as T, _run);
  }
}

Widget _rowActions(AppStrings s, {required VoidCallback onEdit, required VoidCallback onDelete}) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(tooltip: s.pn('Edit', 'Modifier'), onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
    IconButton(tooltip: s.pn('Delete', 'Supprimer'), onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 20)),
  ]);
}

// ============================================================ statistics

const _kMetrics = ['custom', 'students', 'teachers', 'classes', 'departments', 'parents'];

String _metricLabel(AppStrings s, String m) {
  switch (m) {
    case 'students':
      return s.pn('Active students', 'Élèves actifs');
    case 'teachers':
      return s.pn('Approved teachers', 'Enseignants approuvés');
    case 'classes':
      return s.pn('Classes', 'Classes');
    case 'departments':
      return s.pn('Departments', 'Départements');
    case 'parents':
      return s.pn('Parents', 'Parents');
    default:
      return s.pn('Typed figure only', 'Chiffre saisi seulement');
  }
}

class PrincipalWebsiteStatsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalWebsiteStatsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalWebsiteStatsPage> createState() => _StatsState();
}

class _StatsState extends ConsumerState<PrincipalWebsiteStatsPage> {
  int _gen = 0;
  AppStrings get _s => widget.strings;

  Future<(List<Map<String, dynamic>>, Map<String, int>)> _load() async {
    final repo = ref.read(pnWebsiteRepositoryProvider);
    final r = await Future.wait([repo.statistics(widget.schoolId), repo.liveCounts(widget.schoolId)]);
    return (r[0] as List<Map<String, dynamic>>, r[1] as Map<String, int>);
  }

  void _reload() => setState(() => _gen++);

  Future<void> _edit(Map<String, dynamic>? row, Map<String, int> live, int count) async {
    final ok = await pnSheet<bool>(context, (_) => _StatSheet(strings: _s, schoolId: widget.schoolId, row: row, live: live, nextOrder: count + 1));
    if (ok == true && mounted) {
      _reload();
      prSnack(context, _s.pn('Saved. The website updates on the next visit.', 'Enregistré. Le site se met à jour à la prochaine visite.'));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final s = _s;
    final yes = await pnConfirm(context, s,
        title: s.pn('Delete this counter?', 'Supprimer ce compteur ?'),
        message: s.pn('It will no longer appear on the website.', 'Il n\'apparaîtra plus sur le site.'),
        confirmLabel: s.pn('Delete', 'Supprimer'));
    if (!yes) return;
    try {
      await ref.read(pnWebsiteRepositoryProvider).deleteStatistic(row['id'] as String);
      _reload();
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  Future<void> _suggest(Map<String, int> live) async {
    final s = _s;
    final repo = ref.read(pnWebsiteRepositoryProvider);
    final items = [
      ('students', 'Students', 'Élèves'),
      ('teachers', 'Teachers', 'Enseignants'),
      ('classes', 'Classes', 'Classes'),
    ];
    try {
      for (var i = 0; i < items.length; i++) {
        await repo.saveStatistic(widget.schoolId, data: {
          'label_en': items[i].$2,
          'label_fr': items[i].$3,
          'value': '',
          'metric': items[i].$1,
          'show_from': 1,
          'display_order': i + 1,
          'is_active': true,
        });
      }
      _reload();
      if (mounted) prSnack(context, s.pn('Counters added. Open each one to type the figure to show until the real number is large enough.', 'Compteurs ajoutés. Ouvrez chacun pour saisir le chiffre à afficher en attendant que le nombre réel soit assez grand.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _Loader<(List<Map<String, dynamic>>, Map<String, int>)>(
      key: ValueKey(_gen),
      strings: s,
      load: _load,
      builder: (context, data, reload) {
        final rows = data.$1;
        final live = data.$2;
        return PrPage(
          onRefresh: () async => _reload(),
          children: [
            PrHeader(
              title: s.pn('Website statistics', 'Statistiques du site'),
              subtitle: s.pn('The numbers parents see on your school website.', 'Les chiffres que les parents voient sur le site de l\'école.'),
              trailing: FilledButton.icon(onPressed: () => _edit(null, live, rows.length), icon: const Icon(Icons.add_rounded), label: Text(s.pn('New counter', 'Nouveau compteur'))),
            ),
            PnNotice(
              icon: Icons.auto_graph_rounded,
              text: s.pn(
                'Type a starting figure for each counter. When the real number in the system reaches the "show live from" value, the website switches to the real number and keeps it up to date by itself. Only counts are shown, never names.',
                'Saisissez un chiffre de départ pour chaque compteur. Quand le nombre réel dans le système atteint la valeur « afficher en direct à partir de », le site passe au nombre réel et le met à jour automatiquement. Seuls des totaux sont affichés, jamais de noms.',
              ),
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              SizedBox(
                height: 320,
                child: PrEmpty(
                  icon: Icons.query_stats_rounded,
                  title: s.pn('No counters yet', 'Aucun compteur'),
                  description: s.pn('Start with the usual three (students, teachers, classes) or create your own.', 'Commencez avec les trois habituels (élèves, enseignants, classes) ou créez les vôtres.'),
                  action: FilledButton.icon(onPressed: () => _suggest(live), icon: const Icon(Icons.auto_fix_high_rounded), label: Text(s.pn('Add the usual counters', 'Ajouter les compteurs habituels'))),
                ),
              )
            else
              PrCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                    _statRow(rows[i], live, rows.length, theme),
                  ],
                ]),
              ),
          ],
        );
      },
    );
  }

  Widget _statRow(Map<String, dynamic> r, Map<String, int> live, int count, ThemeData theme) {
    final s = _s;
    final cs = theme.colorScheme;
    final metric = (r['metric'] as String?) ?? 'custom';
    final typed = (r['value'] as String? ?? '').trim();
    final showFrom = (r['show_from'] as num?)?.toInt() ?? 0;
    final liveVal = metric == 'custom' ? null : live[metric];
    final active = r['is_active'] != false;
    final usingLive = liveVal != null && liveVal >= showFrom && liveVal > 0;
    final shown = usingLive ? '$liveVal' : typed;
    final label = (s.isFrench ? r['label_fr'] : r['label_en']) as String? ?? (r['label_en'] as String? ?? '');

    String note;
    if (metric == 'custom') {
      note = s.pn('Always shows the figure you typed.', 'Affiche toujours le chiffre saisi.');
    } else if (usingLive) {
      note = s.pn('Showing the real number from the system.', 'Affiche le nombre réel du système.');
    } else if (typed.isEmpty) {
      note = s.pn('Hidden until the real number reaches $showFrom.', 'Masqué jusqu\'à ce que le nombre réel atteigne $showFrom.');
    } else {
      note = s.pn('Showing your typed figure until the real number reaches $showFrom.', 'Affiche votre chiffre saisi jusqu\'à ce que le nombre réel atteigne $showFrom.');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Text(shown.isEmpty ? '–' : shown, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              PnChip(label: _metricLabel(s, metric)),
              if (liveVal != null) PnChip(label: s.pn('Real now: $liveVal', 'Réel actuel : $liveVal'), color: cs.primary),
              if (!active) PnChip(label: s.pn('Hidden', 'Masqué'), color: pnWarn()),
            ]),
            const SizedBox(height: 4),
            Text(note, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          ]),
        ),
        _rowActions(s, onEdit: () => _edit(r, live, count), onDelete: () => _delete(r)),
      ]),
    );
  }
}

class _StatSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final String schoolId;
  final Map<String, dynamic>? row;
  final Map<String, int> live;
  final int nextOrder;
  const _StatSheet({required this.strings, required this.schoolId, required this.row, required this.live, required this.nextOrder});

  @override
  ConsumerState<_StatSheet> createState() => _StatSheetState();
}

class _StatSheetState extends ConsumerState<_StatSheet> {
  late final TextEditingController _en = TextEditingController(text: widget.row?['label_en'] as String? ?? '');
  late final TextEditingController _fr = TextEditingController(text: widget.row?['label_fr'] as String? ?? '');
  late final TextEditingController _value = TextEditingController(text: widget.row?['value'] as String? ?? '');
  late final TextEditingController _from = TextEditingController(text: '${(widget.row?['show_from'] as num?)?.toInt() ?? 1}');
  late String _metric = (widget.row?['metric'] as String?) ?? 'custom';
  late bool _active = widget.row?['is_active'] != false;
  bool _busy = false;
  String? _error;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _en.dispose();
    _fr.dispose();
    _value.dispose();
    _from.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = _s;
    var en = _en.text.trim();
    var fr = _fr.text.trim();
    if (en.isEmpty && fr.isEmpty) {
      setState(() => _error = s.pn('Give the counter a name.', 'Donnez un nom au compteur.'));
      return;
    }
    if (en.isEmpty) en = fr;
    if (fr.isEmpty) fr = en;
    final typed = _value.text.trim();
    final from = int.tryParse(_from.text.trim()) ?? 0;
    if (_metric == 'custom' && typed.isEmpty) {
      setState(() => _error = s.pn('Type the figure to show.', 'Saisissez le chiffre à afficher.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(pnWebsiteRepositoryProvider).saveStatistic(widget.schoolId, id: widget.row?['id'] as String?, data: {
        'label_en': en,
        'label_fr': fr,
        'value': typed,
        'metric': _metric,
        'show_from': from < 0 ? 0 : from,
        'is_active': _active,
        if (widget.row == null) 'display_order': widget.nextOrder,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = pnErr(s, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final liveNow = _metric == 'custom' ? null : widget.live[_metric];
    return PnSheetBody(
      title: widget.row == null ? s.pn('New counter', 'Nouveau compteur') : s.pn('Edit counter', 'Modifier le compteur'),
      children: [
        TextField(controller: _en, decoration: pnDeco(s.pn('Name in English', 'Nom en anglais'), hint: 'Students')),
        const SizedBox(height: 12),
        TextField(controller: _fr, decoration: pnDeco(s.pn('Name in French', 'Nom en français'), hint: 'Élèves')),
        const SizedBox(height: 16),
        Text(s.pn('Where does the real number come from?', 'D\'où vient le nombre réel ?'), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        PrPills<String>(values: _kMetrics, selected: _metric, label: (m) => _metricLabel(s, m), onChanged: (v) => setState(() => _metric = v)),
        const SizedBox(height: 16),
        TextField(
          controller: _value,
          decoration: pnDeco(
            _metric == 'custom' ? s.pn('Figure to show', 'Chiffre à afficher') : s.pn('Starting figure (shown until the real number is large enough)', 'Chiffre de départ (affiché tant que le nombre réel est trop petit)'),
            hint: s.pn('e.g. 450 or 25+', 'ex. 450 ou 25+'),
          ),
        ),
        if (_metric != 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _from,
            keyboardType: TextInputType.number,
            decoration: pnDeco(s.pn('Show the real number from', 'Afficher le nombre réel à partir de')),
          ),
          const SizedBox(height: 10),
          PnNotice(
            icon: Icons.info_outline_rounded,
            text: s.pn(
              'The system has ${liveNow ?? 0} now. Leave the starting figure empty to hide this counter until the real number reaches the value above.',
              'Le système en compte ${liveNow ?? 0} actuellement. Laissez le chiffre de départ vide pour masquer ce compteur jusqu\'à ce que le nombre réel atteigne la valeur ci-dessus.',
            ),
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _active,
          onChanged: (v) => setState(() => _active = v),
          title: Text(s.pn('Show on the website', 'Afficher sur le site')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
        ],
      ],
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy ? null : _save, child: PnBusyLabel(busy: _busy, label: s.pn('Save', 'Enregistrer'))),
      ],
    );
  }
}

// ============================================================ announcements

class PrincipalAnnouncementsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalAnnouncementsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalAnnouncementsPage> createState() => _AnnState();
}

class _AnnState extends ConsumerState<PrincipalAnnouncementsPage> {
  int _gen = 0;
  AppStrings get _s => widget.strings;
  void _reload() => setState(() => _gen++);

  Future<void> _edit(Map<String, dynamic>? row) async {
    final ok = await pnSheet<bool>(context, (_) => _AnnouncementSheet(strings: _s, schoolId: widget.schoolId, row: row));
    if (ok == true && mounted) {
      _reload();
      prSnack(context, _s.pn('Saved.', 'Enregistré.'));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final s = _s;
    final yes = await pnConfirm(context, s,
        title: s.pn('Delete this announcement?', 'Supprimer cette annonce ?'),
        message: s.pn('It will disappear from the website.', 'Elle disparaîtra du site.'),
        confirmLabel: s.pn('Delete', 'Supprimer'));
    if (!yes) return;
    try {
      await ref.read(pnWebsiteRepositoryProvider).deleteAnnouncement(row['id'] as String);
      _reload();
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  /// draft / scheduled / live / ended
  String _state(Map<String, dynamic> r) {
    if (r['status'] != 'published') return 'draft';
    final pub = DateTime.tryParse('${r['published_at']}')?.toLocal();
    final exp = r['expires_at'] == null ? null : DateTime.tryParse('${r['expires_at']}')?.toLocal();
    final now = DateTime.now();
    if (exp != null && exp.isBefore(now)) return 'ended';
    if (pub != null && pub.isAfter(now)) return 'scheduled';
    return 'live';
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _Loader<List<Map<String, dynamic>>>(
      key: ValueKey(_gen),
      strings: s,
      load: () => ref.read(pnWebsiteRepositoryProvider).announcements(widget.schoolId),
      builder: (context, rows, reload) => PrPage(
        onRefresh: () async => _reload(),
        children: [
          PrHeader(
            title: s.pn('Announcements', 'Annonces'),
            subtitle: s.pn('News for parents on the school website. Publish now, or choose a date and time.', 'Les nouvelles pour les parents sur le site. Publiez maintenant ou choisissez une date et une heure.'),
            trailing: FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add_rounded), label: Text(s.pn('New announcement', 'Nouvelle annonce'))),
          ),
          if (rows.isEmpty)
            SizedBox(
              height: 300,
              child: PrEmpty(
                icon: Icons.campaign_outlined,
                title: s.pn('No announcements yet', 'Aucune annonce'),
                description: s.pn('The website shows the latest three that are published.', 'Le site affiche les trois dernières annonces publiées.'),
                action: FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add_rounded), label: Text(s.pn('New announcement', 'Nouvelle annonce'))),
              ),
            )
          else
            PrCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                  _row(rows[i], theme),
                ],
              ]),
            ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r, ThemeData theme) {
    final s = _s;
    final cs = theme.colorScheme;
    final st = _state(r);
    final pub = DateTime.tryParse('${r['published_at']}')?.toLocal();
    final exp = r['expires_at'] == null ? null : DateTime.tryParse('${r['expires_at']}')?.toLocal();
    final chip = switch (st) {
      'live' => PnChip(label: s.pn('On the website', 'Sur le site'), color: pnGood()),
      'scheduled' => PnChip(label: s.pn('Scheduled', 'Programmée'), color: cs.primary, icon: Icons.schedule_rounded),
      'ended' => PnChip(label: s.pn('Ended', 'Terminée')),
      _ => PnChip(label: s.pn('Draft', 'Brouillon'), color: pnWarn()),
    };
    return InkWell(
      onTap: () => _edit(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['title'] as String? ?? '', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(r['content'] as String? ?? '', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                chip,
                if (pub != null && st != 'draft') Text(_dt(pub), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                if (exp != null) Text('${s.pn('hidden after', 'masquée après')} ${pDate(exp)}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
              ]),
            ]),
          ),
          _rowActions(s, onEdit: () => _edit(r), onDelete: () => _delete(r)),
        ]),
      ),
    );
  }
}

class _AnnouncementSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final String schoolId;
  final Map<String, dynamic>? row;
  const _AnnouncementSheet({required this.strings, required this.schoolId, required this.row});

  @override
  ConsumerState<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends ConsumerState<_AnnouncementSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.row?['title'] as String? ?? '');
  late final TextEditingController _content = TextEditingController(text: widget.row?['content'] as String? ?? '');
  String _mode = 'now'; // draft | now | schedule
  DateTime? _when;
  DateTime? _hideAfter;
  bool _busy = false;
  String? _error;

  AppStrings get _s => widget.strings;
  bool get _wasLive {
    final r = widget.row;
    if (r == null || r['status'] != 'published') return false;
    final p = DateTime.tryParse('${r['published_at']}');
    return p != null && !p.toLocal().isAfter(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    if (r == null) return;
    if (r['status'] != 'published') {
      _mode = 'draft';
    } else {
      final p = DateTime.tryParse('${r['published_at']}')?.toLocal();
      if (p != null && p.isAfter(DateTime.now())) {
        _mode = 'schedule';
        _when = p;
      }
    }
    if (r['expires_at'] != null) _hideAfter = DateTime.tryParse('${r['expires_at']}')?.toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final d = await pnPickDate(context, initial, first: DateTime.now().subtract(const Duration(days: 1)), last: DateTime.now().add(const Duration(days: 730)));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : const TimeOfDay(hour: 8, minute: 0));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    final s = _s;
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = s.pn('Write a title and the announcement text.', 'Écrivez un titre et le texte de l\'annonce.'));
      return;
    }
    if (_mode == 'schedule') {
      if (_when == null || !_when!.isAfter(DateTime.now())) {
        setState(() => _error = s.pn('Choose a date and time in the future.', 'Choisissez une date et une heure dans le futur.'));
        return;
      }
    }
    final pubBase = _mode == 'schedule' ? _when! : DateTime.now();
    if (_hideAfter != null && !_hideAfter!.isAfter(pubBase)) {
      setState(() => _error = s.pn('The hide date must be after the publish date.', 'La date de masquage doit être après la date de publication.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'title': title,
        'content': content,
        'expires_at': _hideAfter?.toUtc().toIso8601String(),
      };
      if (_mode == 'draft') {
        data['status'] = 'draft';
        data['published_at'] = null;
      } else if (_mode == 'schedule') {
        data['status'] = 'published';
        data['published_at'] = _when!.toUtc().toIso8601String();
      } else {
        data['status'] = 'published';
        if (!_wasLive) data['published_at'] = DateTime.now().toUtc().toIso8601String();
      }
      await ref.read(pnWebsiteRepositoryProvider).saveAnnouncement(widget.schoolId, id: widget.row?['id'] as String?, data: data);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = pnErr(s, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    String modeLabel(String m) => switch (m) {
          'draft' => s.pn('Save as draft', 'Brouillon'),
          'schedule' => s.pn('Schedule', 'Programmer'),
          _ => _wasLive ? s.pn('Keep published', 'Garder publiée') : s.pn('Publish now', 'Publier maintenant'),
        };
    return PnSheetBody(
      title: widget.row == null ? s.pn('New announcement', 'Nouvelle annonce') : s.pn('Edit announcement', 'Modifier l\'annonce'),
      children: [
        TextField(controller: _title, decoration: pnDeco(s.pn('Title', 'Titre'))),
        const SizedBox(height: 12),
        TextField(controller: _content, minLines: 4, maxLines: 10, textCapitalization: TextCapitalization.sentences, decoration: pnDeco(s.pn('Announcement', 'Annonce'))),
        const SizedBox(height: 16),
        Text(s.pn('When should it appear?', 'Quand doit-elle apparaître ?'), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        PrPills<String>(values: const ['now', 'schedule', 'draft'], selected: _mode, label: modeLabel, onChanged: (v) => setState(() => _mode = v)),
        if (_mode == 'schedule') ...[
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final d = await _pickDateTime(_when);
              if (d != null) setState(() => _when = d);
            },
            child: InputDecorator(
              decoration: pnDeco(s.pn('Publish on', 'Publier le'), icon: Icons.schedule_rounded),
              child: Text(_when == null ? s.pn('Choose date and time', 'Choisir la date et l\'heure') : _dt(_when!)),
            ),
          ),
        ],
        if (_mode == 'draft') ...[
          const SizedBox(height: 10),
          PnNotice(icon: Icons.visibility_off_outlined, text: s.pn('A draft is not shown on the website. Open it later to publish.', 'Un brouillon n\'est pas affiché sur le site. Rouvrez-le plus tard pour le publier.')),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await _pickDateTime(_hideAfter);
                if (d != null) setState(() => _hideAfter = d);
              },
              child: InputDecorator(
                decoration: pnDeco(s.pn('Hide after (optional)', 'Masquer après (facultatif)'), icon: Icons.timer_off_outlined),
                child: Text(_hideAfter == null ? s.pn('Stays until replaced', 'Reste jusqu\'à remplacement') : _dt(_hideAfter!)),
              ),
            ),
          ),
          if (_hideAfter != null) IconButton(tooltip: s.pn('Clear', 'Effacer'), onPressed: () => setState(() => _hideAfter = null), icon: const Icon(Icons.close_rounded)),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
        ],
      ],
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: PnBusyLabel(busy: _busy, label: _mode == 'draft' ? s.pn('Save draft', 'Enregistrer le brouillon') : _mode == 'schedule' ? s.pn('Schedule', 'Programmer') : s.pn('Publish', 'Publier')),
        ),
      ],
    );
  }
}

// ============================================================ events

class PrincipalEventsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalEventsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalEventsPage> createState() => _EventsState();
}

class _EventsState extends ConsumerState<PrincipalEventsPage> {
  int _gen = 0;
  AppStrings get _s => widget.strings;
  void _reload() => setState(() => _gen++);

  Future<void> _edit(Map<String, dynamic>? row) async {
    final ok = await pnSheet<bool>(context, (_) => _EventSheet(strings: _s, schoolId: widget.schoolId, row: row));
    if (ok == true && mounted) {
      _reload();
      prSnack(context, _s.pn('Saved.', 'Enregistré.'));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final s = _s;
    final yes = await pnConfirm(context, s,
        title: s.pn('Delete this event?', 'Supprimer cet événement ?'),
        message: s.pn('It will disappear from the website.', 'Il disparaîtra du site.'),
        confirmLabel: s.pn('Delete', 'Supprimer'));
    if (!yes) return;
    try {
      await ref.read(pnWebsiteRepositoryProvider).deleteEvent(row['id'] as String);
      _reload();
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _Loader<List<Map<String, dynamic>>>(
      key: ValueKey(_gen),
      strings: s,
      load: () => ref.read(pnWebsiteRepositoryProvider).events(widget.schoolId),
      builder: (context, rows, reload) => PrPage(
        onRefresh: () async => _reload(),
        children: [
          PrHeader(
            title: s.pn('Events', 'Événements'),
            subtitle: s.pn('Upcoming dates for parents. An event leaves the website 30 days after its date.', 'Les dates à venir pour les parents. Un événement quitte le site 30 jours après sa date.'),
            trailing: FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add_rounded), label: Text(s.pn('New event', 'Nouvel événement'))),
          ),
          if (rows.isEmpty)
            SizedBox(
              height: 300,
              child: PrEmpty(
                icon: Icons.event_available_outlined,
                title: s.pn('No events yet', 'Aucun événement'),
                description: s.pn('Add open days, exams, holidays, meetings…', 'Ajoutez portes ouvertes, examens, vacances, réunions…'),
                action: FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add_rounded), label: Text(s.pn('New event', 'Nouvel événement'))),
              ),
            )
          else
            PrCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                  _row(rows[i], theme),
                ],
              ]),
            ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r, ThemeData theme) {
    final s = _s;
    final cs = theme.colorScheme;
    final day = _parseDay(r['event_date']);
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final published = r['status'] == 'published';
    final past = day != null && day.isBefore(t0);
    final gone = day != null && day.add(const Duration(days: 30)).isBefore(t0);
    final time = (r['event_time'] as String?)?.split(':');
    final timeText = time != null && time.length >= 2 ? '${time[0]}:${time[1]}' : null;

    final chip = !published
        ? PnChip(label: s.pn('Draft', 'Brouillon'), color: pnWarn())
        : gone
            ? PnChip(label: s.pn('Removed from site', 'Retiré du site'))
            : past
                ? PnChip(label: s.pn('Past', 'Passé'))
                : PnChip(label: s.pn('Upcoming', 'À venir'), color: pnGood());

    return InkWell(
      onTap: () => _edit(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(day == null ? '–' : '${day.day}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              Text(day == null ? '' : '${day.month}/${day.year % 100}', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['title'] as String? ?? '', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                [if (timeText != null) timeText, if ((r['location'] as String?)?.isNotEmpty ?? false) r['location'] as String].join('  ·  '),
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                chip,
                if (published && day != null && !gone)
                  Text('${s.pn('leaves the website on', 'quitte le site le')} ${pDate(day.add(const Duration(days: 30)))}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
              ]),
            ]),
          ),
          _rowActions(s, onEdit: () => _edit(r), onDelete: () => _delete(r)),
        ]),
      ),
    );
  }
}

class _EventSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final String schoolId;
  final Map<String, dynamic>? row;
  const _EventSheet({required this.strings, required this.schoolId, required this.row});

  @override
  ConsumerState<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<_EventSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.row?['title'] as String? ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.row?['description'] as String? ?? '');
  late final TextEditingController _place = TextEditingController(text: widget.row?['location'] as String? ?? '');
  DateTime? _date;
  TimeOfDay? _time;
  bool _publish = true;
  bool _busy = false;
  String? _error;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    if (r == null) return;
    _date = _parseDay(r['event_date']);
    final t = (r['event_time'] as String?)?.split(':');
    if (t != null && t.length >= 2) _time = TimeOfDay(hour: int.tryParse(t[0]) ?? 0, minute: int.tryParse(t[1]) ?? 0);
    _publish = r['status'] == 'published';
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = _s;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = s.pn('Give the event a title.', 'Donnez un titre à l\'événement.'));
      return;
    }
    if (_date == null) {
      setState(() => _error = s.pn('Choose the date of the event.', 'Choisissez la date de l\'événement.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(pnWebsiteRepositoryProvider).saveEvent(widget.schoolId, id: widget.row?['id'] as String?, data: {
        'title': _title.text.trim(),
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'event_date': pnIso(_date!),
        'event_time': _time == null ? null : '${_hm(_time!)}:00',
        'location': _place.text.trim().isEmpty ? null : _place.text.trim(),
        'status': _publish ? 'published' : 'draft',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = pnErr(s, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    return PnSheetBody(
      title: widget.row == null ? s.pn('New event', 'Nouvel événement') : s.pn('Edit event', 'Modifier l\'événement'),
      children: [
        TextField(controller: _title, decoration: pnDeco(s.pn('Title', 'Titre'))),
        const SizedBox(height: 12),
        TextField(controller: _desc, minLines: 2, maxLines: 6, textCapitalization: TextCapitalization.sentences, decoration: pnDeco(s.pn('Description (optional)', 'Description (facultatif)'))),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final d = await pnPickDate(context, _date, first: DateTime.now().subtract(const Duration(days: 60)), last: DateTime.now().add(const Duration(days: 1095)));
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(decoration: pnDeco(s.pn('Date', 'Date'), icon: Icons.event_outlined), child: Text(_date == null ? s.pn('Choose a date', 'Choisir une date') : pDate(_date!))),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0));
                if (t != null) setState(() => _time = t);
              },
              child: InputDecorator(decoration: pnDeco(s.pn('Time (optional)', 'Heure (facultatif)'), icon: Icons.schedule_rounded), child: Text(_time == null ? '–' : _hm(_time!))),
            ),
          ),
          if (_time != null) IconButton(tooltip: s.pn('Clear', 'Effacer'), onPressed: () => setState(() => _time = null), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _place, decoration: pnDeco(s.pn('Place (optional)', 'Lieu (facultatif)'), icon: Icons.place_outlined)),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _publish,
          onChanged: (v) => setState(() => _publish = v),
          title: Text(s.pn('Show on the website', 'Afficher sur le site')),
          subtitle: Text(s.pn('It leaves the website 30 days after the date.', 'Il quitte le site 30 jours après la date.')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
        ],
      ],
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy ? null : _save, child: PnBusyLabel(busy: _busy, label: s.pn('Save', 'Enregistrer'))),
      ],
    );
  }
}

// ============================================================ letterhead & stamps

class PrincipalDocumentsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalDocumentsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalDocumentsPage> createState() => _DocsState();
}

class _DocsState extends ConsumerState<PrincipalDocumentsPage> {
  int _gen = 0;
  String? _busyType;
  AppStrings get _s => widget.strings;
  void _reload() => setState(() => _gen++);

  String _title(String t) {
    final s = _s;
    switch (t) {
      case 'letterhead':
        return s.pn('Letterhead', 'En-tête');
      case 'principal_stamp':
        return s.pn('Principal\'s stamp', 'Cachet du directeur');
      case 'proprietor_stamp':
        return s.pn('Proprietor\'s stamp', 'Cachet du promoteur');
      default:
        return s.pn('Discipline master\'s stamp', 'Cachet du surveillant général');
    }
  }

  String _hint(String t) {
    final s = _s;
    if (t == 'letterhead') {
      return s.pn('The banner at the top of official documents: school name, logo, address. A wide image works best.', 'La bannière en haut des documents officiels : nom, logo, adresse. Une image large convient le mieux.');
    }
    return s.pn('A clear photo or scan of the stamp. A PNG with a transparent background looks best.', 'Une photo ou un scan net du cachet. Un PNG à fond transparent donne le meilleur rendu.');
  }

  Future<void> _upload(String type) async {
    final s = _s;
    try {
      // No resizing here: it would flatten a transparent stamp.
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : '';
      if (ext != 'png' && ext != 'jpg' && ext != 'jpeg') {
        if (mounted) prSnack(context, s.pn('Use a PNG or JPG image.', 'Utilisez une image PNG ou JPG.'));
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        if (mounted) prSnack(context, s.pn('That image is too large (maximum 3 MB).', 'Cette image est trop lourde (3 Mo maximum).'));
        return;
      }
      setState(() => _busyType = type);
      await ref.read(pnWebsiteRepositoryProvider).uploadDocument(widget.schoolId, type: type, bytes: bytes, ext: ext == 'png' ? 'png' : 'jpg');
      ref.invalidate(officialBrandingProvider(widget.schoolId));
      if (mounted) {
        setState(() => _busyType = null);
        _reload();
        prSnack(context, s.pn('Saved. New documents will use it.', 'Enregistré. Les nouveaux documents l\'utiliseront.'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busyType = null);
        prSnack(context, pnErr(s, e));
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> row, String type) async {
    final s = _s;
    final yes = await pnConfirm(context, s,
        title: s.pn('Remove this image?', 'Retirer cette image ?'),
        message: s.pn('Documents you create from now on will not have it.', 'Les documents créés à partir de maintenant ne l\'auront plus.'),
        confirmLabel: s.pn('Remove', 'Retirer'));
    if (!yes) return;
    try {
      await ref.read(pnWebsiteRepositoryProvider).removeDocument(row);
      ref.invalidate(officialBrandingProvider(widget.schoolId));
      _reload();
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    return _Loader<Map<String, Map<String, dynamic>>>(
      key: ValueKey(_gen),
      strings: s,
      load: () => ref.read(pnWebsiteRepositoryProvider).documents(widget.schoolId),
      builder: (context, docs, reload) => PrPage(
        onRefresh: () async => _reload(),
        children: [
          PrHeader(
            title: s.pn('School documents', 'Documents de l\'école'),
            subtitle: s.pn('Your letterhead and stamps. They appear on report cards, receipts, ID cards and timetables.', 'Votre en-tête et vos cachets. Ils apparaissent sur les bulletins, reçus, cartes d\'élève et emplois du temps.'),
          ),
          PnNotice(
            icon: Icons.info_outline_rounded,
            text: s.pn(
              'Only upload images you are authorised to use. Anyone who has the exact image link could view it, so do not upload a signature you want to keep private.',
              'Ne téléversez que des images que vous avez le droit d\'utiliser. Toute personne ayant le lien exact de l\'image pourrait la voir : ne téléversez pas une signature que vous voulez garder privée.',
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 760 ? 2 : 1;
            final w = (c.maxWidth - (cols - 1) * 14) / cols;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (final t in PnWebsiteRepository.docTypes)
                SizedBox(width: w, child: _card(t, docs[t], theme)),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _card(String type, Map<String, dynamic>? row, ThemeData theme) {
    final s = _s;
    final cs = theme.colorScheme;
    final url = row?['file_url'] as String?;
    final busy = _busyType == type;
    return PrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_title(type), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(_hint(type), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.4)),
        const SizedBox(height: 12),
        Container(
          height: type == 'letterhead' ? 110 : 140,
          width: double.infinity,
          decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6))),
          alignment: Alignment.center,
          child: url == null
              ? Text(s.pn('Nothing uploaded yet', 'Rien de téléversé'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: cs.outline)),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(
            onPressed: busy ? null : () => _upload(type),
            icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_rounded, size: 18),
            label: Text(url == null ? s.pn('Upload', 'Téléverser') : s.pn('Replace', 'Remplacer')),
          ),
          if (row != null)
            TextButton.icon(onPressed: busy ? null : () => _remove(row, type), icon: const Icon(Icons.delete_outline_rounded, size: 18), label: Text(s.pn('Remove', 'Retirer'))),
        ]),
      ]),
    );
  }
}
