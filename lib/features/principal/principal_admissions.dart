import 'dart:async';

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
// ADMISSIONS AWAITING APPROVAL
// ============================================================

class AdmissionsReviewPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const AdmissionsReviewPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<AdmissionsReviewPage> createState() => _AdmissionsReviewPageState();
}

class _AdmissionsReviewPageState extends ConsumerState<AdmissionsReviewPage> {
  final Set<String> _busy = {};
  String _query = '';
  String? _classFilter;

  AppStrings get _s => widget.strings;

  void _reload() {
    ref.invalidate(admissionsForReviewProvider(widget.schoolId));
    ref.invalidate(pnOverviewProvider);
  }

  Future<void> _approve(PendingAdmissionReview a) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Approve ${a.fullName}?', 'Approuver ${a.fullName} ?'),
      message: s.pn(
        'This creates the student record, enrolls them in ${a.requestedClassName} and links them to their parent’s account.',
        'Cela crée le dossier de l’élève, l’inscrit en ${a.requestedClassName} et le relie au compte de son parent.',
      ),
      confirmLabel: s.pn('Approve & enroll', 'Approuver et inscrire'),
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(a.id));
    try {
      await ref.read(principalRepositoryProvider).approveAdmission(a.id);
      _reload();
      if (mounted) prSnack(context, s.pn('${a.fullName} approved and enrolled.', '${a.fullName} approuvé(e) et inscrit(e).'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy.remove(a.id));
    }
  }

  Future<void> _reject(PendingAdmissionReview a) async {
    final s = _s;
    final ctrl = TextEditingController();
    final ok = await pnSheet<bool>(
      context,
      (ctx) => PnSheetBody(
        title: s.pn('Reject ${a.fullName}?', 'Refuser ${a.fullName} ?'),
        subtitle: s.pn('The parent will see this request marked as rejected.', 'Le parent verra cette demande marquée comme refusée.'),
        children: [TextField(controller: ctrl, maxLines: 3, decoration: pnDeco(s.pn('Reason (optional)', 'Motif (facultatif)')))],
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.pn('Cancel', 'Annuler'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), onPressed: () => Navigator.pop(ctx, true), child: Text(s.pn('Reject', 'Refuser'))),
        ],
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted) return;
    setState(() => _busy.add(a.id));
    try {
      await ref.read(principalRepositoryProvider).rejectAdmission(a.id, reason);
      _reload();
      if (mounted) prSnack(context, s.pn('Request rejected.', 'Demande refusée.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy.remove(a.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(admissionsForReviewProvider(widget.schoolId));
    ref.listen<int>(pnTickProvider, (_, __) => ref.invalidate(admissionsForReviewProvider(widget.schoolId)));
    return PrPage(
      maxWidth: 900,
      onRefresh: () async => ref.refresh(admissionsForReviewProvider(widget.schoolId).future),
      children: [
        PrHeader(
          title: s.pn('Admissions awaiting approval', 'Admissions en attente'),
          subtitle: s.pn('Review each request, then approve to enroll the student or reject with a reason.', 'Examinez chaque demande, puis approuvez pour inscrire l’élève ou refusez avec un motif.'),
          trailing: FilledButton.tonalIcon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateStudentByPrincipalPage(schoolId: widget.schoolId, strings: s))),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(s.pn('Enroll a student', 'Inscrire un élève')),
          ),
        ),
        const SizedBox(height: 16),
        PnAsync<List<PendingAdmissionReview>>(
          value: async,
          strings: s,
          onRetry: () => ref.invalidate(admissionsForReviewProvider(widget.schoolId)),
          isEmpty: (d) => d.isEmpty,
          empty: PnEmpty(icon: Icons.how_to_reg_rounded, title: s.pn('No admissions waiting', 'Aucune admission en attente'), text: s.pn('New requests from parents will appear here.', 'Les nouvelles demandes des parents apparaîtront ici.')),
          builder: (all) {
            final classes = {for (final a in all) a.requestedClassName}.toList()..sort();
            final q = _query.trim().toLowerCase();
            final list = all.where((a) => (_classFilter == null || a.requestedClassName == _classFilter) && (q.isEmpty || a.fullName.toLowerCase().contains(q))).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Search(hint: s.pn('Search by name', 'Rechercher par nom'), onChanged: (v) => setState(() => _query = v)),
              if (classes.length > 1) ...[
                const SizedBox(height: 10),
                PrPills<String?>(values: [null, ...classes], selected: _classFilter, label: (c) => c ?? s.pn('All classes', 'Toutes les classes'), onChanged: (c) => setState(() => _classFilter = c)),
              ],
              const SizedBox(height: 14),
              if (list.isEmpty)
                PnEmpty(icon: Icons.search_off_rounded, title: s.pn('No match', 'Aucun résultat'))
              else
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PrReveal(
                      index: i > 8 ? 8 : i,
                      child: PrCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            PnAvatar(stored: list[i].photoUrl, name: list[i].fullName, radius: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(list[i].fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  PnChip(label: list[i].requestedClassName, color: cs.primary, icon: Icons.groups_rounded),
                                  if (list[i].dateOfBirth != null) PnChip(label: pDate(list[i].dateOfBirth!), icon: Icons.cake_rounded),
                                ]),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          if (list[i].guardianName != null) _row(s.pn('Guardian', 'Tuteur'), list[i].guardianName!),
                          if (list[i].emergencyContactName != null) _row(s.pn('Emergency contact', 'Contact d’urgence'), '${list[i].emergencyContactName} · ${list[i].emergencyContactPhone ?? ''}'),
                          if (list[i].address != null && list[i].address!.isNotEmpty) _row(s.pn('Address', 'Adresse'), list[i].address!),
                          if (list[i].selectedSubjectNames.isNotEmpty) _row(s.pn('Subjects', 'Matières'), list[i].selectedSubjectNames.join(', ')),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(spacing: 8, runSpacing: 8, children: [
                              OutlinedButton.icon(onPressed: _busy.contains(list[i].id) ? null : () => _reject(list[i]), icon: Icon(Icons.close_rounded, size: 18, color: cs.error), label: Text(s.pn('Reject', 'Refuser'))),
                              FilledButton.icon(
                                onPressed: _busy.contains(list[i].id) ? null : () => _approve(list[i]),
                                icon: _busy.contains(list[i].id) ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded, size: 18),
                                label: Text(s.pn('Approve', 'Approuver')),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
            ]);
          },
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
        Expanded(child: Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.35))),
      ]),
    );
  }
}

