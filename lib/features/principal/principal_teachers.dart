import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';
import 'principal_kit.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// TEACHING SLOT CREATOR
// Department > Class > Subject > periods / days / time > teacher
// ============================================================

class CreateTeachingSlotPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const CreateTeachingSlotPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<CreateTeachingSlotPage> createState() => _CreateTeachingSlotPageState();
}

class _CreateTeachingSlotPageState extends ConsumerState<CreateTeachingSlotPage> {
  DepartmentFull? _department;
  ManagedClass? _class;
  SubjectWithCoefficient? _subject;
  int _periods = 3;
  final Set<int> _days = {};
  TimeOfDay? _start;
  TimeOfDay? _end;

  AppStrings get _s => widget.strings;

  String? _fmt(TimeOfDay? t) => t == null ? null : '${pnHm(t)}:00';

  bool get _ready => _department != null && _class != null && _subject != null;

  Future<void> _pickTime(bool start) async {
    final p = await showTimePicker(context: context, initialTime: (start ? _start : _end) ?? TimeOfDay(hour: start ? 8 : 9, minute: 0));
    if (p == null) return;
    setState(() => start ? _start = p : _end = p);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final depts = ref.watch(departmentsFullProvider(widget.schoolId));
    final timeInvalid = _start != null && _end != null && pnMinutes(pnHm(_end!)) <= pnMinutes(pnHm(_start!));

    Widget step(int n, String title, Widget child, {bool active = true}) => AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: active ? 1 : 0.45,
          child: IgnorePointer(
            ignoring: !active,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 12, backgroundColor: active ? cs.primary : cs.outlineVariant, child: Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onPrimary))),
                  const SizedBox(width: 10),
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                child,
              ]),
            ),
          ),
        );

    return PrPage(
      maxWidth: 720,
      children: [
        PrHeader(
          title: s.pn('Create a teaching slot', 'Créer un créneau d’enseignement'),
          subtitle: s.pn('Define the department, class and subject first, then choose who teaches it.', 'Définissez d’abord le département, la classe et la matière, puis choisissez l’enseignant.'),
        ),
        const SizedBox(height: 18),
        PrReveal(
          child: PrCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              step(
                1,
                s.pn('Department', 'Département'),
                PnAsync<List<DepartmentFull>>(
                  value: depts,
                  strings: s,
                  skeletonRows: 1,
                  onRetry: () => ref.invalidate(departmentsFullProvider(widget.schoolId)),
                  builder: (list) => DropdownButtonFormField<DepartmentFull>(
                    initialValue: _department,
                    isExpanded: true,
                    decoration: pnDeco(s.pn('Choose a department', 'Choisir un département')),
                    items: [for (final d in list) DropdownMenuItem(value: d, child: Text(d.departmentName))],
                    onChanged: (v) => setState(() {
                      _department = v;
                      _class = null;
                      _subject = null;
                    }),
                  ),
                ),
              ),
              step(
                2,
                s.pn('Class', 'Classe'),
                _department == null
                    ? const SizedBox(height: 4)
                    : PnAsync<List<ManagedClass>>(
                        value: ref.watch(managedClassesProvider(widget.schoolId)),
                        strings: s,
                        skeletonRows: 1,
                        onRetry: () => ref.invalidate(managedClassesProvider(widget.schoolId)),
                        builder: (all) {
                          final list = all.where((c) => c.departmentId == _department!.id && c.isActive).toList();
                          if (list.isEmpty) return Text(s.pn('No active class in this department.', 'Aucune classe active dans ce département.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline));
                          return DropdownButtonFormField<ManagedClass>(
                            initialValue: _class,
                            isExpanded: true,
                            decoration: pnDeco(s.pn('Choose a class', 'Choisir une classe')),
                            items: [for (final c in list) DropdownMenuItem(value: c, child: Text(c.className))],
                            onChanged: (v) => setState(() => _class = v),
                          );
                        },
                      ),
                active: _department != null,
              ),
              step(
                3,
                s.pn('Subject', 'Matière'),
                _department == null
                    ? const SizedBox(height: 4)
                    : PnAsync<List<SubjectWithCoefficient>>(
                        value: ref.watch(subjectsForDepartmentProvider(_department!.id)),
                        strings: s,
                        skeletonRows: 1,
                        onRetry: () => ref.invalidate(subjectsForDepartmentProvider(_department!.id)),
                        builder: (list) => DropdownButtonFormField<String>(
                          initialValue: _subject?.subjectId,
                          isExpanded: true,
                          decoration: pnDeco(s.pn('Choose a subject', 'Choisir une matière')),
                          items: [for (final x in list) DropdownMenuItem(value: x.subjectId, child: Text(x.subjectName))],
                          onChanged: (v) => setState(() => _subject = list.firstWhere((x) => x.subjectId == v)),
                        ),
                      ),
                active: _department != null && _class != null,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_ready
                    ? const SizedBox(width: double.infinity)
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Divider(height: 28),
                        step(
                          4,
                          s.pn('Schedule', 'Horaire'),
                          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              Text(s.pn('Periods per week', 'Périodes par semaine'), style: theme.textTheme.bodyMedium),
                              const Spacer(),
                              IconButton.filledTonal(onPressed: _periods > 1 ? () => setState(() => _periods--) : null, icon: const Icon(Icons.remove_rounded)),
                              SizedBox(width: 44, child: Center(child: Text('$_periods', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)))),
                              IconButton.filledTonal(onPressed: _periods < 20 ? () => setState(() => _periods++) : null, icon: const Icon(Icons.add_rounded)),
                            ]),
                            const SizedBox(height: 14),
                            Text(s.pn('Preferred teaching days (optional)', 'Jours d’enseignement préférés (facultatif)'), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(s.pn('Select every day the teacher can be free.', 'Sélectionnez tous les jours où l’enseignant peut être libre.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                            const SizedBox(height: 8),
                            PnDayChips(strings: s, selected: _days, onChanged: (v) => setState(() {
                                  _days
                                    ..clear()
                                    ..addAll(v);
                                })),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(true), icon: const Icon(Icons.schedule_rounded, size: 18), label: Text(_start == null ? s.pn('Start time', 'Heure de début') : pnHm(_start!)))),
                              const SizedBox(width: 10),
                              Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(false), icon: const Icon(Icons.schedule_rounded, size: 18), label: Text(_end == null ? s.pn('End time', 'Heure de fin') : pnHm(_end!)))),
                            ]),
                            if (timeInvalid)
                              Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.pn('The end time must be after the start time.', 'L’heure de fin doit être après l’heure de début.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.error))),
                          ]),
                        ),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: timeInvalid
                                ? null
                                : () => pnSheet<void>(
                                      context,
                                      (_) => SelectTeacherDialog(
                                        schoolId: widget.schoolId,
                                        strings: s,
                                        classId: _class!.id,
                                        className: _class!.className,
                                        subjectId: _subject!.subjectId,
                                        subjectName: _subject!.subjectName,
                                        periodsPerWeek: _periods,
                                        preferredDays: _days.isEmpty ? null : (_days.toList()..sort()),
                                        preferredStartTime: _fmt(_start),
                                        preferredEndTime: _fmt(_end),
                                      ),
                                    ),
                            icon: const Icon(Icons.person_search_rounded),
                            label: Text(s.pn('Select a teacher', 'Choisir un enseignant')),
                          ),
                        ),
                      ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SELECT TEACHER: approve pending ones inline, assign in one step
