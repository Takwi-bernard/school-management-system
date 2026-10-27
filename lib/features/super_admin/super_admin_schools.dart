import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'super_admin_models.dart';
import 'super_admin_providers.dart';
import 'super_admin_school_detail.dart';
import 'super_admin_theme.dart';
import 'super_admin_ui.dart';

Color? parseHexColor(String hex) {
  var v = hex.trim().replaceAll('#', '');
  if (v.length == 6) v = 'FF$v';
  if (v.length != 8) return null;
  final parsed = int.tryParse(v, radix: 16);
  return parsed == null ? null : Color(parsed);
}

enum _StatusFilter { all, active, inactive }

class SchoolsSection extends ConsumerStatefulWidget {
  const SchoolsSection({super.key});

  @override
  ConsumerState<SchoolsSection> createState() => _SchoolsSectionState();
}

class _SchoolsSectionState extends ConsumerState<SchoolsSection> {
  final _search = TextEditingController();
  String _query = '';
  _StatusFilter _filter = _StatusFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SchoolSummary> _apply(List<SchoolSummary> all) {
    final q = _query.trim().toLowerCase();
    return all.where((s) {
      final okStatus = switch (_filter) {
        _StatusFilter.all => true,
        _StatusFilter.active => s.isActive,
        _StatusFilter.inactive => !s.isActive,
      };
      if (!okStatus) return false;
      if (q.isEmpty) return true;
      return s.schoolName.toLowerCase().contains(q) ||
          s.schoolCode.toLowerCase().contains(q) ||
          s.domain.toLowerCase().contains(q) ||
          s.id.toLowerCase().contains(q) ||
          (s.city?.toLowerCase().contains(q) ?? false) ||
          (s.country?.toLowerCase().contains(q) ?? false) ||
          (s.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(schoolsListProvider);
    ref.invalidate(schoolMetricsProvider);
    await ref.read(schoolsListProvider.future).catchError((_) => <SchoolSummary>[]);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(schoolsListProvider);
    final metrics = ref.watch(schoolMetricsProvider).valueOrNull ?? const <String, SchoolMetrics>{};

    return SaPage(
      title: 'Schools',
      subtitle: 'Every school on the platform, in one place.',
      onRefresh: _refresh,
      actions: [
        FilledButton.icon(
          onPressed: () async {
            final created = await showDialog<bool>(context: context, builder: (_) => const SchoolFormDialog());
            if (created == true) {
              ref.invalidate(schoolsListProvider);
              ref.invalidate(schoolMetricsProvider);
              ref.invalidate(platformOverviewProvider);
            }
          },
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Onboard a school'),
        ),
      ],
      children: [
        LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 700;
          final search = SaSearchField(controller: _search, hint: 'Search name, code, domain, city, email...', onChanged: (v) => setState(() => _query = v));
          final seg = SaSegmented<_StatusFilter>(
            options: const {_StatusFilter.all: 'All', _StatusFilter.active: 'Active', _StatusFilter.inactive: 'Suspended'},
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          );
          if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [search, const SizedBox(height: 12), seg]);
          return Row(children: [Expanded(child: search), const SizedBox(width: 14), seg]);
        }),
        const SizedBox(height: 18),
        async.when(
          loading: () => const SaCardSkeleton(count: 6),
          error: (e, _) => SaErrorState(e, onRetry: () => ref.invalidate(schoolsListProvider)),
          data: (all) {
            final schools = _apply(all);
            if (all.isEmpty) {
              return const SaEmpty(icon: Icons.apartment_rounded, title: 'No schools onboarded yet', message: 'Use "Onboard a school" to add the first one.');
            }
            if (schools.isEmpty) {
              return const SaEmpty(icon: Icons.search_off_rounded, title: 'No school matches', message: 'Try a different search or filter.');
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${schools.length} of ${all.length} schools', style: const TextStyle(color: Sa.faint, fontSize: 12.5)),
              ),
              SaGrid(minItemWidth: 340, children: [for (final s in schools) _SchoolCard(school: s, metrics: metrics[s.id])]),
            ]);
          },
        ),
      ],
    );
  }
}

