import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'super_admin_models.dart';
import 'super_admin_providers.dart';
import 'super_admin_theme.dart';
import 'super_admin_ui.dart';

class ActivitySection extends ConsumerWidget {
  const ActivitySection({super.key});

  IconData _icon(String action) {
    if (action.contains('admin') || action.contains('password')) return Icons.admin_panel_settings_rounded;
    if (action.contains('school')) return Icons.apartment_rounded;
    if (action.contains('asset') || action.contains('gallery') || action.contains('content') || action.contains('achievement') || action.contains('event')) return Icons.palette_rounded;
    return Icons.account_tree_rounded;
  }

  String _day(DateTime d) {
    final now = DateTime.now();
    final l = d.toLocal();
    if (l.year == now.year && l.month == now.month && l.day == now.day) return 'Today';
    final y = now.subtract(const Duration(days: 1));
    if (l.year == y.year && l.month == y.month && l.day == y.day) return 'Yesterday';
    return saDate(d);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditLogProvider);
    return SaPage(
      title: 'Activity',
      subtitle: 'A record of every change made from this portal.',
      onRefresh: () async {
        ref.invalidate(auditLogProvider);
        await ref.read(auditLogProvider.future).catchError((_) => <AuditEntry>[]);
      },
      children: [
        async.when(
          loading: () => const SaCard(child: Column(children: [SaSkeleton(height: 40), SizedBox(height: 14), SaSkeleton(height: 40), SizedBox(height: 14), SaSkeleton(height: 40)])),
          error: (e, _) => SaErrorState(e, onRetry: () => ref.invalidate(auditLogProvider)),
          data: (entries) {
            if (entries.isEmpty) {
              return const SaEmpty(icon: Icons.history_rounded, title: 'Nothing recorded yet', message: 'Creating schools, accounts and changing settings will show up here.');
            }
            final widgets = <Widget>[];
            String? lastDay;
            for (final e in entries) {
              final day = _day(e.createdAt);
              if (day != lastDay) {
                widgets.add(Padding(padding: EdgeInsets.only(top: lastDay == null ? 0 : 20, bottom: 10), child: Text(day.toUpperCase(), style: const TextStyle(color: Sa.faint, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8))));
                lastDay = day;
              }
              widgets.add(Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SaCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: Sa.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
                      child: Icon(_icon(e.action), color: Sa.primaryHi, size: 19),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.summary, style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 3),
                        Text('${e.actorName}${e.schoolName != null ? ' · ${e.schoolName}' : ''}', style: const TextStyle(color: Sa.muted, fontSize: 12.5)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Text(saDateTime(e.createdAt).split(', ').last, style: const TextStyle(color: Sa.faint, fontSize: 12)),
                  ]),
                ),
              ));
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
          },
        ),
      ],
    );
  }
}