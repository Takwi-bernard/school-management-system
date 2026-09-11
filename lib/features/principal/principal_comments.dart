import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

class PendingCommentsPage extends ConsumerWidget {
  final String schoolId;
  const PendingCommentsPage({super.key, required this.schoolId});

  Future<void> _approve(BuildContext context, WidgetRef ref, PendingComment c) async {
    final editController = TextEditingController(text: c.comment);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve comment for ${c.studentName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You can edit the text before it reaches the parent, if needed.'),
            const SizedBox(height: 12),
            TextField(controller: editController, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve & Publish')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(principalRepositoryProvider).approveComment(c.id, editedText: editController.text.trim());
    ref.invalidate(pendingCommentsProvider(schoolId));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment approved and now visible to the parent.')));
  }

  Future<void> _discard(BuildContext context, WidgetRef ref, PendingComment c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Discard this comment?'),
        content: Text('${c.teacherName}\'s comment about ${c.studentName} will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(principalRepositoryProvider).discardComment(c.id);
    ref.invalidate(pendingCommentsProvider(schoolId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final commentsAsync = ref.watch(pendingCommentsProvider(schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comment Review', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('A teacher\'s comment only reaches the parent after you approve it here.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),
          Expanded(
            child: commentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (comments) {
                if (comments.isEmpty) return Center(child: Text('No comments waiting for review.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)));
                return ListView.separated(
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = comments[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c.studentName} · ${c.className}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text('${c.teacherName} · ${c.examPeriodName}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                          const SizedBox(height: 8),
                          Text(c.comment),
                          const SizedBox(height: 12),
                          Row(children: [
                            OutlinedButton(onPressed: () => _discard(context, ref, c), child: const Text('Discard')),
                            const SizedBox(width: 8),
                            FilledButton(onPressed: () => _approve(context, ref, c), child: const Text('Approve & Publish')),
                          ]),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}