import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_navigation.dart';
import 'teacher_providers.dart';
import 'teacher_strings.dart';
import 'teacher_ui.dart';

/// Reached via pushTeacherContent, not Navigator.push - stays inside
/// TeacherShell so the sidebar/drawer is always still reachable.
///
/// Rules this page enforces (the database enforces the same ones, so a
/// tampered client cannot bypass them - this page just makes them clear):
///  * a score must be a number from 0 to 20; "12,5" and "12.5" both work
///  * marks that are already submitted or approved are read-only and are
///    never re-sent (re-sending them would make the whole save fail)
///  * submitting asks for confirmation and reports missing scores
class TeacherMarksEntryPage extends ConsumerStatefulWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;

  const TeacherMarksEntryPage({super.key, required this.profile, required this.assignment});

  @override
  ConsumerState<TeacherMarksEntryPage> createState() => _TeacherMarksEntryPageState();
}

class _TeacherMarksEntryPageState extends ConsumerState<TeacherMarksEntryPage> {
  static const double _maxScore = 20;

  // Controllers are keyed by "periodId|studentId" so switching between
  // open exam periods never mixes up what was typed.
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, TextEditingController> _remarkControllers = {};
  final Set<String> _seeded = {};

  String? _selectedPeriodId;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    for (final c in _remarkControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _key(String periodId, String studentId) => '$periodId|$studentId';

  TextEditingController _scoreFor(String key) =>
      _scoreControllers.putIfAbsent(key, () => TextEditingController());

  TextEditingController _remarkFor(String key) =>
      _remarkControllers.putIfAbsent(key, () => TextEditingController());

  bool _isLocked(String status) => status == 'submitted' || status == 'approved';

  /// Accepts "12", "12.5" and the French "12,5". Returns null for
  /// anything that is not a plain number - it is never silently turned
  /// into 0.
  double? _parseScore(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return value;
  }

  bool _inRange(double value) => value >= 0 && value <= _maxScore;

  String _formatScore(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  MarkEntry? _markFor(List<MarkEntry> marks, String studentId, String periodId) {
    for (final m in marks) {
      if (m.studentId == studentId && m.examPeriodId == periodId) return m;
    }
    return null;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirmSubmit(AppStrings strings, int entered, int missing) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.tSubmitConfirmTitle),
        content: Text(strings.tSubmitConfirmBody(entered, missing)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.submitToPrincipal),
          ),
        ],
      ),
    );
  }

  Future<void> _save({
    required String status, // 'draft' or 'submitted'
    required ExamPeriod period,
    required List<RosterStudent> students,
    required Map<String, MarkEntry> existing,
    required AppStrings strings,
  }) async {
    final entries = <MarkEntry>[];
    var hasInvalid = false;
    var missing = 0;

    for (final student in students) {
      final current = existing[student.studentId];
      // Submitted / approved rows are read-only - never send them again.
      if (current != null && _isLocked(current.status)) continue;

      final key = _key(period.id, student.studentId);
      final text = (_scoreControllers[key]?.text ?? '').trim();
      if (text.isEmpty) {
        missing++;
        continue;
      }

      final score = _parseScore(text);
      if (score == null || !_inRange(score)) {
        hasInvalid = true;
        continue;
      }

      final remark = (_remarkControllers[key]?.text ?? '').trim();
      entries.add(MarkEntry(
        studentId: student.studentId,
        subjectId: widget.assignment.subjectId,
        classId: widget.assignment.classId,
        examPeriodId: period.id,
        score: score,
        status: status,
        remarks: remark.isEmpty ? null : remark,
      ));
    }

    if (hasInvalid) {
      _snack(strings.tFixScores);
      return;
    }
    if (entries.isEmpty) {
      _snack(strings.tNothingToSave);
      return;
    }

    if (status == 'submitted') {
      final confirmed = await _confirmSubmit(strings, entries.length, missing);
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(teacherRepositoryProvider).saveMarks(
            profile: widget.profile,
            examPeriodId: period.id,
            academicYearId: widget.assignment.academicYearId,
            entries: entries,
            status: status,
          );

      ref.invalidate(marksProvider((
        classId: widget.assignment.classId,
        subjectId: widget.assignment.subjectId,
        academicYearId: widget.assignment.academicYearId,
      )));

      _snack(status == 'submitted' ? strings.marksSubmittedMessage : strings.draftSavedMessage);
    } catch (e) {
      debugPrint('[TeacherMarksEntry] save failed: $e');
      _snack(strings.saveMarksError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final periodsAsync = ref.watch(examPeriodsProvider);
    final rosterProviderKey = (
      classId: widget.assignment.classId,
      academicYearId: widget.assignment.academicYearId,
    );
    final marksProviderKey = (
      classId: widget.assignment.classId,
      subjectId: widget.assignment.subjectId,
      academicYearId: widget.assignment.academicYearId,
    );
    final rosterAsync = ref.watch(rosterProvider(rosterProviderKey));
    final marksAsync = ref.watch(marksProvider(marksProviderKey));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TeacherBackHeader(
                  title: '${widget.assignment.subjectName} - ${strings.marksLabel}',
                  onBack: () => popTeacherContent(ref),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: periodsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => TeacherErrorView(
                      error: e,
                      onRetry: () => ref.invalidate(examPeriodsProvider),
                    ),
                    data: (periods) {
                      final openPeriods = periods
                          .where((p) => p.isOpen && p.academicYearId == widget.assignment.academicYearId)
                          .toList();

                      if (openPeriods.isEmpty) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: TeacherEmptyState(
                              icon: Icons.lock_clock_outlined,
                              title: strings.marksLabel,
                              description: strings.marksNotOpenYet,
                            ),
                          ),
                        );
                      }

                      final period = openPeriods.firstWhere(
                        (p) => p.id == _selectedPeriodId,
                        orElse: () => openPeriods.first,
                      );

                      return rosterAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => TeacherErrorView(
                          error: e,
                          onRetry: () => ref.invalidate(rosterProvider(rosterProviderKey)),
                        ),
                        data: (students) {
                          return marksAsync.when(
                            // Keep the list on screen while marks reload after a save.
                            skipLoadingOnReload: true,
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => TeacherErrorView(
                              error: e,
                              onRetry: () => ref.invalidate(marksProvider(marksProviderKey)),
                            ),
                            data: (allMarks) => _buildEditor(
                              strings: strings,
                              openPeriods: openPeriods,
                              period: period,
                              otherPeriods: periods.where((p) => p.id != period.id).toList(),
                              students: students,
                              allMarks: allMarks,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor({
    required AppStrings strings,
    required List<ExamPeriod> openPeriods,
    required ExamPeriod period,
    required List<ExamPeriod> otherPeriods,
    required List<RosterStudent> students,
    required List<MarkEntry> allMarks,
  }) {
    final theme = Theme.of(context);

    // Marks that already exist for THIS period, by student.
    final existing = <String, MarkEntry>{
      for (final m in allMarks)
        if (m.examPeriodId == period.id) m.studentId: m,
    };

    // Fill the text boxes from saved marks exactly once per student and
    // period - so a box the teacher clears on purpose is not refilled on
    // the next rebuild.
    for (final student in students) {
      final key = _key(period.id, student.studentId);
      if (_seeded.add(key)) {
        final saved = existing[student.studentId];
        if (saved != null) {
          _scoreFor(key).text = _formatScore(saved.score);
          _remarkFor(key).text = saved.remarks ?? '';
        }
      }
    }

    final editableCount = students.where((s) {
      final saved = existing[s.studentId];
      return saved == null || !_isLocked(saved.status);
    }).length;

    final subtitle = '${strings.coefficientLabel} ${widget.assignment.coefficient}'
        '${period.dueDate != null ? ' · ${strings.dueLabel} ${_fmt(period.dueDate!)}' : ''}';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(period.name,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (openPeriods.length > 1)
                DropdownButton<String>(
                  value: period.id,
                  underline: const SizedBox.shrink(),
                  hint: Text(strings.tExamPeriod),
                  items: [
                    for (final p in openPeriods) DropdownMenuItem<String>(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _selectedPeriodId = value);
                        },
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (students.isEmpty)
            TeacherEmptyState(
              icon: Icons.groups_outlined,
              title: strings.studentsLabel,
              description: strings.noStudentsEnrolled,
            )
          else ...[
            if (editableCount == 0) ...[
              Text(strings.tAllLocked,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
            ],
            TeacherCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < students.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    _studentRow(
                      theme: theme,
                      strings: strings,
                      student: students[i],
                      period: period,
                      otherPeriods: otherPeriods,
                      allMarks: allMarks,
                      saved: existing[students[i].studentId],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: (_saving || editableCount == 0)
                      ? null
                      : () => _save(
                            status: 'draft',
                            period: period,
                            students: students,
                            existing: existing,
                            strings: strings,
                          ),
                  child: Text(strings.saveDraft),
                ),
                FilledButton.icon(
                  onPressed: (_saving || editableCount == 0)
                      ? null
                      : () => _save(
                            status: 'submitted',
                            period: period,
                            students: students,
                            existing: existing,
                            strings: strings,
                          ),
                  icon: const Icon(Icons.send_outlined),
                  label: Text(strings.submitToPrincipal),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _studentRow({
    required ThemeData theme,
    required AppStrings strings,
    required RosterStudent student,
    required ExamPeriod period,
    required List<ExamPeriod> otherPeriods,
    required List<MarkEntry> allMarks,
    required MarkEntry? saved,
  }) {
    final key = _key(period.id, student.studentId);
    final locked = saved != null && _isLocked(saved.status);
    final scoreController = _scoreFor(key);
    final remarkController = _remarkFor(key);

    String? scoreError;
    final typed = scoreController.text.trim();
    if (!locked && typed.isNotEmpty) {
      final value = _parseScore(typed);
      if (value == null || !_inRange(value)) scoreError = strings.tInvalidScore;
    }

    final history = <Widget>[];
    for (final p in otherPeriods) {
      final previous = _markFor(allMarks, student.studentId, p.id);
      if (previous != null) {
        history.add(_pill(theme, '${p.name}: ${_formatScore(previous.score)}'));
      }
    }

    final feedback = saved?.principalFeedback;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(student.fullName,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (saved != null) _statusChip(theme, strings, saved.status),
              ...history,
            ],
          ),
          if (feedback != null && feedback.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${strings.tPrincipalFeedback}: ${feedback.trim()}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: scoreController,
                  enabled: !locked,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: strings.scoreLabel,
                    isDense: true,
                    errorText: scoreError,
                    errorMaxLines: 2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: remarkController,
                  enabled: !locked,
                  decoration: InputDecoration(
                    labelText: strings.commentOptional,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }

  Widget _statusChip(ThemeData theme, AppStrings strings, String status) {
    final scheme = theme.colorScheme;
    Color background;
    Color foreground;
    String label;

    switch (status) {
      case 'submitted':
        background = scheme.primary.withValues(alpha: 0.12);
        foreground = scheme.primary;
        label = strings.tStatusSubmitted;
        break;
      case 'approved':
        background = scheme.tertiary.withValues(alpha: 0.14);
        foreground = scheme.tertiary;
        label = strings.tStatusApproved;
        break;
      case 'rejected':
        background = scheme.error.withValues(alpha: 0.12);
        foreground = scheme.error;
        label = strings.tStatusRejected;
        break;
      default:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
        label = strings.tStatusDraft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
