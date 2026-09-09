import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

/// Home, inside ParentShell. Migrated from the old _DashboardBody
/// (parent_home.dart) - same content and RevealOnScroll/HoverLift
/// animations (kept on request), just hosted in-shell now instead of
/// being the shell's only body.
class ParentDashboardTab extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ParentDashboardTab({super.key, required this.schoolId, required this.landing, required this.strings});

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
          // Mobile only - desktop already has the sidebar's Admissions
          // item visible at all times, so a duplicate button would be
          // noise.
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

/// Explicit about WHY the child isn't visible to the school yet - not
/// just a status label with a hidden button.
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