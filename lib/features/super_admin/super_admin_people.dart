import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'super_admin_models.dart';
import 'super_admin_providers.dart';
import 'super_admin_school_detail.dart';
import 'super_admin_theme.dart';
import 'super_admin_ui.dart';

class PeopleSection extends ConsumerStatefulWidget {
  const PeopleSection({super.key});

  @override
  ConsumerState<PeopleSection> createState() => _PeopleSectionState();
}

class _PeopleSectionState extends ConsumerState<PeopleSection> {
  final _search = TextEditingController();
  String _query = '';
  String _role = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(allAdminsProvider);
    await ref.read(allAdminsProvider.future).catchError((_) => <SchoolAdminAccount>[]);
  }

  List<SchoolAdminAccount> _apply(List<SchoolAdminAccount> all) {
    final q = _query.trim().toLowerCase();
    return all.where((a) {
      if (_role != 'all' && a.role != _role) return false;
      if (q.isEmpty) return true;
      return a.fullName.toLowerCase().contains(q) ||
          (a.email?.toLowerCase().contains(q) ?? false) ||
          (a.phone?.toLowerCase().contains(q) ?? false) ||
          (a.schoolName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allAdminsProvider);
    return SaPage(
      title: 'People',
      subtitle: 'Every principal, proprietor and secretary on the platform.',
      onRefresh: _refresh,
      children: [
        LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 760;
          final search = SaSearchField(controller: _search, hint: 'Search name, email, phone or school...', onChanged: (v) => setState(() => _query = v));
          final seg = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SaSegmented<String>(
              options: const {'all': 'All', 'principal': 'Principals', 'proprietor': 'Proprietors', 'secretary': 'Secretaries'},
              value: _role,
              onChanged: (v) => setState(() => _role = v),
            ),
          );
          if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [search, const SizedBox(height: 12), seg]);
          return Row(children: [Expanded(child: search), const SizedBox(width: 14), seg]);
        }),
        const SizedBox(height: 18),
        async.when(
          loading: () => const SaCard(child: Column(children: [SaSkeleton(height: 44), SizedBox(height: 12), SaSkeleton(height: 44), SizedBox(height: 12), SaSkeleton(height: 44)])),
          error: (e, _) => SaErrorState(e, onRetry: () => ref.invalidate(allAdminsProvider)),
          data: (all) {
            final list = _apply(all);
            if (all.isEmpty) return const SaEmpty(icon: Icons.groups_rounded, title: 'No admin accounts yet', message: 'Open a school and use "Add account" to create its principal, proprietor or secretary.');
            if (list.isEmpty) return const SaEmpty(icon: Icons.search_off_rounded, title: 'No one matches', message: 'Try a different search or role.');
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('${list.length} of ${all.length} accounts', style: const TextStyle(color: Sa.faint, fontSize: 12.5))),
              SaCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(),
                    _PersonRow(account: list[i]),
                  ],
                ]),
              ),
            ]);
          },
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  final SchoolAdminAccount account;
  const _PersonRow({required this.account});

  @override
  Widget build(BuildContext context) {
    final a = account;
    return InkWell(
      onTap: a.schoolId == null ? null : () => Navigator.push(context, saRoute(SchoolDetailPage(schoolId: a.schoolId!))),
      child: Opacity(
        opacity: a.isActive ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(children: [
            SaAvatar(a.fullName, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text([if (a.email != null && a.email!.isNotEmpty) a.email!, if (a.schoolName != null) a.schoolName!].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.muted, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(width: 10),
            SaChip(saRoleLabel(a.role), tone: switch (a.role) { 'principal' => SaTone.primary, 'proprietor' => SaTone.info, _ => SaTone.success }),
            if (!a.isActive) ...[const SizedBox(width: 6), const SaChip('Inactive', tone: SaTone.danger)],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Sa.faint),
          ]),
        ),
      ),
    );
  }
}