// ============================================================

class SelectTeacherDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final int periodsPerWeek;
  final List<int>? preferredDays;
  final String? preferredStartTime;
  final String? preferredEndTime;

  const SelectTeacherDialog({
    super.key,
    required this.schoolId,
    required this.strings,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.periodsPerWeek,
    this.preferredDays,
    this.preferredStartTime,
    this.preferredEndTime,
  });

  @override
  ConsumerState<SelectTeacherDialog> createState() => _SelectTeacherDialogState();
}

class _SelectTeacherDialogState extends ConsumerState<SelectTeacherDialog> {
  String? _busyId;
  String _query = '';

  AppStrings get _s => widget.strings;

  Future<void> _confirm(PnTeacher t) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: t.isApproved ? s.pn('Assign ${t.fullName}?', 'Affecter ${t.fullName} ?') : s.pn('Approve & assign ${t.fullName}?', 'Approuver et affecter ${t.fullName} ?'),
      message: t.isApproved
          ? s.pn('${t.fullName} will teach ${widget.subjectName} in ${widget.className}.', '${t.fullName} enseignera ${widget.subjectName} en ${widget.className}.')
          : s.pn(
              '${t.fullName} is not yet approved at this school. This approves their account AND assigns them to teach ${widget.subjectName} in ${widget.className}.',
              '${t.fullName} n’est pas encore approuvé(e) dans cet établissement. Cela approuve son compte ET l’affecte à ${widget.subjectName} en ${widget.className}.'),
      confirmLabel: t.isApproved ? s.pn('Assign', 'Affecter') : s.pn('Approve & assign', 'Approuver et affecter'),
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = t.id);
    try {
      final repo = ref.read(principalRepositoryProvider);
      final yearId = await repo.getCurrentAcademicYearId(widget.schoolId);
      final principal = await ref.read(principalProfileProvider.future);
      if (yearId == null) throw Exception('no_current_year');
      if (principal == null) throw Exception('profile');
      await repo.approveAndAssign(
        schoolId: widget.schoolId,
        academicYearId: yearId,
        teacherId: t.id,
        wasAlreadyApproved: t.isApproved,
        principalId: principal.principalId,
        classId: widget.classId,
        subjectId: widget.subjectId,
        periodsPerWeek: widget.periodsPerWeek,
        preferredDays: widget.preferredDays,
        preferredStartTime: widget.preferredStartTime,
        preferredEndTime: widget.preferredEndTime,
      );
      ref.invalidate(pnTeachersProvider);
      ref.invalidate(pnOverviewProvider);
      if (mounted) {
        final nav = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        nav.pop();
        messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(s.pn('${t.fullName} assigned to ${widget.subjectName}, ${widget.className}.', '${t.fullName} affecté(e) à ${widget.subjectName}, ${widget.className}.'))));
      }
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(PnTeacher t) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Reject ${t.fullName}?', 'Refuser ${t.fullName} ?'),
      message: s.pn('This account will not gain teacher access at this school.', 'Ce compte n’aura pas accès enseignant dans cet établissement.'),
      confirmLabel: s.pn('Reject', 'Refuser'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      final principal = await ref.read(principalProfileProvider.future);
      if (principal == null) throw Exception('profile');
      await ref.read(principalRepositoryProvider).rejectTeacher(t.id, principal.principalId);
      ref.invalidate(pnTeachersProvider);
      ref.invalidate(pnOverviewProvider);
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(pnTeachersProvider(null));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.pn('Select a teacher', 'Choisir un enseignant'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${widget.subjectName} · ${widget.className} · ${s.pn('${widget.periodsPerWeek} periods/week', '${widget.periodsPerWeek} périodes/semaine')}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => setState(() => _query = v.toLowerCase()), decoration: pnDeco(s.pn('Search teachers', 'Rechercher un enseignant'), icon: Icons.search_rounded)),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: PnAsync<List<PnTeacher>>(
                value: async,
                strings: s,
                onRetry: () => ref.invalidate(pnTeachersProvider),
                isEmpty: (d) => d.isEmpty,
                empty: PnEmpty(icon: Icons.person_off_rounded, title: s.pn('No teachers yet', 'Aucun enseignant'), text: s.pn('Teachers who sign up at this school will appear here.', 'Les enseignants qui s’inscrivent dans cet établissement apparaîtront ici.')),
                builder: (all) {
                  final list = all.where((t) => _query.isEmpty || t.fullName.toLowerCase().contains(_query)).toList();
                  if (list.isEmpty) return PnEmpty(icon: Icons.search_off_rounded, title: s.pn('No match', 'Aucun résultat'));
                  return Column(children: [
                    for (var i = 0; i < list.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PrReveal(
                          index: i > 8 ? 8 : i,
                          child: PrCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              PnAvatar(stored: list[i].photo, bucket: pnStaffPhotos, name: list[i].fullName, radius: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                    Text(list[i].fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                    if (!list[i].isApproved) PnChip(label: s.pn('Pending', 'En attente'), color: pnWarn()),
                                  ]),
                                  Text([list[i].email, list[i].phone].where((e) => e != null && e.isNotEmpty).join(' · '), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                              if (!list[i].isApproved) IconButton(icon: Icon(Icons.close_rounded, color: cs.error), tooltip: s.pn('Reject', 'Refuser'), onPressed: _busyId != null ? null : () => _reject(list[i])),
                              FilledButton(
                                onPressed: _busyId != null ? null : () => _confirm(list[i]),
                                child: _busyId == list[i].id ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(list[i].isApproved ? s.pn('Assign', 'Affecter') : s.pn('Approve & assign', 'Approuver')),
                              ),
                            ]),
                          ),
                        ),
                      ),
                  ]);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================
// TEACHER OVERVIEW: every teacher with their assignments
// ============================================================

enum _TeacherFilter { all, assigned, unassigned, pending }

class TeacherOverviewPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const TeacherOverviewPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<TeacherOverviewPage> createState() => _TeacherOverviewPageState();
}

