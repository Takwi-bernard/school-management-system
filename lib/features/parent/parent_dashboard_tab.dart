import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../landing/landing_model.dart';
import '../principal/principal_core.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_admissions_tab.dart';
import 'parent_fees_tab.dart';
import 'parent_models.dart';
import 'parent_navigation.dart';
import 'parent_providers.dart';
import 'parent_report_card_tab.dart';
import 'parent_review_child_tab.dart';
import 'parent_shell.dart' show ParentChildAvatar;
import 'parent_ui.dart';

/// Home, inside ParentShell.
class ParentDashboardTab extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ParentDashboardTab({super.key, required this.schoolId, required this.landing, required this.strings});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return strings.isFrench ? 'Bonjour' : 'Good morning';
    if (hour < 17) return strings.isFrench ? 'Bon après-midi' : 'Good afternoon';
    return strings.isFrench ? 'Bonsoir' : 'Good evening';
  }

  void _openAdmissions(WidgetRef ref) {
    ref.read(parentActiveNavKeyProvider.notifier).state = 'admissions';
    showParentContent(
      ref,
      ParentContentPage(
        title: strings.enrollMyChild,
        builder: (ctx) => ParentAdmissionsTab(schoolId: schoolId, landing: landing, strings: strings),
      ),
    );
  }

  void _openFor(WidgetRef ref, EnrolledChild child, String key) {
    ref.read(parentActiveNavKeyProvider.notifier).state = key;
    late final String title;
    late final WidgetBuilder builder;
    switch (key) {
      case 'report_cards':
        title = strings.reportCards;
        builder = (ctx) => ParentReportCardTab(child: child, landing: landing, strings: strings);
        break;
      case 'review':
        title = strings.reviewMyChild;
        builder = (ctx) => ParentReviewChildTab(child: child, landing: landing, strings: strings);
        break;
      default:
        title = strings.schoolFees;
        builder = (ctx) => ParentFeesTab(child: child, landing: landing, strings: strings);
    }
    showParentContent(ref, ParentContentPage(title: '$title · ${child.fullName}', builder: builder));
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(enrolledChildrenProvider);
    ref.invalidate(pendingAdmissionsProvider);
    ref.invalidate(parentProfileProvider);
    await ref.read(enrolledChildrenProvider.future).catchError((_) => <EnrolledChild>[]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profileAsync = ref.watch(parentProfileProvider);
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final pendingAsync = ref.watch(pendingAdmissionsProvider);

    final childCount = enrolledAsync.valueOrNull?.length;
    final pending = pendingAsync.valueOrNull ?? const <PendingAdmission>[];
    final firstName = profileAsync.valueOrNull?.fullName.trim().split(' ').first;

    return PrPage(
      maxWidth: 980,
      onRefresh: () => _refresh(ref),
      children: [
        PaHero(
          eyebrow: _greeting(),
          title: (firstName == null || firstName.isEmpty) ? strings.myChildren : firstName,
          subtitle: strings.isFrench
              ? 'Voici où en sont vos enfants aujourd\'hui.'
              : 'Here\'s where things stand with your children today.',
          bottom: Row(children: [
            Expanded(child: PaHeroStat(label: strings.myChildren, value: childCount?.toString() ?? '-')),
            if (pending.isNotEmpty) Expanded(child: PaHeroStat(label: strings.admissionsInProgress, value: pending.length.toString())),
          ]),
        ),
        const SizedBox(height: 16),
        PrReveal(
          index: 1,
          child: PrCard(
            onTap: () => _openAdmissions(ref),
            child: Row(children: [
              const PaIconBadge(icon: Icons.person_add_alt_1_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(strings.enrollMyChild, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    strings.isFrench ? 'Nouvelle inscription ou lien avec un enfant déjà admis' : 'New enrollment, or link a child already admitted',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                  ),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.outline),
            ]),
          ),
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 26),
          PrSectionTitle(
            title: strings.admissionsInProgress,
            subtitle: strings.isFrench
                ? 'Ces demandes ne sont pas encore visibles par l\'école tant qu\'elles ne sont pas terminées.'
                : 'These requests aren\'t visible to the school yet, until they\'re complete.',
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < pending.length; i++)
            PrReveal(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PendingAdmissionCard(admission: pending[i], strings: strings, landing: landing, schoolId: schoolId),
              ),
            ),
        ],
        const SizedBox(height: 26),
        PrSectionTitle(title: strings.myChildren),
        const SizedBox(height: 12),
        PaAsync<List<EnrolledChild>>(
          value: enrolledAsync,
          strings: strings,
          onRetry: () => ref.invalidate(enrolledChildrenProvider),
          rows: 2,
          rowHeight: 150,
          isEmpty: (l) => l.isEmpty,
          empty: PaEmpty(
            icon: Icons.family_restroom_rounded,
            title: strings.noChildrenTitle,
            text: strings.isFrench
                ? 'Commencez par inscrire votre enfant, ou reliez-le à votre compte s\'il a déjà été admis par l\'école.'
                : 'Start by enrolling your child, or link them to your account if the school has already admitted them.',
            action: FilledButton.icon(
              onPressed: () => _openAdmissions(ref),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(strings.enrollMyChild),
            ),
          ),
          builder: (children) => PrGrid(
            max: 2,
            minTile: 380,
            children: [
              for (var i = 0; i < children.length; i++)
                PrReveal(
                  index: i,
                  child: _ChildCard(
                    child: children[i],
                    strings: strings,
                    onOpen: (key) => _openFor(ref, children[i], key),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  final EnrolledChild child;
  final AppStrings strings;
  final void Function(String key) onOpen;
  const _ChildCard({required this.child, required this.strings, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ParentChildAvatar(child: child, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(child.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(child.className ?? strings.classNotAssigned, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(
            avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
            label: Text(strings.schoolFees),
            onPressed: () => onOpen('fees'),
          ),
          ActionChip(
            avatar: const Icon(Icons.description_outlined, size: 16),
            label: Text(strings.reportCards),
            onPressed: () => onOpen('report_cards'),
          ),
          ActionChip(
            avatar: const Icon(Icons.fact_check_outlined, size: 16),
            label: Text(strings.reviewMyChild),
            onPressed: () => onOpen('review'),
          ),
        ]),
      ]),
    );
  }
}

/// Explicit about WHY the child isn't visible to the school yet - not
/// just a status label with a hidden button.
class PendingAdmissionCard extends ConsumerWidget {
  final PendingAdmission admission;
  final AppStrings strings;
  final LandingModel landing;
  final String schoolId;
  const PendingAdmissionCard({
    super.key,
    required this.admission,
    required this.strings,
    required this.landing,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fr = strings.isFrench;

    final statusColor = admission.isRejected
        ? kOverdue
        : admission.needsPayment
            ? kPending
            : cs.onSurfaceVariant;

    final statusLabel = admission.isRejected
        ? (fr ? 'Rejeté' : 'Rejected')
        : admission.needsPayment
            ? (fr ? 'Paiement requis' : 'Payment needed')
            : (fr ? 'En cours d\'examen' : 'Under review');

    final explanation = admission.isRejected
        ? (fr ? 'L\'école n\'a pas approuvé cette demande.' : 'The school did not approve this request.')
        : admission.needsPayment
            ? (fr
                ? 'Le Directeur ne verra cet enfant qu\'une fois les frais d\'inscription payés.'
                : 'The Principal won\'t see this child until the registration fee is paid.')
            : (fr
                ? 'Votre paiement a été reçu. L\'école examine actuellement cette demande.'
                : 'Your payment has been received - the school is reviewing this now.');

    return PrCard(
      onTap: admission.needsPayment
          ? () => _goToPayment(context, ref)
          : () => pnSheet<void>(
                context,
                (_) => PnSheetBody(
                  title: admission.fullName,
                  subtitle: statusLabel,
                  children: [
                    Text(explanation, style: theme.textTheme.bodyMedium),
                    if (admission.isRejected && (admission.rejectionReason ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PaKeyValue(label: fr ? 'Motif' : 'Reason', value: admission.rejectionReason!.trim()),
                    ],
                  ],
                  actions: [
                    FilledButton(onPressed: () => Navigator.pop(context), child: Text(fr ? 'Fermer' : 'Close')),
                  ],
                ),
              ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PaIconBadge(icon: admission.isRejected ? Icons.close_rounded : Icons.hourglass_top_rounded, color: statusColor, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(admission.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text(admission.requestedClassName, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(explanation, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
        if (admission.needsPayment)
          Consumer(builder: (context, ref, _) {
            final feeAsync = ref.watch(registrationFeeProvider((classId: admission.requestedClassId, academicYearId: admission.academicYearId)));
            return feeAsync.when(
              loading: () => const Padding(padding: EdgeInsets.only(top: 12), child: PrSkeleton(height: 44, radius: 14)),
              error: (e, _) => const SizedBox(),
              data: (fee) {
                if (fee == null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      fr
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
                      label: Text('${strings.payNow} - ${paMoney(fee)}'),
                    ),
                  ),
                );
              },
            );
          }),
      ]),
    );
  }

  Future<void> _goToPayment(BuildContext context, WidgetRef ref, {double? amountOverride}) async {
    final fee = amountOverride ??
        await ref.read(registrationFeeProvider((classId: admission.requestedClassId, academicYearId: admission.academicYearId)).future);
    if (fee == null || !context.mounted) return;

    context.push('/parent/payment', extra: {
      'admissionRequestId': admission.id,
      'landing': landing,
      'amount': fee,
      'paymentPurpose': 'Registration Fee',
    });
  }
}
