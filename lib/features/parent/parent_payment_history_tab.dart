import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../landing/landing_model.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_fees.dart' show generateReceiptPdf;
import 'parent_models.dart';
import 'parent_providers.dart';
import 'parent_ui.dart';

enum _Filter { all, paid, pending, failed }

/// Payment history across all children, with a summary and filter.
class ParentPaymentHistoryTab extends ConsumerStatefulWidget {
  final LandingModel landing;
  final AppStrings strings;
  const ParentPaymentHistoryTab({super.key, required this.landing, required this.strings});

  @override
  ConsumerState<ParentPaymentHistoryTab> createState() => _ParentPaymentHistoryTabState();
}

class _ParentPaymentHistoryTabState extends ConsumerState<ParentPaymentHistoryTab> {
  _Filter _filter = _Filter.all;

  bool _matches(PaymentTransaction t) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.paid:
        return t.isSuccessful;
      case _Filter.pending:
        return !t.isTerminal;
      case _Filter.failed:
        return t.isFailed || t.isCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final fr = strings.isFrench;
    final historyAsync = ref.watch(paymentHistoryProvider);

    return PrPage(
      maxWidth: 820,
      onRefresh: () async {
        ref.invalidate(paymentHistoryProvider);
        await ref.read(paymentHistoryProvider.future).catchError((_) => <PaymentTransaction>[]);
      },
      children: [
        PrHeader(
          title: strings.paymentHistory,
          subtitle: fr
              ? 'Toutes vos transactions, pour tous vos enfants, les plus récentes en premier.'
              : 'All your transactions, across all your children, most recent first.',
        ),
        const SizedBox(height: 16),
        PaAsync<List<PaymentTransaction>>(
          value: historyAsync,
          strings: strings,
          onRetry: () => ref.invalidate(paymentHistoryProvider),
          rows: 4,
          rowHeight: 110,
          isEmpty: (l) => l.isEmpty,
          empty: PaEmpty(icon: Icons.receipt_long_rounded, title: strings.noPaymentsYet),
          builder: (all) {
            final paidTotal = all.where((t) => t.isSuccessful).fold<double>(0, (a, t) => a + t.amount);
            final shown = all.where(_matches).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PaHero(
                eyebrow: fr ? 'Total payé' : 'Total paid',
                title: paMoney(paidTotal),
                subtitle: fr ? '${all.length} transaction${all.length > 1 ? 's' : ''}' : '${all.length} transaction${all.length > 1 ? 's' : ''}',
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: PrPills<_Filter>(
                  values: _Filter.values,
                  selected: _filter,
                  label: (f) => switch (f) {
                    _Filter.all => fr ? 'Tout' : 'All',
                    _Filter.paid => fr ? 'Payé' : 'Paid',
                    _Filter.pending => fr ? 'En attente' : 'Pending',
                    _Filter.failed => fr ? 'Échoué' : 'Failed',
                  },
                  onChanged: (f) => setState(() => _filter = f),
                ),
              ),
              const SizedBox(height: 14),
              if (shown.isEmpty)
                PrCard(child: PaEmpty(icon: Icons.filter_alt_off_rounded, title: strings.noPaymentsYet))
              else
                for (var i = 0; i < shown.length; i++)
                  PrReveal(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PaymentTile(transaction: shown[i], landing: widget.landing, strings: strings),
                    ),
                  ),
            ]);
          },
        ),
      ],
    );
  }
}

class _PaymentTile extends ConsumerStatefulWidget {
  final PaymentTransaction transaction;
  final LandingModel landing;
  final AppStrings strings;
  const _PaymentTile({required this.transaction, required this.landing, required this.strings});

  @override
  ConsumerState<_PaymentTile> createState() => _PaymentTileState();
}

class _PaymentTileState extends ConsumerState<_PaymentTile> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await generateReceiptPdf(ref: ref, transaction: widget.transaction, landing: widget.landing, isFrench: widget.strings.isFrench);
    } catch (_) {
      if (mounted) {
        prSnack(context, widget.strings.isFrench ? 'Échec du téléchargement. Veuillez réessayer.' : 'Download failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = widget.transaction;
    final fr = widget.strings.isFrench;

    final (Color color, String label, IconData icon) = t.isSuccessful
        ? (kSettled, fr ? 'Payé' : 'Paid', Icons.check_circle_rounded)
        : t.isFailed
            ? (kOverdue, fr ? 'Échoué' : 'Failed', Icons.cancel_rounded)
            : t.isCancelled
                ? (kOverdue, fr ? 'Annulé' : 'Cancelled', Icons.block_rounded)
                : (kPending, fr ? 'En attente' : 'Pending', Icons.hourglass_top_rounded);

    return PrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PaIconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.paymentPurpose, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (t.childName != null) Text(t.childName!, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(paMoney(t.amount), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Text(paDateTime(t.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
        ]),
        if (t.isSuccessful) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _downloading ? null : _download,
              icon: _downloading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 16),
              label: Text(widget.strings.downloadReceipt),
            ),
          ),
        ],
      ]),
    );
  }
}
