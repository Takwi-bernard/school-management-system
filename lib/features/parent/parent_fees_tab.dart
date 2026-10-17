import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../landing/landing_model.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_models.dart';
import 'parent_providers.dart';
import 'parent_ui.dart';

/// Fees for one child: progress per fee and each installment with its
/// urgency. "Pay Now" keeps pushing to the payment route.
class ParentFeesTab extends ConsumerWidget {
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const ParentFeesTab({super.key, required this.child, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = strings.isFrench;
    final yearAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));

    Widget body;
    if (yearAsync.isLoading && !yearAsync.hasValue) {
      body = const PaSkeletonList(rows: 2, height: 180);
    } else if (yearAsync.hasError) {
      body = PaError(error: yearAsync.error!, strings: strings, onRetry: () => ref.invalidate(currentAcademicYearIdProvider(child.schoolId)));
    } else {
      final yearId = yearAsync.valueOrNull;
      if (yearId == null) {
        body = _info(Icons.event_busy_rounded, strings.academicYearNotSet);
      } else if (child.classId == null) {
        body = _info(
          Icons.info_outline_rounded,
          fr ? 'La classe de cet enfant n\'est pas encore confirmée par l\'école.' : 'This child\'s class has not been confirmed by the school yet.',
        );
      } else {
        final key = (studentId: child.studentId, classId: child.classId!, academicYearId: yearId);
        body = PaAsync<List<FeeSummary>>(
          value: ref.watch(childFeesProvider(key)),
          strings: strings,
          onRetry: () => ref.invalidate(childFeesProvider(key)),
          rows: 2,
          rowHeight: 180,
          isEmpty: (l) => l.isEmpty,
          empty: PaEmpty(icon: Icons.receipt_long_outlined, title: strings.noFeesConfigured),
          builder: (fees) {
            final total = fees.fold<double>(0, (a, f) => a + f.totalAmount);
            final paid = fees.fold<double>(0, (a, f) => a + f.amountPaid);
            final balance = (total - paid).clamp(0, double.infinity).toDouble();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PaHero(
                eyebrow: fr ? 'Solde à payer' : 'Balance due',
                title: paMoney(balance),
                subtitle: fr ? '${paMoney(paid)} payés sur ${paMoney(total)}' : '${paMoney(paid)} paid of ${paMoney(total)}',
                bottom: PrProgressBar(value: total <= 0 ? 0 : (paid / total).clamp(0.0, 1.0).toDouble(), color: Theme.of(context).colorScheme.onPrimary),
              ),
              const SizedBox(height: 14),
              PrReveal(
                index: 1,
                child: PrCard(
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, color: kSettled, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fr
                            ? 'Frais d\'inscription payés. ${child.firstName} est officiellement inscrit(e) à ${landing.schoolName}.'
                            : 'Registration fee paid. ${child.firstName} is officially enrolled at ${landing.schoolName}.',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < fees.length; i++)
                PrReveal(
                  index: i + 2,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FeeCard(fee: fees[i], child: child, landing: landing, strings: strings),
                  ),
                ),
            ]);
          },
        );
      }
    }

    return PrPage(
      maxWidth: 820,
      onRefresh: () async {
        ref.invalidate(currentAcademicYearIdProvider(child.schoolId));
      },
      children: [
        PrHeader(
          title: strings.schoolFees,
          subtitle: fr ? 'Frais et échéances de ${child.firstName}.' : '${child.firstName}\'s fees and due dates.',
        ),
        const SizedBox(height: 16),
        body,
      ],
    );
  }

  Widget _info(IconData icon, String message) => PrReveal(child: PrCard(child: PaEmpty(icon: icon, title: message)));
}

enum _Urgency { paid, overdue, dueSoon, upcoming, noDueDate }

