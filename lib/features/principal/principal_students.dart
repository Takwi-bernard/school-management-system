import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

/// Every student of the school: search, filter by class, move a student
/// to another class, or record a withdrawal or transfer.
class PrincipalStudentsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalStudentsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalStudentsPage> createState() => _PrincipalStudentsPageState();
}

class _PrincipalStudentsPageState extends ConsumerState<PrincipalStudentsPage> {
  static const _pageSize = 40;

  final _search = TextEditingController();
  final _debounce = PrDebouncer();
  final List<PnStudentRow> _items = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  String? _yearId;
  String? _classId;
  int _request = 0;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final years = await ref.read(pnCalendarProvider.future);
      if (years.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _yearId = years.firstWhere((y) => y.isCurrent, orElse: () => years.first).id;
      await _load(reset: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _load({required bool reset}) async {
    if (_yearId == null) return;
    final ticket = ++_request;
    if (reset) {
      setState(() {
        _loading = _items.isEmpty; // keep the list on screen during a refresh
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref.read(principalHubRepositoryProvider).getStudents(
            yearId: _yearId!,
            search: _search.text,
            classId: _classId,
            limit: _pageSize,
            offset: reset ? 0 : _items.length,
          );
      if (!mounted || ticket != _request) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.rows);
        _total = page.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || ticket != _request) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _move(PnStudentRow st) async {
    final s = _s;
    final moved = await pnSheet<bool>(context, (_) => _MoveSheet(strings: s, schoolId: widget.schoolId, yearId: _yearId!, student: st));
    if (moved == true) {
      ref.invalidate(pnOverviewProvider);
      _load(reset: true);
      if (mounted) prSnack(context, s.pn('${st.fullName} was moved.', '${st.fullName} a été déplacé(e).'));
    }
  }

  Future<void> _status(PnStudentRow st) async {
    final s = _s;
    final done = await pnSheet<bool>(context, (_) => _StatusSheet(strings: s, student: st));
    if (done == true) {
      ref.invalidate(pnOverviewProvider);
      _load(reset: true);
      if (mounted) prSnack(context, s.pn('Status updated.', 'Statut mis à jour.'));
    }
  }

  String _statusLabel(String v) {
    final s = _s;
    switch (v) {
      case 'active':
        return s.pn('Active', 'Actif');
      case 'withdrawn':
        return s.pn('Withdrawn', 'Retiré');
      case 'transferred':
        return s.pn('Transferred', 'Transféré');
      case 'graduated':
        return s.pn('Graduated', 'Diplômé');
      default:
        return v;
    }
  }

  Color _statusColor(String v, ColorScheme cs) {
    switch (v) {
      case 'active':
        return pnGood();
      case 'withdrawn':
        return pnBad();
      case 'transferred':
        return pnWarn();
      default:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final classes = ref.watch(pnClassesProvider(widget.schoolId)).valueOrNull ?? const <PnClass>[];

    // live: reload quietly when something changed elsewhere
    ref.listen<int>(pnTickProvider, (_, __) {
      if (_yearId != null && !_loading) _load(reset: true);
    });

    return PrPage(
      onRefresh: () => _load(reset: true),
      children: [
        PrHeader(
          title: s.pn('Students', 'Élèves'),
          subtitle: s.pn('All enrolled students of the current year.', 'Tous les élèves inscrits de l\'année en cours.'),
          trailing: _loading ? null : PnChip(label: '$_total ${s.pn('students', 'élèves')}', color: cs.primary),
        ),
        LayoutBuilder(builder: (context, c) {
          final search = PnSearch(
            controller: _search,
            hint: s.pn('Search by name or admission number', 'Rechercher par nom ou matricule'),
            onChanged: (_) {
              setState(() {});
              _debounce.run(() => _load(reset: true));
            },
          );
          final filter = DropdownButtonFormField<String?>(
            initialValue: _classId,
            isExpanded: true,
            decoration: pnDeco(s.pn('Class', 'Classe')),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(s.pn('All classes', 'Toutes les classes'))),
              for (final k in classes) DropdownMenuItem<String?>(value: k.id, child: Text(k.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              setState(() => _classId = v);
              _load(reset: true);
            },
          );
          if (c.maxWidth < 600) return Column(children: [search, const SizedBox(height: 12), filter]);
          return Row(children: [Expanded(flex: 2, child: search), const SizedBox(width: 12), Expanded(child: filter)]);
        }),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          SizedBox(height: 260, child: PrError(error: _error!, strings: s, onRetry: () => _load(reset: true)))
        else if (_items.isEmpty)
          SizedBox(height: 280, child: PrEmpty(icon: Icons.groups_2_outlined, title: s.pn('No students found', 'Aucun élève trouvé'), description: s.pn('Try another name or class.', 'Essayez un autre nom ou une autre classe.')))
        else
          PrCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                _row(_items[i], theme),
              ],
              if (_items.length < _total)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _loadingMore
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
                      : TextButton(onPressed: () => _load(reset: false), child: Text(s.pn('Show more (${_items.length} of $_total)', 'Afficher plus (${_items.length} sur $_total)'))),
                ),
            ]),
          ),
      ],
    );
  }

