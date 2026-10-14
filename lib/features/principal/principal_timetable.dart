import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/l10n/app_strings.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import '../parent/parent_providers.dart' show officialBrandingProvider;
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_card_art.dart' show pnHex;
import 'principal_core.dart';
import 'principal_hub_providers.dart';
import 'principal_kit.dart';
import 'principal_models.dart';
import 'principal_providers.dart' hide officialBrandingProvider;

// ============================================================
// shared helpers
// ============================================================

String _hm5(String v) => v.length >= 5 ? v.substring(0, 5) : v;

class _Break {
  final String label;
  final String start;
  final String end;
  const _Break(this.label, this.start, this.end);
}

List<_Break> _breaksOf(TimetableSettings st) {
  final out = <_Break>[];
  for (final b in st.breakPeriods) {
    final s = _hm5(b['start'] ?? '');
    final e = _hm5(b['end'] ?? '');
    if (s.isEmpty) continue;
    out.add(_Break((b['label'] ?? '').trim().isEmpty ? 'Break' : b['label']!, s, e));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

class _Cell {
  final TimetableSlot slot;
  final String className;
  final String classId;
  final bool conflict;
  const _Cell(this.slot, this.className, this.classId, this.conflict);
}

/// Finds teachers booked in two classes at the same moment.
Set<String> _conflictKeys(Map<String, List<TimetableSlot>> byClass) {
  final byTeacherDay = <String, List<({String classId, TimetableSlot slot})>>{};
  byClass.forEach((classId, slots) {
    for (final sl in slots) {
      final t = sl.teacherName;
      if (sl.needsTeacher || t == null || t.isEmpty) continue;
      byTeacherDay.putIfAbsent('$t|${sl.dayOfWeek}', () => []).add((classId: classId, slot: sl));
    }
  });
  final keys = <String>{};
  for (final list in byTeacherDay.values) {
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i];
        final b = list[j];
        if (a.classId == b.classId) continue;
        final overlap = pnMinutes(a.slot.startTime) < pnMinutes(b.slot.endTime) && pnMinutes(b.slot.startTime) < pnMinutes(a.slot.endTime);
        if (overlap) {
          keys.add('${a.classId}|${a.slot.dayOfWeek}|${a.slot.startTime}');
          keys.add('${b.classId}|${b.slot.dayOfWeek}|${b.slot.startTime}');
        }
      }
    }
  }
  return keys;
}

String _teacherOf(AppStrings s, TimetableSlot sl) => sl.needsTeacher ? s.pn('No teacher yet', 'Pas encore d’enseignant') : (sl.teacherName ?? '');

final _schoolSlotsProvider = FutureProvider.family<Map<String, List<TimetableSlot>>, ({String schoolId, String yearId})>((ref, k) async {
  final classes = await ref.watch(managedClassesProvider(k.schoolId).future);
  return ref.watch(principalHubRepositoryProvider).getTimetablePaged([for (final c in classes) c.id], k.yearId);
});

// ============================================================
// TIMETABLE SETTINGS: the fixed rules the generator must respect
// ============================================================

class _BreakDraft {
  final TextEditingController label;
  TimeOfDay start;
  TimeOfDay end;
  _BreakDraft(String l, this.start, this.end) : label = TextEditingController(text: l);
}

class TimetableSettingsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const TimetableSettingsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<TimetableSettingsPage> createState() => _TimetableSettingsPageState();
}

