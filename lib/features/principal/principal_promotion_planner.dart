import 'principal_hub_models.dart';

/// Pure promotion planning (no database, no UI) so it can be reasoned
/// about, and re-run instantly while the principal adjusts the pass mark.
///
/// Rules
///  1. Average at or above the pass mark   -> promoted to the next level.
///  2. Within [margin] below the pass mark -> repeat, flagged "borderline"
///     so the council can overturn it with one tap.
///  3. Lower                               -> repeat.
///  4. No average yet                      -> held until a decision is made.
///  5. Highest level of the school         -> graduated.
///  6. Target class: same section first (1A -> 2A). If that class does
///     not exist or is full, any class of the next level with free seats,
///     spreading students across classes (fewest students first). The
///     same department is preferred; another department is used only
///     when the department has no class at the next level.
///  7. A full level is never silently overfilled: the student is marked
///     "no seat" so the principal can raise a capacity or choose a class.

enum PnOutcome { promoted, repeat, graduated, held }

enum PnFlag { none, borderline, noAverage, noSeat, crossDepartment, alreadyPlaced }

class PnManual {
  final PnOutcome outcome;
  final String? toClassId;
  const PnManual(this.outcome, this.toClassId);
}

class PnPlanRow {
  final PnPromoStudent student;
  final PnPromoClass? from;
  final PnOutcome outcome;
  final String? toClassId;
  final PnFlag flag;
  final bool manual;
  final bool include;

  const PnPlanRow({
    required this.student,
    required this.from,
    required this.outcome,
    required this.toClassId,
    required this.flag,
    required this.manual,
    required this.include,
  });

  bool get applicable => include && flag != PnFlag.alreadyPlaced && outcome != PnOutcome.held && (outcome == PnOutcome.graduated || toClassId != null);
}

class PnPlan {
  final List<PnPlanRow> rows;
  final Map<String, int> planned; // classId -> students planned into it
  const PnPlan({required this.rows, required this.planned});

  int count(PnOutcome o) => rows.where((r) => r.flag != PnFlag.alreadyPlaced && r.outcome == o).length;
  int get alreadyPlaced => rows.where((r) => r.flag == PnFlag.alreadyPlaced).length;
  int get noSeat => rows.where((r) => r.flag == PnFlag.noSeat).length;
  int get borderline => rows.where((r) => r.flag == PnFlag.borderline).length;
  int get held => rows.where((r) => r.outcome == PnOutcome.held && r.flag != PnFlag.alreadyPlaced).length;
}

String pnSectionOf(String name) {
  final n = name.trim();
  final m = RegExp(r'\d\s*([A-Za-z]+)$').firstMatch(n);
  if (m != null) return m.group(1)!.toLowerCase();
  final parts = n.split(RegExp(r'\s+'));
  return parts.length > 1 ? parts.last.toLowerCase() : '';
}

class PnPlanner {
  final PnPromoData data;
  final double passMark;
  final double margin;
  final bool balance;
  final Map<String, PnManual> manual;
  final Set<String> excluded;

  PnPlanner({required this.data, required this.passMark, required this.margin, required this.balance, this.manual = const {}, this.excluded = const {}});

  late final Map<String, PnPromoClass> _classes = {for (final c in data.classes) c.id: c};
  late final int _maxLevel = data.classes.isEmpty ? 0 : data.classes.map((c) => c.level).reduce((a, b) => a > b ? a : b);

