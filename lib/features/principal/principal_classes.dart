import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_providers.dart';
import 'principal_kit.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// DEPARTMENTS > (SUBJECTS | CLASSES) > CLASS OFFERINGS
// ============================================================

enum _Tab { subjects, classes }

class ManageClassesPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const ManageClassesPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<ManageClassesPage> createState() => _ManageClassesPageState();
}

class _ManageClassesPageState extends ConsumerState<ManageClassesPage> {
  DepartmentFull? _dept;
  ManagedClass? _class;
  _Tab _tab = _Tab.classes;

  AppStrings get _s => widget.strings;

  void _afterClassChange() {
    ref.invalidate(managedClassesProvider(widget.schoolId));
    ref.invalidate(pnClassesProvider(widget.schoolId));
  }

  Future<void> _departmentSheet({DepartmentFull? existing}) async {
    final s = _s;
    final name = TextEditingController(text: existing?.departmentName ?? '');
    final type = TextEditingController(text: existing?.departmentType ?? 'general');
    final ok = await pnSheet<bool>(
      context,
      (ctx) => PnSheetBody(
        title: existing == null ? s.pn('New department', 'Nouveau département') : s.pn('Edit department', 'Modifier le département'),
        children: [
          TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: pnDeco(s.pn('Department name', 'Nom du département'), hint: s.pn('General Education, Technical…', 'Enseignement général, Technique…'))),
          const SizedBox(height: 12),
          TextField(controller: type, decoration: pnDeco(s.pn('Type', 'Type'), hint: 'general, technical, commercial')),
        ],
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.pn('Cancel', 'Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.pn('Save', 'Enregistrer'))),
        ],
      ),
    );
    final n = name.text.trim();
    final t = type.text.trim();
    name.dispose();
    type.dispose();
    if (ok != true || n.isEmpty || !mounted) return;
    try {
      final repo = ref.read(principalRepositoryProvider);
      if (existing == null) {
        await repo.createDepartment(schoolId: widget.schoolId, name: n, type: t);
      } else {
        await repo.updateDepartment(departmentId: existing.id, name: n, type: t);
        if (_dept?.id == existing.id) _dept = DepartmentFull(id: existing.id, departmentName: n, departmentType: t);
      }
      ref.invalidate(departmentsFullProvider(widget.schoolId));
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  Future<void> _subjectSheet(DepartmentFull dept) async {
    final s = _s;
    List<ManagedSubject> all;
    try {
      all = await ref.read(managedSubjectsProvider(widget.schoolId).future);
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
      return;
    }
    if (!mounted) return;
    final name = TextEditingController();
    final code = TextEditingController();
    final coef = TextEditingController(text: '2');
    ManagedSubject? pick;
    final ok = await pnSheet<bool>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, set) => PnSheetBody(
          title: s.pn('Add a subject to ${dept.departmentName}', 'Ajouter une matière à ${dept.departmentName}'),
          children: [
            DropdownButtonFormField<ManagedSubject?>(
              initialValue: pick,
              isExpanded: true,
              decoration: pnDeco(s.pn('Use an existing subject (optional)', 'Utiliser une matière existante (facultatif)')),
              items: [
                DropdownMenuItem(value: null, child: Text(s.pn('Create a new subject', 'Créer une nouvelle matière'))),
                for (final x in all) DropdownMenuItem(value: x, child: Text('${x.subjectName} (${x.subjectCode})')),
              ],
              onChanged: (v) => set(() => pick = v),
            ),
            if (pick == null) ...[
              const SizedBox(height: 12),
              TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: pnDeco(s.pn('Subject name', 'Nom de la matière'))),
              const SizedBox(height: 12),
              TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: pnDeco(s.pn('Subject code', 'Code de la matière'), hint: 'MATH')),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: coef,
              keyboardType: TextInputType.number,
              decoration: pnDeco(s.pn('Coefficient in ${dept.departmentName}', 'Coefficient en ${dept.departmentName}')).copyWith(helperText: s.pn('How heavily it counts toward the average here.', 'Poids de la matière dans la moyenne ici.')),
            ),
          ],
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.pn('Cancel', 'Annuler'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.pn('Save', 'Enregistrer'))),
          ],
        ),
      ),
    );
    final c = (int.tryParse(coef.text.trim()) ?? 1).clamp(1, 20).toInt();
    final n = name.text.trim();
    final cd = code.text.trim().toUpperCase();
    name.dispose();
    code.dispose();
    coef.dispose();
    if (ok != true || !mounted) return;
    if (pick == null && (n.isEmpty || cd.isEmpty)) {
      prSnack(context, s.pn('Enter a subject name and code.', 'Saisissez le nom et le code de la matière.'));
      return;
    }
    try {
      final repo = ref.read(principalRepositoryProvider);
      if (pick != null) {
        await repo.attachExistingSubjectToDepartment(subjectId: pick!.id, departmentId: dept.id, coefficient: c);
      } else {
        await repo.createSubjectInDepartment(schoolId: widget.schoolId, departmentId: dept.id, subjectCode: cd, subjectName: n, coefficient: c);
      }
      ref.invalidate(subjectsForDepartmentProvider(dept.id));
      ref.invalidate(managedSubjectsProvider(widget.schoolId));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  Future<void> _coefSheet(DepartmentFull dept, SubjectWithCoefficient sub) async {
    final s = _s;
    final ctrl = TextEditingController(text: '${sub.coefficient}');
    final ok = await pnSheet<bool>(
      context,
      (ctx) => PnSheetBody(
        title: s.pn('Coefficient for ${sub.subjectName}', 'Coefficient de ${sub.subjectName}'),
        children: [TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, decoration: pnDeco(s.pn('Coefficient', 'Coefficient')))],
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.pn('Cancel', 'Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.pn('Save', 'Enregistrer'))),
        ],
      ),
    );
    final v = int.tryParse(ctrl.text.trim());
    ctrl.dispose();
    if (ok != true || v == null || v < 1 || !mounted) return;
    try {
      await ref.read(principalRepositoryProvider).updateSubjectCoefficient(subjectId: sub.subjectId, departmentId: dept.id, coefficient: v);
      ref.invalidate(subjectsForDepartmentProvider(dept.id));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  Future<void> _classSheet(DepartmentFull dept, {ManagedClass? existing}) async {
    final s = _s;
    final name = TextEditingController(text: existing?.className ?? '');
    final code = TextEditingController(text: existing?.classCode ?? '');
    final level = TextEditingController(text: existing?.levelOrder.toString() ?? '');
    final cap = TextEditingController(text: existing?.maxStudents.toString() ?? '50');
    final ok = await pnSheet<bool>(
      context,
      (ctx) => PnSheetBody(
        title: existing == null ? s.pn('New class in ${dept.departmentName}', 'Nouvelle classe en ${dept.departmentName}') : s.pn('Edit class', 'Modifier la classe'),
        children: [
          TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: pnDeco(s.pn('Class name', 'Nom de la classe'), hint: 'Form 1E')),
          const SizedBox(height: 12),
          TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: pnDeco(s.pn('Class code', 'Code de la classe'), hint: 'F1E')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: level, keyboardType: TextInputType.number, decoration: pnDeco(s.pn('Level order', 'Ordre du niveau')))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: cap, keyboardType: TextInputType.number, decoration: pnDeco(s.pn('Capacity', 'Capacité')))),
          ]),
        ],
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.pn('Cancel', 'Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.pn('Save', 'Enregistrer'))),
        ],
      ),
    );
    final n = name.text.trim();
    final cd = code.text.trim().toUpperCase();
    final lv = int.tryParse(level.text.trim()) ?? 0;
    final cp = (int.tryParse(cap.text.trim()) ?? 50).clamp(1, 500).toInt();
    name.dispose();
    code.dispose();
    level.dispose();
    cap.dispose();
    if (ok != true || n.isEmpty || !mounted) return;
    try {
      final repo = ref.read(principalRepositoryProvider);
      if (existing == null) {
        final c = await repo.createClass(schoolId: widget.schoolId, className: n, classCode: cd.isEmpty ? null : cd, departmentId: dept.id, levelOrder: lv, maxStudents: cp);
        _afterClassChange();
        if (!mounted) return;
        final now = await pnConfirm(
          context,
          s,
          title: s.pn('${c.className} created', '${c.className} créée'),
          message: s.pn('Configure which subjects this class offers now? You can always do it later.', 'Configurer maintenant les matières de cette classe ? Vous pourrez toujours le faire plus tard.'),
          confirmLabel: s.pn('Configure now', 'Configurer'),
        );
        if (now && mounted) setState(() => _class = c);
      } else {
        await repo.updateClass(classId: existing.id, className: n, classCode: cd.isEmpty ? null : cd, departmentId: dept.id, levelOrder: lv, maxStudents: cp);
        _afterClassChange();
      }
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  Future<void> _toggleActive(ManagedClass c) async {
    final s = _s;
    try {
      await ref.read(principalRepositoryProvider).setClassActive(c.id, !c.isActive);
      _afterClassChange();
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final stage = _dept == null ? 'd' : (_class == null ? 'x${_tab.name}${_dept!.id}' : 'o${_class!.id}');
    return PrPage(
      maxWidth: 900,
      onRefresh: () async {
        ref.invalidate(managedClassesProvider(widget.schoolId));
        ref.invalidate(departmentsFullProvider(widget.schoolId));
        await ref.refresh(departmentsFullProvider(widget.schoolId).future);
      },
      children: [
        PnStage(
          stageKey: stage,
          child: _dept == null ? _departments(s) : (_class == null ? _departmentDetail(s, _dept!) : _offerings(s, _dept!, _class!)),
        ),
      ],
    );
  }

  Widget _departments(AppStrings s) {
    final depts = ref.watch(departmentsFullProvider(widget.schoolId));
    final classes = ref.watch(managedClassesProvider(widget.schoolId)).valueOrNull ?? const <ManagedClass>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PrHeader(
        title: s.pn('Departments', 'Départements'),
        subtitle: s.pn('Pick a department to manage its classes and subjects.', 'Choisissez un département pour gérer ses classes et ses matières.'),
        trailing: FilledButton.icon(onPressed: () => _departmentSheet(), icon: const Icon(Icons.add_rounded, size: 18), label: Text(s.pn('New department', 'Nouveau département'))),
      ),
      const SizedBox(height: 16),
      PnAsync<List<DepartmentFull>>(
        value: depts,
        strings: s,
        onRetry: () => ref.invalidate(departmentsFullProvider(widget.schoolId)),
        isEmpty: (d) => d.isEmpty,
        empty: PnEmpty(
          icon: Icons.folder_open_rounded,
          title: s.pn('No departments yet', 'Aucun département'),
          text: s.pn('Create one to start adding classes and subjects.', 'Créez-en un pour commencer à ajouter des classes et des matières.'),
          action: FilledButton.icon(onPressed: () => _departmentSheet(), icon: const Icon(Icons.add_rounded), label: Text(s.pn('New department', 'Nouveau département'))),
        ),
        builder: (list) => Column(children: [
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PnPickTile(
                index: i,
                icon: Icons.folder_rounded,
                title: list[i].departmentName,
                subtitle: [if (list[i].departmentType != null) list[i].departmentType!, s.pn('${classes.where((c) => c.departmentId == list[i].id).length} classes', '${classes.where((c) => c.departmentId == list[i].id).length} classes')].join(' · '),
                trailing: IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: s.pn('Edit', 'Modifier'), onPressed: () => _departmentSheet(existing: list[i])),
                onTap: () => setState(() => _dept = list[i]),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _departmentDetail(AppStrings s, DepartmentFull dept) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PnCrumbs(labels: [s.pn('Departments', 'Départements'), dept.departmentName], onTap: (_) => setState(() => _dept = null)),
      const SizedBox(height: 8),
      PrPills<_Tab>(values: _Tab.values, selected: _tab, label: (t) => t == _Tab.subjects ? s.pn('Subjects & coefficients', 'Matières et coefficients') : s.pn('Classes', 'Classes'), onChanged: (t) => setState(() => _tab = t)),
      const SizedBox(height: 14),
      if (_tab == _Tab.subjects) _subjectsTab(s, dept) else _classesTab(s, dept),
    ]);
  }

  Widget _subjectsTab(AppStrings s, DepartmentFull dept) {
    final theme = Theme.of(context);
    final async = ref.watch(subjectsForDepartmentProvider(dept.id));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _subjectSheet(dept), icon: const Icon(Icons.add_rounded, size: 18), label: Text(s.pn('Add subject', 'Ajouter une matière')))),
      const SizedBox(height: 12),
      PnAsync<List<SubjectWithCoefficient>>(
        value: async,
        strings: s,
        onRetry: () => ref.invalidate(subjectsForDepartmentProvider(dept.id)),
        isEmpty: (d) => d.isEmpty,
        empty: PnEmpty(icon: Icons.menu_book_rounded, title: s.pn('No subjects yet', 'Aucune matière'), text: s.pn('Add the subjects taught in this department.', 'Ajoutez les matières enseignées dans ce département.')),
        builder: (list) => Column(children: [
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrReveal(
                index: i > 8 ? 8 : i,
                child: PrCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(list[i].subjectName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text(list[i].subjectCode, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                      ]),
                    ),
                    PnChip(label: s.pn('Coef. ${list[i].coefficient}', 'Coef. ${list[i].coefficient}'), color: theme.colorScheme.primary),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _coefSheet(dept, list[i])),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _classesTab(AppStrings s, DepartmentFull dept) {
    final theme = Theme.of(context);
    final async = ref.watch(managedClassesProvider(widget.schoolId));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _classSheet(dept), icon: const Icon(Icons.add_rounded, size: 18), label: Text(s.pn('New class', 'Nouvelle classe')))),
      const SizedBox(height: 12),
      PnAsync<List<ManagedClass>>(
        value: async,
        strings: s,
        onRetry: () => ref.invalidate(managedClassesProvider(widget.schoolId)),
        builder: (all) {
          final list = all.where((c) => c.departmentId == dept.id).toList();
          if (list.isEmpty) return PnEmpty(icon: Icons.groups_rounded, title: s.pn('No classes yet', 'Aucune classe'), text: s.pn('Create the first class of this department.', 'Créez la première classe de ce département.'));
          return Column(children: [
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PnPickTile(
                  index: i,
                  icon: Icons.groups_rounded,
                  title: list[i].className,
                  subtitle: s.pn('Capacity ${list[i].maxStudents}', 'Capacité ${list[i].maxStudents}'),
                  badge: list[i].isActive ? null : s.pn('Archived', 'Archivée'),
                  badgeColor: theme.colorScheme.outline,
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (v) {
                      if (v == 'edit') _classSheet(dept, existing: list[i]);
                      if (v == 'active') _toggleActive(list[i]);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(s.pn('Edit', 'Modifier'))),
                      PopupMenuItem(value: 'active', child: Text(list[i].isActive ? s.pn('Archive', 'Archiver') : s.pn('Restore', 'Restaurer'))),
                    ],
                  ),
                  onTap: () => setState(() => _class = list[i]),
                ),
              ),
          ]);
        },
      ),
    ]);
  }

  Widget _offerings(AppStrings s, DepartmentFull dept, ManagedClass c) {
    final theme = Theme.of(context);
    final key = (schoolId: widget.schoolId, classId: c.id);
    final async = ref.watch(subjectOfferingsForClassProvider(key));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PnCrumbs(
        labels: [s.pn('Departments', 'Départements'), dept.departmentName, c.className],
        onTap: (i) => setState(() {
          _class = null;
          if (i == 0) _dept = null;
        }),
      ),
      const SizedBox(height: 4),
      Text(s.pn('Turn a subject on to offer it in this class. Mark it compulsory to lock it in during enrollment.', 'Activez une matière pour l’offrir dans cette classe. Rendez-la obligatoire pour la verrouiller lors de l’inscription.'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.4)),
      const SizedBox(height: 14),
      PnAsync<List<SubjectOfferingRow>>(
        value: async,
        strings: s,
        onRetry: () => ref.invalidate(subjectOfferingsForClassProvider(key)),
        isEmpty: (d) => d.isEmpty,
        empty: PnEmpty(icon: Icons.menu_book_rounded, title: s.pn('No subjects at this school yet', 'Aucune matière dans cet établissement')),
        builder: (list) => Column(children: [
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OfferingRow(
                strings: s,
                row: list[i],
                onChange: (offered, compulsory) async {
                  try {
                    await ref.read(principalRepositoryProvider).setSubjectOffering(classId: c.id, subjectId: list[i].subjectId, isOffered: offered, isCompulsory: compulsory);
                    ref.invalidate(subjectOfferingsForClassProvider(key));
                  } catch (e) {
                    if (mounted) prSnack(context, pnErr(s, e));
                  }
                },
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _OfferingRow extends StatelessWidget {
  final AppStrings strings;
  final SubjectOfferingRow row;
  final Future<void> Function(bool offered, bool compulsory) onChange;
  const _OfferingRow({required this.strings, required this.row, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PrCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(child: Text(row.subjectName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: row.isOffered ? null : cs.outline))),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: row.isOffered
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(s.pn('Compulsory', 'Obligatoire'), style: theme.textTheme.labelSmall),
                  Switch(value: row.isCompulsory, onChanged: (v) => onChange(true, v)),
                  const SizedBox(width: 8),
                ])
              : const SizedBox.shrink(),
        ),
        Text(row.isOffered ? s.pn('Offered', 'Offerte') : s.pn('Off', 'Non'), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        Switch(value: row.isOffered, onChanged: (v) => onChange(v, false)),
      ]),
    );
  }
}

