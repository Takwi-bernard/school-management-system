import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/status_colors.dart';
import '../landing/landing_model.dart';
import 'parent_admissions_tab.dart';
import 'parent_fees_tab.dart';
import 'parent_models.dart';
import 'parent_navigation.dart';
import 'parent_providers.dart';

/// Home, inside ParentShell.
class ParentDashboardTab extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ParentDashboardTab({super.key, required this.schoolId, required this.landing, required this.strings});

  String _greeting(AppStrings strings) {
    final hour = DateTime.now().hour;
    if (hour < 12) return strings.isFrench ? 'Bonjour' : 'Good morning';
    if (hour < 17) return strings.isFrench ? 'Bon après-midi' : 'Good afternoon';
    return strings.isFrench ? 'Bonsoir' : 'Good evening';
  }

  void _openAdmissions(WidgetRef ref) {
    ref.read(parentActiveNavKeyProvider.notifier).state = 'admissions';
    pushParentContent(
      ref,
      ParentContentPage(
        title: strings.enrollMyChild,
        builder: (ctx) => ParentAdmissionsTab(schoolId: schoolId, landing: landing, strings: strings),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);
    final profileAsync = ref.watch(parentProfileProvider);
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final pendingAsync = ref.watch(pendingAdmissionsProvider);

    final childCount = enrolledAsync.valueOrNull?.length;
    final pendingCount = pendingAsync.valueOrNull?.length;
    final firstName = profileAsync.valueOrNull?.fullName.split(' ').first;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevealOnScroll(
            child: Text(
              firstName == null ? _greeting(strings) : '${_greeting(strings)}, $firstName',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          RevealOnScroll(
            child: Text(
              strings.isFrench
                  ? 'Voici où en sont vos enfants aujourd\'hui.'
                  : 'Here\'s where things stand with your children today.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 22),

          RevealOnScroll(
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.groups_rounded,
                    value: childCount?.toString() ?? '-',
                    label: strings.myChildren,
                    color: scheme.primary,
                  ),
                ),
                if ((pendingCount ?? 0) > 0) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.hourglass_top_rounded,
                      value: pendingCount.toString(),
                      label: strings.admissionsInProgress,
                      color: scheme.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (isMobile) ...[
            RevealOnScroll(
              child: HoverLift(
                onTap: () => _openAdmissions(ref),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, color: scheme.onPrimary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(strings.enrollMyChild,
                                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                              strings.isFrench
                                  ? 'Nouvelle inscription ou lien avec un enfant déjà admis'
                                  : 'New enrollment, or link a child already admitted',
                              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: scheme.onPrimary),
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
                      const SizedBox(height: 4),
                      Text(
                        strings.isFrench
                            ? 'Ces demandes ne sont pas encore visibles par l\'école tant qu\'elles ne sont pas terminées.'
                            : 'These requests aren\'t visible to the school yet, until they\'re complete.',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      ...pending.map((p) => RevealOnScroll(
                            child: PendingAdmissionCard(admission: p, strings: strings, landing: landing, schoolId: schoolId),
                          )),
                      const SizedBox(height: 26),
                    ],
                  ),
          ),

          Text(strings.myChildren, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          enrolledAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorStateView(
              error: e,
              onRetry: () => ref.invalidate(enrolledChildrenProvider),
            ),
            data: (children) {
              if (children.isEmpty) {
                return RevealOnScroll(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.family_restroom_rounded, size: 30, color: scheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(strings.noChildrenTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(
                          strings.isFrench
                              ? 'Commencez par inscrire votre enfant, ou reliez-le à votre compte s\'il a déjà été admis par l\'école.'
                              : 'Start by enrolling your child, or link them to your account if the school has already admitted them.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => _openAdmissions(ref),
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                          label: Text(strings.enrollMyChild),
                        ),
                      ],
                    ),
                  ),
                );
              }
              // A fixed-aspect-ratio GridView forces every card to the
              // same tall box regardless of how little it has to show -
              // with only 1 or 2 children that reads as a lot of empty
              // space for no reason. A Wrap of fixed-WIDTH, natural-
              // HEIGHT cards fixes that: each card is exactly as tall
              // as its own content, on mobile or desktop alike.
              return LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  final columns = isMobile ? 1 : 2;
                  final cardWidth = columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - spacing * (columns - 1)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final child in children)
                        SizedBox(
                          width: cardWidth,
                          child: RevealOnScroll(
                            child: _ChildCard(
                              child: child,
                              strings: strings,
                              color: scheme.primary,
                              onTap: () {
                                ref.read(parentActiveNavKeyProvider.notifier).state = 'fees';
                                showParentContent(
                                  ref,
                                  ParentContentPage(
                                    title: '${strings.schoolFees} \u00b7 ${child.fullName}',
                                    builder: (ctx) => ParentFeesTab(child: child, landing: landing, strings: strings),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatTile({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, color: color.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Explicit about WHY the child isn't visible to the school yet - not
/// just a status label with a hidden button.
class PendingAdmissionCard extends ConsumerWidget {
  final PendingAdmission admission;
  final AppStrings strings;
  final LandingModel landing;
  final String schoolId;
  const PendingAdmissionCard({
    super.key,
    required this.admission,
    required this.strings,
    required this.landing,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Status color is semantic (rejected = decline, pending = needs
    // attention, under review = neutral/waiting) - never the school's
    // brand color, so it reads correctly no matter which school this
    // is.
    final statusColor = admission.isRejected
        ? kOverdue
        : admission.needsPayment
            ? kPending
            : scheme.onSurfaceVariant;

    final statusLabel = admission.isRejected
        ? (strings.isFrench ? 'Rejeté' : 'Rejected')
        : admission.needsPayment
            ? (strings.isFrench ? 'Paiement requis' : 'Payment needed')
            : (strings.isFrench ? 'En cours d\'examen' : 'Under review');

    final explanation = admission.isRejected
        ? (strings.isFrench
            ? 'L\'école n\'a pas approuvé cette demande.'
            : 'The school did not approve this request.')
        : admission.needsPayment
            ? (strings.isFrench
                ? 'Le Directeur ne verra cet enfant qu\'une fois les frais d\'inscription payés.'
                : 'The Principal won\'t see this child until the registration fee is paid.')
            : (strings.isFrench
                ? 'Votre paiement a été reçu. L\'école examine actuellement cette demande.'
                : 'Your payment has been received - the school is reviewing this now.');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHighest,
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
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.isFrench ? 'Fermer' : 'Close'))],
                    ),
                  ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(
                        admission.isRejected ? Icons.close_rounded : Icons.hourglass_top_rounded,
                        size: 17,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(admission.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(explanation, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
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
  final Color color;
  final VoidCallback onTap;
  const _ChildCard({required this.child, required this.strings, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withValues(alpha: 0.12),
                backgroundImage: child.photoUrl != null ? NetworkImage(child.photoUrl!) : null,
                onBackgroundImageError: child.photoUrl != null ? (_, __) {} : null,
                child: child.photoUrl == null
                    ? Text(
                        child.firstName.isNotEmpty ? child.firstName[0].toUpperCase() : '?',
                        style: TextStyle(color: color, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      child.className ?? strings.classNotAssigned,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
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
