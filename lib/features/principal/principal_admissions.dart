import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// ADMISSIONS AWAITING APPROVAL
// ============================================================

class AdmissionsReviewPage extends ConsumerWidget {
  final String schoolId;
  const AdmissionsReviewPage({super.key, required this.schoolId});

  Future<void> _approve(BuildContext context, WidgetRef ref, PendingAdmissionReview a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve ${a.fullName}?'),
        content: Text(
          'This creates a real student record with a permanent admission number, enrolls them in ${a.requestedClassName}, and links them to their parent\'s account.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(principalRepositoryProvider).approveAdmission(a.id);
      ref.invalidate(admissionsForReviewProvider(schoolId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${a.fullName} approved and enrolled.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, PendingAdmissionReview a) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reject ${a.fullName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The parent will see this request marked as rejected.'),
            const SizedBox(height: 12),
            TextField(controller: reasonController, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Reason (optional but recommended)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(principalRepositoryProvider).rejectAdmission(a.id, reasonController.text.trim());
    ref.invalidate(admissionsForReviewProvider(schoolId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final admissionsAsync = ref.watch(admissionsForReviewProvider(schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admissions Awaiting Approval', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'These requests have already had their registration fee paid. Approving creates the real student record.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: admissionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (admissions) {
                if (admissions.isEmpty) {
                  return Center(child: Text('No admissions waiting for approval right now.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)));
                }
                return ListView.separated(
                  itemCount: admissions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = admissions[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: a.photoUrl != null ? NetworkImage(a.photoUrl!) : null,
                                child: a.photoUrl == null ? Text(a.firstName.isNotEmpty ? a.firstName[0] : '?') : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    Text('Requested: ${a.requestedClassName}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (a.guardianName != null) _detailRow('Guardian', a.guardianName!),
                          if (a.emergencyContactName != null) _detailRow('Emergency Contact', '${a.emergencyContactName} · ${a.emergencyContactPhone ?? ""}'),
                          if (a.address != null) _detailRow('Address', a.address!),
                          if (a.selectedSubjectNames.isNotEmpty) _detailRow('Subjects', a.selectedSubjectNames.join(', ')),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton(onPressed: () => _reject(context, ref, a), child: const Text('Reject')),
                              const SizedBox(width: 8),
                              FilledButton(onPressed: () => _approve(context, ref, a), child: const Text('Approve')),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        )),
      );
}

// ============================================================
// ALL STUDENTS - school-wide, with a department filter
// ============================================================

class AllStudentsPage extends ConsumerStatefulWidget {
  final String schoolId;
  const AllStudentsPage({super.key, required this.schoolId});

  @override
  ConsumerState<AllStudentsPage> createState() => _AllStudentsPageState();
}

class _AllStudentsPageState extends ConsumerState<AllStudentsPage> {
  String? _departmentFilter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentsAsync = ref.watch(allStudentsProvider(widget.schoolId));
    final departmentsAsync = ref.watch(departmentsFullProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Students', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Every enrolled student at this school, across all departments.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Search by name', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              departmentsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (departments) => DropdownButton<String?>(
                  value: _departmentFilter,
                  hint: const Text('All departments'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All departments')),
                    ...departments.map((d) => DropdownMenuItem(value: d.departmentName, child: Text(d.departmentName))),
                  ],
                  onChanged: (v) => setState(() => _departmentFilter = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: studentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (students) {
                final filtered = students.where((s) {
                  final matchesSearch = _search.isEmpty || s.fullName.toLowerCase().contains(_search);
                  final matchesDept = _departmentFilter == null || s.departmentName == _departmentFilter;
                  return matchesSearch && matchesDept;
                }).toList();

                if (filtered.isEmpty) return const Center(child: Text('No students match this filter.'));

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: s.photoUrl != null ? NetworkImage(s.photoUrl!) : null,
                            child: s.photoUrl == null ? Text(s.firstName.isNotEmpty ? s.firstName[0] : '?') : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('${s.admissionNumber} · ${s.className} · ${s.departmentName}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                              ],
                            ),
                          ),
                          // Further per-student actions (view marks,
                          // attendance, etc.) land here once defined -
                          // per your own note that these will come later.
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}