class _TimetableSettingsPageState extends ConsumerState<TimetableSettingsPage> {
  int _period = 55;
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _end = const TimeOfDay(hour: 15, minute: 30);
  final Set<int> _days = {};
  final List<_BreakDraft> _breaks = [];
  bool _seeded = false;
  bool _dirty = false;
  bool _saving = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    for (final b in _breaks) {
      b.label.dispose();
    }
    super.dispose();
  }

  void _seed(TimetableSettings st) {
    if (_seeded) return;
    _seeded = true;
    _period = st.periodDurationMinutes;
    _start = pnParseHm(st.dayStartTime);
    _end = pnParseHm(st.dayEndTime, fallback: const TimeOfDay(hour: 15, minute: 30));
    _days
      ..clear()
      ..addAll(st.workingDays);
    for (final b in _breaksOf(st)) {
      _breaks.add(_BreakDraft(b.label, pnParseHm(b.start), pnParseHm(b.end, fallback: const TimeOfDay(hour: 10, minute: 20))));
    }
  }

  int _m(TimeOfDay t) => t.hour * 60 + t.minute;

  List<String> _problems() {
    final s = _s;
    final out = <String>[];
    if (_period < 20 || _period > 180) out.add(s.pn('The period length must be between 20 and 180 minutes.', 'La durée d’une période doit être comprise entre 20 et 180 minutes.'));
    if (_m(_end) <= _m(_start)) out.add(s.pn('The day must end after it starts.', 'La journée doit se terminer après son début.'));
    if (_days.isEmpty) out.add(s.pn('Select at least one working day.', 'Sélectionnez au moins un jour de classe.'));
    final sorted = [..._breaks]..sort((a, b) => _m(a.start).compareTo(_m(b.start)));
    for (var i = 0; i < sorted.length; i++) {
      final b = sorted[i];
      if (_m(b.end) <= _m(b.start)) out.add(s.pn('A break must end after it starts.', 'Une pause doit se terminer après son début.'));
      if (_m(b.start) < _m(_start) || _m(b.end) > _m(_end)) out.add(s.pn('Every break must fall inside the school day.', 'Chaque pause doit se situer dans la journée scolaire.'));
      if (i > 0 && _m(b.start) < _m(sorted[i - 1].end)) out.add(s.pn('Two breaks overlap.', 'Deux pauses se chevauchent.'));
    }
    return out.toSet().toList();
  }

  Future<void> _pick(TimeOfDay initial, ValueChanged<TimeOfDay> set) async {
    final p = await showTimePicker(context: context, initialTime: initial);
    if (p != null) {
      setState(() {
        set(p);
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    final s = _s;
    setState(() => _saving = true);
    try {
      await ref.read(principalRepositoryProvider).saveTimetableSettings(
            schoolId: widget.schoolId,
            periodDurationMinutes: _period,
            dayStartTime: '${pnHm(_start)}:00',
            dayEndTime: '${pnHm(_end)}:00',
            breakPeriods: [for (final b in _breaks) {'label': b.label.text.trim().isEmpty ? 'Break' : b.label.text.trim(), 'start': pnHm(b.start), 'end': pnHm(b.end)}],
            workingDays: _days.toList()..sort(),
          );
      ref.invalidate(timetableSettingsProvider(widget.schoolId));
      if (mounted) {
        setState(() => _dirty = false);
        prSnack(context, s.pn('Timetable settings saved.', 'Paramètres de l’emploi du temps enregistrés.'));
      }
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(timetableSettingsProvider(widget.schoolId));
    return PrPage(
      maxWidth: 780,
      children: [
        PrHeader(
          title: s.pn('Timetable settings', 'Paramètres de l’emploi du temps'),
          subtitle: s.pn('These rules are fixed: the generator never breaks them, whatever else you ask it.', 'Ces règles sont fixes : le générateur ne les enfreint jamais, quoi que vous lui demandiez.'),
        ),
        const SizedBox(height: 16),
        PnAsync<TimetableSettings>(
          value: async,
          strings: s,
          onRetry: () => ref.invalidate(timetableSettingsProvider(widget.schoolId)),
          builder: (st) {
            _seed(st);
            final problems = _problems();
            final dayMin = _m(_end) - _m(_start);
            final breakMin = _breaks.fold<int>(0, (a, b) => a + (_m(b.end) - _m(b.start)).clamp(0, 600).toInt());
            final perDay = _period > 0 && dayMin > 0 ? ((dayMin - breakMin) / _period).floor() : 0;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PrReveal(
                child: PnPanel(
                  title: s.pn('The school day', 'La journée scolaire'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(s.pn('Period length', 'Durée d’une période'), style: theme.textTheme.bodyMedium)),
                      IconButton.filledTonal(onPressed: _period > 20 ? () => setState(() { _period -= 5; _dirty = true; }) : null, icon: const Icon(Icons.remove_rounded)),
                      SizedBox(width: 78, child: Center(child: Text('$_period min', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)))),
                      IconButton.filledTonal(onPressed: _period < 180 ? () => setState(() { _period += 5; _dirty = true; }) : null, icon: const Icon(Icons.add_rounded)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () => _pick(_start, (t) => _start = t), icon: const Icon(Icons.wb_twilight_rounded, size: 18), label: Text(s.pn('Starts ${pnHm(_start)}', 'Début ${pnHm(_start)}')))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(onPressed: () => _pick(_end, (t) => _end = t), icon: const Icon(Icons.nightlight_round, size: 18), label: Text(s.pn('Ends ${pnHm(_end)}', 'Fin ${pnHm(_end)}')))),
                    ]),
                    const SizedBox(height: 16),
                    Text(s.pn('Working days', 'Jours de classe'), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    PnDayChips(strings: s, selected: _days, onChanged: (v) => setState(() {
                          _days
                            ..clear()
                            ..addAll(v);
                          _dirty = true;
                        })),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              PrReveal(
                index: 1,
                child: PnPanel(
                  title: s.pn('Breaks', 'Pauses'),
                  subtitle: s.pn('Nothing is scheduled during a break.', 'Aucun cours n’est programmé pendant une pause.'),
                  trailing: TextButton.icon(
                    onPressed: () => setState(() {
                      _breaks.add(_BreakDraft(s.pn('Break', 'Récréation'), const TimeOfDay(hour: 10, minute: 0), const TimeOfDay(hour: 10, minute: 20)));
                      _dirty = true;
                    }),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(s.pn('Add', 'Ajouter')),
                  ),
                  child: _breaks.isEmpty
                      ? Text(s.pn('No breaks yet.', 'Aucune pause.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))
                      : Column(children: [
                          for (var i = 0; i < _breaks.length; i++)
                            Container(
                              key: ObjectKey(_breaks[i]),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14)),
                              child: Column(children: [
                                Row(children: [
                                  Expanded(child: TextField(controller: _breaks[i].label, onChanged: (_) => setState(() => _dirty = true), decoration: pnDeco(s.pn('Label', 'Libellé')))),
                                  IconButton(icon: Icon(Icons.delete_outline_rounded, color: cs.error), tooltip: s.pn('Remove', 'Retirer'), onPressed: () => setState(() {
                                        final b = _breaks.removeAt(i);
                                        b.label.dispose();
                                        _dirty = true;
                                      })),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(child: OutlinedButton(onPressed: () => _pick(_breaks[i].start, (t) => _breaks[i].start = t), child: Text(s.pn('From ${pnHm(_breaks[i].start)}', 'De ${pnHm(_breaks[i].start)}')))),
                                  const SizedBox(width: 10),
                                  Expanded(child: OutlinedButton(onPressed: () => _pick(_breaks[i].end, (t) => _breaks[i].end = t), child: Text(s.pn('To ${pnHm(_breaks[i].end)}', 'À ${pnHm(_breaks[i].end)}')))),
                                ]),
                              ]),
                            ),
                        ]),
                ),
              ),
              const SizedBox(height: 14),
              PrReveal(
                index: 2,
                child: PnPanel(
                  title: s.pn('Preview of a day', 'Aperçu d’une journée'),
                  subtitle: dayMin > 0 ? s.pn('About $perDay teaching periods per day.', 'Environ $perDay périodes de cours par jour.') : null,
                  child: _DayBar(strings: s, startMin: _m(_start), endMin: _m(_end), breaks: [for (final b in _breaks) (label: b.label.text, s: _m(b.start), e: _m(b.end))]),
                ),
              ),
              if (problems.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final p in problems) Padding(padding: const EdgeInsets.only(bottom: 6), child: PnNotice(icon: Icons.error_outline_rounded, color: cs.error, text: p)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton(onPressed: (_saving || !_dirty || problems.isNotEmpty) ? null : _save, child: PnBusyLabel(busy: _saving, label: s.pn('Save settings', 'Enregistrer les paramètres'))),
              ),
            ]);
          },
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  final AppStrings strings;
  final int startMin;
  final int endMin;
  final List<({String label, int s, int e})> breaks;
  const _DayBar({required this.strings, required this.startMin, required this.endMin, required this.breaks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (endMin <= startMin) return Text('—', style: theme.textTheme.bodySmall);
    final valid = [...breaks.where((b) => b.e > b.s && b.s >= startMin && b.e <= endMin)]..sort((a, b) => a.s.compareTo(b.s));
    final segs = <Widget>[];
    var t = startMin;
    for (final b in valid) {
      if (b.s < t) continue;
      if (b.s > t) segs.add(_seg(b.s - t, cs.primary.withValues(alpha: 0.85), null));
      segs.add(_seg(b.e - b.s, const Color(0xFFF2B33D), b.label));
      t = b.e;
    }
    if (endMin > t) segs.add(_seg(endMin - t, cs.primary.withValues(alpha: 0.85), null));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(height: 34, child: Row(children: segs))),
      const SizedBox(height: 6),
      Row(children: [
        Text(pnFromMinutes(startMin), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        const Spacer(),
        Text(pnFromMinutes(endMin), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
      ]),
    ]);
  }

  Widget _seg(int minutes, Color color, String? label) {
    return Expanded(
      flex: minutes,
      child: Container(
        margin: const EdgeInsets.only(right: 1.5),
        color: color,
        alignment: Alignment.center,
        child: label == null || minutes < 25 ? null : Text(label, overflow: TextOverflow.clip, maxLines: 1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF3B2A00))),
      ),
    );
  }
}

// ============================================================
// GENERATE TIMETABLE
// ============================================================

enum _GenScope { class_, department, school }

class GenerateTimetablePage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const GenerateTimetablePage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<GenerateTimetablePage> createState() => _GenerateTimetablePageState();
}

class _GenerateTimetablePageState extends ConsumerState<GenerateTimetablePage> {
  _GenScope _scope = _GenScope.class_;
  DepartmentFull? _department;
  ManagedClass? _class;
  final _note = TextEditingController();
  bool _generating = false;
  Map<String, dynamic>? _result;
  Timer? _ticker;
  int _msg = 0;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _ticker?.cancel();
    _note.dispose();
    super.dispose();
  }

  List<String> get _messages => [
        _s.pn('Reading your settings and breaks…', 'Lecture de vos paramètres et pauses…'),
        _s.pn('Checking teacher availability…', 'Vérification des disponibilités des enseignants…'),
        _s.pn('Placing subjects across the week…', 'Répartition des matières sur la semaine…'),
        _s.pn('Validating every slot against your rules…', 'Validation de chaque créneau selon vos règles…'),
        _s.pn('Almost there…', 'Presque terminé…'),
      ];

  Future<void> _generate() async {
    final s = _s;
    if (_scope == _GenScope.department && _department == null) {
      prSnack(context, s.pn('Select a department.', 'Sélectionnez un département.'));
      return;
    }
    if (_scope == _GenScope.class_ && _class == null) {
      prSnack(context, s.pn('Select a class.', 'Sélectionnez une classe.'));
      return;
    }
    final msg = _scope == _GenScope.school
        ? s.pn('This regenerates the timetable of EVERY class. Existing slots of these classes are replaced.', 'Cela régénère l’emploi du temps de TOUTES les classes. Les créneaux existants de ces classes seront remplacés.')
        : _scope == _GenScope.department
            ? s.pn('This regenerates the timetable of every class in ${_department!.departmentName}. Existing slots are replaced.', 'Cela régénère l’emploi du temps de chaque classe de ${_department!.departmentName}. Les créneaux existants seront remplacés.')
            : s.pn('This regenerates the timetable of ${_class!.className}. Its existing slots are replaced.', 'Cela régénère l’emploi du temps de ${_class!.className}. Ses créneaux existants seront remplacés.');
    final ok = await pnConfirm(context, s, title: s.pn('Generate the timetable?', 'Générer l’emploi du temps ?'), message: msg, confirmLabel: s.pn('Generate', 'Générer'), destructive: _scope == _GenScope.school);
    if (!ok || !mounted) return;

    setState(() {
      _generating = true;
      _result = null;
      _msg = 0;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _msg = (_msg + 1) % _messages.length);
    });
    try {
      final r = await ref.read(principalRepositoryProvider).generateTimetable(
            schoolId: widget.schoolId,
            scopeType: _scope == _GenScope.school ? 'school' : (_scope == _GenScope.department ? 'department' : 'class'),
            departmentId: _scope == _GenScope.department ? _department!.id : null,
            classId: _scope == _GenScope.class_ ? _class!.id : null,
            principalNote: _note.text,
          );
      ref.invalidate(timetableHistoryProvider(widget.schoolId));
      ref.invalidate(pnOverviewProvider);
      ref.invalidate(classesTimetableProvider);
      ref.invalidate(classTimetableProvider);
      ref.invalidate(_schoolSlotsProvider);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      _ticker?.cancel();
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final depts = ref.watch(departmentsFullProvider(widget.schoolId));
    final settings = ref.watch(timetableSettingsProvider(widget.schoolId));
    return PrPage(
      maxWidth: 780,
      children: [
        PrHeader(
          title: s.pn('Generate timetable', 'Générer l’emploi du temps'),
          subtitle: s.pn('The AI schedules strictly within your saved settings and each teacher’s declared free days. It never invents rules of its own.', 'L’IA planifie strictement selon vos paramètres enregistrés et les jours libres déclarés par chaque enseignant. Elle n’invente jamais de règles.'),
        ),
        const SizedBox(height: 16),
        settings.maybeWhen(
          data: (st) => PrReveal(
            child: PnNotice(
              icon: Icons.tune_rounded,
              text: s.pn(
                'Rules in force: ${st.periodDurationMinutes} min periods, ${st.dayStartTime}–${st.dayEndTime}, ${st.workingDays.length} working days, ${st.breakPeriods.length} break${st.breakPeriods.length == 1 ? '' : 's'}.',
                'Règles en vigueur : périodes de ${st.periodDurationMinutes} min, ${st.dayStartTime}–${st.dayEndTime}, ${st.workingDays.length} jours de classe, ${st.breakPeriods.length} pause${st.breakPeriods.length == 1 ? '' : 's'}.',
              ),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        PrReveal(
          index: 1,
          child: PrCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(s.pn('Scope', 'Portée'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              PrPills<_GenScope>(
                values: _GenScope.values,
                selected: _scope,
                label: (v) => v == _GenScope.class_ ? s.pn('One class', 'Une classe') : (v == _GenScope.department ? s.pn('Department', 'Département') : s.pn('Whole school', 'Toute l’école')),
                onChanged: _generating
                    ? (_) {}
                    : (v) => setState(() {
                          _scope = v;
                          _department = null;
                          _class = null;
                        }),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_scope != _GenScope.school) ...[
                    const SizedBox(height: 14),
                    PnAsync<List<DepartmentFull>>(
                      value: depts,
                      strings: s,
                      skeletonRows: 1,
                      onRetry: () => ref.invalidate(departmentsFullProvider(widget.schoolId)),
                      builder: (list) => DropdownButtonFormField<String>(
                        initialValue: _department?.id,
                        isExpanded: true,
                        decoration: pnDeco(s.pn('Department', 'Département')),
                        items: [for (final d in list) DropdownMenuItem(value: d.id, child: Text(d.departmentName))],
                        onChanged: _generating ? null : (v) => setState(() {
                              _department = list.firstWhere((d) => d.id == v);
                              _class = null;
                            }),
                      ),
                    ),
                  ],
                  if (_scope == _GenScope.class_ && _department != null) ...[
                    const SizedBox(height: 12),
                    PnAsync<List<ManagedClass>>(
                      value: ref.watch(managedClassesProvider(widget.schoolId)),
                      strings: s,
                      skeletonRows: 1,
                      onRetry: () => ref.invalidate(managedClassesProvider(widget.schoolId)),
                      builder: (all) {
                        final list = all.where((c) => c.departmentId == _department!.id && c.isActive).toList();
                        return DropdownButtonFormField<String>(
                          initialValue: _class?.id,
                          isExpanded: true,
                          decoration: pnDeco(s.pn('Class', 'Classe')),
                          items: [for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.className))],
                          onChanged: _generating ? null : (v) => setState(() => _class = list.firstWhere((c) => c.id == v)),
                        );
                      },
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 18),
              Text(s.pn('Note for the AI (optional)', 'Note pour l’IA (facultatif)'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(s.pn('Context only: it can never override your fixed settings.', 'Contexte uniquement : elle ne peut jamais outrepasser vos paramètres fixes.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLines: 3,
                enabled: !_generating,
                decoration: pnDeco(s.pn('Your note', 'Votre note'), hint: s.pn('e.g. Place Physics in the morning.', 'ex. Placer la Physique le matin.')),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_generating ? s.pn('Generating…', 'Génération…') : s.pn('Generate timetable', 'Générer l’emploi du temps')),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                child: _generating
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(children: [
                          const LinearProgressIndicator(minHeight: 4),
                          const SizedBox(height: 10),
                          AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Text(_messages[_msg], key: ValueKey(_msg), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))),
                          const SizedBox(height: 4),
                          Text(s.pn('This can take up to a minute. Please keep this page open.', 'Cela peut prendre jusqu’à une minute. Gardez cette page ouverte.'), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                        ]),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ]),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _result == null ? const SizedBox(key: ValueKey('none'), width: double.infinity) : Padding(key: const ValueKey('res'), padding: const EdgeInsets.only(top: 16), child: _resultCard(s, _result!)),
        ),
        const SizedBox(height: 22),
        _history(s),
      ],
    );
  }

  Widget _resultCard(AppStrings s, Map<String, dynamic> r) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final created = (r['slots_created'] as num?)?.toInt() ?? 0;
    final rejected = (r['slots_rejected'] as num?)?.toInt() ?? 0;
    final details = ((r['rejection_details'] as List?) ?? const []).map((e) => '$e').toList();
    return PrCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(rejected == 0 ? Icons.check_circle_rounded : Icons.info_rounded, color: rejected == 0 ? pnGood() : pnWarn()),
          const SizedBox(width: 10),
          Expanded(child: Text(s.pn('Timetable generated', 'Emploi du temps généré'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 14),
        PrGrid(minTile: 150, max: 2, children: [
          PrStatTile(icon: Icons.event_available_rounded, label: s.pn('Slots created', 'Créneaux créés'), value: created.toDouble(), format: (v) => v.round().toString()),
          PrStatTile(icon: Icons.block_rounded, label: s.pn('Rejected by rules', 'Rejetés par les règles'), value: rejected.toDouble(), format: (v) => v.round().toString()),
        ]),
        const SizedBox(height: 14),
        Text(s.pn('AI summary', 'Résumé de l’IA'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text((r['ai_summary'] as String?)?.trim().isNotEmpty == true ? r['ai_summary'] as String : s.pn('No summary provided.', 'Aucun résumé fourni.'), style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 12),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(s.pn('$rejected slot${rejected == 1 ? '' : 's'} rejected', '$rejected créneau${rejected == 1 ? '' : 'x'} rejeté${rejected == 1 ? '' : 's'}'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: pnWarn())),
              children: [for (final d in details) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $d', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))))],
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(s.pn('Open “View timetables” to see and print the result.', 'Ouvrez « Voir les emplois du temps » pour consulter et imprimer le résultat.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
      ]),
    );
  }

  Widget _history(AppStrings s) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(timetableHistoryProvider(widget.schoolId));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PrSectionTitle(title: s.pn('Previous generations', 'Générations précédentes')),
      PnAsync<List<TimetableGenerationRecord>>(
        value: async,
        strings: s,
        skeletonRows: 2,
        onRetry: () => ref.invalidate(timetableHistoryProvider(widget.schoolId)),
        isEmpty: (d) => d.isEmpty,
        empty: PnEmpty(icon: Icons.history_rounded, title: s.pn('Nothing generated yet', 'Rien de généré pour l’instant')),
        builder: (list) => Column(children: [
          for (var i = 0; i < (list.length > 10 ? 10 : list.length); i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrReveal(
                index: i > 6 ? 6 : i,
                child: PrCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      leading: Icon(Icons.auto_awesome_rounded, color: cs.primary),
                      title: Text(list[i].scopeLabel ?? s.pn('Whole school', 'Toute l’école'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      subtitle: Text(pDateTime(list[i].generatedAt), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                      children: [
                        if ((list[i].principalNote ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s.pn('Your note: ${list[i].principalNote}', 'Votre note : ${list[i].principalNote}'), style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
                        Text((list[i].aiSummary ?? '').isEmpty ? s.pn('No summary.', 'Aucun résumé.') : list[i].aiSummary!, style: theme.textTheme.bodySmall?.copyWith(height: 1.45)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// ============================================================
// VIEW / PRINT TIMETABLES: by class, by teacher, whole school
// ============================================================

enum _ViewMode { class_, teacher, school }

class ViewTimetablePage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ViewTimetablePage({super.key, required this.schoolId, required this.landing, required this.strings});

  @override
  ConsumerState<ViewTimetablePage> createState() => _ViewTimetablePageState();
}

class _ViewTimetablePageState extends ConsumerState<ViewTimetablePage> {
  _ViewMode _mode = _ViewMode.class_;
  String? _classId;
  String? _teacher;
  int _day = DateTime.now().weekday;
  bool _downloading = false;

  AppStrings get _s => widget.strings;

  // ------------------------------------------------------------ PDF

  Future<void> _pdf({required String fileName, required List<({String title, Map<int, List<_Cell>> cells, bool teacherMode})> pages, required TimetableSettings settings}) async {
    final s = _s;
    setState(() => _downloading = true);
    try {
      Map<String, String> assets = const {};
      try {
        assets = await ref.read(officialBrandingProvider(widget.schoolId).future);
      } catch (_) {}
      final branding = await OfficialBranding.fetch(assets);
      final primary = PdfColor.fromInt(pnHex(widget.landing.primaryColor, const Color(0xFF1A73E8)).toARGB32());
      final secondary = PdfColor.fromInt(pnHex(widget.landing.secondaryColor, const Color(0xFFF59E0B)).toARGB32());
      final days = (settings.workingDays.isEmpty ? [1, 2, 3, 4, 5] : ([...settings.workingDays]..sort()));
      final breaks = _breaksOf(settings);
      final doc = pw.Document();
      for (final pg in pages) {
        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => [
            buildDocumentHeader(branding: branding, schoolName: widget.landing.schoolName, motto: widget.landing.motto),
            pw.SizedBox(height: 10),
            _pdfSection(s, pg.title, pg.cells, days, breaks, primary, secondary, pg.teacherMode),
          ],
        ));
      }
      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: '${fileName.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')}.pdf');
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _ascii(String v) => v.replaceAll('’', "'").replaceAll('–', '-').replaceAll('—', '-').replaceAll('…', '...');

  pw.Widget _pdfSection(AppStrings s, String title, Map<int, List<_Cell>> cells, List<int> days, List<_Break> breaks, PdfColor primary, PdfColor secondary, bool teacherMode) {
    final times = <String>{};
    for (final d in days) {
      for (final c in cells[d] ?? const <_Cell>[]) {
        times.add(c.slot.startTime);
      }
    }
    final timeline = <String>{...times, ...breaks.map((b) => b.start)}.toList()..sort();
    final breakAt = {for (final b in breaks) b.start: b};

    String endOf(String start) {
      for (final d in days) {
        for (final c in cells[d] ?? const <_Cell>[]) {
          if (c.slot.startTime == start) return c.slot.endTime;
        }
      }
      return '';
    }

    pw.Widget slotCell(int d, String t) {
      final list = (cells[d] ?? const <_Cell>[]).where((c) => c.slot.startTime == t).toList();
      if (list.isEmpty) return pw.SizedBox(height: 30);
      final c = list.first;
      final warn = c.slot.needsTeacher || c.conflict;
      return pw.Container(
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          color: c.conflict ? PdfColors.red50 : (c.slot.needsTeacher ? PdfColors.orange50 : PdfColors.grey100),
          border: pw.Border.all(color: c.conflict ? PdfColors.red300 : (c.slot.needsTeacher ? PdfColors.orange300 : PdfColors.grey400), width: 0.5),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_ascii(c.slot.subjectName), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), maxLines: 2),
          pw.Text(_ascii(teacherMode ? c.className : _teacherOf(s, c.slot)), style: pw.TextStyle(fontSize: 6.5, color: warn ? PdfColors.orange800 : PdfColors.grey700), maxLines: 1),
        ]),
      );
    }

    pw.Widget table(List<String> rows, {required bool header}) {
      return pw.Table(
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(width: 0.4, color: PdfColors.grey400),
          verticalInside: pw.BorderSide(width: 0.4, color: PdfColors.grey400),
          top: pw.BorderSide(width: 0.7, color: PdfColors.grey700),
          bottom: pw.BorderSide(width: 0.7, color: PdfColors.grey700),
          left: pw.BorderSide(width: 0.7, color: PdfColors.grey700),
          right: pw.BorderSide(width: 0.7, color: PdfColors.grey700),
        ),
        columnWidths: {0: const pw.FixedColumnWidth(52), for (var i = 0; i < days.length; i++) i + 1: const pw.FlexColumnWidth(1)},
        children: [
          if (header)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: primary),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 7), child: pw.Text(_ascii(s.pn('Time', 'Heure')), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                for (final d in days) pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 7), child: pw.Text(_ascii(pnDayLong(s, d)), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
              ],
            ),
          for (final t in rows)
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('$t\n${endOf(t)}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700))),
              for (final d in days) pw.Padding(padding: const pw.EdgeInsets.all(3), child: slotCell(d, t)),
            ]),
        ],
      );
    }

    final out = <pw.Widget>[
      pw.Row(children: [
        pw.Container(width: 5, height: 18, color: secondary),
        pw.SizedBox(width: 8),
        pw.Text(_ascii(title), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ]),
      pw.SizedBox(height: 10),
    ];
    var current = <String>[];
    var first = true;
    void flush() {
      if (current.isEmpty) return;
      out.add(table(current, header: first));
      first = false;
      current = [];
    }

    for (final t in timeline) {
      final b = breakAt[t];
      if (b != null) {
        flush();
        out.add(pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          width: double.infinity,
          decoration: pw.BoxDecoration(color: PdfColors.amber100, border: pw.Border.all(color: PdfColors.amber700, width: 0.6), borderRadius: pw.BorderRadius.circular(3)),
          child: pw.Center(child: pw.Text('${_ascii(b.label)}  ·  ${b.start} - ${b.end}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900))),
        ));
      } else {
        current.add(t);
      }
    }
    flush();
    if (out.length == 2) out.add(pw.Text(_ascii(s.pn('No slots to display.', 'Aucun créneau à afficher.')), style: const pw.TextStyle(fontSize: 10)));
    out.add(pw.SizedBox(height: 8));
    out.add(pw.Text(_ascii(s.pn('Orange: no teacher yet. Red: teacher booked twice at the same time.', 'Orange : pas encore d\'enseignant. Rouge : enseignant planifié deux fois en même temps.')), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)));
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: out);
  }

  // ------------------------------------------------------------ data

  Map<int, List<_Cell>> _cellsForClass(String classId, String className, Map<String, List<TimetableSlot>> all, Set<String> conflicts) {
    final out = <int, List<_Cell>>{};
    for (final sl in all[classId] ?? const <TimetableSlot>[]) {
      final d = int.tryParse(sl.dayOfWeek) ?? 1;
      out.putIfAbsent(d, () => []).add(_Cell(sl, className, classId, conflicts.contains('$classId|${sl.dayOfWeek}|${sl.startTime}')));
    }
    return out;
  }

  Map<int, List<_Cell>> _cellsForTeacher(String teacher, Map<String, String> names, Map<String, List<TimetableSlot>> all, Set<String> conflicts) {
    final out = <int, List<_Cell>>{};
    all.forEach((classId, slots) {
      for (final sl in slots) {
        if (sl.teacherName != teacher || sl.needsTeacher) continue;
        final d = int.tryParse(sl.dayOfWeek) ?? 1;
        out.putIfAbsent(d, () => []).add(_Cell(sl, names[classId] ?? '', classId, conflicts.contains('$classId|${sl.dayOfWeek}|${sl.startTime}')));
      }
    });
    return out;
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final yearAsync = ref.watch(principalCurrentAcademicYearIdProvider(widget.schoolId));
    return PrPage(
      maxWidth: 1100,
      children: [
        PrHeader(
          title: s.pn('Timetables', 'Emplois du temps'),
          subtitle: s.pn('Browse the weekly timetable by class, by teacher or for the whole school, and print it.', 'Consultez l’emploi du temps hebdomadaire par classe, par enseignant ou pour toute l’école, et imprimez-le.'),
        ),
        const SizedBox(height: 14),
        PrPills<_ViewMode>(
          values: _ViewMode.values,
          selected: _mode,
          label: (m) => m == _ViewMode.class_ ? s.pn('By class', 'Par classe') : (m == _ViewMode.teacher ? s.pn('By teacher', 'Par enseignant') : s.pn('Whole school', 'Toute l’école')),
          onChanged: (m) => setState(() => _mode = m),
        ),
        const SizedBox(height: 16),
        PnAsync<String?>(
          value: yearAsync,
          strings: s,
          onRetry: () => ref.invalidate(principalCurrentAcademicYearIdProvider(widget.schoolId)),
          isEmpty: (y) => y == null,
          empty: PnEmpty(icon: Icons.event_busy_rounded, title: s.pn('No current academic year', 'Aucune année scolaire en cours'), text: s.pn('Set the current year in the Calendar first.', 'Définissez d’abord l’année en cours dans le Calendrier.')),
          builder: (yearId) => _body(s, yearId!),
        ),
      ],
    );
  }

  Widget _body(AppStrings s, String yearId) {
    final classes = ref.watch(managedClassesProvider(widget.schoolId));
    final settings = ref.watch(timetableSettingsProvider(widget.schoolId));
    final key = (schoolId: widget.schoolId, yearId: yearId);
    final all = ref.watch(_schoolSlotsProvider(key));

    return PnAsync<List<ManagedClass>>(
      value: classes,
      strings: s,
      onRetry: () => ref.invalidate(managedClassesProvider(widget.schoolId)),
      isEmpty: (d) => d.isEmpty,
      empty: PnEmpty(icon: Icons.groups_rounded, title: s.pn('No classes yet', 'Aucune classe')),
      builder: (cls) => PnAsync<TimetableSettings>(
        value: settings,
        strings: s,
        onRetry: () => ref.invalidate(timetableSettingsProvider(widget.schoolId)),
        builder: (st) => PnAsync<Map<String, List<TimetableSlot>>>(
          value: all,
          strings: s,
          onRetry: () => ref.invalidate(_schoolSlotsProvider(key)),
          builder: (byClass) {
            final active = cls.where((c) => c.isActive).toList();
            final names = {for (final c in cls) c.id: c.className};
            final conflicts = _conflictKeys(byClass);
            final days = st.workingDays.isEmpty ? [1, 2, 3, 4, 5] : ([...st.workingDays]..sort());
            final breaks = _breaksOf(st);
            final noTeacher = byClass.values.fold<int>(0, (a, l) => a + l.where((x) => x.needsTeacher).length);
            final generated = active.where((c) => (byClass[c.id] ?? const []).isNotEmpty).length;

            Widget status = PrReveal(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                PnChip(label: s.pn('$generated of ${active.length} classes generated', '$generated classe(s) sur ${active.length} générée(s)'), color: generated == active.length && active.isNotEmpty ? pnGood() : pnWarn(), icon: Icons.event_available_rounded),
                if (noTeacher > 0) PnChip(label: s.pn('$noTeacher slot${noTeacher == 1 ? '' : 's'} without a teacher', '$noTeacher créneau(x) sans enseignant'), color: pnWarn(), icon: Icons.person_off_rounded),
                if (conflicts.isNotEmpty) PnChip(label: s.pn('${conflicts.length ~/ 2} teacher clash${conflicts.length ~/ 2 == 1 ? '' : 'es'}', '${conflicts.length ~/ 2} conflit(s) d’enseignant'), color: pnBad(), icon: Icons.warning_amber_rounded),
              ]),
            );

            if (_mode == _ViewMode.school) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                status,
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: _downloading || generated == 0
                        ? null
                        : () => _pdf(
                              fileName: 'timetables_${widget.landing.schoolName}',
                              settings: st,
                              pages: [
                                for (final c in active)
                                  if ((byClass[c.id] ?? const []).isNotEmpty) (title: s.pn('${c.className} - Weekly timetable', '${c.className} - Emploi du temps hebdomadaire'), cells: _cellsForClass(c.id, c.className, byClass, conflicts), teacherMode: false),
                              ],
                            ),
                    icon: _downloading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
                    label: Text(s.pn('Download all classes (PDF)', 'Télécharger toutes les classes (PDF)')),
                  ),
                ),
                const SizedBox(height: 14),
                if (active.isEmpty)
                  PnEmpty(icon: Icons.groups_rounded, title: s.pn('No active classes', 'Aucune classe active'))
                else
                  for (var i = 0; i < active.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Builder(builder: (context) {
                        final slots = byClass[active[i].id] ?? const <TimetableSlot>[];
                        return PnPickTile(
                          index: i,
                          icon: slots.isEmpty ? Icons.event_busy_rounded : Icons.event_available_rounded,
                          title: active[i].className,
                          subtitle: slots.isEmpty ? s.pn('Not generated', 'Non généré') : s.pn('${slots.length} slots', '${slots.length} créneaux'),
                          badge: slots.isEmpty ? null : s.pn('View', 'Voir'),
                          onTap: slots.isEmpty
                              ? null
                              : () => setState(() {
                                    _mode = _ViewMode.class_;
                                    _classId = active[i].id;
                                  }),
                        );
                      }),
                    ),
              ]);
            }

            if (_mode == _ViewMode.teacher) {
              final teachers = <String>{
                for (final l in byClass.values)
                  for (final x in l)
                    if (!x.needsTeacher && (x.teacherName ?? '').isNotEmpty) x.teacherName!,
              }.toList()
                ..sort();
              if (teachers.isEmpty) return PnEmpty(icon: Icons.person_off_rounded, title: s.pn('No teacher in the timetable yet', 'Aucun enseignant dans l’emploi du temps'), text: s.pn('Generate a timetable first.', 'Générez d’abord un emploi du temps.'));
              final sel = teachers.contains(_teacher) ? _teacher! : teachers.first;
              final cells = _cellsForTeacher(sel, names, byClass, conflicts);
              final total = cells.values.fold<int>(0, (a, l) => a + l.length);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                status,
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: sel,
                      isExpanded: true,
                      decoration: pnDeco(s.pn('Teacher', 'Enseignant'), icon: Icons.person_rounded),
                      items: [for (final t in teachers) DropdownMenuItem(value: t, child: Text(t))],
                      onChanged: (v) => setState(() => _teacher = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: _downloading ? null : () => _pdf(fileName: 'timetable_$sel', settings: st, pages: [(title: s.pn('$sel - Weekly timetable', '$sel - Emploi du temps hebdomadaire'), cells: cells, teacherMode: true)]),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(s.pn('PDF', 'PDF')),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(s.pn('$total periods per week', '$total périodes par semaine'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 12),
                _WeekGrid(strings: s, days: days, cells: cells, breaks: breaks, teacherMode: true, day: _day, onDay: (d) => setState(() => _day = d)),
              ]);
            }

            // by class
            if (active.isEmpty) return PnEmpty(icon: Icons.groups_rounded, title: s.pn('No active classes', 'Aucune classe active'));
            final selId = active.any((c) => c.id == _classId) ? _classId! : active.first.id;
            final cls0 = active.firstWhere((c) => c.id == selId);
            final slots = byClass[selId] ?? const <TimetableSlot>[];
            final cells = _cellsForClass(selId, cls0.className, byClass, conflicts);
            final myConflicts = cells.values.fold<int>(0, (a, l) => a + l.where((c) => c.conflict).length);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              status,
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selId,
                    isExpanded: true,
                    decoration: pnDeco(s.pn('Class', 'Classe'), icon: Icons.groups_rounded),
                    items: [for (final c in active) DropdownMenuItem(value: c.id, child: Text(c.className))],
                    onChanged: (v) => setState(() => _classId = v),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: _downloading || slots.isEmpty ? null : () => _pdf(fileName: 'timetable_${cls0.className}', settings: st, pages: [(title: s.pn('${cls0.className} - Weekly timetable', '${cls0.className} - Emploi du temps hebdomadaire'), cells: cells, teacherMode: false)]),
                  icon: _downloading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
                  label: Text(s.pn('PDF', 'PDF')),
                ),
              ]),
              if (myConflicts > 0) ...[
                const SizedBox(height: 10),
                PnNotice(icon: Icons.warning_amber_rounded, color: pnBad(), text: s.pn('$myConflicts slot${myConflicts == 1 ? '' : 's'} of this class clash with a teacher’s other class at the same time. Regenerate this class to fix it.', '$myConflicts créneau(x) de cette classe entrent en conflit avec une autre classe d’un enseignant à la même heure. Régénérez cette classe pour corriger.')),
              ],
              const SizedBox(height: 12),
              if (slots.isEmpty)
                PnEmpty(icon: Icons.event_busy_rounded, title: s.pn('No timetable for ${cls0.className}', 'Pas d’emploi du temps pour ${cls0.className}'), text: s.pn('Use “Generate timetable” to create it.', 'Utilisez « Générer l’emploi du temps » pour le créer.'))
              else
                _WeekGrid(strings: s, days: days, cells: cells, breaks: breaks, teacherMode: false, day: _day, onDay: (d) => setState(() => _day = d)),
            ]);
          },
        ),
      ),
    );
  }
}