class _Search extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _Search({required this.hint, required this.onChanged});
  @override
  State<_Search> createState() => _SearchState();
}

class _SearchState extends State<_Search> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PnSearch(
        controller: _c,
        hint: widget.hint,
        onChanged: (v) {
          widget.onChanged(v);
          setState(() {});
        },
      );
}

// ============================================================
// STUDENT DETAIL (profile + guardians) as a bottom sheet
// ============================================================

Future<void> pnShowStudentDetail(BuildContext context, AppStrings strings, String studentId) {
  return pnSheet<void>(context, (_) => _StudentDetailSheet(strings: strings, studentId: studentId));
}

class _StudentDetailSheet extends ConsumerWidget {
  final AppStrings strings;
  final String studentId;
  const _StudentDetailSheet({required this.strings, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(studentDetailProvider(studentId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: PnAsync<StudentDetail>(
          value: async,
          strings: s,
          skeletonRows: 2,
          onRetry: () => ref.invalidate(studentDetailProvider(studentId)),
          builder: (d) {
            final st = d.student;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: PnAvatar(stored: st.photoUrl, name: st.fullName, radius: 38)),
              const SizedBox(height: 10),
              Text(st.fullName, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              Text(st.admissionNumber, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline)),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                PnChip(label: st.className, color: cs.primary, icon: Icons.groups_rounded),
                if (st.departmentName.isNotEmpty) PnChip(label: st.departmentName),
                PnChip(label: st.currentStatus, color: st.currentStatus == 'active' ? pnGood() : pnWarn()),
              ]),
              const SizedBox(height: 22),
              Text(s.pn('Guardians', 'Tuteurs'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (d.guardians.isEmpty)
                PnEmpty(icon: Icons.family_restroom_rounded, title: s.pn('No guardian on file', 'Aucun tuteur enregistré'))
              else
                for (final g in d.guardians)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(g.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text('(${g.relationshipType})', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                        if (g.isPrimary) PnChip(label: s.pn('Primary', 'Principal'), color: cs.primary),
                        if (g.isEmergencyContact) PnChip(label: s.pn('Emergency', 'Urgence'), color: pnWarn()),
                      ]),
                      if (g.phone != null && g.phone!.isNotEmpty) _contact(context, Icons.phone_rounded, g.phone!, s),
                      if (g.email != null && g.email!.isNotEmpty) _contact(context, Icons.mail_outline_rounded, g.email!, s),
                    ]),
                  ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _contact(BuildContext context, IconData icon, String text, AppStrings s) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => prCopy(context, text, s.pn('Copied', 'Copié')),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          Icon(Icons.copy_rounded, size: 14, color: Theme.of(context).colorScheme.outline),
        ]),
      ),
    );
  }
}