  PnPlan plan({String? onlyClassId}) {
    // free seats left in each class; unlimited when no capacity is set
    final used = <String, int>{for (final c in data.classes) c.id: c.enrolledTo};
    final planned = <String, int>{};

    bool hasRoom(PnPromoClass c) => c.max <= 0 || (used[c.id] ?? 0) < c.max;
    void take(PnPromoClass c) {
      used[c.id] = (used[c.id] ?? 0) + 1;
      planned[c.id] = (planned[c.id] ?? 0) + 1;
    }

    PnPromoClass? pick(List<PnPromoClass> candidates, String section) {
      final open = candidates.where(hasRoom).toList();
      if (open.isEmpty) return null;
      if (section.isNotEmpty) {
        for (final c in open) {
          if (pnSectionOf(c.name) == section) return c;
        }
      }
      return null;
    }

    PnPromoClass? spread(List<PnPromoClass> candidates) {
      final open = candidates.where(hasRoom).toList();
      if (open.isEmpty) return null;
      if (!balance) return open.first;
      open.sort((a, b) {
        final ra = a.max <= 0 ? 0.0 : (used[a.id] ?? 0) / a.max;
        final rb = b.max <= 0 ? 0.0 : (used[b.id] ?? 0) / b.max;
        final byRatio = ra.compareTo(rb);
        return byRatio != 0 ? byRatio : a.name.compareTo(b.name);
      });
      return open.first;
    }

    List<PnPromoClass> sameLevel(PnPromoClass from, int level, {required bool sameDept}) => data.classes
        .where((c) => c.level == level && (sameDept ? c.departmentId == from.departmentId : c.departmentId != from.departmentId))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final students = data.students.where((s) => onlyClassId == null || s.classId == onlyClassId).toList()
      ..sort((a, b) {
        final c = a.classId.compareTo(b.classId);
        return c != 0 ? c : a.fullName.compareTo(b.fullName);
      });

    final result = <String, PnPlanRow>{};

    PnPlanRow row(PnPromoStudent s, PnPromoClass? from, PnOutcome o, String? to, PnFlag f, {bool isManual = false}) {
      final inc = !excluded.contains(s.id) && f != PnFlag.alreadyPlaced && o != PnOutcome.held && (o == PnOutcome.graduated || to != null);
      return PnPlanRow(student: s, from: from, outcome: o, toClassId: to, flag: f, manual: isManual, include: inc);
    }

    // Pass 0: already placed in the new year, and manual decisions (they
    // consume seats first, so automatic placement works around them).
    final pending = <PnPromoStudent>[];
    for (final s in students) {
      final from = _classes[s.classId];
      if (s.alreadyTo != null || s.alreadyPromoted) {
        result[s.id] = row(s, from, PnOutcome.promoted, s.alreadyTo, PnFlag.alreadyPlaced);
        continue;
      }
      final m = manual[s.id];
      if (m != null) {
        final target = m.toClassId == null ? null : _classes[m.toClassId!];
        if (target != null && (m.outcome == PnOutcome.promoted || m.outcome == PnOutcome.repeat)) {
          take(target);
          result[s.id] = row(s, from, m.outcome, target.id, PnFlag.none, isManual: true);
        } else {
          result[s.id] = row(s, from, m.outcome, null, m.outcome == PnOutcome.held ? PnFlag.noAverage : (m.outcome == PnOutcome.graduated ? PnFlag.none : PnFlag.noSeat), isManual: true);
        }
        continue;
      }
      pending.add(s);
    }

    // Decide the outcome of everyone else.
    final decided = <PnPromoStudent, PnOutcome>{};
    final flags = <String, PnFlag>{};
    for (final s in pending) {
      final from = _classes[s.classId];
      if (from == null) {
        decided[s] = PnOutcome.held;
        flags[s.id] = PnFlag.noAverage;
        continue;
      }
      final avg = s.average;
      if (avg == null) {
        decided[s] = PnOutcome.held;
        flags[s.id] = PnFlag.noAverage;
      } else if (avg >= passMark) {
        decided[s] = from.level >= _maxLevel ? PnOutcome.graduated : PnOutcome.promoted;
        flags[s.id] = PnFlag.none;
      } else {
        decided[s] = PnOutcome.repeat;
        flags[s.id] = avg >= passMark - margin ? PnFlag.borderline : PnFlag.none;
      }
    }

    // Pass 1: same section (1A -> 2A) for those promoted.
    final waiting = <PnPromoStudent>[];
    for (final s in pending) {
      final o = decided[s]!;
      final from = _classes[s.classId];
      if (o == PnOutcome.promoted && from != null) {
        final cands = sameLevel(from, from.level + 1, sameDept: true);
        final match = pick(cands, pnSectionOf(from.name));
        if (match != null) {
          take(match);
          result[s.id] = row(s, from, o, match.id, flags[s.id]!);
        } else {
          waiting.add(s);
        }
      } else if (o == PnOutcome.repeat && from != null) {
        // repeaters stay in their own class when there is room
        if (hasRoom(from)) {
          take(from);
          result[s.id] = row(s, from, o, from.id, flags[s.id]!);
        } else {
          waiting.add(s);
        }
      } else {
        waiting.add(s);
      }
    }

    // Pass 2: everyone left is spread across the classes of the level.
    for (final s in waiting) {
      final o = decided[s]!;
      final from = _classes[s.classId];
      var f = flags[s.id]!;
      if (from == null || o == PnOutcome.held || o == PnOutcome.graduated) {
        result[s.id] = row(s, from, o, null, f);
        continue;
      }
      final level = o == PnOutcome.promoted ? from.level + 1 : from.level;
      var cands = sameLevel(from, level, sameDept: true);
      if (o == PnOutcome.repeat) cands = [...cands.where((c) => c.id == from.id), ...cands.where((c) => c.id != from.id)];
      var target = o == PnOutcome.repeat && hasRoom(from) ? from : spread(cands);
      if (target == null && o == PnOutcome.promoted && cands.isEmpty) {
        final other = sameLevel(from, level, sameDept: false);
        if (other.isNotEmpty) {
          target = spread(other);
          if (target != null) f = PnFlag.crossDepartment;
        }
      }
      if (target == null) {
        if (o == PnOutcome.promoted && cands.isEmpty && sameLevel(from, level, sameDept: false).isEmpty) {
          // no class at the next level exists anywhere: needs a decision
          result[s.id] = row(s, from, o, null, PnFlag.noSeat);
        } else {
          result[s.id] = row(s, from, o, null, PnFlag.noSeat);
        }
      } else {
        take(target);
        result[s.id] = row(s, from, o, target.id, f);
      }
    }

    final rows = [for (final s in students) result[s.id]!];
    return PnPlan(rows: rows, planned: planned);
  }
}