  Widget _row(PnStudentRow st, ThemeData theme) {
    final s = _s;
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        PrAvatar(photoUrl: st.photo, name: st.fullName, radius: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(st.fullName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              [if (st.className != null) st.className!, if (st.admissionNumber != null) st.admissionNumber!, if (st.dateOfBirth != null) pDate(st.dateOfBirth!)].join('  ·  '),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(width: 8),
        if (st.status != 'active') PnChip(label: _statusLabel(st.status), color: _statusColor(st.status, cs)),
        PopupMenuButton<String>(
          tooltip: s.pn('Actions', 'Actions'),
          icon: Icon(Icons.more_vert_rounded, color: cs.outline),
          onSelected: (v) {
            if (v == 'move') _move(st);
            if (v == 'status') _status(st);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'move', enabled: st.status == 'active', child: Text(s.pn('Move to another class', 'Changer de classe'))),
            PopupMenuItem(value: 'status', child: Text(s.pn('Change status', 'Changer le statut'))),
          ],
        ),
      ]),
    );
  }
}

// ============================================================ move

class _MoveSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final String schoolId;
  final String yearId;
  final PnStudentRow student;
  const _MoveSheet({required this.strings, required this.schoolId, required this.yearId, required this.student});

  @override
  ConsumerState<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends ConsumerState<_MoveSheet> {
  String? _to;
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = widget.strings;
    setState(() => _busy = true);
    try {
      await ref.read(principalHubRepositoryProvider).moveStudent(studentId: widget.student.id, yearId: widget.yearId, toClassId: _to!, reason: _reason.text.trim().isEmpty ? null : _reason.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        prSnack(context, pnErr(s, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final classes = ref.watch(pnClassesProvider(widget.schoolId)).valueOrNull ?? const <PnClass>[];
    final options = classes.where((c) => c.id != widget.student.classId).toList();

    return PnSheetBody(
      title: s.pn('Move ${widget.student.fullName}', 'Déplacer ${widget.student.fullName}'),
      subtitle: widget.student.className == null ? null : '${s.pn('Now in', 'Actuellement en')} ${widget.student.className}',
      children: [
        DropdownButtonFormField<String>(
          initialValue: _to,
          isExpanded: true,
          decoration: pnDeco(s.pn('New class', 'Nouvelle classe')),
          items: [for (final c in options) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => _to = v),
        ),
        const SizedBox(height: 14),
        TextField(controller: _reason, decoration: pnDeco(s.pn('Reason (optional)', 'Motif (facultatif)'))),
        const SizedBox(height: 10),
        PnNotice(text: s.pn('Fees and marks stay with the student. The class must have a free seat.', 'Les frais et les notes restent attachés à l\'élève. La classe doit avoir une place libre.')),
      ],
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _to == null || _busy ? null : _save, child: PnBusyLabel(busy: _busy, label: s.pn('Move student', 'Déplacer'))),
      ],
    );
  }
}

// ============================================================ status

class _StatusSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final PnStudentRow student;
  const _StatusSheet({required this.strings, required this.student});

  @override
  ConsumerState<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends ConsumerState<_StatusSheet> {
  late String _status = widget.student.status;
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = widget.strings;
    setState(() => _busy = true);
    try {
      await ref.read(principalHubRepositoryProvider).setStudentStatus(studentId: widget.student.id, status: _status, reason: _reason.text.trim().isEmpty ? null : _reason.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        prSnack(context, pnErr(s, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    String label(String v) {
      switch (v) {
        case 'withdrawn':
          return s.pn('Withdrawn', 'Retiré');
        case 'transferred':
          return s.pn('Transferred out', 'Transféré');
        case 'graduated':
          return s.pn('Graduated', 'Diplômé');
        default:
          return s.pn('Active', 'Actif');
      }
    }

    return PnSheetBody(
      title: widget.student.fullName,
      subtitle: s.pn('Change the student\'s status. The history is kept.', 'Changez le statut de l\'élève. L\'historique est conservé.'),
      children: [
        PrPills<String>(
          values: const ['active', 'withdrawn', 'transferred', 'graduated'],
          selected: _status,
          label: label,
          onChanged: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: 14),
        TextField(controller: _reason, maxLines: 2, decoration: pnDeco(s.pn('Reason (optional)', 'Motif (facultatif)'))),
      ],
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy || _status == widget.student.status ? null : _save, child: PnBusyLabel(busy: _busy, label: s.pn('Save', 'Enregistrer'))),
      ],
    );
  }
}