_Urgency _urgencyOf(InstallmentSummary i) {
  if (i.isPaid) return _Urgency.paid;
  if (i.dueDate == null) return _Urgency.noDueDate;
  final daysLeft = i.dueDate!.difference(DateTime.now()).inDays;
  if (daysLeft < 0) return _Urgency.overdue;
  if (daysLeft <= 7) return _Urgency.dueSoon;
  return _Urgency.upcoming;
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
    final cs = theme.colorScheme;
    final fr = strings.isFrench;
    final progress = fee.totalAmount <= 0 ? 0.0 : (fee.amountPaid / fee.totalAmount).clamp(0.0, 1.0).toDouble();
    final unpaid = fee.installments.where((i) => !i.isPaid).length;

    return PrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(fee.feeName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          Text(paMoney(fee.totalAmount), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 4),
        Text(
          fee.fullyPaid
              ? (fr ? 'Tous les frais de scolarité ont été réglés.' : 'All school fees have been settled.')
              : fr
                  ? 'Divisé en ${fee.installments.length} versement${fee.installments.length > 1 ? 's' : ''}. Il en reste $unpaid à payer.'
                  : 'Split into ${fee.installments.length} installment${fee.installments.length > 1 ? 's' : ''}. $unpaid remain${unpaid == 1 ? 's' : ''} unpaid.',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
        ),
        const SizedBox(height: 14),
        PrProgressBar(value: progress, color: fee.fullyPaid ? kSettled : null),
        const SizedBox(height: 8),
        Text(
          '${paMoney(fee.amountPaid)} / ${paMoney(fee.totalAmount)}  ·  ${(progress * 100).toStringAsFixed(0)}% ${fr ? 'payé' : 'paid'}',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        if (fee.fullyPaid)
          Row(children: [
            const Icon(Icons.celebration_rounded, color: kSettled, size: 20),
            const SizedBox(width: 8),
            Text(fr ? 'Rien d\'autre à payer pour le moment.' : 'Nothing else to pay right now.', style: const TextStyle(color: kSettled, fontWeight: FontWeight.w700)),
          ])
        else
          for (final i in fee.installments) _InstallmentRow(installment: i, child: child, landing: landing, strings: strings),
      ]),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final InstallmentSummary installment;
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const _InstallmentRow({required this.installment, required this.child, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fr = strings.isFrench;
    final urgency = _urgencyOf(installment);

    final (Color color, String text, IconData icon) = switch (urgency) {
      _Urgency.paid => (kSettled, fr ? 'Payé' : 'Paid', Icons.check_circle_rounded),
      _Urgency.overdue => (kOverdue, fr ? 'En retard' : 'Overdue', Icons.error_rounded),
      _Urgency.dueSoon => (kPending, fr ? 'Échéance proche' : 'Due soon', Icons.schedule_rounded),
      _Urgency.upcoming => (cs.primary, fr ? 'À venir' : 'Upcoming', Icons.event_rounded),
      _Urgency.noDueDate => (cs.outline, fr ? 'Non payé' : 'Unpaid', Icons.radio_button_unchecked_rounded),
    };

    String? note;
    if (urgency == _Urgency.overdue) {
      final late = DateTime.now().difference(installment.dueDate!).inDays;
      note = fr
          ? 'La date limite était il y a $late jour${late > 1 ? 's' : ''}. Veuillez régulariser dès que possible.'
          : 'This was due $late day${late > 1 ? 's' : ''} ago. Please settle it as soon as possible.';
    } else if (urgency == _Urgency.dueSoon) {
      final left = installment.dueDate!.difference(DateTime.now()).inDays;
      note = fr ? 'Échéance dans $left jour${left > 1 ? 's' : ''}.' : 'Due in $left day${left > 1 ? 's' : ''}.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: urgency == _Urgency.overdue ? kOverdue.withValues(alpha: 0.05) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: urgency == _Urgency.overdue ? kOverdue.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(installment.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (installment.dueDate != null) Text('${strings.due}: ${paDate(installment.dueDate!)}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ]),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Flexible(child: Text(paMoney(installment.amount), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
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
            style: urgency == _Urgency.overdue ? FilledButton.styleFrom(backgroundColor: kOverdue) : null,
          ),
        ]),
      ]),
    );
  }
}
