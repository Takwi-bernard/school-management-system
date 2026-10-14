import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

/// Payments the secretary asked to correct. The principal approves
/// (the payment is cancelled so the secretary can record it again) or
/// declines with a note.
class PrincipalCorrectionsPage extends ConsumerStatefulWidget {
  final AppStrings strings;
  const PrincipalCorrectionsPage({super.key, required this.strings});

  @override
  ConsumerState<PrincipalCorrectionsPage> createState() => _PrincipalCorrectionsPageState();
}

class _PrincipalCorrectionsPageState extends ConsumerState<PrincipalCorrectionsPage> {
  bool _history = false;
  String? _busyId;

  AppStrings get _s => widget.strings;

  void _refresh() {
    ref.invalidate(pnCorrectionsProvider);
    ref.invalidate(pnOverviewProvider);
    ref.invalidate(pnArrearsProvider);
  }

  Future<void> _resolve(PnCorrection c, bool approve) async {
    final s = _s;
    String? note;
    if (approve) {
      final ok = await pnConfirm(
        context,
        s,
        title: s.pn('Approve this correction?', 'Approuver cette correction ?'),
        message: c.linkedAdmission
            ? s.pn('This payment is linked to an admission. Cancelling it removes ${pMoney(c.amount)} from ${c.student}\'s fees. The secretary will record the right payment afterwards. Check the admission before you approve.', 'Ce paiement est lié à une admission. L\'annuler retire ${pMoney(c.amount)} des frais de ${c.student}. La secrétaire enregistrera ensuite le bon paiement. Vérifiez l\'admission avant d\'approuver.')
            : s.pn('The payment of ${pMoney(c.amount)} by ${c.student} will be cancelled. The secretary can then record the right payment.', 'Le paiement de ${pMoney(c.amount)} de ${c.student} sera annulé. La secrétaire pourra alors enregistrer le bon paiement.'),
        confirmLabel: s.pn('Approve and cancel payment', 'Approuver et annuler le paiement'),
        destructive: true,
      );
      if (!ok || !mounted) return;
    } else {
      note = await pnSheet<String>(context, (_) => _DeclineSheet(strings: s, correction: c));
      if (note == null || !mounted) return;
    }

    setState(() => _busyId = c.id);
    try {
      await ref.read(principalHubRepositoryProvider).resolveCorrection(paymentId: c.id, approve: approve, note: note);
      _refresh();
      if (mounted) {
        prSnack(context, approve ? s.pn('Correction approved. The payment was cancelled.', 'Correction approuvée. Le paiement a été annulé.') : s.pn('Request declined. The secretary was informed.', 'Demande refusée. La secrétaire a été informée.'));
      }
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final async = ref.watch(pnCorrectionsProvider(_history));

    return PrPage(
      onRefresh: () async => _refresh(),
      children: [
        PrHeader(
          title: s.pn('Payment corrections', 'Corrections de paiements'),
          subtitle: s.pn('The secretary asks you before a recorded payment can be changed.', 'La secrétaire vous demande l\'accord avant qu\'un paiement enregistré soit modifié.'),
        ),
        PrPills<bool>(
          values: const [false, true],
          selected: _history,
          label: (v) => v ? s.pn('With history', 'Avec l\'historique') : s.pn('Waiting for me', 'En attente'),
          onChanged: (v) => setState(() => _history = v),
        ),
        const SizedBox(height: 16),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SizedBox(height: 260, child: PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnCorrectionsProvider))),
          data: (items) {
            if (items.isEmpty) {
              return SizedBox(
                height: 300,
                child: PrEmpty(
                  icon: Icons.task_alt_rounded,
                  title: s.pn('Nothing to review', 'Rien à examiner'),
                  description: s.pn('When the secretary asks to correct a payment, it appears here.', 'Quand la secrétaire demande de corriger un paiement, il apparaît ici.'),
                ),
              );
            }
            return Column(children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PrReveal(index: i, child: _CorrectionCard(item: items[i], strings: s, busy: _busyId == items[i].id, onApprove: () => _resolve(items[i], true), onDecline: () => _resolve(items[i], false))),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  final PnCorrection item;
  final AppStrings strings;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  const _CorrectionCard({required this.item, required this.strings, required this.busy, required this.onApprove, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = item;

    return PrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.student, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                [if (c.className != null) c.className!, if (c.admissionNumber != null) c.admissionNumber!, if (c.installment != null) c.installment!].join('  ·  '),
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
            ]),
          ),
          Text(pMoney(c.amount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          PnChip(label: pMethodLabel(s, c.method), color: cs.primary),
          if (c.paidAt != null) PnChip(label: pDate(c.paidAt!)),
          if (c.reference != null) PnChip(label: c.reference!),
          if (c.linkedAdmission) PnChip(label: s.pn('Linked to an admission', 'Lié à une admission'), color: pnWarn(), icon: Icons.link_rounded),
          if (c.isResolved)
            PnChip(
              label: c.resolution == 'approved' ? s.pn('Approved', 'Approuvée') : s.pn('Declined', 'Refusée'),
              color: c.resolution == 'approved' ? pnGood() : pnBad(),
            ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${s.pn('Reason given by', 'Motif donné par')} ${c.requestedBy.isEmpty ? s.pn('the secretary', 'la secrétaire') : c.requestedBy}${c.requestedAt == null ? '' : '  ·  ${pDateTime(c.requestedAt!)}'}',
              style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 4),
            Text(c.reason ?? '–', style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          ]),
        ),
        if (c.isResolved && c.resolutionNote != null) ...[
          const SizedBox(height: 8),
          Text('${s.pn('Your note', 'Votre note')}: ${c.resolutionNote}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
        ],
        if (!c.isResolved) ...[
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: busy ? null : onDecline, child: Text(s.pn('Decline', 'Refuser'))),
            const SizedBox(width: 10),
            FilledButton(onPressed: busy ? null : onApprove, child: PnBusyLabel(busy: busy, label: s.pn('Approve', 'Approuver'))),
          ]),
        ],
      ]),
    );
  }
}

class _DeclineSheet extends StatefulWidget {
  final AppStrings strings;
  final PnCorrection correction;
  const _DeclineSheet({required this.strings, required this.correction});

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PnSheetBody(
      title: s.pn('Decline this request', 'Refuser cette demande'),
      subtitle: '${widget.correction.student} · ${pMoney(widget.correction.amount)}',
      children: [
        TextField(
          controller: _note,
          autofocus: true,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: pnDeco(s.pn('Tell the secretary why', 'Dites à la secrétaire pourquoi')),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(
          onPressed: _note.text.trim().length < 3 ? null : () => Navigator.pop(context, _note.text.trim()),
          child: Text(s.pn('Decline request', 'Refuser la demande')),
        ),
      ],
    );
  }
}