class _SchoolCard extends StatelessWidget {
  final SchoolSummary school;
  final SchoolMetrics? metrics;
  const _SchoolCard({required this.school, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final s = school;
    final accent = parseHexColor(s.primaryColor) ?? Sa.primary;
    final place = [if (s.city != null && s.city!.isNotEmpty) s.city!, if (s.country != null && s.country!.isNotEmpty) s.country!].join(', ');

    Widget stat(IconData icon, String label, int? v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 14, color: Sa.faint), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Sa.faint, fontSize: 11.5))]),
            const SizedBox(height: 3),
            Text(v == null ? '-' : saCount(v), style: const TextStyle(color: Sa.text, fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
        );

    return SaCard(
      accent: accent,
      onTap: () => Navigator.push(context, saRoute(SchoolDetailPage(schoolId: s.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(saInitials(s.schoolName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.schoolName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.text, fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text('${s.schoolCode} · ${s.domain}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.muted, fontSize: 12.5)),
            ]),
          ),
          SaChip(s.isActive ? 'Active' : 'Suspended', tone: s.isActive ? SaTone.success : SaTone.danger),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          stat(Icons.school_outlined, 'Students', metrics?.students),
          stat(Icons.co_present_outlined, 'Teachers', metrics?.teachers),
          stat(Icons.admin_panel_settings_outlined, 'Admins', metrics?.admins),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          if (place.isNotEmpty) ...[
            const Icon(Icons.place_outlined, size: 14, color: Sa.faint),
            const SizedBox(width: 4),
            Flexible(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.faint, fontSize: 12))),
          ],
          const Spacer(),
          if (metrics != null && metrics!.principals == 0) const SaChip('No principal', tone: SaTone.warning, icon: Icons.warning_amber_rounded),
        ]),
      ]),
    );
  }
}

// ============================================================
// CREATE / EDIT SCHOOL
// ============================================================

class SchoolFormDialog extends ConsumerStatefulWidget {
  final SchoolSummary? existing;
  const SchoolFormDialog({super.key, this.existing});

  @override
  ConsumerState<SchoolFormDialog> createState() => _SchoolFormDialogState();
}

class _SchoolFormDialogState extends ConsumerState<SchoolFormDialog> {
  int _step = 0;
  static const _titles = ['Identity', 'Contact and location', 'Look and feel', 'Done'];

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _domain;
  late final TextEditingController _website;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _motto;
  late final TextEditingController _primaryHex;
  late final TextEditingController _secondaryHex;
  String _languageMode = 'bilingual';

