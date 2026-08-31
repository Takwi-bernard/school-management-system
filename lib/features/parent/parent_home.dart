import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_providers.dart';
import 'parent_enrollment.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

class ParentHome extends ConsumerWidget {
  const ParentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);

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
            if (session.role != 'parent') {
              return Scaffold(
                body: Center(child: Text('This account is a ${session.role} account, not Parent.')),
              );
            }

            final primary = _parseColor(school.primaryColor);
            final secondary = _parseColor(school.secondaryColor);
            final theme = ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary),
            );

            return Theme(
              data: theme,
              child: _ParentDashboard(
                schoolId: school.schoolId,
                schoolName: school.schoolName,
                logoUrl: school.logoUrl,
                motto: school.motto,
                strings: AppStrings(locale),
              ),
            );
          },
        );
      },
    );
  }

  Color _parseColor(String hex) {
    var v = hex.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    return Color(int.tryParse(v, radix: 16) ?? 0xFF1A73E8);
  }
}

class _ParentDashboard extends ConsumerWidget {
  final String schoolId;
  final String schoolName;
  final String logoUrl;
  final String motto;
  final AppStrings strings;

  const _ParentDashboard({
    required this.schoolId,
    required this.schoolName,
    required this.logoUrl,
    required this.motto,
    required this.strings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final profileAsync = ref.watch(parentProfileProvider);
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final pendingAsync = ref.watch(pendingAdmissionsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                Responsive.pagePadding(context), 60, Responsive.pagePadding(context), 40,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  if (logoUrl.isNotEmpty)
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Image.network(logoUrl, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary)),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(schoolName,
                            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                        profileAsync.when(
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                          data: (profile) => Text(
                            '${strings.welcomeBack}, ${profile?.fullName ?? ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (context.mounted) context.go('/');
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(Responsive.pagePadding(context)),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HoverLift(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EnrollChildPage(schoolId: schoolId)),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, color: theme.colorScheme.onPrimary),
                          const SizedBox(width: 12),
                          Text(strings.enrollMyChild,
                              style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  pendingAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (pending) => pending.isEmpty
                        ? const SizedBox()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(strings.admissionsInProgress,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 12),
                              ...pending.map((p) => _PendingAdmissionCard(admission: p, strings: strings)),
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),

                  Text(strings.myChildren, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  enrolledAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('$e'),
                    data: (children) {
                      if (children.isEmpty) {
                        return RevealOnScroll(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.family_restroom_rounded, size: 40, color: theme.colorScheme.primary),
                                const SizedBox(height: 12),
                                Text(strings.noChildrenTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(strings.noChildrenDescription,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                              ],
                            ),
                          ),
                        );
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: children.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isMobile ? 3.2 : 2.8,
                        ),
                        itemBuilder: (context, i) => _ChildCard(child: children[i], strings: strings),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingAdmissionCard extends StatelessWidget {
  final PendingAdmission admission;
  final AppStrings strings;
  const _PendingAdmissionCard({required this.admission, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = admission.isRejected
        ? strings.admissionRejected
        : admission.needsPayment
            ? strings.registrationFeePending
            : strings.admissionUnderReview;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(admission.isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
              color: admission.isRejected ? theme.colorScheme.error : theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(admission.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final EnrolledChild child;
  final AppStrings strings;
  const _ChildCard({required this.child, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: child.photoUrl != null ? NetworkImage(child.photoUrl!) : null,
            child: child.photoUrl == null ? Text(child.firstName.isNotEmpty ? child.firstName[0] : '?') : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(child.className ?? strings.classNotAssigned, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}