class _TeacherOverviewPageState extends ConsumerState<TeacherOverviewPage> {
  _TeacherFilter _filter = _TeacherFilter.all;
  String _query = '';
  final _search = TextEditingController();

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _filterLabel(_TeacherFilter f) {
    final s = _s;
    switch (f) {
      case _TeacherFilter.all:
        return s.pn('All', 'Tous');
      case _TeacherFilter.assigned:
        return s.pn('Assigned', 'Affectés');
      case _TeacherFilter.unassigned:
        return s.pn('Unassigned', 'Non affectés');
      case _TeacherFilter.pending:
        return s.pn('Pending', 'En attente');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(pnTeachersProvider(null));
    return PrPage(
      maxWidth: 900,
      onRefresh: () async {
        await ref.refresh(pnTeachersProvider(null).future);
      },
      children: [
        PrHeader(
          title: s.pn('Teacher overview', 'Vue des enseignants'),
          subtitle: s.pn('Every teacher who signed up at this school, assigned or not.', 'Tous les enseignants inscrits dans cet établissement, affectés ou non.'),
        ),
        const SizedBox(height: 16),
        Builder(builder: (context) {
            return PnAsync<List<PnTeacher>>(
              value: async,
              strings: s,
              onRetry: () => ref.invalidate(pnTeachersProvider),
              isEmpty: (d) => d.isEmpty,
              empty: PnEmpty(icon: Icons.school_rounded, title: s.pn('No teachers yet', 'Aucun enseignant'), text: s.pn('Teachers who sign up will appear here.', 'Les enseignants inscrits apparaîtront ici.')),
              builder: (all) {
                final assigned = all.where((t) => t.isApproved && t.isAssigned).length;
                final pending = all.where((t) => !t.isApproved).length;
                final free = all.where((t) => t.isApproved && !t.isAssigned).length;
                final q = _query.trim().toLowerCase();
                final list = all.where((t) {
                  final matchQ = q.isEmpty || t.fullName.toLowerCase().contains(q);
                  final matchF = switch (_filter) {
                    _TeacherFilter.all => true,
                    _TeacherFilter.assigned => t.isApproved && t.isAssigned,
                    _TeacherFilter.unassigned => t.isApproved && !t.isAssigned,
                    _TeacherFilter.pending => !t.isApproved,
                  };
                  return matchQ && matchF;
                }).toList();
                final totalPeriods = all.fold<int>(0, (a, t) => a + t.assignments.fold<int>(0, (b, x) => b + x.periodsPerWeek));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PrGrid(minTile: 170, max: 4, children: [
                    PrStatTile(icon: Icons.groups_rounded, label: s.pn('Teachers', 'Enseignants'), value: all.length.toDouble(), format: (v) => v.round().toString()),
                    PrStatTile(icon: Icons.assignment_turned_in_rounded, label: s.pn('Assigned', 'Affectés'), value: assigned.toDouble(), format: (v) => v.round().toString()),
                    PrStatTile(icon: Icons.person_outline_rounded, label: s.pn('Unassigned', 'Non affectés'), value: free.toDouble(), format: (v) => v.round().toString()),
                    PrStatTile(icon: Icons.hourglass_top_rounded, label: s.pn('Pending', 'En attente'), value: pending.toDouble(), format: (v) => v.round().toString(), footer: Text(s.pn('$totalPeriods periods/week in all', '$totalPeriods périodes/semaine au total'), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline))),
                  ]),
                  const SizedBox(height: 16),
                  PnSearch(controller: _search, hint: s.pn('Search by name', 'Rechercher par nom'), onChanged: (v) => setState(() => _query = v)),
                  const SizedBox(height: 10),
                  PrPills<_TeacherFilter>(values: _TeacherFilter.values, selected: _filter, label: _filterLabel, onChanged: (f) => setState(() => _filter = f)),
                  const SizedBox(height: 14),
                  if (list.isEmpty)
                    PnEmpty(icon: Icons.search_off_rounded, title: s.pn('No teachers match this filter', 'Aucun enseignant ne correspond'))
                  else
                    for (var i = 0; i < list.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PrReveal(index: i > 8 ? 8 : i, child: _TeacherTile(strings: s, info: list[i])),
                      ),
                ]);
              },
            );
        }),
      ],
    );
  }
}

