import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../principal/principal_core.dart';
import '../proprietor/proprietor_ui.dart';
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
        return Icons.payments_rounded;
      case 'bank_transfer':
        return Icons.account_balance_rounded;
      default:
        return Icons.smartphone_rounded;
    }
  }

  Future<void> _flag(BuildContext context, WidgetRef ref, MyPayment payment) async {
    final sent = await pnSheet<bool>(context, (_) => _FlagSheet(payment: payment, strings: strings));
    if (sent == true) {
      ref.invalidate(myPaymentsProvider(schoolId));
      if (context.mounted) prSnack(context, strings.sFlagSubmittedMessage);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(myPaymentsProvider(schoolId));
    final fr = strings.isFrench;

    Future<void> refresh() async {
      ref.invalidate(myPaymentsProvider(schoolId));
      try {
        await ref.read(myPaymentsProvider(schoolId).future);
      } catch (_) {}
    }

    return PrPage(
      onRefresh: refresh,
      children: [
        PrHeader(
          title: strings.sMyCollections,
          subtitle: strings.sMyCollectionsDescription,
          trailing: IconButton.filledTonal(tooltip: strings.tryAgain, icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(myPaymentsProvider(schoolId))),
        ),
        SxAsync<List<MyPayment>>(
          value: async,
          strings: strings,
          onRetry: () => ref.invalidate(myPaymentsProvider(schoolId)),
          isEmpty: (l) => l.isEmpty,
          empty: SxEmpty(icon: Icons.receipt_long_outlined, title: strings.sNoCollectionsYetMessage),
          builder: (payments) {
            final total = payments.fold<double>(0, (sum, p) => sum + p.amount);
            final flagged = payments.where((p) => p.correctionRequested).length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PrGrid(max: 3, minTile: 220, children: [
                PrStatTile(icon: Icons.account_balance_wallet_rounded, label: fr ? 'Total encaissé' : 'Total collected', value: total, format: formatMoney),
                PrStatTile(icon: Icons.receipt_long_rounded, label: fr ? 'Paiements enregistrés' : 'Payments recorded', value: payments.length.toDouble(), format: (v) => v.round().toString()),
                PrStatTile(icon: Icons.flag_rounded, label: strings.sCorrectionRequestedLabel, value: flagged.toDouble(), format: (v) => v.round().toString()),
              ]),
              const SizedBox(height: 22),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 900 ? 2 : 1;
                const gap = 12.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(spacing: gap, children: [
                  for (var i = 0; i < payments.length; i++)
                    SizedBox(
                      width: w,
                      child: SxRow(
                        index: i < 10 ? i : 0,
                        leading: SxIconBadge(icon: _methodIcon(payments[i].method)),
                        title: payments[i].childName.isEmpty ? '-' : payments[i].childName,
                        lines: ['${payments[i].purpose} · ${paymentMethodLabel(strings, payments[i].method)}', formatDateTime(payments[i].createdAt)],
                        trailing: Text(formatMoney(payments[i].amount), textAlign: TextAlign.end, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        bottom: payments[i].correctionRequested
                            ? Align(alignment: Alignment.centerLeft, child: PnChip(label: strings.sCorrectionRequestedLabel, color: pnWarn(), icon: Icons.flag_rounded))
                            : Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant, visualDensity: VisualDensity.compact),
                                  onPressed: () => _flag(context, ref, payments[i]),
                                  icon: const Icon(Icons.flag_outlined, size: 16),
                                  label: Text(strings.sFlagForReviewLabel),
                                ),
                              ),
                      ),
                    ),
                ]);
              }),
            ]);
          },
        ),
      ],
    );
  }
}

class _FlagSheet extends ConsumerStatefulWidget {
  final MyPayment payment;
  final AppStrings strings;
  const _FlagSheet({required this.payment, required this.strings});

  @override
  ConsumerState<_FlagSheet> createState() => _FlagSheetState();
}

class _FlagSheetState extends ConsumerState<_FlagSheet> {
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
      if (mounted) setState(() => _error = sxMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PnSheetBody(
      title: _s.sFlagForReviewLabel,
      subtitle: '${widget.payment.childName} · ${formatMoney(widget.payment.amount)}',
      children: [
        TextField(
          controller: _reason,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: pnDeco(_s.sFlagReasonHint).copyWith(alignLabelWithHint: true),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: cs.error, fontSize: 12.5)),
        ],
      ],
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text(_s.sNotNowLabel)),
        FilledButton(onPressed: _saving ? null : _submit, child: PnBusyLabel(busy: _saving, label: _s.sSubmitLabel)),
      ],
    );
  }
}
