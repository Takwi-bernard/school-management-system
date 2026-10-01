import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import '../parent/parent_models.dart' show buildSchoolTheme;
import 'proprietor_models.dart';
import 'proprietor_providers.dart';

class ProprietorHome extends ConsumerWidget {
  const ProprietorHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (school) {
        final sessionAsync = ref.watch(sessionProfileProvider(school.schoolId));
        return sessionAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (session) {
            if (session == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/sign-in'));
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (session.role != 'proprietor') {
              return Scaffold(body: Center(child: Text('This account is a ${session.role} account, not Proprietor.')));
            }
            return Theme(
              data: buildSchoolTheme(school.primaryColor, school.secondaryColor),
              child: _ProprietorShell(landing: school),
            );
          },
        );
      },
    );
  }
}

class _ProprietorShell extends ConsumerWidget {
  final LandingModel landing;
  const _ProprietorShell({required this.landing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overviewAsync = ref.watch(schoolOverviewProvider(landing.schoolId));
    final enrollmentAsync = ref.watch(enrollmentByClassProvider(landing.schoolId));
    final paymentsAsync = ref.watch(recentPaymentsProvider(landing.schoolId));
    final profileAsync = ref.watch(proprietorProfileProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          if (landing.logoUrl.isNotEmpty)
            Container(
              width: 34, height: 34, padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
              child: Image.network(landing.logoUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 18)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(landing.schoolName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(schoolOverviewProvider(landing.schoolId));
          ref.invalidate(enrollmentByClassProvider(landing.schoolId));
          ref.invalidate(recentPaymentsProvider(landing.schoolId));
        },
        child: ListView(
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          children: [
            profileAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (p) => Text('Welcome, ${p?.fullName ?? 'Proprietor'}',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text('Everything happening at ${landing.schoolName}, live from the database.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 20),
            overviewAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (o) => _OverviewGrid(overview: o),
            ),
            const SizedBox(height: 28),
            Text('Enrollment by Class', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            enrollmentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (classes) {
                if (classes.isEmpty) return Text('No classes configured yet.', style: theme.textTheme.bodySmall);
                return Column(children: classes.map((c) => _EnrollmentBar(c: c)).toList());
              },
            ),
            const SizedBox(height: 28),
            Text('Recent Payments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            paymentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (payments) {
                if (payments.isEmpty) return Text('No payments recorded yet.', style: theme.textTheme.bodySmall);
                return Column(children: payments.map((p) => _PaymentRow(p: p)).toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final SchoolOverview overview;
  const _OverviewGrid({required this.overview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      _Stat('Students', '${overview.totalStudents}', Icons.groups_rounded, theme.colorScheme.primary),
      _Stat('Classes', '${overview.totalClasses}', Icons.class_outlined, theme.colorScheme.secondary),
      _Stat('Departments', '${overview.totalDepartments}', Icons.account_tree_outlined, Colors.teal),
      _Stat('Teachers (approved)', '${overview.totalTeachersApproved}', Icons.check_circle_outline, Colors.green),
      _Stat('Teachers (pending)', '${overview.totalTeachersPending}', Icons.hourglass_top_rounded, Colors.orange),
      _Stat('Awaiting registration fee', '${overview.admissionsAwaitingPayment}', Icons.payments_outlined, Colors.redAccent),
      _Stat('Awaiting Principal approval', '${overview.admissionsUnderReview}', Icons.fact_check_outlined, Colors.indigo),
      _Stat('Revenue this month', '${overview.revenueThisMonth.toStringAsFixed(0)} FCFA', Icons.trending_up_rounded, Colors.green.shade700),
      _Stat('Revenue all time', '${overview.revenueAllTime.toStringAsFixed(0)} FCFA', Icons.account_balance_wallet_outlined, Colors.blueGrey),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
        children: cards,
      );
    });
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _EnrollmentBar extends StatelessWidget {
  final ClassEnrollmentCount c;
  const _EnrollmentBar({required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = c.capacity > 0 ? (c.studentCount / c.capacity).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c.className} · ${c.departmentName}', style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${c.studentCount}/${c.capacity}', style: theme.textTheme.bodySmall),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 7)),
      ]),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final RecentPayment p;
  const _PaymentRow({required this.p});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.childName, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${p.purpose} · ${p.method}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ]),
        ),
        Text('${p.amount.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}