// ============================================================
// ALL SUBJECTS (browse): by department, which classes and teachers
// ============================================================

class SubjectBrowsePage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const SubjectBrowsePage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<SubjectBrowsePage> createState() => _SubjectBrowsePageState();
}

class _SubjectBrowsePageState extends ConsumerState<SubjectBrowsePage> {
  final _search = TextEditingController();
  String _query = '';
  bool _onlyGaps = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final yearAsync = ref.watch(principalCurrentAcademicYearIdProvider(widget.schoolId));
    return PrPage(
      maxWidth: 900,
      children: [
        PrHeader(
          title: s.pn('All subjects', 'Toutes les matières'),
          subtitle: s.pn('Grouped by department. Expand a subject to see where it is offered and who teaches it.', 'Regroupées par département. Ouvrez une matière pour voir où elle est offerte et qui l’enseigne.'),
        ),
        const SizedBox(height: 16),
        PnAsync<String?>(
          value: yearAsync,
          strings: s,
          onRetry: () => ref.invalidate(principalCurrentAcademicYearIdProvider(widget.schoolId)),
          isEmpty: (y) => y == null,
          empty: PnEmpty(icon: Icons.event_busy_rounded, title: s.pn('No current academic year', 'Aucune année scolaire en cours')),
          builder: (yearId) {
            final key = (schoolId: widget.schoolId, academicYearId: yearId!);
            return PnAsync<List<SubjectBrowseItem>>(
              value: ref.watch(subjectBrowseListProvider(key)),
              strings: s,
              onRetry: () => ref.invalidate(subjectBrowseListProvider(key)),
              isEmpty: (d) => d.isEmpty,
              empty: PnEmpty(icon: Icons.menu_book_rounded, title: s.pn('No subjects yet', 'Aucune matière'), text: s.pn('Add subjects from Classes & subjects.', 'Ajoutez des matières depuis Classes et matières.')),
              builder: (items) {
                final q = _query.trim().toLowerCase();
                final shown = items.where((x) => (q.isEmpty || x.subjectName.toLowerCase().contains(q)) && (!_onlyGaps || x.teachersAssigned.isEmpty)).toList();
                final gaps = items.where((x) => x.teachersAssigned.isEmpty).length;
                final grouped = <String, List<SubjectBrowseItem>>{};
                for (final x in shown) {
                  grouped.putIfAbsent(x.departmentName, () => []).add(x);
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (gaps > 0) PnNotice(icon: Icons.person_off_rounded, color: pnWarn(), text: s.pn('$gaps subject${gaps == 1 ? '' : 's'} have no teacher assigned yet.', '$gaps matière${gaps == 1 ? '' : 's'} sans enseignant affecté.')),
                  if (gaps > 0) const SizedBox(height: 12),
                  PnSearch(controller: _search, hint: s.pn('Search a subject', 'Rechercher une matière'), onChanged: (v) => setState(() => _query = v)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(label: Text(s.pn('Without a teacher', 'Sans enseignant')), selected: _onlyGaps, onSelected: (v) => setState(() => _onlyGaps = v)),
                  ),
                  const SizedBox(height: 12),
                  if (grouped.isEmpty)
                    PnEmpty(icon: Icons.search_off_rounded, title: s.pn('No match', 'Aucun résultat'))
                  else
                    for (final e in grouped.entries.toList().asMap().entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: PrReveal(
                          index: e.key,
                          child: PnPanel(
                            title: e.value.key,
                            subtitle: s.pn('${e.value.value.length} subjects', '${e.value.value.length} matières'),
                            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                            child: Column(children: [
                              for (final sub in e.value.value)
                                Theme(
                                  data: theme.copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                                    childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                    title: Text(sub.subjectName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    subtitle: Text(s.pn('Coefficient ${sub.coefficient}', 'Coefficient ${sub.coefficient}'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                                    trailing: sub.teachersAssigned.isEmpty ? PnChip(label: s.pn('No teacher', 'Sans enseignant'), color: pnWarn()) : null,
                                    children: [
                                      _chips(context, s.pn('Offered in', 'Offerte en'), sub.classesOffering, s.pn('No class yet', 'Aucune classe')),
                                      const SizedBox(height: 10),
                                      _chips(context, s.pn('Taught by', 'Enseignée par'), sub.teachersAssigned, s.pn('No teacher assigned yet', 'Aucun enseignant affecté')),
                                    ],
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      ),
                ]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _chips(BuildContext context, String label, List<String> values, String empty) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 4),
      if (values.isEmpty)
        Text(empty, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))
      else
        Wrap(spacing: 6, runSpacing: 6, children: [for (final v in values) PnChip(label: v)]),
    ]);
  }
}

// ============================================================
// SCHOOL FEES: registration fee + installments per class
// ============================================================

class _InstDraft {
  final String? id;
  final TextEditingController name;
  final TextEditingController amount;
  DateTime? due;
  _InstDraft({this.id, required String name, required double amt, this.due})
      : name = TextEditingController(text: name),
        amount = TextEditingController(text: amt == 0 ? '' : amt.toStringAsFixed(0));

  double get value => double.tryParse(amount.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class ManageFeesEntryPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const ManageFeesEntryPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<ManageFeesEntryPage> createState() => _ManageFeesEntryPageState();
}

class _ManageFeesEntryPageState extends ConsumerState<ManageFeesEntryPage> {
  ManagedClass? _class;
  final _reg = TextEditingController();
  final List<_InstDraft> _rows = [];
  final List<String> _removed = [];
  String? _feeId;
  bool _loading = false;
  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;
  Object? _loadError;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _reg.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load(String classId, String yearId) async {
    setState(() {
      _loading = true;
      _loaded = false;
      _loadError = null;
    });
    try {
      final cfg = await ref.read(principalRepositoryProvider).getFeeConfig(classId: classId, academicYearId: yearId);
      if (!mounted) return;
      for (final r in _rows) {
        r.dispose();
      }
      _rows
        ..clear()
        ..addAll([for (final i in cfg.installments) _InstDraft(id: i.id, name: i.name, amt: i.amount, due: i.dueDate)]);
      _removed.clear();
      setState(() {
        _reg.text = cfg.registrationFee == 0 ? '' : cfg.registrationFee.toStringAsFixed(0);
        _feeId = cfg.feeId;
        _loaded = true;
        _dirty = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickClass(ManagedClass c, String yearId) async {
    if (_dirty) {
      final ok = await pnConfirm(context, _s, title: _s.pn('Discard unsaved changes?', 'Abandonner les modifications ?'), message: _s.pn('You have unsaved changes for ${_class?.className}.', 'Vous avez des modifications non enregistrées pour ${_class?.className}.'), confirmLabel: _s.pn('Discard', 'Abandonner'), destructive: true);
      if (!ok || !mounted) return;
    }
    setState(() => _class = c);
    await _load(c.id, yearId);
  }

  Future<void> _save(String yearId) async {
    final s = _s;
    for (final r in _rows) {
      if (r.name.text.trim().isEmpty) {
        prSnack(context, s.pn('Every installment needs a name.', 'Chaque tranche doit avoir un nom.'));
        return;
      }
      if (r.value <= 0) {
        prSnack(context, s.pn('Every installment needs an amount above 0.', 'Chaque tranche doit avoir un montant supérieur à 0.'));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final reg = double.tryParse(_reg.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
      await ref.read(principalHubRepositoryProvider).saveFeesSafe(
            schoolId: widget.schoolId,
            classId: _class!.id,
            yearId: yearId,
            feeId: _feeId,
            registrationFee: reg,
            installments: [for (final r in _rows) (id: r.id, name: r.name.text.trim(), amount: r.value, due: r.due)],
            removedIds: List.of(_removed),
          );
      ref.invalidate(pnCalendarProvider);
      if (mounted) prSnack(context, s.pn('Fee configuration saved.', 'Configuration des frais enregistrée.'));
      await _load(_class!.id, yearId);
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _add() {
    setState(() {
      _rows.add(_InstDraft(name: _s.pn('Installment ${_rows.length + 1}', 'Tranche ${_rows.length + 1}'), amt: 0));
      _dirty = true;
    });
  }

  void _remove(int i) {
    setState(() {
      final r = _rows.removeAt(i);
      if (r.id != null) _removed.add(r.id!);
      r.dispose();
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final yearAsync = ref.watch(principalCurrentAcademicYearIdProvider(widget.schoolId));
    final classes = ref.watch(managedClassesProvider(widget.schoolId));
    return PrPage(
      maxWidth: 820,
      children: [
        PrHeader(
          title: s.pn('School fees', 'Frais de scolarité'),
          subtitle: s.pn('Set the registration fee and the installments of each class for the current year.', 'Définissez les frais d’inscription et les tranches de chaque classe pour l’année en cours.'),
        ),
        const SizedBox(height: 16),
        PnAsync<String?>(
          value: yearAsync,
          strings: s,
          onRetry: () => ref.invalidate(principalCurrentAcademicYearIdProvider(widget.schoolId)),
          isEmpty: (y) => y == null,
          empty: PnEmpty(icon: Icons.event_busy_rounded, title: s.pn('No current academic year', 'Aucune année scolaire en cours'), text: s.pn('Set the current year in the Calendar first.', 'Définissez d’abord l’année en cours dans le Calendrier.')),
          builder: (yearId) => PnAsync<List<ManagedClass>>(
            value: classes,
            strings: s,
            onRetry: () => ref.invalidate(managedClassesProvider(widget.schoolId)),
            isEmpty: (d) => d.isEmpty,
            empty: PnEmpty(icon: Icons.groups_rounded, title: s.pn('No classes yet', 'Aucune classe')),
            builder: (all) {
              final list = all.where((c) => c.isActive).toList();
              final total = _rows.fold<double>(0, (a, r) => a + r.value);
              final reg = double.tryParse(_reg.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<String>(
                  initialValue: _class?.id,
                  isExpanded: true,
                  decoration: pnDeco(s.pn('Select a class', 'Choisir une classe'), icon: Icons.groups_rounded),
                  items: [for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.className))],
                  onChanged: (v) {
                    if (v != null) _pickClass(list.firstWhere((c) => c.id == v), yearId!);
                  },
                ),
                const SizedBox(height: 16),
                if (_class == null)
                  PnEmpty(icon: Icons.payments_rounded, title: s.pn('Choose a class', 'Choisissez une classe'), text: s.pn('Its fees will appear here.', 'Ses frais apparaîtront ici.'))
                else if (_loading)
                  const PnSkeletonList(rows: 3)
                else if (_loadError != null)
                  PnErrorBox(strings: s, error: _loadError!, onRetry: () => _load(_class!.id, yearId!))
                else if (_loaded)
                  PrReveal(
                    child: PrCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (_feeId == null) PnNotice(text: s.pn('No fees are set for ${_class!.className} yet.', 'Aucun frais défini pour ${_class!.className}.')),
                        if (_feeId == null) const SizedBox(height: 14),
                        TextField(controller: _reg, keyboardType: TextInputType.number, onChanged: (_) => setState(() => _dirty = true), decoration: pnDeco(s.pn('Registration fee', 'Frais d’inscription'), suffix: 'FCFA')),
                        const SizedBox(height: 20),
                        Row(children: [
                          Text(s.pn('Installments', 'Tranches'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const Spacer(),
                          TextButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded, size: 18), label: Text(s.pn('Add installment', 'Ajouter une tranche'))),
                        ]),
                        const SizedBox(height: 6),
                        if (_rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(s.pn('No installments yet.', 'Aucune tranche pour le moment.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))),
                        for (var i = 0; i < _rows.length; i++)
                          Container(
                            key: ObjectKey(_rows[i]),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14)),
                            child: LayoutBuilder(builder: (context, c) {
                              final narrow = c.maxWidth < 560;
                              final nameF = TextField(controller: _rows[i].name, onChanged: (_) => setState(() => _dirty = true), decoration: pnDeco(s.pn('Name', 'Nom')));
                              final amtF = TextField(controller: _rows[i].amount, keyboardType: TextInputType.number, onChanged: (_) => setState(() => _dirty = true), decoration: pnDeco(s.pn('Amount', 'Montant'), suffix: 'FCFA'));
                              final dueF = InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final d = await pnPickDate(context, _rows[i].due, first: DateTime.now().subtract(const Duration(days: 400)), last: DateTime.now().add(const Duration(days: 800)));
                                  if (d != null) setState(() {
                                    _rows[i].due = d;
                                    _dirty = true;
                                  });
                                },
                                child: InputDecorator(decoration: pnDeco(s.pn('Due date', 'Échéance'), icon: Icons.event_rounded), child: Text(_rows[i].due == null ? s.pn('Pick a date', 'Choisir une date') : pDate(_rows[i].due!))),
                              );
                              final del = IconButton(icon: Icon(Icons.delete_outline_rounded, color: cs.error), tooltip: s.pn('Remove', 'Retirer'), onPressed: () => _remove(i));
                              if (narrow) {
                                return Column(children: [nameF, const SizedBox(height: 10), amtF, const SizedBox(height: 10), dueF, Align(alignment: Alignment.centerRight, child: del)]);
                              }
                              return Row(children: [Expanded(flex: 3, child: nameF), const SizedBox(width: 10), Expanded(flex: 3, child: amtF), const SizedBox(width: 10), Expanded(flex: 3, child: dueF), del]);
                            }),
                          ),
                        const Divider(height: 28),
                        _sumRow(context, s.pn('Registration', 'Inscription'), reg),
                        _sumRow(context, s.pn('Tuition (installments)', 'Scolarité (tranches)'), total),
                        _sumRow(context, s.pn('Total per student', 'Total par élève'), reg + total, strong: true),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: FilledButton(onPressed: (_saving || !_dirty) ? null : () => _save(yearId!), child: PnBusyLabel(busy: _saving, label: s.pn('Save fee configuration', 'Enregistrer les frais'))),
                        ),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ],
    );
  }

  Widget _sumRow(BuildContext context, String label, double v, {bool strong = false}) {
    final theme = Theme.of(context);
    final st = strong ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900) : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(label, style: st)), Text(pMoney(v), style: st)]),
    );
  }
}