class _TeacherTile extends StatelessWidget {
  final AppStrings strings;
  final PnTeacher info;
  const _TeacherTile({required this.strings, required this.info});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = info;
    final periods = info.assignments.fold<int>(0, (a, x) => a + x.periodsPerWeek);
    return PrCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: PnAvatar(stored: t.photo, bucket: pnStaffPhotos, name: t.fullName, radius: 20),
          title: Text(t.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              if (!t.isApproved)
                PnChip(label: s.pn('Pending approval', 'En attente d’approbation'), color: pnWarn())
              else if (!info.isAssigned)
                PnChip(label: s.pn('No assignments', 'Aucune affectation'))
              else
                PnChip(label: s.pn('${info.assignments.length} assignment${info.assignments.length == 1 ? '' : 's'} · $periods periods/week', '${info.assignments.length} affectation${info.assignments.length == 1 ? '' : 's'} · $periods périodes/semaine'), color: pnGood()),
            ]),
          ),
          children: [
            _contact(context, Icons.mail_outline_rounded, t.email, s.pn('No email', 'Aucun e-mail')),
            _contact(context, Icons.phone_rounded, t.phone, s.pn('No phone', 'Aucun téléphone')),
            const SizedBox(height: 10),
            if (info.assignments.isEmpty)
              Text(s.pn('No teaching assignments yet.', 'Aucune affectation pour le moment.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, fontStyle: FontStyle.italic))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in info.assignments)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(a.subjectName, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${a.className} · ${s.pn('${a.periodsPerWeek}/week', '${a.periodsPerWeek}/sem.')}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                    ]),
                  ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _contact(BuildContext context, IconData icon, String? value, String empty) {
    final theme = Theme.of(context);
    final has = value != null && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(child: Text(has ? value : empty, style: theme.textTheme.bodySmall?.copyWith(color: has ? null : theme.colorScheme.outline))),
      ]),
    );
  }
}
