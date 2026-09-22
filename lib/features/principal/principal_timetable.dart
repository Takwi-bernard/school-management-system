import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/responsive.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import 'principal_models.dart';
import 'principal_providers.dart';
import 'principal_repository.dart';

const _dayNames = {'1': 'Monday', '2': 'Tuesday', '3': 'Wednesday', '4': 'Thursday', '5': 'Friday', '6': 'Saturday', '7': 'Sunday'};

// ============================================================
// TIMETABLE SETTINGS - the FIXED facts the AI must respect
// ============================================================

class TimetableSettingsPage extends ConsumerStatefulWidget {
  final String schoolId;
  const TimetableSettingsPage({super.key, required this.schoolId});

  @override
  ConsumerState<TimetableSettingsPage> createState() => _TimetableSettingsPageState();
}

class _TimetableSettingsPageState extends ConsumerState<TimetableSettingsPage> {
  final _periodController = TextEditingController();
  TimeOfDay? _dayStart;
  TimeOfDay? _dayEnd;
  final Set<int> _workingDays = {};
  List<Map<String, String>> _breaks = [];
  bool _loaded = false;
  bool _saving = false;

  void _loadFrom(TimetableSettings s) {
    _periodController.text = s.periodDurationMinutes.toString();
    _dayStart = _parseTime(s.dayStartTime);
    _dayEnd = _parseTime(s.dayEndTime);
    _workingDays..clear()..addAll(s.workingDays);
    _breaks = List.from(s.breakPeriods);
    _loaded = true;
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _addBreak() {
    setState(() => _breaks.add({'label': 'Break', 'start': '10:00', 'end': '10:20'}));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(principalRepositoryProvider).saveTimetableSettings(
            schoolId: widget.schoolId,
            periodDurationMinutes: int.tryParse(_periodController.text) ?? 55,
            dayStartTime: '${_fmt(_dayStart!)}:00',
            dayEndTime: '${_fmt(_dayEnd!)}:00',
            breakPeriods: _breaks,
            workingDays: _workingDays.toList()..sort(),
          );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timetable settings saved.')));
      ref.invalidate(timetableSettingsProvider(widget.schoolId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(timetableSettingsProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
        data: (settings) {
          if (!_loaded) _loadFrom(settings);
          return ListView(
            children: [
              Text('Timetable Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'These rules are FIXED - the AI generator will never violate them, regardless of what else you ask it to do.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _periodController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Period duration (minutes)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final p = await showTimePicker(context: context, initialTime: _dayStart!);
                      if (p != null) setState(() => _dayStart = p);
                    },
                    child: Text('Day starts: ${_fmt(_dayStart!)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final p = await showTimePicker(context: context, initialTime: _dayEnd!);
                      if (p != null) setState(() => _dayEnd = p);
                    },
                    child: Text('Day ends: ${_fmt(_dayEnd!)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Text('Working days', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _dayNames.entries.map((e) => FilterChip(
                      label: Text(e.value.substring(0, 3)),
                      selected: _workingDays.contains(int.parse(e.key)),
                      onSelected: (sel) => setState(() {
                        final d = int.parse(e.key);
                        if (sel) { _workingDays.add(d); } else { _workingDays.remove(d); }
                      }),
                    )).toList(),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Text('Break periods', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(onPressed: _addBreak, icon: const Icon(Icons.add_rounded), label: const Text('Add Break')),
              ]),
              ..._breaks.asMap().entries.map((entry) {
                final i = entry.key;
                final b = entry.value;
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(flex: 2, child: TextFormField(initialValue: b['label'], decoration: const InputDecoration(labelText: 'Label'), onChanged: (v) => b['label'] = v)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(initialValue: b['start'], decoration: const InputDecoration(labelText: 'Start (HH:mm)'), onChanged: (v) => b['start'] = v)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(initialValue: b['end'], decoration: const InputDecoration(labelText: 'End (HH:mm)'), onChanged: (v) => b['end'] = v)),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => setState(() => _breaks.removeAt(i))),
                  ]),
                );
              }),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Settings'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// GENERATE TIMETABLE - scope + optional note + trigger
// ============================================================

enum _Scope { school, department, class_ }

class GenerateTimetablePage extends ConsumerStatefulWidget {
  final String schoolId;
  const GenerateTimetablePage({super.key, required this.schoolId});

  @override
  ConsumerState<GenerateTimetablePage> createState() => _GenerateTimetablePageState();
}

class _GenerateTimetablePageState extends ConsumerState<GenerateTimetablePage> {
  _Scope _scope = _Scope.class_;
  DepartmentFull? _department;
  ManagedClass? _class;
  final _noteController = TextEditingController();
  bool _generating = false;
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_scope == _Scope.department && _department == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a department.')));
      return;
    }
    if (_scope == _Scope.class_ && _class == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a class.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generate timetable?'),
        content: Text(
          _scope == _Scope.school
              ? 'This regenerates the timetable for EVERY class in the school. Existing slots for these classes will be replaced.'
              : _scope == _Scope.department
                  ? 'This regenerates the timetable for every class in ${_department!.departmentName}. Existing slots for these classes will be replaced.'
                  : 'This regenerates the timetable for ${_class!.className}. Existing slots for this class will be replaced.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _generating = true; _lastResult = null; });
    try {
      final result = await ref.read(principalRepositoryProvider).generateTimetable(
            schoolId: widget.schoolId,
            scopeType: _scope == _Scope.school ? 'school' : _scope == _Scope.department ? 'department' : 'class',
            departmentId: _scope == _Scope.department ? _department!.id : null,
            classId: _scope == _Scope.class_ ? _class!.id : null,
            principalNote: _noteController.text,
          );
      setState(() => _lastResult = result);
      ref.invalidate(timetableHistoryProvider(widget.schoolId));
      if (_scope == _Scope.class_) ref.invalidate(classTimetableProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result['slots_created']} slots created${(result['slots_rejected'] as int) > 0 ? ", ${result['slots_rejected']} rejected by validation" : ""}.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final departmentsAsync = ref.watch(departmentsFullProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: ListView(
        children: [
          Text('Generate Timetable', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'The AI schedules classes strictly within your saved settings (period length, hours, breaks) and each teacher\'s declared free days. It never invents rules of its own.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          SegmentedButton<_Scope>(
            segments: const [
              ButtonSegment(value: _Scope.class_, label: Text('One Class')),
              ButtonSegment(value: _Scope.department, label: Text('Department')),
              ButtonSegment(value: _Scope.school, label: Text('Whole School')),
            ],
            selected: {_scope},
            onSelectionChanged: (s) => setState(() { _scope = s.first; _department = null; _class = null; }),
          ),
          const SizedBox(height: 16),
          if (_scope != _Scope.school)
            departmentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (departments) => DropdownButtonFormField<DepartmentFull>(
                initialValue: _department,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d.departmentName))).toList(),
                onChanged: (v) => setState(() { _department = v; _class = null; }),
              ),
            ),
          if (_scope == _Scope.class_ && _department != null) ...[
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final classesAsync = ref.watch(managedClassesProvider(widget.schoolId));
                return classesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (classes) {
                    final filtered = classes.where((c) => c.departmentId == _department!.id).toList();
                    return DropdownButtonFormField<ManagedClass>(
                      initialValue: _class,
                      decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                      items: filtered.map((c) => DropdownMenuItem(value: c, child: Text(c.className))).toList(),
                      onChanged: (v) => setState(() => _class = v),
                    );
                  },
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          Text('Note for the AI (optional)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'This adds context only - it can never override your fixed settings above (period length, hours, or double-booking rules).',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. Physics has no teacher confirmed yet - place it in the morning in case one is assigned soon.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
            label: Text(_generating ? 'Generating...' : 'Generate Timetable'),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Summary', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(_lastResult!['ai_summary'] as String? ?? 'No summary provided.'),
                  if ((_lastResult!['slots_rejected'] as int? ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    Text('${_lastResult!['slots_rejected']} slot(s) were rejected by validation:', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ...((_lastResult!['rejection_details'] as List?) ?? []).map((r) => Text('• $r', style: theme.textTheme.bodySmall)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// VIEW / DOWNLOAD TIMETABLE - Department -> Class -> weekly grid
// ============================================================

class ViewTimetablePage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  const ViewTimetablePage({super.key, required this.schoolId, required this.landing});

  @override
  ConsumerState<ViewTimetablePage> createState() => _ViewTimetablePageState();
}

class _ViewTimetablePageState extends ConsumerState<ViewTimetablePage> {
  DepartmentFull? _department;
  ManagedClass? _class;

  PdfColor _parseColor(String hex) {
    var v = hex.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    return PdfColor.fromInt(int.tryParse(v, radix: 16) ?? 0xFF1A73E8);
  }

  Future<void> _downloadPdf(List<TimetableSlot> slots) async {
    final assets = await ref.read(officialBrandingProvider(widget.schoolId).future);
    final branding = await OfficialBranding.fetch(assets);

    final byDay = <String, List<TimetableSlot>>{};
    for (final s in slots) {
      byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(children: [
          buildDocumentHeader(branding: branding, schoolName: widget.landing.schoolName, motto: widget.landing.motto),
          pw.SizedBox(height: 10),
          pw.Text('${_class!.className} - Weekly Timetable', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
                for (final d in ['1', '2', '3', '4', '5', '6']) pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_dayNames[d] ?? '', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
              ]),
              pw.TableRow(children: [
                for (final d in ['1', '2', '3', '4', '5', '6'])
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Column(children: [
                      for (final slot in (byDay[d] ?? []))
                        pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 4),
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(color: slot.needsTeacher ? PdfColors.orange100 : PdfColors.blue50, borderRadius: pw.BorderRadius.circular(3)),
                          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                            pw.Text('${slot.startTime}-${slot.endTime}', style: const pw.TextStyle(fontSize: 7)),
                            pw.Text(slot.subjectName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text(slot.needsTeacher ? 'No teacher yet' : (slot.teacherName ?? ''), style: pw.TextStyle(fontSize: 7, color: slot.needsTeacher ? PdfColors.orange900 : PdfColors.grey700)),
                          ]),
                        ),
                    ]),
                  ),
              ]),
            ],
          ),
        ]),
      ),
    ));

    await Printing.sharePdf(bytes: await doc.save(), filename: 'timetable_${_class!.className.replaceAll(' ', '_')}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yearIdAsync = ref.watch(principalCurrentAcademicYearIdProvider(widget.schoolId));

    if (_class != null) {
      return Padding(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _class = null)),
              Expanded(child: Text('${_class!.className} · ${_department!.departmentName}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: yearIdAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (yearId) {
                  if (yearId == null) return const Text('No current academic year set.');
                  final slotsAsync = ref.watch(classTimetableProvider((classId: _class!.id, academicYearId: yearId)));
                  return slotsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (slots) {
                      if (slots.isEmpty) return const Center(child: Text('No timetable generated for this class yet.'));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(onPressed: () => _downloadPdf(slots), icon: const Icon(Icons.download_rounded), label: const Text('Download PDF')),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView(
                              children: _dayNames.entries.map((entry) {
                                final daySlots = slots.where((s) => s.dayOfWeek == entry.key).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
                                if (daySlots.isEmpty) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 6),
                                      ...daySlots.map((s) => Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: s.needsTeacher ? Colors.orange.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(children: [
                                              Text('${s.startTime} - ${s.endTime}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                              const SizedBox(width: 12),
                                              Expanded(child: Text(s.subjectName)),
                                              Text(s.needsTeacher ? 'No teacher yet' : (s.teacherName ?? ''), style: TextStyle(color: s.needsTeacher ? Colors.orange.shade800 : theme.colorScheme.outline, fontWeight: s.needsTeacher ? FontWeight.w700 : FontWeight.normal)),
                                            ]),
                                          )),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
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

    if (_department != null) {
      return Padding(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _department = null)),
              Text(_department!.departmentName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final classesAsync = ref.watch(managedClassesProvider(widget.schoolId));
                  return classesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (classes) {
                      final filtered = classes.where((c) => c.departmentId == _department!.id).toList();
                      if (filtered.isEmpty) return const Center(child: Text('No classes in this department.'));
                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _drillTile(filtered[i].className, () => setState(() => _class = filtered[i])),
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

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('View Timetables', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final departmentsAsync = ref.watch(departmentsFullProvider(widget.schoolId));
                return departmentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (departments) => ListView.separated(
                    itemCount: departments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _drillTile(departments[i].departmentName, () => setState(() => _department = departments[i])),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _drillTile(String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right_rounded)]))),
    );
  }
}