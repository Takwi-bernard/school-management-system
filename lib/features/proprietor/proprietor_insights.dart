import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import 'proprietor_format.dart';
import 'proprietor_models.dart';
import 'proprietor_providers.dart';
import 'proprietor_strings.dart';
import 'proprietor_ui.dart';

/// An advisor that reads the school's recorded numbers: a structured
/// analysis (summary, strengths, concerns, next steps) plus free-form
/// questions answered from the same data. Language follows the school.
class ProprietorInsightsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const ProprietorInsightsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<ProprietorInsightsPage> createState() => _ProprietorInsightsPageState();
}

class _ProprietorInsightsPageState extends ConsumerState<ProprietorInsightsPage> {
  final _question = TextEditingController();
  bool _generating = false;
  bool _asking = false;
  String? _answer;
  String? _askedQuestion;
  String? _error;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await ref.read(proprietorRepositoryProvider).generateReport(widget.schoolId);
      ref.invalidate(latestReportProvider(widget.schoolId));
      ref.invalidate(reportHistoryProvider(widget.schoolId));
      await ref.read(latestReportProvider(widget.schoolId).future);
    } catch (_) {
      if (mounted) setState(() => _error = _s.prAiError);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _ask([String? preset]) async {
    final q = (preset ?? _question.text).trim();
    if (q.isEmpty || _asking) return;
    if (preset != null) _question.text = preset;
    FocusScope.of(context).unfocus();
    setState(() {
      _asking = true;
      _answer = null;
      _askedQuestion = q;
      _error = null;
    });
    try {
      final a = await ref.read(proprietorRepositoryProvider).askQuestion(widget.schoolId, q);
      if (mounted) setState(() => _answer = a);
    } catch (_) {
      if (mounted) setState(() => _error = _s.prAiError);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final latest = ref.watch(latestReportProvider(widget.schoolId));
    final history = ref.watch(reportHistoryProvider(widget.schoolId)).valueOrNull ?? const <AiSchoolReport>[];

    final suggestions = [s.prQ1, s.prQ2, s.prQ3, s.prQ4];

    return PrPage(
      onRefresh: () async {
        ref.invalidate(latestReportProvider(widget.schoolId));
        ref.invalidate(reportHistoryProvider(widget.schoolId));
      },
      children: [
        PrHeader(title: s.prInsightsTitle, subtitle: s.prInsightsIntro),
        // ------------------------------------------------ generate card
        PrReveal(
          child: PrCard(
            child: LayoutBuilder(builder: (context, c) {
              final narrow = c.maxWidth < 560;
              final info = Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.auto_awesome_rounded, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(latest.valueOrNull == null ? s.prNoReport : '${s.prGeneratedOn} ${pDateTime(latest.valueOrNull!.generatedAt)}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(_generating ? s.prGenerating : (latest.valueOrNull == null ? s.prNoReportHint : s.prAiDisclaimer), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.35)),
                  ]),
                ),
              ]);
              final button = FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.bolt_rounded, size: 18),
                label: Text(latest.valueOrNull == null ? s.prGenerate : s.prRegenerate),
              );
              if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 14), button]);
              return Row(children: [Expanded(child: info), const SizedBox(width: 14), button]);
            }),
          ),
        ),
        if (_generating) ...[
          const SizedBox(height: 14),
          const PrSkeleton(height: 120, radius: 20),
          const SizedBox(height: 10),
          PrGrid(minTile: 260, max: 3, children: List.generate(3, (_) => const PrSkeleton(height: 180, radius: 20))),
        ] else
          latest.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 14), child: PrSkeleton(height: 160, radius: 20)),
            error: (e, _) => SizedBox(height: 200, child: PrError(error: e, strings: s, onRetry: () => ref.invalidate(latestReportProvider(widget.schoolId)))),
            data: (r) => r == null ? const SizedBox.shrink() : _ReportView(report: r, strings: s),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PrCard(
              color: kOverdue.withValues(alpha: 0.07),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: kOverdue, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!, style: theme.textTheme.bodyMedium)),
              ]),
            ),
          ),
        // ------------------------------------------------ ask
        PrSectionTitle(title: s.prAskTitle),
        PrReveal(
          child: PrCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _question,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _ask(),
                decoration: InputDecoration(
                  hintText: s.prAskHint,
                  filled: true,
                  fillColor: cs.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant)),
                  suffixIcon: IconButton(
                    onPressed: _asking ? null : () => _ask(),
                    icon: _asking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.arrow_upward_rounded, color: cs.primary),
                    tooltip: s.prAsk,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(s.prSuggestedQuestions, style: theme.textTheme.labelMedium?.copyWith(color: cs.outline, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final q in suggestions)
                  ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12.5)),
                    onPressed: _asking ? null : () => _ask(q),
                    side: BorderSide(color: cs.outlineVariant),
                    backgroundColor: Colors.transparent,
                  ),
              ]),
            ]),
          ),
        ),
        if (_asking)
          const Padding(padding: EdgeInsets.only(top: 12), child: PrSkeleton(height: 110, radius: 20))
        else if (_answer != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PrReveal(
              child: PrCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_askedQuestion ?? '', style: theme.textTheme.labelLarge?.copyWith(color: cs.outline, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(s.prAnswer, style: theme.textTheme.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  SelectableText(_answer!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
                  const SizedBox(height: 10),
                  Text(s.prAiDisclaimer, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                ]),
              ),
            ),
          ),
        // ------------------------------------------------ history
        if (history.length > 1) ...[
          PrSectionTitle(title: s.prHistory),
          for (final r in history.skip(1))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text(pDateTime(r.generatedAt), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                    subtitle: Text(r.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                    children: [
                      Text(r.summary, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                      if (r.concerns.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (final c in r.concerns) _Bullet(text: c, color: kPending),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ReportView extends StatelessWidget {
  final AiSchoolReport report;
  final AppStrings strings;
  const _ReportView({required this.report, required this.strings});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget block(IconData icon, String title, List<String> items, Color accent) => PrCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text('—', style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline))
            else
              for (final i in items) _Bullet(text: i, color: accent),
          ]),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PrReveal(
          child: PrCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.notes_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(s.prSummary, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 10),
              SelectableText(report.summary, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        PrGrid(minTile: 300, max: 3, children: [
          block(Icons.check_circle_outline_rounded, s.prStrengths, report.strengths, kSettled),
          block(Icons.warning_amber_rounded, s.prConcerns, report.concerns, kPending),
          block(Icons.arrow_circle_right_outlined, s.prRecommendations, report.recommendations, cs.primary),
        ]),
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final Color color;
  const _Bullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 7, right: 10), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
        Expanded(child: SelectableText(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))),
      ]),
    );
  }
}