// ============================================================
// Weekly grid (desktop/tablet) and day list (phone)
// ============================================================

class _WeekGrid extends StatelessWidget {
  final AppStrings strings;
  final List<int> days;
  final Map<int, List<_Cell>> cells;
  final List<_Break> breaks;
  final bool teacherMode;
  final int day;
  final ValueChanged<int> onDay;
  const _WeekGrid({required this.strings, required this.days, required this.cells, required this.breaks, required this.teacherMode, required this.day, required this.onDay});

  List<String> _timeline() {
    final times = <String>{};
    for (final d in days) {
      for (final c in cells[d] ?? const <_Cell>[]) {
        times.add(c.slot.startTime);
      }
    }
    return <String>{...times, ...breaks.map((b) => b.start)}.toList()..sort();
  }

  String _end(String start) {
    for (final d in days) {
      for (final c in cells[d] ?? const <_Cell>[]) {
        if (c.slot.startTime == start) return c.slot.endTime;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final timeline = _timeline();
    final breakAt = {for (final b in breaks) b.start: b};
    if (timeline.every((t) => breakAt.containsKey(t))) {
      return PnEmpty(icon: Icons.event_busy_rounded, title: s.pn('Nothing scheduled', 'Rien de planifié'));
    }
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 720) return _phone(context, s, timeline, breakAt);
      return _desktop(context, s, timeline, breakAt);
    });
  }

  Widget _phone(BuildContext context, AppStrings s, List<String> timeline, Map<String, _Break> breakAt) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sel = days.contains(day) ? day : days.first;
    final list = cells[sel] ?? const <_Cell>[];
    final dayTimes = <String>{...list.map((x) => x.slot.startTime), ...breakAt.keys}.toList()..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: PrPills<int>(values: days, selected: sel, label: (d) => pnDayShort(s, d), onChanged: onDay),
      ),
      const SizedBox(height: 12),
      if (list.isEmpty)
        PnEmpty(icon: Icons.weekend_rounded, title: s.pn('Nothing on ${pnDayLong(s, sel)}', 'Rien le ${pnDayLong(s, sel).toLowerCase()}'))
      else
        PnStage(
          stageKey: 'd$sel',
          child: Column(children: [
            for (var i = 0; i < dayTimes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Builder(builder: (context) {
                  final t = dayTimes[i];
                  final b = breakAt[t];
                  if (b != null) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFF2B33D).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                      child: Text('${b.label} · ${b.start}–${b.end}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    );
                  }
                  final matches = list.where((x) => x.slot.startTime == t).toList();
                  if (matches.isEmpty) return const SizedBox.shrink();
                  final x = matches.first;
                  return PrReveal(
                    index: i > 6 ? 6 : i,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 58, child: Padding(padding: const EdgeInsets.only(top: 10), child: Text('${x.slot.startTime}\n${x.slot.endTime}', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)))),
                      Expanded(child: _CellBox(strings: s, cell: x, teacherMode: teacherMode)),
                    ]),
                  );
                }),
              ),
          ]),
        ),
    ]);
  }

  Widget _desktop(BuildContext context, AppStrings s, List<String> timeline, Map<String, _Break> breakAt) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PrReveal(
      child: PrCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 62),
            for (final d in days)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
                  child: Text(pnDayLong(s, d), style: theme.textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          for (final t in timeline)
            Builder(builder: (context) {
              final b = breakAt[t];
              if (b != null) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  width: double.infinity,
                  decoration: BoxDecoration(color: const Color(0xFFF2B33D).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                  child: Text('${b.label} · ${b.start}–${b.end}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(width: 62, child: Center(child: Text('$t\n${_end(t)}', textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)))),
                    for (final d in days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Builder(builder: (context) {
                            final m = (cells[d] ?? const <_Cell>[]).where((x) => x.slot.startTime == t).toList();
                            if (m.isEmpty) return const SizedBox.shrink();
                            return _CellBox(strings: s, cell: m.first, teacherMode: teacherMode);
                          }),
                        ),
                      ),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 10),
          Row(children: [
            _legend(context, cs.primary.withValues(alpha: 0.4), s.pn('Scheduled', 'Planifié')),
            const SizedBox(width: 16),
            _legend(context, pnWarn(), s.pn('No teacher yet', 'Pas encore d’enseignant')),
            const SizedBox(width: 16),
            _legend(context, pnBad(), s.pn('Teacher clash', 'Conflit d’enseignant')),
          ]),
        ]),
      ),
    );
  }

  Widget _legend(BuildContext context, Color c, String label) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
    ]);
  }
}

