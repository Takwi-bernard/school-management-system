import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
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

            return Theme(
              data: buildSchoolTheme(school.primaryColor, school.secondaryColor),
              child: _ParentShell(schoolId: school.schoolId, landing: school, strings: AppStrings(locale)),
            );
          },
        );
      },
    );
  }
}

/// Describes one item in the sidebar (desktop) / drawer (mobile) -
/// icon, title, and a short explanation, since many parents are
/// unfamiliar with this kind of system and need to know what a tap
/// will actually do, not just guess from an icon.
class _NavItem {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.title, required this.description, required this.onTap});
}

class _ParentShell extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const _ParentShell({required this.schoolId, required this.landing, required this.strings});

  List<_NavItem> _buildNavItems(BuildContext context, WidgetRef ref, List<EnrolledChild> children) {
    return [
      _NavItem(
        icon: Icons.person_add_alt_1_rounded,
        title: strings.enrollMyChild,
        description: strings.isFrench
            ? 'Inscrire un nouvel enfant dans cette école.'
            : 'Register a new child at this school.',
        onTap: () => context.push('/parent/enroll', extra: schoolId),
      ),
      _NavItem(
        icon: Icons.payments_outlined,
        title: strings.schoolFees,
        description: strings.isFrench
            ? 'Voir et payer les frais scolaires de vos enfants.'
            : 'View and pay your children\'s school fees.',
        onTap: () => _pickChildThen(context, children, (child) => context.push('/parent/fees', extra: child)),
      ),
      _NavItem(
        icon: Icons.assessment_outlined,
        title: strings.reportCards,
        description: strings.isFrench
            ? 'Consulter les bulletins publiés par l\'école.'
            : 'View report cards published by the school.',
        onTap: () => _pickChildThen(context, children, (child) => context.push('/parent/report-card', extra: child)),
      ),
      _NavItem(
        icon: Icons.rate_review_outlined,
        title: strings.reviewMyChild,
        description: strings.isFrench
            ? 'Voir la présence et les commentaires de l\'école.'
            : 'View attendance and school comments.',
        onTap: () => _pickChildThen(context, children, (child) => context.push('/parent/review', extra: child)),
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        title: strings.myProfile,
        description: strings.isFrench
            ? 'Modifier vos informations et votre mot de passe.'
            : 'Update your information and password.',
        onTap: () => context.push('/parent/profile'),
      ),
    ];
  }

  /// If there's more than one enrolled child, ask which one first -
  /// there's no other way to know which child's fees/report/review
  /// the parent means from the sidebar alone.
  void _pickChildThen(BuildContext context, List<EnrolledChild> children, void Function(EnrolledChild) onPicked) {
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.isFrench
            ? 'Vous n\'avez pas encore d\'enfant inscrit.'
            : 'You do not have an enrolled child yet.')),
      );
      return;
    }
    if (children.length == 1) {
      onPicked(children.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children
              .map((c) => ListTile(
                    leading: CircleAvatar(child: Text(c.firstName.isNotEmpty ? c.firstName[0] : '?')),
                    title: Text(c.fullName),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPicked(c);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final children = enrolledAsync.valueOrNull ?? [];
    final navItems = _buildNavItems(context, ref, children);

    final body = _DashboardBody(schoolId: schoolId, landing: landing, strings: strings);

    if (isMobile) {
      return Scaffold(
        appBar: _StaticBrandedAppBar(landing: landing, strings: strings),
        drawer: Drawer(
          child: _SidebarContent(landing: landing, strings: strings, navItems: navItems, isDrawer: true),
        ),
        body: body,
      );
    }

    // DESKTOP: fixed sidebar + main content, both below one static app bar.
    return Scaffold(
      appBar: _StaticBrandedAppBar(landing: landing, strings: strings, showMenuIcon: false),
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: _SidebarContent(landing: landing, strings: strings, navItems: navItems, isDrawer: false),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// A real, FIXED app bar - previously the branding header scrolled
/// away with the page content, which read as broken/unpolished.
class _StaticBrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final LandingModel landing;
  final AppStrings strings;
  final bool showMenuIcon;
  const _StaticBrandedAppBar({required this.landing, required this.strings, this.showMenuIcon = true});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      automaticallyImplyLeading: showMenuIcon,
      titleSpacing: 12,
      title: Row(
        children: [
          if (landing.logoUrl.isNotEmpty)
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Image.network(landing.logoUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 20)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(landing.schoolName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _SidebarContent extends ConsumerWidget {
  final LandingModel landing;
  final AppStrings strings;
  final List<_NavItem> navItems;
  final bool isDrawer;
  const _SidebarContent({required this.landing, required this.strings, required this.navItems, required this.isDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(parentProfileProvider);

    // Primary-led gradient, secondary only as a light accent at the
    // very end - previously an even 2-color split muddied the brand.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.88), theme.colorScheme.secondary],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: profileAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (profile) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.welcomeBack, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(profile?.fullName ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: navItems
                    .map((item) => ListTile(
                          leading: Icon(item.icon, color: Colors.white),
                          title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          subtitle: Text(item.description,
                              style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            if (isDrawer) Navigator.pop(context);
                            item.onTap();
                          },
                        ))
                    .toList(),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.white),
              title: Text(strings.signOut, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onTap: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const _DashboardBody({required this.schoolId, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final pendingAsync = ref.watch(pendingAdmissionsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mobile only - desktop already has the sidebar's Enroll item
          // visible at all times, so a duplicate button would be noise.
          if (isMobile) ...[
            RevealOnScroll(
              child: HoverLift(
                onTap: () => context.push('/parent/enroll', extra: schoolId),
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
            ),
            const SizedBox(height: 28),
          ],

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
                      const SizedBox(height: 6),
                      Text(
                        strings.isFrench
                            ? 'Ces demandes ne sont pas encore visibles par l\'école tant qu\'elles ne sont pas terminées.'
                            : 'These requests are not visible to the school until they are completed.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                      const SizedBox(height: 12),
                      ...pending.map((p) => RevealOnScroll(
                            child: _PendingAdmissionCard(admission: p, strings: strings, landing: landing, schoolId: schoolId),
                          )),
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
                  childAspectRatio: isMobile ? 3.0 : 2.6,
                ),
                itemBuilder: (context, i) => RevealOnScroll(child: _ChildCard(child: children[i], strings: strings)),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Now fully clickable and explicit about WHY the child isn't visible
/// to the school yet - not just a status label with a hidden button.
class _PendingAdmissionCard extends ConsumerWidget {
  final PendingAdmission admission;
  final AppStrings strings;
  final LandingModel landing;
  final String schoolId;
  const _PendingAdmissionCard({
    required this.admission,
    required this.strings,
    required this.landing,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final explanation = admission.isRejected
        ? (strings.isFrench
            ? 'L\'école n\'a pas approuvé cette demande.'
            : 'The school did not approve this request.')
        : admission.needsPayment
            ? (strings.isFrench
                ? 'Le Directeur ne verra jamais cet enfant tant que les frais d\'inscription ne sont pas payés. Appuyez ici pour payer maintenant.'
                : 'The Principal will never see this child until the registration fee is paid. Tap here to pay now.')
            : (strings.isFrench
                ? 'Votre paiement a été reçu. L\'école examine actuellement cette demande.'
                : 'Your payment has been received. The school is currently reviewing this request.');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: admission.needsPayment
              ? () => _goToPayment(context, ref)
              : () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(admission.fullName),
                      content: Text(explanation),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                    ),
                  ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(admission.isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                        color: admission.isRejected ? theme.colorScheme.error : theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(admission.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (admission.needsPayment) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 8),
                Text(explanation, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                if (admission.needsPayment)
                  Consumer(
                    builder: (context, ref, _) {
                      final feeAsync = ref.watch(registrationFeeProvider(
                        (classId: admission.requestedClassId, academicYearId: admission.academicYearId),
                      ));
                      return feeAsync.when(
                        loading: () => const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
                        error: (e, _) => const SizedBox(),
                        data: (fee) {
                          if (fee == null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                strings.isFrench
                                    ? 'L\'école n\'a pas encore configuré les frais d\'inscription pour cette classe.'
                                    : 'The school has not configured a registration fee for this class yet.',
                                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _goToPayment(context, ref, amountOverride: fee),
                                icon: const Icon(Icons.payments_outlined, size: 18),
                                label: Text('${strings.payNow} - ${fee.toStringAsFixed(0)} FCFA'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _goToPayment(BuildContext context, WidgetRef ref, {double? amountOverride}) async {
    final fee = amountOverride ??
        await ref.read(registrationFeeProvider(
          (classId: admission.requestedClassId, academicYearId: admission.academicYearId),
        ).future);
    if (fee == null || !context.mounted) return;

    context.push('/parent/payment', extra: {
      'admissionRequestId': admission.id,
      'landing': landing,
      'amount': fee,
      'paymentPurpose': 'Registration Fee',
    });
  }
}

class _ChildCard extends StatelessWidget {
  final EnrolledChild child;
  final AppStrings strings;
  const _ChildCard({required this.child, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/parent/fees', extra: child),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}