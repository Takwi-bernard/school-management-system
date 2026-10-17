import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_model.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_admissions_tab.dart';
import 'parent_dashboard_tab.dart' show PendingAdmissionCard;
import 'parent_models.dart';
import 'parent_navigation.dart';
import 'parent_providers.dart';
import 'parent_review_child_tab.dart';
import 'parent_shell.dart' show ParentChildAvatar;
import 'parent_ui.dart';

/// "My Children": every enrolled child (tap for the full review page)
/// plus admissions still in progress, with one combined empty state.
class ParentChildrenTab extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ParentChildrenTab({super.key, required this.schoolId, required this.landing, required this.strings});

  void _openAdmissions(WidgetRef ref) {
    ref.read(parentActiveNavKeyProvider.notifier).state = 'admissions';
    pushParentContent(
      ref,
      ParentContentPage(
        title: strings.enrollMyChild,
        builder: (ctx) => ParentAdmissionsTab(schoolId: schoolId, landing: landing, strings: strings),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(enrolledChildrenProvider);
    ref.invalidate(pendingAdmissionsProvider);
    await ref.read(enrolledChildrenProvider.future).catchError((_) => <EnrolledChild>[]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final pendingAsync = ref.watch(pendingAdmissionsProvider);
    final fr = strings.isFrench;

    final children = enrolledAsync.valueOrNull;
    final pending = pendingAsync.valueOrNull;
    final bothEmpty = children != null && pending != null && children.isEmpty && pending.isEmpty;

    return PrPage(
      maxWidth: 860,
      onRefresh: () => _refresh(ref),
      children: [
        PrHeader(
          title: strings.myChildren,
          subtitle: fr
              ? 'Chaque enfant inscrit ou en cours d\'admission apparaît ici.'
              : 'Every enrolled child, and any admission still in progress, shows up here.',
          trailing: FilledButton.tonalIcon(
            onPressed: () => _openAdmissions(ref),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(strings.enrollMyChild),
          ),
        ),
        const SizedBox(height: 18),
        if (bothEmpty)
          PrReveal(
            child: PrCard(
              child: PaEmpty(
                icon: Icons.family_restroom_rounded,
                title: strings.noChildrenTitle,
                text: fr
                    ? 'Commencez par inscrire votre enfant, ou reliez-le à votre compte s\'il a déjà été admis par l\'école.'
                    : 'Start by enrolling your child, or link them to your account if the school has already admitted them.',
                action: FilledButton.icon(
                  onPressed: () => _openAdmissions(ref),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(strings.enrollMyChild),
                ),
              ),
            ),
          )
        else ...[
          PaAsync<List<EnrolledChild>>(
            value: enrolledAsync,
            strings: strings,
            onRetry: () => ref.invalidate(enrolledChildrenProvider),
            rows: 3,
            rowHeight: 84,
            builder: (list) => Column(children: [
              for (var i = 0; i < list.length; i++)
                PrReveal(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EnrolledChildCard(child: list[i], landing: landing, strings: strings),
                  ),
                ),
            ]),
          ),
          if ((pending ?? const <PendingAdmission>[]).isNotEmpty) ...[
            const SizedBox(height: 18),
            PrSectionTitle(title: strings.admissionsInProgress),
            const SizedBox(height: 12),
            for (var i = 0; i < pending!.length; i++)
              PrReveal(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PendingAdmissionCard(admission: pending[i], strings: strings, landing: landing, schoolId: schoolId),
                ),
              ),
          ],
          if (pendingAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PaError(error: pendingAsync.error!, strings: strings, onRetry: () => ref.invalidate(pendingAdmissionsProvider)),
            ),
        ],
      ],
    );
  }
}

class _EnrolledChildCard extends ConsumerWidget {
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const _EnrolledChildCard({required this.child, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PrCard(
      onTap: () => pushParentContent(
        ref,
        ParentContentPage(
          title: child.fullName,
          builder: (context) => ParentReviewChildTab(child: child, landing: landing, strings: strings),
        ),
      ),
      child: Row(children: [
        ParentChildAvatar(child: child, radius: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(child.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              child.className == null || child.className!.isEmpty ? child.admissionNumber : '${child.className} · ${child.admissionNumber}',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: cs.outline),
      ]),
    );
  }
}
