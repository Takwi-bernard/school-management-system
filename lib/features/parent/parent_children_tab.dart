import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import 'parent_dashboard_tab.dart' show PendingAdmissionCard;
import 'parent_models.dart';
import 'parent_navigation.dart';
import 'parent_providers.dart';
import 'parent_review_child_tab.dart';

/// The "My Children" sidebar destination - was a _ComingSoon stub.
/// Lists every enrolled child (tap to open the full Review page for
/// them) plus, underneath, any admission still in progress, using the
/// exact same card the dashboard already shows for those.
class ParentChildrenTab extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ParentChildrenTab({super.key, required this.schoolId, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final pendingAsync = ref.watch(pendingAdmissionsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.myChildren, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          enrolledAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorStateView(error: e, onRetry: () => ref.invalidate(enrolledChildrenProvider)),
            data: (children) {
              if (children.isEmpty) return const SizedBox();
              return Column(
                children: [
                  for (final child in children)
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
            data: (pending) {
              if (pending.isEmpty) return const SizedBox();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(strings.admissions, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final p in pending)
                    PendingAdmissionCard(admission: p, strings: strings, landing: landing, schoolId: schoolId),
                ],
              );
            },
          ),
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
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
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
                backgroundColor: theme.colorScheme.surface,
                backgroundImage: (child.photoUrl != null && child.photoUrl!.isNotEmpty)
                    ? NetworkImage(child.photoUrl!)
                    : null,
                onBackgroundImageError: (child.photoUrl != null && child.photoUrl!.isNotEmpty) ? (_, __) {} : null,
                child: (child.photoUrl == null || child.photoUrl!.isEmpty)
                    ? Icon(Icons.person_outline, color: theme.colorScheme.primary)
                    : null,
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
                          : '${child.className} · ${child.admissionNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
