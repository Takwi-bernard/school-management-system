import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'super_admin_models.dart';
import 'super_admin_providers.dart';
import 'super_admin_school_detail.dart';
import 'super_admin_schools.dart';
import 'super_admin_theme.dart';
import 'super_admin_ui.dart';

class OverviewSection extends ConsumerWidget {
  /// Called with the index of the section to open (1 = Schools, 3 = Activity).
  final ValueChanged<int> onNavigate;
  const OverviewSection({super.key, required this.onNavigate});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(platformOverviewProvider);
    await ref.read(platformOverviewProvider.future).catchError((_) => const PlatformOverview(
          schools: 0,
          activeSchools: 0,
          students: 0,
          teachers: 0,
          parents: 0,
          adminAccounts: 0,
          metricsAvailable: false,
          recentSchools: [],
          alerts: [],
          recentActivity: [],
        ));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(platformOverviewProvider);
    final name = ref.watch(superAdminProfileProvider).valueOrNull?.fullName.split(' ').first ?? '';

    return SaPage(
      title: '${_greeting()}${name.isEmpty ? '' : ', $name'}',
      subtitle: 'Here is how the platform is doing today.',
      onRefresh: () => _refresh(ref),
      actions: [
        FilledButton.icon(
          onPressed: () async {
            final created = await showDialog<bool>(context: context, builder: (_) => const SchoolFormDialog());
            if (created == true) {
              ref.invalidate(schoolsListProvider);
              ref.invalidate(platformOverviewProvider);
            }
          },
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Onboard a school'),
        ),
      ],
      children: [
        async.when(
          loading: () => const SaCardSkeleton(count: 4, minWidth: 240),
          error: (e, _) => SaErrorState(e, onRetry: () => ref.invalidate(platformOverviewProvider)),
          data: (o) => _content(context, ref, o),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, PlatformOverview o) {
    final inactive = o.schools - o.activeSchools;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!o.metricsAvailable) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Sa.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Sa.warning.withValues(alpha: 0.3))),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, color: Sa.warning, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Student and staff totals are not available yet. Run the super_admin_final.sql update in Supabase to switch them on.', style: TextStyle(color: Sa.warning, fontSize: 13))),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      SaGrid(minItemWidth: 250, children: [
        SaStatTile(icon: Icons.apartment_rounded, label: 'Schools', value: o.schools, note: '${o.activeSchools} active${inactive > 0 ? ' · $inactive suspended' : ''}', tone: SaTone.primary),
        SaStatTile(icon: Icons.school_rounded, label: 'Students', value: o.students, note: 'Across all schools', tone: SaTone.info),
        SaStatTile(icon: Icons.co_present_rounded, label: 'Teachers', value: o.teachers, note: '${saCount(o.parents)} parents registered', tone: SaTone.success),
        SaStatTile(icon: Icons.admin_panel_settings_rounded, label: 'Admin accounts', value: o.adminAccounts, note: 'Principals, proprietors, secretaries', tone: SaTone.warning),
      ]),
      const SizedBox(height: 26),
      LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 900;
        final attention = _attention(context, ref, o);
        final recent = _recentSchools(context, ref, o);
        final activity = _activity(o);
        if (!wide) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [attention, const SizedBox(height: 22), recent, const SizedBox(height: 22), activity]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [attention, const SizedBox(height: 22), recent])),
          const SizedBox(width: 22),
          Expanded(flex: 4, child: activity),
        ]);
      }),
    ]);
  }

  void _openSchool(BuildContext context, String schoolId) {
    Navigator.push(context, saRoute(SchoolDetailPage(schoolId: schoolId)));
  }

  Widget _attention(BuildContext context, WidgetRef ref, PlatformOverview o) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SaSectionTitle('Needs attention', trailing: o.alerts.isEmpty ? null : SaChip('${o.alerts.length}', tone: SaTone.warning)),
      if (o.alerts.isEmpty)
        const SaCard(
          child: Row(children: [
            Icon(Icons.verified_rounded, color: Sa.success, size: 26),
            SizedBox(width: 14),
            Expanded(child: Text('Everything looks good. Every active school has its admin accounts set up.', style: TextStyle(color: Sa.muted, fontSize: 13.5))),
          ]),
        )
      else
        SaCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < o.alerts.length && i < 6; i++) ...[
              if (i > 0) const Divider(),
              InkWell(
                onTap: () => _openSchool(context, o.alerts[i].schoolId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(children: [
                    Icon(o.alerts[i].type == 'inactive' ? Icons.pause_circle_outline_rounded : Icons.person_add_alt_1_rounded, color: o.alerts[i].type == 'inactive' ? Sa.muted : Sa.warning, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.alerts[i].schoolName, style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(o.alerts[i].message, style: const TextStyle(color: Sa.muted, fontSize: 12.5)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Sa.faint),
                  ]),
                ),
              ),
            ],
          ]),
        ),
    ]);
  }

  Widget _recentSchools(BuildContext context, WidgetRef ref, PlatformOverview o) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SaSectionTitle('Recently onboarded', trailing: TextButton(onPressed: () => onNavigate(1), child: const Text('View all'))),
      if (o.recentSchools.isEmpty)
        const SaCard(child: SaEmpty(icon: Icons.apartment_rounded, title: 'No schools yet', message: 'Onboard your first school to get started.'))
      else
        SaCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < o.recentSchools.length; i++) ...[
              if (i > 0) const Divider(),
              InkWell(
                onTap: () => Navigator.push(context, saRoute(SchoolDetailPage(schoolId: o.recentSchools[i].id))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(children: [
                    SaAvatar(o.recentSchools[i].schoolName, size: 38),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.recentSchools[i].schoolName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('${o.recentSchools[i].schoolCode} · added ${saAgo(o.recentSchools[i].createdAt)}', style: const TextStyle(color: Sa.muted, fontSize: 12.5)),
                      ]),
                    ),
                    SaChip(o.recentSchools[i].isActive ? 'Active' : 'Suspended', tone: o.recentSchools[i].isActive ? SaTone.success : SaTone.danger),
                  ]),
                ),
              ),
            ],
          ]),
        ),
    ]);
  }

  Widget _activity(PlatformOverview o) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SaSectionTitle('Recent activity', trailing: TextButton(onPressed: () => onNavigate(3), child: const Text('See all'))),
      SaCard(
        child: o.recentActivity.isEmpty
            ? const SaEmpty(icon: Icons.history_rounded, title: 'No activity yet', message: 'Changes made in this portal will appear here.')
            : Column(children: [
                for (var i = 0; i < o.recentActivity.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == o.recentActivity.length - 1 ? 0 : 16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6, right: 12), decoration: const BoxDecoration(color: Sa.primaryHi, shape: BoxShape.circle)),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o.recentActivity[i].summary, style: const TextStyle(color: Sa.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${o.recentActivity[i].actorName}${o.recentActivity[i].schoolName != null ? ' · ${o.recentActivity[i].schoolName}' : ''} · ${saAgo(o.recentActivity[i].createdAt)}', style: const TextStyle(color: Sa.faint, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}