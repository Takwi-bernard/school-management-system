import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_model.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

/// Migrated from ChildFeesPage - no own Scaffold/AppBar/Theme wrap
/// anymore, ParentShell provides all three. "Pay Now" still uses
/// context.push to MobileMoneyPaymentPage (parent_fees.dart) - that
/// flow stays a focused, full-screen push for this pass, same as it
/// already was; only the six sidebar-reachable destinations are
/// being brought in-shell right now.
class ParentFeesTab extends ConsumerWidget {
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const ParentFeesTab({super.key, required this.child, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academicYearIdAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));

    return academicYearIdAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (yearId) {
        if (yearId == null) {
          return _FeesInfoState(icon: Icons.event_busy_rounded, message: strings.academicYearNotSet);
        }
        if (child.classId == null) {
          return _FeesInfoState(
            icon: Icons.info_outline_rounded,
            message: strings.isFrench
                ? 'La classe de cet enfant n\'est pas encore confirmée par l\'école.'
                : 'This child\'s class has not been confirmed by the school yet.',
          );
        }
        final feesAsync = ref.watch(
          childFeesProvider((studentId: child.studentId, classId: child.classId!, academicYearId: yearId)),
        );
        return feesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (fees) {
            if (fees.isEmpty) {
              return _FeesInfoState(icon: Icons.receipt_long_outlined, message: strings.noFeesConfigured);
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(strings.schoolFees, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(child.fullName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.isFrench
                              ? 'Frais d\'inscription payés. ${child.firstName} est officiellement inscrit(e) à ${landing.schoolName}.'
                              : 'Registration fee paid. ${child.firstName} is officially enrolled at ${landing.schoolName}.',
                          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                ...fees.map((fee) => _FeeCard(fee: fee, child: child, landing: landing, strings: strings)),
              ],
            );
          },
        );
      },
    );
  }
}

class _FeesInfoState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _FeesInfoState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

enum _InstallmentUrgency { paid, overdue, dueSoon, upcoming, noDueDate }

_InstallmentUrgency _urgencyOf(InstallmentSummary i) {
  if (i.isPaid) return _InstallmentUrgency.paid;
  if (i.dueDate == null) return _InstallmentUrgency.noDueDate;
  final daysLeft = i.dueDate!.difference(DateTime.now()).inDays;
  if (daysLeft < 0) return _InstallmentUrgency.overdue;
  if (daysLeft <= 7) return _InstallmentUrgency.dueSoon;
  return _InstallmentUrgency.upcoming;
}

class _FeeCard extends StatelessWidget {
  final FeeSummary fee;
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const _FeeCard({required this.fee, required this.child, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = fee.totalAmount <= 0 ? 0.0 : (fee.amountPaid / fee.totalAmount).clamp(0.0, 1.0);
    final unpaidCount = fee.installments.where((i) => !i.isPaid).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(fee.feeName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text('${fee.totalAmount.toStringAsFixed(0)} FCFA', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fee.fullyPaid
                ? (strings.isFrench
                    ? 'Tous les frais de scolarité ont été réglés.'
                    : 'All school fees have been settled.')
                : strings.isFrench
                    ? 'L\'école a divisé ces frais en ${fee.installments.length} versements. Il reste $unpaidCount versement${unpaidCount > 1 ? 's' : ''} à payer.'
                    : 'The school has split this fee into ${fee.installments.length} installment${fee.installments.length > 1 ? 's' : ''}. $unpaidCount remain${unpaidCount == 1 ? 's' : ''} unpaid.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          const SizedBox(height: 8),
          Text(
            '${fee.amountPaid.toStringAsFixed(0)} / ${fee.totalAmount.toStringAsFixed(0)} FCFA  ·  '
            '${(progress * 100).toStringAsFixed(0)}% ${strings.isFrench ? 'payé' : 'paid'}',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          if (fee.fullyPaid)
            Row(
              children: [
                const Icon(Icons.celebration_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  strings.isFrench ? 'Rien d\'autre à payer pour le moment.' : 'Nothing else to pay right now.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            )
          else
            ...fee.installments.map((i) => _InstallmentRow(installment: i, child: child, landing: landing, strings: strings)),
        ],
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final InstallmentSummary installment;
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const _InstallmentRow({
    required this.installment,
    required this.child,
    required this.landing,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = _urgencyOf(installment);

    final (Color badgeColor, String badgeText, IconData badgeIcon) = switch (urgency) {
      _InstallmentUrgency.paid => (Colors.green, strings.isFrench ? 'Payé' : 'Paid', Icons.check_circle_rounded),
      _InstallmentUrgency.overdue => (Colors.red, strings.isFrench ? 'En retard' : 'Overdue', Icons.error_rounded),
      _InstallmentUrgency.dueSoon => (Colors.orange, strings.isFrench ? 'Échéance proche' : 'Due soon', Icons.schedule_rounded),
      _InstallmentUrgency.upcoming => (theme.colorScheme.primary, strings.isFrench ? 'À venir' : 'Upcoming', Icons.event_rounded),
      _InstallmentUrgency.noDueDate => (theme.colorScheme.outline, strings.isFrench ? 'Non payé' : 'Unpaid', Icons.radio_button_unchecked_rounded),
    };

    String? explanation;
    if (urgency == _InstallmentUrgency.overdue) {
      final daysLate = DateTime.now().difference(installment.dueDate!).inDays;
      explanation = strings.isFrench
          ? 'La date limite était il y a $daysLate jour${daysLate > 1 ? 's' : ''}. Veuillez régulariser dès que possible pour éviter tout retard supplémentaire.'
          : 'This was due $daysLate day${daysLate > 1 ? 's' : ''} ago. Please settle it as soon as possible to avoid falling further behind.';
    } else if (urgency == _InstallmentUrgency.dueSoon) {
      final daysLeft = installment.dueDate!.difference(DateTime.now()).inDays;
      explanation = strings.isFrench
          ? 'Échéance dans $daysLeft jour${daysLeft > 1 ? 's' : ''}.'
          : 'Due in $daysLeft day${daysLeft > 1 ? 's' : ''}.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: urgency == _InstallmentUrgency.overdue ? Colors.red.withValues(alpha: 0.05) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: urgency == _InstallmentUrgency.overdue ? Colors.red.withValues(alpha: 0.3) : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(badgeIcon, color: badgeColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(installment.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (installment.dueDate != null)
                      Text('${strings.due}: ${_formatDate(installment.dueDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (explanation != null) ...[
            const SizedBox(height: 8),
            Text(explanation, style: theme.textTheme.bodySmall?.copyWith(color: badgeColor)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${installment.amount.toStringAsFixed(0)} FCFA', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => context.push('/parent/payment', extra: {
                  'child': child,
                  'landing': landing,
                  'amount': installment.amount,
                  'paymentPurpose': installment.name,
                  'installmentId': installment.installmentId,
                }),
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: Text(strings.payNow),
                style: urgency == _InstallmentUrgency.overdue ? FilledButton.styleFrom(backgroundColor: Colors.red.shade600) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}