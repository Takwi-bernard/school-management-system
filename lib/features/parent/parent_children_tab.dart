import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import 'parent_admissions_tab.dart';
import 'parent_dashboard_tab.dart' show PendingAdmissionCard;
import 'parent_models.dart';
import 'parent_navigation.dart';
import 'parent_providers.dart';
import 'parent_review_child_tab.dart';

/// The "My Children" sidebar destination - was a _ComingSoon stub.
/// Lists every enrolled child (tap to open the full Review page for
/// them) plus, underneath, any admission still in progress, using the
/// exact same card the dashboard already shows for those. Same visual
/// language as the dashboard: brand-color tints only, semantic color
/// reserved for status, one combined empty state rather than two
/// silently-blank sections when there's nothing to show yet.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final pendingAsync = ref.watch(pendingAdmissionsProvider);

    final children = enrolledAsync.valueOrNull;
    final pending = pendingAsync.valueOrNull;
    final bothLoaded = children != null && pending != null;
    final bothEmpty = bothLoaded && children.isEmpty && pending.isEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.myChildren, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            strings.isFrench
                ? 'Chaque enfant inscrit ou en cours d\'admission apparaît ici.'
                : 'Every enrolled child, and any admission still in progress, shows up here.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),

          if (bothEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.family_restroom_rounded, size: 30, color: scheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(strings.noChildrenTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    strings.isFrench
                        ? 'Commencez par inscrire votre enfant, ou reliez-le à votre compte s\'il a déjà été admis par l\'école.'
                        : 'Start by enrolling your child, or link them to your account if the school has already admitted them.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _openAdmissions(ref),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(strings.enrollMyChild),
                  ),
                ],
              ),
            )
          else ...[
            enrolledAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorStateView(error: e, onRetry: () => ref.invalidate(enrolledChildrenProvider)),
              data: (list) {
                if (list.isEmpty) return const SizedBox();
                return Column(
                  children: [
                    for (final child in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EnrolledChildCard(child: child, landing: landing, strings: strings),
                      ),
                  ],
                );
              },
            ),
            pendingAsync.when(
              loading: () => const SizedBox(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ErrorStateView(error: e, onRetry: () => ref.invalidate(pendingAdmissionsProvider)),
              ),
              data: (list) {
                if (list.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(strings.admissionsInProgress, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    for (final p in list)
                      PendingAdmissionCard(admission: p, strings: strings, landing: landing, schoolId: schoolId),
                  ],
                );
              },
            ),
          ],
        ],
      ),
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
    final scheme = theme.colorScheme;
    final hasPhoto = child.photoUrl != null && child.photoUrl!.isNotEmpty;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          pushParentContent(
            ref,
            ParentContentPage(
              title: child.fullName,
              builder: (context) => ParentReviewChildTab(child: child, landing: landing, strings: strings),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                backgroundImage: hasPhoto ? NetworkImage(child.photoUrl!) : null,
                onBackgroundImageError: hasPhoto ? (_, __) {} : null,
                child: hasPhoto
                    ? null
                    : Text(
                        child.firstName.isNotEmpty ? child.firstName[0].toUpperCase() : '?',
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      child.className == null || child.className!.isEmpty
                          ? child.admissionNumber
                          : '${child.className} \u00b7 ${child.admissionNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
