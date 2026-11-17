import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../../core/status_colors.dart';
import '../landing/landing_model.dart';
import '../parent/parent_models.dart';
import 'parent_fees.dart' show generateReceiptPdf;
import 'parent_providers.dart';

/// Payment history, in-shell (ParentShell provides the Scaffold,
/// AppBar and Theme).
///
/// This tab is also the safety net for the payment flow: if a parent
/// left the status page, lost signal or closed the app, any payment
/// still "pending" here is re-checked automatically (against the
/// provider, not just the database) the moment the tab opens and every
/// few seconds after, until it resolves. Pull down to refresh.
class ParentPaymentHistoryTab extends ConsumerStatefulWidget {
  final LandingModel landing;
  final AppStrings strings;
  const ParentPaymentHistoryTab({super.key, required this.landing, required this.strings});

  @override
  ConsumerState<ParentPaymentHistoryTab> createState() => _ParentPaymentHistoryTabState();
}

class _ParentPaymentHistoryTabState extends ConsumerState<ParentPaymentHistoryTab> {
  Timer? _timer;
  bool _reconciling = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _reconcile());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reconcile();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reconcile() async {
    if (!mounted || _reconciling) return;
    final list = ref.read(paymentHistoryProvider).valueOrNull;
    if (list == null) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    final pending = list.where((t) => t.isPending && t.createdAt.isAfter(cutoff)).take(3).toList();
    if (pending.isEmpty) return;

    _reconciling = true;
    try {
      final repo = ref.read(parentRepositoryProvider);
      for (final t in pending) {
        try {
          await repo.verifyPayment(t.id).timeout(const Duration(seconds: 20));
        } catch (_) {
          // Weak network - the next round tries again.
        }
      }
    } finally {
      _reconciling = false;
    }
    if (!mounted) return;
    ref.invalidate(paymentHistoryProvider);
    ref.invalidate(childFeesProvider);
    ref.invalidate(pendingInstallmentsProvider);
  }

  Future<void> _refresh() async {
    ref.invalidate(paymentHistoryProvider);
    try {
      await ref.read(paymentHistoryProvider.future);
    } catch (_) {
      // The error state below explains it; pull-to-refresh just ends.
    }
    _reconcile();
  }

  @override
  Widget build(BuildContext context) {
    final landing = widget.landing;
    final strings = widget.strings;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final historyAsync = ref.watch(paymentHistoryProvider);
    final pendingCount = (historyAsync.valueOrNull ?? const <PaymentTransaction>[]).where((t) => t.isPending).length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.paymentHistory, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              strings.isFrench
                  ? 'Toutes vos transactions, pour tous vos enfants, les plus récentes en premier.'
                  : 'All your transactions, across all your children, most recent first.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: pendingCount == 0
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
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
                              strings.isFrench
                                  ? '$pendingCount paiement${pendingCount > 1 ? 's' : ''} en cours de confirmation. Nous vérifions automatiquement - ne payez pas une deuxième fois.'
                                  : '$pendingCount payment${pendingCount > 1 ? 's are' : ' is'} being confirmed. We are checking automatically - please do not pay again.',
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorStateView(error: e, onRetry: () => ref.invalidate(paymentHistoryProvider)),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.receipt_long_rounded, size: 30, color: scheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(strings.noPaymentsYet, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final t in transactions) _PaymentHistoryTile(key: ValueKey(t.id), transaction: t, landing: landing, strings: strings),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHistoryTile extends ConsumerStatefulWidget {
  final PaymentTransaction transaction;
  final LandingModel landing;
  final AppStrings strings;
  const _PaymentHistoryTile({super.key, required this.transaction, required this.landing, required this.strings});

  @override
  ConsumerState<_PaymentHistoryTile> createState() => _PaymentHistoryTileState();
}

class _PaymentHistoryTileState extends ConsumerState<_PaymentHistoryTile> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await generateReceiptPdf(ref: ref, transaction: widget.transaction, landing: widget.landing, isFrench: widget.strings.isFrench);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.strings.isFrench ? 'Échec du téléchargement. Veuillez réessayer.' : 'Download failed. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _openStatus() {
    final t = widget.transaction;
    context.push('/parent/payment-status', extra: {
      'transactionId': t.id,
      'landing': widget.landing,
      'child': null,
      'paymentPurpose': t.paymentPurpose,
      'amount': t.amount,
      'startedAt': t.createdAt,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.transaction;
    final strings = widget.strings;
    final fr = strings.isFrench;

    final (Color color, String label, IconData icon) = t.isSuccessful
        ? (kSettled, fr ? 'Payé' : 'Paid', Icons.check_circle_rounded)
        : t.isFailed
            ? (kOverdue, fr ? 'Échoué' : 'Failed', Icons.cancel_rounded)
            : t.isCancelled
                ? (kOverdue, fr ? 'Annulé' : 'Cancelled', Icons.block_rounded)
                : (kPending, fr ? 'En attente' : 'Pending', Icons.hourglass_top_rounded);

    final ref0 = t.transactionReference;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: t.isPending ? Border.all(color: kPending.withValues(alpha: 0.35)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.paymentPurpose, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (t.childName != null)
                      Text(t.childName!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              Text('${_formatAmount(t.amount)} FCFA', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_formatDate(t.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ),
            ],
          ),
          if (ref0 != null && ref0.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Clipboard.setData(ClipboardData(text: ref0));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(fr ? 'Référence copiée' : 'Reference copied'), duration: const Duration(seconds: 2)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${fr ? 'Réf' : 'Ref'}: $ref0',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, size: 13, color: theme.colorScheme.outline),
                  ],
                ),
              ),
            ),
          ],
          if (t.isPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openStatus,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: Text(fr ? 'Voir l\'état du paiement' : 'Check payment status'),
              ),
            ),
          ],
          if (t.isSuccessful) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(strings.downloadReceipt),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final whole = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return buffer.toString();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}