import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import '../parent/parent_models.dart';
import 'parent_fees.dart' show generateReceiptPdf;
import 'parent_providers.dart';

/// Migrated from PaymentHistoryPage/_PaymentHistoryTile - no own
/// Scaffold/AppBar/Theme wrap anymore, ParentShell provides all
/// three. generateReceiptPdf itself is unchanged in behavior here,
/// just reformatted inside (see parent_fees.dart).
class ParentPaymentHistoryTab extends ConsumerWidget {
  final LandingModel landing;
  final AppStrings strings;
  const ParentPaymentHistoryTab({super.key, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(paymentHistoryProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: historyAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('$e'),
        data: (transactions) {
          if (transactions.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(strings.noPaymentsYet, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.paymentHistory, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                strings.isFrench
                    ? 'Toutes vos transactions, pour tous vos enfants, les plus récentes en premier.'
                    : 'All your transactions, across all your children, most recent first.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              ...transactions.map((t) => _PaymentHistoryTile(transaction: t, landing: landing, strings: strings)),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentHistoryTile extends ConsumerStatefulWidget {
  final PaymentTransaction transaction;
  final LandingModel landing;
  final AppStrings strings;
  const _PaymentHistoryTile({required this.transaction, required this.landing, required this.strings});

  @override
  ConsumerState<_PaymentHistoryTile> createState() => _PaymentHistoryTileState();
}

class _PaymentHistoryTileState extends ConsumerState<_PaymentHistoryTile> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await generateReceiptPdf(ref: ref, transaction: widget.transaction, landing: widget.landing);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.transaction;
    final strings = widget.strings;

    final (Color color, String label, IconData icon) = t.isSuccessful
        ? (Colors.green, strings.isFrench ? 'Payé' : 'Paid', Icons.check_circle_rounded)
        : t.isFailed
            ? (Colors.red, strings.isFrench ? 'Échoué' : 'Failed', Icons.cancel_rounded)
            : (Colors.orange, strings.isFrench ? 'En attente' : 'Pending', Icons.hourglass_top_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
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
              Text('${t.amount.toStringAsFixed(0)} FCFA', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Text(_formatDate(t.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}