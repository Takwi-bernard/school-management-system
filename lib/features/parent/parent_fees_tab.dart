import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../landing/landing_model.dart';
import 'parent_models.dart';
import 'parent_providers.dart';
import 'parent_repository.dart' show PendingPayment;

/// Fees for one child, in-shell (ParentShell provides the Scaffold,
/// AppBar and Theme).
///
/// State rules this tab follows:
///  - An installment with a payment in flight shows "Awaiting
///    confirmation" instead of a Pay button - nobody pays twice.
///  - While anything is in flight the tab quietly re-checks it (and
///    asks the provider), then refreshes the balance by itself the
///    moment it is confirmed.
///  - Pull down to refresh; a weak network never leaves it stale.
///  - A paid installment never shows a Pay button.
class ParentFeesTab extends ConsumerStatefulWidget {
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const ParentFeesTab({super.key, required this.child, required this.landing, required this.strings});

  @override
  ConsumerState<ParentFeesTab> createState() => _ParentFeesTabState();
}

class _ParentFeesTabState extends ConsumerState<ParentFeesTab> {
  Timer? _timer;
  bool _reconciling = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (!mounted || _reconciling) return;
    final pending = ref.read(pendingInstallmentsProvider(widget.child.studentId)).valueOrNull ?? const {};
    if (pending.isEmpty) return;
    _reconciling = true;
    try {
      final repo = ref.read(parentRepositoryProvider);
      for (final p in pending.values.take(3)) {
        try {
          await repo.verifyPayment(p.id).timeout(const Duration(seconds: 20));
        } catch (_) {
          // Weak network - the next tick tries again.
        }
      }
    } finally {
      _reconciling = false;
    }
    if (mounted) ref.invalidate(pendingInstallmentsProvider(widget.child.studentId));
  }

  Future<void> _refresh(String? yearId) async {
    ref.invalidate(pendingInstallmentsProvider(widget.child.studentId));
    if (yearId != null && widget.child.classId != null) {
      final key = (studentId: widget.child.studentId, classId: widget.child.classId!, academicYearId: yearId);
      ref.invalidate(childFeesProvider(key));
      try {
        await ref.read(childFeesProvider(key).future);
      } catch (_) {
        // The error state below explains it; pull-to-refresh just ends.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final landing = widget.landing;
    final strings = widget.strings;
    final academicYearIdAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));

    // The moment the last in-flight payment resolves, the balance and
    // history must reflect it - without the parent doing anything.
    ref.listen(pendingInstallmentsProvider(child.studentId), (prev, next) {
      final had = prev?.valueOrNull?.isNotEmpty ?? false;
      final has = next.valueOrNull?.isNotEmpty ?? false;
      if (had && !has) {
        ref.invalidate(childFeesProvider);
        ref.invalidate(paymentHistoryProvider);
      }
    });

    return academicYearIdAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateView(
        error: e,
        onRetry: () => ref.invalidate(currentAcademicYearIdProvider(child.schoolId)),
      ),
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
        final feesKey = (studentId: child.studentId, classId: child.classId!, academicYearId: yearId);
        final feesAsync = ref.watch(childFeesProvider(feesKey));
        final pending = ref.watch(pendingInstallmentsProvider(child.studentId)).valueOrNull ?? const <String, PendingPayment>{};

        return feesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorStateView(error: e, onRetry: () => ref.invalidate(childFeesProvider(feesKey))),
          data: (fees) {
            if (fees.isEmpty) {
              return _FeesInfoState(icon: Icons.receipt_long_outlined, message: strings.noFeesConfigured);
            }
            final theme = Theme.of(context);
            return RefreshIndicator(
              onRefresh: () => _refresh(yearId),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(strings.schoolFees, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    strings.isFrench
                        ? 'Frais et échéances de ${child.firstName}, avec l\'historique de paiement.'
                        : '${child.firstName}\'s fees and due dates, with payment progress for each.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  _BalanceCard(fees: fees, strings: strings),
                  const SizedBox(height: 14),
                  if (pending.isNotEmpty) ...[
                    _PendingBanner(count: pending.length, strings: strings),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kSettled.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kSettled.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: kSettled, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.isFrench
                                ? 'Frais d\'inscription payés. ${child.firstName} est officiellement inscrit(e) à ${landing.schoolName}.'
                                : 'Registration fee paid. ${child.firstName} is officially enrolled at ${landing.schoolName}.',
                            style: const TextStyle(color: kSettled, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...fees.map((fee) => _FeeCard(fee: fee, child: child, landing: landing, strings: strings, pending: pending)),
                ],
              ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

String _fcfa(double amount) {
  final whole = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '$buffer FCFA';
}

/// The one number a parent opens this tab for: how much is left to pay.
class _BalanceCard extends StatelessWidget {
  final List<FeeSummary> fees;
  final AppStrings strings;
  const _BalanceCard({required this.fees, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fr = strings.isFrench;

    final total = fees.fold<double>(0, (s, f) => s + f.totalAmount);
    final paid = fees.fold<double>(0, (s, f) => s + f.amountPaid);
    final balance = (total - paid).clamp(0, double.infinity).toDouble();
    final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);

    InstallmentSummary? next;
    for (final f in fees) {
      for (final i in f.installments) {
        if (i.isPaid) continue;
        if (next == null) {
          next = i;
        } else if (i.dueDate != null && (next.dueDate == null || i.dueDate!.isBefore(next.dueDate!))) {
          next = i;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            balance <= 0 ? (fr ? 'SOLDE' : 'BALANCE') : (fr ? 'RESTE À PAYER' : 'LEFT TO PAY'),
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: balance),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              balance <= 0 ? (fr ? 'Tout est réglé' : 'All settled') : _fcfa(v),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: balance <= 0 ? kSettled : scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(value: v, minHeight: 9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_fcfa(paid)} / ${_fcfa(total)}  ·  ${(progress * 100).toStringAsFixed(0)}% ${fr ? 'payé' : 'paid'}',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (next != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.event_rounded, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    next.dueDate != null
                        ? (fr
                            ? 'Prochain versement : ${next.name} - ${_dateText(next.dueDate!)}'
                            : 'Next payment: ${next.name} - due ${_dateText(next.dueDate!)}')
                        : (fr ? 'Prochain versement : ${next.name}' : 'Next payment: ${next.name}'),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _dateText(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _PendingBanner extends StatelessWidget {
  final int count;
  final AppStrings strings;
  const _PendingBanner({required this.count, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fr = strings.isFrench;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPending.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPending.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPending)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fr
                  ? '$count paiement${count > 1 ? 's' : ''} en cours de confirmation. Nous vérifions pour vous - ne payez pas une deuxième fois.'
                  : '$count payment${count > 1 ? 's are' : ' is'} being confirmed. We are checking for you - please do not pay again.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
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
  final Map<String, PendingPayment> pending;
  const _FeeCard({
    required this.fee,
    required this.child,
    required this.landing,
    required this.strings,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Text(_fcfa(fee.totalAmount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fee.fullyPaid
                ? (strings.isFrench ? 'Tous les frais de scolarité ont été réglés.' : 'All school fees have been settled.')
                : strings.isFrench
                    ? 'L\'école a divisé ces frais en ${fee.installments.length} versements. Il reste $unpaidCount versement${unpaidCount > 1 ? 's' : ''} à payer.'
                    : 'The school has split this fee into ${fee.installments.length} installment${fee.installments.length > 1 ? 's' : ''}. $unpaidCount remain${unpaidCount == 1 ? 's' : ''} unpaid.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 6),
          ...fee.installments.map(
            (i) => _InstallmentRow(installment: i, child: child, landing: landing, strings: strings, pendingPayment: pending[i.installmentId]),
          ),
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
  final PendingPayment? pendingPayment;
  const _InstallmentRow({
    required this.installment,
    required this.child,
    required this.landing,
    required this.strings,
    required this.pendingPayment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fr = strings.isFrench;
    final urgency = _urgencyOf(installment);
    final inFlight = pendingPayment != null && !installment.isPaid;

    final (Color badgeColor, String badgeText, IconData badgeIcon) = inFlight
        ? (kPending, fr ? 'Confirmation en cours' : 'Awaiting confirmation', Icons.hourglass_top_rounded)
        : switch (urgency) {
            _InstallmentUrgency.paid => (kSettled, fr ? 'Payé' : 'Paid', Icons.check_circle_rounded),
            _InstallmentUrgency.overdue => (kOverdue, fr ? 'En retard' : 'Overdue', Icons.error_rounded),
            _InstallmentUrgency.dueSoon => (kPending, fr ? 'Échéance proche' : 'Due soon', Icons.schedule_rounded),
            _InstallmentUrgency.upcoming => (theme.colorScheme.primary, fr ? 'À venir' : 'Upcoming', Icons.event_rounded),
            _InstallmentUrgency.noDueDate => (theme.colorScheme.outline, fr ? 'Non payé' : 'Unpaid', Icons.radio_button_unchecked_rounded),
          };

    String? explanation;
    if (inFlight) {
      explanation = fr
          ? 'Votre paiement est en cours de confirmation. Ne payez pas à nouveau.'
          : 'Your payment is being confirmed. Please do not pay again.';
    } else if (urgency == _InstallmentUrgency.overdue) {
      final daysLate = DateTime.now().difference(installment.dueDate!).inDays;
      explanation = fr
          ? 'La date limite était il y a $daysLate jour${daysLate > 1 ? 's' : ''}. Veuillez régulariser dès que possible pour éviter tout retard supplémentaire.'
          : 'This was due $daysLate day${daysLate > 1 ? 's' : ''} ago. Please settle it as soon as possible to avoid falling further behind.';
    } else if (urgency == _InstallmentUrgency.dueSoon) {
      final daysLeft = installment.dueDate!.difference(DateTime.now()).inDays;
      explanation = fr ? 'Échéance dans $daysLeft jour${daysLeft > 1 ? 's' : ''}.' : 'Due in $daysLeft day${daysLeft > 1 ? 's' : ''}.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: urgency == _InstallmentUrgency.overdue && !inFlight ? kOverdue.withValues(alpha: 0.05) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: urgency == _InstallmentUrgency.overdue && !inFlight
              ? kOverdue.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant,
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
                      Text('${strings.due}: ${_dateText(installment.dueDate!)}',
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
            Text(explanation, style: theme.textTheme.bodySmall?.copyWith(color: badgeColor, height: 1.4)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(_fcfa(installment.amount), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (installment.isPaid)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded, size: 16, color: kSettled),
                    const SizedBox(width: 4),
                    Text(fr ? 'Réglé' : 'Settled', style: const TextStyle(color: kSettled, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                )
              else if (inFlight)
                OutlinedButton.icon(
                  onPressed: () => context.push('/parent/payment-status', extra: {
                    'transactionId': pendingPayment!.id,
                    'landing': landing,
                    'child': child,
                    'paymentPurpose': installment.name,
                    'amount': installment.amount,
                    'startedAt': pendingPayment!.createdAt,
                  }),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(fr ? 'Voir l\'état' : 'Check status'),
                )
              else
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
                  style: urgency == _InstallmentUrgency.overdue ? FilledButton.styleFrom(backgroundColor: kOverdue) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}