  bool _saving = false;
  String? _error;
  SchoolSummary? _result;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.schoolName ?? '');
    _code = TextEditingController(text: e?.schoolCode ?? '');
    _domain = TextEditingController(text: e?.domain ?? '');
    _website = TextEditingController(text: e?.website ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _country = TextEditingController(text: e?.country ?? '');
    _motto = TextEditingController(text: e?.motto ?? '');
    _primaryHex = TextEditingController(text: e?.primaryColor ?? '#1A73E8');
    _secondaryHex = TextEditingController(text: e?.secondaryColor ?? '#0D47A1');
    _languageMode = e?.languageMode ?? 'bilingual';
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _domain, _website, _email, _phone, _address, _city, _country, _motto, _primaryHex, _secondaryHex]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty) {
      setState(() {
        _step = 0;
        _error = 'School name and code are required.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      final SchoolSummary saved;
      if (_isEdit) {
        saved = await repo.updateSchool(
          schoolId: widget.existing!.id,
          schoolName: _name.text.trim(),
          schoolCode: _code.text.trim(),
          domain: _domain.text.trim(),
          languageMode: _languageMode,
          motto: _motto.text.trim(),
          website: _website.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          city: _city.text.trim(),
          country: _country.text.trim(),
          primaryColor: _primaryHex.text.trim(),
          secondaryColor: _secondaryHex.text.trim(),
        );
      } else {
        saved = await repo.createSchool(
          schoolName: _name.text.trim(),
          schoolCode: _code.text.trim(),
          domain: _domain.text.trim(),
          languageMode: _languageMode,
          motto: _motto.text.trim(),
          website: _website.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          city: _city.text.trim(),
          country: _country.text.trim(),
          primaryColor: _primaryHex.text.trim(),
          secondaryColor: _secondaryHex.text.trim(),
        );
      }
      if (mounted) {
        setState(() {
          _result = saved;
          _step = 3;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_step == 0 && (_name.text.trim().isEmpty || _code.text.trim().isEmpty)) {
      setState(() => _error = 'School name and code are required.');
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SaDialog(
      icon: _isEdit ? Icons.edit_rounded : Icons.add_business_rounded,
      title: _isEdit ? 'Edit school' : 'Onboard a school',
      subtitle: _step < 3 ? 'Step ${_step + 1} of 3 · ${_titles[_step]}' : null,
      maxWidth: 560,
      actions: [
        if (_step > 0 && _step < 3) TextButton(onPressed: _saving ? null : () => setState(() => _step--), child: const Text('Back')),
        if (_step == 0) TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        if (_step < 2) FilledButton(onPressed: _next, child: const Text('Continue')),
        if (_step == 2)
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_isEdit ? 'Save changes' : 'Create school'),
          ),
        if (_step == 3) FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Done')),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_step < 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    decoration: BoxDecoration(color: i <= _step ? Sa.primaryHi : Colors.white12, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                if (i < 2) const SizedBox(width: 6),
              ],
            ]),
          ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: _step == 0 ? _identity() : _step == 1 ? _contact() : _step == 2 ? _look() : _done(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Sa.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Sa.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: Sa.danger, fontSize: 13))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _identity() => Column(children: [
        SaField(controller: _name, label: 'School name', icon: Icons.apartment_rounded),
        const SizedBox(height: 14),
        SaField(controller: _code, label: 'School code', icon: Icons.tag_rounded, hint: 'e.g. SHC (used in admission numbers)'),
        const SizedBox(height: 14),
        SaField(controller: _domain, label: 'Domain', icon: Icons.language_rounded, hint: 'e.g. sacredheart.com (blank = from the name)'),
        const SizedBox(height: 14),
        SaField(controller: _website, label: 'Website (optional)', icon: Icons.link_rounded),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _languageMode,
          dropdownColor: Sa.cardHi,
          style: const TextStyle(color: Sa.text),
          decoration: const InputDecoration(labelText: 'Language mode', prefixIcon: Icon(Icons.translate_rounded, color: Sa.faint, size: 20)),
          items: const [
            DropdownMenuItem(value: 'bilingual', child: Text('Bilingual (English + French)')),
            DropdownMenuItem(value: 'english', child: Text('English only')),
            DropdownMenuItem(value: 'french', child: Text('French only')),
          ],
          onChanged: (v) => setState(() => _languageMode = v ?? 'bilingual'),
        ),
      ]);

  Widget _contact() => Column(children: [
        SaField(controller: _email, label: 'Email', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        SaField(controller: _phone, label: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        SaField(controller: _address, label: 'Address', icon: Icons.place_outlined),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final city = SaField(controller: _city, label: 'City', icon: Icons.location_city_rounded);
          final country = SaField(controller: _country, label: 'Country', icon: Icons.flag_outlined);
          if (c.maxWidth < 420) return Column(children: [city, const SizedBox(height: 14), country]);
          return Row(children: [Expanded(child: city), const SizedBox(width: 12), Expanded(child: country)]);
        }),
      ]);

  Widget _look() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SaField(controller: _motto, label: 'Motto (optional)', icon: Icons.format_quote_rounded),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final a = _hex('Primary colour', _primaryHex);
          final b = _hex('Secondary colour', _secondaryHex);
          if (c.maxWidth < 420) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [a, const SizedBox(height: 14), b]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)]);
        }),
        const SizedBox(height: 14),
        const Text('Logo, banner, gallery and the school story are managed from the school page, under Website content.', style: TextStyle(color: Sa.faint, fontSize: 12)),
      ]);

  Widget _hex(String label, TextEditingController controller) {
    return StatefulBuilder(builder: (context, setLocal) {
      final color = parseHexColor(controller.text) ?? Colors.grey;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Sa.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: Border.all(color: Sa.border))),
          const SizedBox(width: 10),
          Expanded(child: SaField(controller: controller, label: 'Hex', hint: '#1A73E8', onChanged: (_) => setLocal(() {}))),
        ]),
      ]);
    });
  }

  Widget _done() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Sa.success.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.check_rounded, color: Sa.success, size: 30),
        ),
        const SizedBox(height: 16),
        Text('${_result?.schoolName ?? ''} ${_isEdit ? 'updated' : 'created'}', style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 6),
        Text('Domain: ${_result?.domain ?? ''}', style: const TextStyle(color: Sa.muted)),
        if (!_isEdit) ...[
          const SizedBox(height: 12),
          const Text('Next step: open the school and create its principal, proprietor and secretary accounts.', style: TextStyle(color: Sa.muted, fontSize: 13.5)),
        ],
      ]);
}