// ============================================================
// PRINCIPAL ENROLLS A STUDENT ON BEHALF OF A PARENT
// Same pipeline as a parent-initiated enrolment: the parent pays the
// registration fee from their own dashboard.
// ============================================================

class CreateStudentByPrincipalPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const CreateStudentByPrincipalPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<CreateStudentByPrincipalPage> createState() => _CreateStudentByPrincipalPageState();
}

class _CreateStudentByPrincipalPageState extends ConsumerState<CreateStudentByPrincipalPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _guardianName = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _address = TextEditingController();
  final _parentSearch = TextEditingController();

  ParentSearchResult? _parent;
  List<ParentSearchResult> _results = [];
  bool _searching = false;
  Timer? _debounce;

  ManagedClass? _class;
  final Set<String> _subjects = {};
  List<SubjectOfferingRow> _offerings = [];
  bool _loadingOfferings = false;
  bool _submitting = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_firstName, _lastName, _guardianName, _emergencyName, _emergencyPhone, _address, _parentSearch]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final r = await ref.read(principalRepositoryProvider).searchParents(widget.schoolId, q.trim());
        if (mounted) setState(() => _results = r);
      } catch (e) {
        if (mounted) prSnack(context, pnErr(_s, e));
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _pickClass(ManagedClass c) async {
    setState(() {
      _class = c;
      _subjects.clear();
      _loadingOfferings = true;
    });
    try {
      final offerings = await ref.read(principalRepositoryProvider).getSubjectOfferingsForClass(widget.schoolId, c.id);
      final offered = offerings.where((o) => o.isOffered).toList();
      if (!mounted) return;
      setState(() {
        _offerings = offered;
        for (final o in offered.where((o) => o.isCompulsory)) {
          _subjects.add(o.subjectId);
        }
      });
    } catch (e) {
      if (mounted) prSnack(context, pnErr(_s, e));
    } finally {
      if (mounted) setState(() => _loadingOfferings = false);
    }
  }

  Future<void> _submit() async {
    final s = _s;
    if (_parent == null) {
      prSnack(context, s.pn('Please select the parent.', 'Veuillez sélectionner le parent.'));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_class == null) {
      prSnack(context, s.pn('Please select a class.', 'Veuillez sélectionner une classe.'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final principal = await ref.read(principalProfileProvider.future);
      if (principal == null) throw Exception('profile');
      final yearId = await ref.read(principalRepositoryProvider).getCurrentAcademicYearId(widget.schoolId);
      if (yearId == null) throw Exception('no_current_year');
      String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      await ref.read(principalRepositoryProvider).createAdmissionOnBehalfOfParent(
            schoolId: widget.schoolId,
            parentId: _parent!.parentId,
            requestedClassId: _class!.id,
            academicYearId: yearId,
            principalUserId: principal.userId,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            guardianName: opt(_guardianName),
            emergencyContactName: opt(_emergencyName),
            emergencyContactPhone: opt(_emergencyPhone),
            address: opt(_address),
            selectedSubjectIds: _subjects.toList(),
          );
      ref.invalidate(pnOverviewProvider);
      if (mounted) {
        prSnack(context, s.pn('Enrollment created. It now appears on ${_parent!.fullName}’s dashboard so the registration fee can be paid.', 'Inscription créée. Elle apparaît maintenant sur le tableau de bord de ${_parent!.fullName} pour le paiement des frais d’inscription.'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final classes = ref.watch(managedClassesProvider(widget.schoolId));
    String? req(String? v) => (v == null || v.trim().isEmpty) ? s.pn('Required', 'Obligatoire') : null;

    Widget step(int n, String title) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Row(children: [
            CircleAvatar(radius: 12, backgroundColor: cs.primary, child: Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onPrimary))),
            const SizedBox(width: 10),
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.pn('Enroll a student', 'Inscrire un élève'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(PrPage.padding(context), 16, PrPage.padding(context), 40),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PnNotice(
                  icon: Icons.info_outline_rounded,
                  text: s.pn(
                    'Use this to enroll a child for a parent who has an account but has not completed enrollment. The parent still pays the registration fee from their own dashboard.',
                    'Utilisez ceci pour inscrire un enfant pour un parent qui a un compte mais n’a pas terminé l’inscription. Le parent paie toujours les frais d’inscription depuis son propre tableau de bord.',
                  ),
                ),
                step(1, s.pn('Select the parent', 'Choisir le parent')),
                if (_parent != null)
                  InputChip(
                    avatar: const Icon(Icons.person_rounded, size: 18),
                    label: Text(_parent!.fullName),
                    onDeleted: () => setState(() => _parent = null),
                  )
                else ...[
                  TextField(
                    controller: _parentSearch,
                    onChanged: _onSearch,
                    decoration: pnDeco(s.pn('Search parent by name', 'Rechercher un parent par nom'), icon: Icons.search_rounded).copyWith(
                      suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        for (final p in _results)
                          ListTile(
                            leading: PrAvatar(name: p.fullName, radius: 16),
                            title: Text(p.fullName),
                            subtitle: Text([p.email, p.phone].where((e) => e != null && e.isNotEmpty).join(' · ')),
                            onTap: () => setState(() {
                              _parent = p;
                              _results = [];
                              _parentSearch.clear();
                            }),
                          ),
                      ]),
                    )
                  else if (_parentSearch.text.trim().length >= 2 && !_searching)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.pn('No parent found.', 'Aucun parent trouvé.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))),
                ],
                step(2, s.pn('Child information', 'Informations sur l’enfant')),
                TextFormField(controller: _firstName, decoration: pnDeco(s.pn('First name', 'Prénom')), validator: req, textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                TextFormField(controller: _lastName, decoration: pnDeco(s.pn('Last name', 'Nom')), validator: req, textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                PnAsync<List<ManagedClass>>(
                  value: classes,
                  strings: s,
                  skeletonRows: 1,
                  onRetry: () => ref.invalidate(managedClassesProvider(widget.schoolId)),
                  builder: (list) => DropdownButtonFormField<ManagedClass>(
                    initialValue: _class,
                    isExpanded: true,
                    decoration: pnDeco(s.pn('Class', 'Classe')),
                    items: [for (final c in list.where((c) => c.isActive)) DropdownMenuItem(value: c, child: Text(c.className))],
                    onChanged: (v) {
                      if (v != null) _pickClass(v);
                    },
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: _loadingOfferings
                      ? const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator())
                      : _offerings.isEmpty
                          ? const SizedBox(width: double.infinity)
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const SizedBox(height: 16),
                              Text(s.pn('Subjects', 'Matières'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                              for (final o in _offerings)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  value: _subjects.contains(o.subjectId),
                                  title: Text(o.subjectName),
                                  subtitle: o.isCompulsory ? Text(s.pn('Compulsory', 'Obligatoire')) : null,
                                  onChanged: o.isCompulsory ? null : (v) => setState(() => v == true ? _subjects.add(o.subjectId) : _subjects.remove(o.subjectId)),
                                ),
                            ]),
                ),
                step(3, s.pn('Guardian (optional)', 'Tuteur (facultatif)')),
                TextFormField(controller: _guardianName, decoration: pnDeco(s.pn('Guardian name', 'Nom du tuteur'))),
                const SizedBox(height: 12),
                TextFormField(controller: _emergencyName, decoration: pnDeco(s.pn('Emergency contact name', 'Nom du contact d’urgence'))),
                const SizedBox(height: 12),
                TextFormField(controller: _emergencyPhone, keyboardType: TextInputType.phone, decoration: pnDeco(s.pn('Emergency contact phone', 'Téléphone du contact d’urgence'))),
                const SizedBox(height: 12),
                TextFormField(controller: _address, maxLines: 2, decoration: pnDeco(s.pn('Address', 'Adresse'))),
                const SizedBox(height: 26),
                SizedBox(
                  height: 50,
                  child: FilledButton(onPressed: _submitting ? null : _submit, child: PnBusyLabel(busy: _submitting, label: s.pn('Create enrollment', 'Créer l’inscription'))),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