class _CellBox extends StatelessWidget {
  final AppStrings strings;
  final _Cell cell;
  final bool teacherMode;
  const _CellBox({required this.strings, required this.cell, required this.teacherMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final sl = cell.slot;
    final warn = sl.needsTeacher;
    final bad = cell.conflict;
    final bg = bad ? pnBad().withValues(alpha: 0.12) : (warn ? pnWarn().withValues(alpha: 0.14) : pnSubjectTint(sl.subjectName, b));
    final ink = bad ? pnBad() : (warn ? pnWarn() : pnSubjectInk(sl.subjectName, b));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: (bad || warn) ? ink.withValues(alpha: 0.5) : Colors.transparent)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(sl.subjectName, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: ink), maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (bad) Icon(Icons.warning_amber_rounded, size: 16, color: ink),
        ]),
        const SizedBox(height: 2),
        Text(teacherMode ? cell.className : _teacherOf(strings, sl), style: theme.textTheme.bodySmall?.copyWith(color: ink.withValues(alpha: 0.85), fontStyle: warn ? FontStyle.italic : FontStyle.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
        if ((sl.roomName ?? '').isNotEmpty) Text(sl.roomName!, style: theme.textTheme.labelSmall?.copyWith(color: ink.withValues(alpha: 0.7))),
      ]),
    );
  }
}
