import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_providers.dart';
import 'principal_kit.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

/// A teacher's comment only reaches the parent after approval here.
class PendingCommentsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PendingCommentsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PendingCommentsPage> createState() => _PendingCommentsPageState();
}

class _PendingCommentsPageState extends ConsumerState<PendingCommentsPage> {
  final Set<String> _busy = {};
  String _query = '';

  AppStrings get _s => widget.strings;

  void _reload() {
    ref.invalidate(pendingCommentsProvider(widget.schoolId));
    ref.invalidate(pnOverviewProvider);
  }

  Future<void> _approve(PendingComment c) async {
    final s = _s;
    final ctrl = TextEditingController(text: c.comment);
    final ok = await pnSheet<bool>(
      context,
      (ctx) => PnSheetBody(
        title: s.pn('Approve comment for ${c.studentName}', 'Approuver le commentaire de ${c.studentName}'),
        subtitle: s.pn('You can edit the text before it reaches the parent.', 'Vous pouvez modifier le texte avant qu’il n’arrive au parent.'),
        children: [TextField(controller: ctrl, maxLines: 6, minLines: 3, decoration: pnDeco(s.pn('Comment', 'Commentaire')))],
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.pn('Cancel', 'Annuler'))),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.check_rounded, size: 18), label: Text(s.pn('Approve & publish', 'Approuver et publier'))),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted) return;
    if (text.isEmpty) {
      prSnack(context, s.pn('The comment cannot be empty.', 'Le commentaire ne peut pas être vide.'));
      return;
    }
    setState(() => _busy.add(c.id));
    try {
      await ref.read(principalRepositoryProvider).approveComment(c.id, editedText: text);
      _reload();
      if (mounted) prSnack(context, s.pn('Comment approved: the parent can now see it.', 'Commentaire approuvé : le parent peut maintenant le voir.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  Future<void> _discard(PendingComment c) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Discard this comment?', 'Supprimer ce commentaire ?'),
      message: s.pn('${c.teacherName}’s comment about ${c.studentName} will be permanently deleted.', 'Le commentaire de ${c.teacherName} sur ${c.studentName} sera définitivement supprimé.'),
      confirmLabel: s.pn('Discard', 'Supprimer'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(c.id));
    try {
      await ref.read(principalRepositoryProvider).discardComment(c.id);
      _reload();
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  Future<void> _approveAll(List<PendingComment> list) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Approve ${list.length} comments?', 'Approuver ${list.length} commentaires ?'),
      message: s.pn('They will all be published to parents as written.', 'Ils seront tous publiés aux parents tels quels.'),
      confirmLabel: s.pn('Approve all', 'Tout approuver'),
    );
    if (!ok || !mounted) return;
    var done = 0;
    try {
      for (final c in list) {
        await ref.read(principalRepositoryProvider).approveComment(c.id);
        done++;
      }
      if (mounted) prSnack(context, s.pn('$done comments approved.', '$done commentaires approuvés.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(pendingCommentsProvider(widget.schoolId));
    ref.listen<int>(pnTickProvider, (_, __) => ref.invalidate(pendingCommentsProvider(widget.schoolId)));
    return PrPage(
      maxWidth: 900,
      onRefresh: () async => ref.refresh(pendingCommentsProvider(widget.schoolId).future),
      children: [
        PrHeader(
          title: s.pn('Comment review', 'Validation des commentaires'),
          subtitle: s.pn('A teacher’s comment only reaches the parent after you approve it.', 'Le commentaire d’un enseignant n’atteint le parent qu’après votre approbation.'),
        ),
        const SizedBox(height: 16),
        PnAsync<List<PendingComment>>(
          value: async,
          strings: s,
          onRetry: () => ref.invalidate(pendingCommentsProvider(widget.schoolId)),
          isEmpty: (d) => d.isEmpty,
          empty: PnEmpty(icon: Icons.mark_chat_read_rounded, title: s.pn('No comments waiting', 'Aucun commentaire en attente'), text: s.pn('New teacher comments will appear here for review.', 'Les nouveaux commentaires des enseignants apparaîtront ici.')),
          builder: (all) {
            final q = _query.trim().toLowerCase();
            final list = q.isEmpty ? all : all.where((c) => '${c.studentName} ${c.className} ${c.teacherName}'.toLowerCase().contains(q)).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: _Search(hint: s.pn('Search student, class or teacher', 'Rechercher élève, classe ou enseignant'), onChanged: (v) => setState(() => _query = v))),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(onPressed: list.isEmpty ? null : () => _approveAll(list), icon: const Icon(Icons.done_all_rounded, size: 18), label: Text(s.pn('Approve all (${list.length})', 'Tout approuver (${list.length})'))),
              ]),
              const SizedBox(height: 14),
              if (list.isEmpty)
                PnEmpty(icon: Icons.search_off_rounded, title: s.pn('No match', 'Aucun résultat'))
              else
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PrReveal(
                      index: i > 8 ? 8 : i,
                      child: PrCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            PrAvatar(name: list[i].studentName, radius: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(list[i].studentName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                Text('${list[i].className} · ${list[i].teacherName}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                              ]),
                            ),
                            PnChip(label: list[i].examPeriodName, color: cs.primary),
                          ]),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
                            child: Text(list[i].comment, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                          ),
                          const SizedBox(height: 6),
                          Text(s.pn('Written ${pDate(list[i].createdAt)}', 'Rédigé le ${pDate(list[i].createdAt)}'), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(spacing: 8, runSpacing: 8, children: [
                              OutlinedButton.icon(onPressed: _busy.contains(list[i].id) ? null : () => _discard(list[i]), icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error), label: Text(s.pn('Discard', 'Supprimer'))),
                              FilledButton.icon(
                                onPressed: _busy.contains(list[i].id) ? null : () => _approve(list[i]),
                                icon: _busy.contains(list[i].id) ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit_note_rounded, size: 20),
                                label: Text(s.pn('Review & publish', 'Relire et publier')),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
            ]);
          },
        ),
      ],
    );
  }
}

class _Search extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _Search({required this.hint, required this.onChanged});
  @override
  State<_Search> createState() => _SearchState();
}

class _SearchState extends State<_Search> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PnSearch(controller: _c, hint: widget.hint, onChanged: (v) {
        widget.onChanged(v);
        setState(() {});
      });
}
