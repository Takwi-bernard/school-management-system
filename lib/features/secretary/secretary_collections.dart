import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import 'secretary_format.dart';
import 'secretary_models.dart';
import 'secretary_providers.dart';
import 'secretary_strings.dart';
import 'secretary_ui.dart';

/// The secretary's own log of payments they recorded - the thing to
/// reconcile a cash drawer against at the end of the day. A mistaken
/// payment can be FLAGGED here; nothing is altered automatically.
class MyCollectionsPage extends ConsumerWidget {
  final String schoolId;
  final AppStrings strings;
  const MyCollectionsPage({super.key, required this.schoolId, required this.strings});

  IconData _methodIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'bank_transfer':
        return Icons.account_balance_outlined;
      default:
        return Icons.phone_android_rounded;
    }
  }

  Future<void> _flag(BuildContext context, WidgetRef ref, MyPayment payment) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _FlagDialog(payment: payment, strings: strings),
    );
    if (sent == true) {
      ref.invalidate(myPaymentsProvider(schoolId));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.sFlagSubmittedMessage)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(myPaymentsProvider(schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SecretaryPageHeader(
          title: strings.sMyCollections,
          subtitle: strings.sMyCollectionsDescription,
          trailing: IconButton(tooltip: strings.tryAgain, icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(myPaymentsProvider(schoolId))),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SecretaryErrorView(error: e, strings: strings, onRetry: () => ref.invalidate(myPaymentsProvider(schoolId))),
            data: (payments) {
              if (payments.isEmpty) {
                return SecretaryEmptyState(icon: Icons.receipt_long_outlined, title: strings.sNoCollectionsYetMessage);
              }
              final total = payments.fold<double>(0, (sum, p) => sum + p.amount);
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myPaymentsProvider(schoolId));
                  try {
                    await ref.read(myPaymentsProvider(schoolId).future);
                  } catch (_) {}
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: payments.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return SecretaryStatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        value: formatMoney(total),
                        label: '${payments.length} · ${strings.sMyCollections}',
                        color: Colors.green.shade700,
                      );
                    }
                    final p = payments[i - 1];
                    return SecretaryCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(_methodIcon(p.method), color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.childName.isEmpty ? '-' : p.childName, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${p.purpose} · ${paymentMethodLabel(strings, p.method)}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                              Text(formatDateTime(p.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                            ]),
                          ),
                          Text(formatMoney(p.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ]),
                        const SizedBox(height: 8),
                        if (p.correctionRequested)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text(strings.sCorrectionRequestedLabel, style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w700)),
                          )
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _flag(context, ref, p),
                              icon: const Icon(Icons.flag_outlined, size: 16),
                              label: Text(strings.sFlagForReviewLabel),
                            ),
                          ),
                      ]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _FlagDialog extends ConsumerStatefulWidget {
  final MyPayment payment;
  final AppStrings strings;
  const _FlagDialog({required this.payment, required this.strings});

  @override
  ConsumerState<_FlagDialog> createState() => _FlagDialogState();
}

class _FlagDialogState extends ConsumerState<_FlagDialog> {
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = _s.required);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(secretaryRepositoryProvider).requestPaymentCorrection(paymentId: widget.payment.id, reason: _reason.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_s.sFlagForReviewLabel),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.payment.childName} · ${formatMoney(widget.payment.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: InputDecoration(hintText: _s.sFlagReasonHint, border: const OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text(_s.cancel)),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_s.sSubmitLabel),
        ),
      ],
    );
  }
}