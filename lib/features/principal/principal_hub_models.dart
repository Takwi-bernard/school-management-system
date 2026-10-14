/// Models for the Principal module's calendar, ranking, promotion, money
/// and overview features. Everything is built from the JSON returned by
/// the `principal_*` database functions.

double pnD(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);
double? pnDn(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int pnI(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
int? pnIn(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
String pnS(Object? v) => v == null ? '' : '$v';
String? pnSn(Object? v) {
  if (v == null) return null;
  final s = '$v';
  return s.isEmpty ? null : s;
}

DateTime? pnDt(Object? v) => v == null ? null : DateTime.tryParse('$v');
bool pnB(Object? v) => v == true;
Map<String, dynamic> pnMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> pnList(Object? v) =>
    v is List ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];

// ============================================================ overview

class PnYearBrief {
  final String id;
  final String name;
  final DateTime? start;
  final DateTime? end;
  const PnYearBrief({required this.id, required this.name, this.start, this.end});

  static PnYearBrief? from(Object? v) {
    if (v == null) return null;
    final m = pnMap(v);
    return PnYearBrief(id: pnS(m['id']), name: pnS(m['name']), start: pnDt(m['start']), end: pnDt(m['end']));
  }

  int? get daysLeft => end == null ? null : end!.difference(DateTime.now()).inDays;
}

class PnTermBrief {
  final String id;
  final String name;
  final DateTime? start;
  final DateTime? end;
  const PnTermBrief({required this.id, required this.name, this.start, this.end});

  static PnTermBrief? from(Object? v) {
    if (v == null) return null;
    final m = pnMap(v);
    return PnTermBrief(id: pnS(m['id']), name: pnS(m['name']), start: pnDt(m['start']), end: pnDt(m['end']));
  }
}

class PnInbox {
  final int teachersPending;
  final int admissions;
  final int marks;
  final int comments;
  final int corrections;
  final int cardsUnpublished;
  final int cardsStale;
  const PnInbox({
    required this.teachersPending,
    required this.admissions,
    required this.marks,
    required this.comments,
    required this.corrections,
    required this.cardsUnpublished,
    required this.cardsStale,
  });

  factory PnInbox.fromMap(Map<String, dynamic> m) => PnInbox(
        teachersPending: pnI(m['teachers_pending']),
        admissions: pnI(m['admissions']),
        marks: pnI(m['marks']),
        comments: pnI(m['comments']),
        corrections: pnI(m['corrections']),
        cardsUnpublished: pnI(m['cards_unpublished']),
        cardsStale: pnI(m['cards_stale']),
      );

  /// Items that need a decision from the principal.
  int get actionable => teachersPending + admissions + marks + comments + corrections;
}

class PnMoney {
  final double collectedMonth;
  final double collectedToday;
  final double arrears;
  final int debtors;
  final double teacherPayMonth;
  final int flagged;
  final double threshold;
  const PnMoney({
    required this.collectedMonth,
    required this.collectedToday,
    required this.arrears,
    required this.debtors,
    required this.teacherPayMonth,
    required this.flagged,
    required this.threshold,
  });

  factory PnMoney.fromMap(Map<String, dynamic> m) => PnMoney(
        collectedMonth: pnD(m['collected_month']),
        collectedToday: pnD(m['collected_today']),
        arrears: pnD(m['arrears']),
        debtors: pnI(m['debtors']),
        teacherPayMonth: pnD(m['teacher_pay_month']),
        flagged: pnI(m['flagged']),
        threshold: pnD(m['threshold']),
      );
}

class PnClassFill {
  final String id;
  final String name;
  final int level;
  final int max;
  final int enrolled;
  const PnClassFill({required this.id, required this.name, required this.level, required this.max, required this.enrolled});

  factory PnClassFill.fromMap(Map<String, dynamic> m) => PnClassFill(
        id: pnS(m['id']),
        name: pnS(m['name']),
        level: pnI(m['level']),
        max: pnI(m['max']),
        enrolled: pnI(m['enrolled']),
      );

  double get ratio => max <= 0 ? 0 : enrolled / max;
  bool get isFull => max > 0 && enrolled >= max;
}

class PnOverview {
  final PnYearBrief? year;
  final PnTermBrief? term;
  final bool nextYearExists;
  final int openSequences;
  final DateTime? nextMarksDue;
  final double passMark;
  final int students;
  final int capacity;
  final int classes;
  final int teachers;
  final PnInbox inbox;
  final PnMoney money;
  final List<PnClassFill> classFill;
  final Map<String, int> gender;

  const PnOverview({
    required this.year,
    required this.term,
    required this.nextYearExists,
    required this.openSequences,
    required this.nextMarksDue,
    required this.passMark,
    required this.students,
    required this.capacity,
    required this.classes,
    required this.teachers,
    required this.inbox,
    required this.money,
    required this.classFill,
    required this.gender,
  });

  factory PnOverview.fromMap(Map<String, dynamic> m) => PnOverview(
        year: PnYearBrief.from(m['year']),
        term: PnTermBrief.from(m['term']),
        nextYearExists: pnB(m['next_year_exists']),
        openSequences: pnI(m['open_sequences']),
        nextMarksDue: pnDt(m['next_marks_due']),
        passMark: pnD(m['pass_mark']),
        students: pnI(m['students']),
        capacity: pnI(m['capacity']),
        classes: pnI(m['classes']),
        teachers: pnI(m['teachers']),
        inbox: PnInbox.fromMap(pnMap(m['inbox'])),
        money: PnMoney.fromMap(pnMap(m['money'])),
        classFill: pnList(m['class_fill']).map(PnClassFill.fromMap).toList(),
        gender: pnMap(m['gender']).map((k, v) => MapEntry(k, pnI(v))),
      );

  double get capacityUsed => capacity <= 0 ? 0 : students / capacity * 100;
}

// ============================================================ calendar

class PnSequence {
  final String id;
  final String name;
  final int order;
  final DateTime? start;
  final DateTime? end;
  final DateTime? marksDue;
  final bool isOpen;
  final bool hasMarks;
  const PnSequence({
    required this.id,
    required this.name,
    required this.order,
    this.start,
    this.end,
    this.marksDue,
    required this.isOpen,
    required this.hasMarks,
  });

  factory PnSequence.fromMap(Map<String, dynamic> m) => PnSequence(
        id: pnS(m['id']),
        name: pnS(m['name']),
        order: pnI(m['order']),
        start: pnDt(m['start']),
        end: pnDt(m['end']),
        marksDue: pnDt(m['marks_due']),
        isOpen: pnB(m['is_open']),
        hasMarks: pnB(m['has_marks']),
      );
}

class PnTerm {
  final String id;
  final String name;
  final int order;
  final DateTime? start;
  final DateTime? end;
  final bool isCurrent;
  final List<PnSequence> sequences;
  const PnTerm({
    required this.id,
    required this.name,
    required this.order,
    this.start,
    this.end,
    required this.isCurrent,
    required this.sequences,
  });

  factory PnTerm.fromMap(Map<String, dynamic> m) => PnTerm(
        id: pnS(m['id']),
        name: pnS(m['name']),
        order: pnI(m['order']),
        start: pnDt(m['start']),
        end: pnDt(m['end']),
        isCurrent: pnB(m['is_current']),
        sequences: pnList(m['sequences']).map(PnSequence.fromMap).toList(),
      );
}

class PnYear {
  final String id;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final bool isCurrent;
  final int students;
  final int feesSet;
  final List<PnTerm> terms;
  const PnYear({
    required this.id,
    required this.name,
    this.start,
    this.end,
    required this.isCurrent,
    required this.students,
    required this.feesSet,
    required this.terms,
  });

  factory PnYear.fromMap(Map<String, dynamic> m) => PnYear(
        id: pnS(m['id']),
        name: pnS(m['name']),
        start: pnDt(m['start']),
        end: pnDt(m['end']),
        isCurrent: pnB(m['is_current']),
        students: pnI(m['students']),
        feesSet: pnI(m['fees_set']),
        terms: pnList(m['terms']).map(PnTerm.fromMap).toList(),
      );

  List<PnSequence> get sequences => [for (final t in terms) ...t.sequences];
}

/// Draft used by the "new academic year" wizard.
class PnTermDraft {
  String name;
  DateTime? start;
  DateTime? end;
  final List<PnSeqDraft> sequences;
  PnTermDraft({required this.name, this.start, this.end, List<PnSeqDraft>? sequences}) : sequences = sequences ?? [];

  Map<String, dynamic> toJson(String Function(DateTime) iso) => {
        'name': name,
        'start': start == null ? null : iso(start!),
        'end': end == null ? null : iso(end!),
        'sequences': [for (final s in sequences) s.toJson(iso)],
      };
}

class PnSeqDraft {
  String name;
  DateTime? start;
  DateTime? end;
  DateTime? marksDue;
  PnSeqDraft({required this.name, this.start, this.end, this.marksDue});

  Map<String, dynamic> toJson(String Function(DateTime) iso) => {
        'name': name,
        'start': start == null ? null : iso(start!),
        'end': end == null ? null : iso(end!),
        'marks_due': marksDue == null ? null : iso(marksDue!),
      };
}

// ============================================================ classes

class PnClass {
  final String id;
  final String name;
  final int level;
  final int max;
  final String? departmentId;
  final String department;
  const PnClass({required this.id, required this.name, required this.level, required this.max, this.departmentId, required this.department});

  factory PnClass.fromMap(Map<String, dynamic> m) => PnClass(
        id: pnS(m['id']),
        name: pnS(m['class_name']),
        level: pnI(m['level_order']),
        max: pnI(m['max_students']),
        departmentId: pnSn(m['department_id']),
        department: pnS(pnMap(m['departments'])['department_name']),
      );
}

// ============================================================ report cards

class PnBoardRow {
  final String studentId;
  final String firstName;
  final String lastName;
  final String? admissionNumber;
  final String? photo;
  final String? gender;
  final String? cardId;
  final double? average;
  final int? rank;
  final int? total;
  final bool isPublished;
  final DateTime? publishAt;
  final String? pdfUrl;
  final DateTime? generatedAt;
  final int marksCount;
  final bool stale;

  const PnBoardRow({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    this.admissionNumber,
    this.photo,
    this.gender,
    this.cardId,
    this.average,
    this.rank,
    this.total,
    required this.isPublished,
    this.publishAt,
    this.pdfUrl,
    this.generatedAt,
    required this.marksCount,
    required this.stale,
  });

  factory PnBoardRow.fromMap(Map<String, dynamic> m) => PnBoardRow(
        studentId: pnS(m['student_id']),
        firstName: pnS(m['first_name']),
        lastName: pnS(m['last_name']),
        admissionNumber: pnSn(m['admission_number']),
        photo: pnSn(m['student_photo_url']),
        gender: pnSn(m['gender']),
        cardId: pnSn(m['card_id']),
        average: pnDn(m['overall_average']),
        rank: pnIn(m['class_rank']),
        total: pnIn(m['total_students']),
        isPublished: pnB(m['is_published']),
        publishAt: pnDt(m['publish_at']),
        pdfUrl: pnSn(m['pdf_url']),
        generatedAt: pnDt(m['generated_at']),
        marksCount: pnI(m['marks_count']),
        stale: pnB(m['stale']),
      );

  String get fullName => '$firstName $lastName'.trim();
  bool get hasCard => cardId != null;
  bool get isScheduled => !isPublished && publishAt != null;
}

class PnBoardStats {
  final int enrolled;
  final int cards;
  final int withMarks;
  final int published;
  final int stale;
  final double? average;
  final double? highest;
  final double? lowest;
  final double passMark;
  final int passed;
  final int failed;
  const PnBoardStats({
    required this.enrolled,
    required this.cards,
    required this.withMarks,
    required this.published,
    required this.stale,
    this.average,
    this.highest,
    this.lowest,
    required this.passMark,
    required this.passed,
    required this.failed,
  });

  factory PnBoardStats.fromMap(Map<String, dynamic> m) => PnBoardStats(
        enrolled: pnI(m['enrolled']),
        cards: pnI(m['cards']),
        withMarks: pnI(m['with_marks']),
        published: pnI(m['published']),
        stale: pnI(m['stale']),
        average: pnDn(m['average']),
        highest: pnDn(m['highest']),
        lowest: pnDn(m['lowest']),
        passMark: pnD(m['pass_mark']),
        passed: pnI(m['passed']),
        failed: pnI(m['failed']),
      );

  double get passRate => cards == 0 ? 0 : passed / cards * 100;
}

class PnBoard {
  final List<PnBoardRow> rows;
  final PnBoardStats stats;
  const PnBoard({required this.rows, required this.stats});

  factory PnBoard.fromMap(Map<String, dynamic> m) =>
      PnBoard(rows: pnList(m['rows']).map(PnBoardRow.fromMap).toList(), stats: PnBoardStats.fromMap(pnMap(m['stats'])));
}

/// Everything the PDF needs for one report card, for any scope.
class PnCardPdfData {
  final String studentName;
  final String? studentPhotoUrl;
  final String? admissionNumber;
  final String className;
  final String reportLabel;
  final String scope; // sequence | term | year
  final List<String> columns;
  final List<PnPdfSubject> subjects;
  final double overallAverage;
  final int? rank;
  final int? total;
  final String? principalComment;
  const PnCardPdfData({
    required this.studentName,
    this.studentPhotoUrl,
    this.admissionNumber,
    required this.className,
    required this.reportLabel,
    required this.scope,
    required this.columns,
    required this.subjects,
    required this.overallAverage,
    this.rank,
    this.total,
    this.principalComment,
  });
}

class PnPdfSubject {
  final String name;
  final int coefficient;
  final List<double?> scores;
  final double average;
  const PnPdfSubject({required this.name, required this.coefficient, required this.scores, required this.average});
}

// ============================================================ promotion

class PnPromoClass {
  final String id;
  final String name;
  final int level;
  final int max;
  final String? departmentId;
  final String department;
  final int enrolledTo;
  const PnPromoClass({
    required this.id,
    required this.name,
    required this.level,
    required this.max,
    this.departmentId,
    required this.department,
    required this.enrolledTo,
  });

  factory PnPromoClass.fromMap(Map<String, dynamic> m) => PnPromoClass(
        id: pnS(m['id']),
        name: pnS(m['name']),
        level: pnI(m['level']),
        max: pnI(m['max']),
        departmentId: pnSn(m['department_id']),
        department: pnS(m['department']),
        enrolledTo: pnI(m['enrolled_to']),
      );
}

class PnPromoStudent {
  final String id;
  final String first;
  final String last;
  final String? adm;
  final String? gender;
  final String classId;
  final double? average;
  final int termsCounted; // -1 = a real annual card exists
  final String? alreadyTo;
  final bool alreadyPromoted;
  const PnPromoStudent({
    required this.id,
    required this.first,
    required this.last,
    this.adm,
    this.gender,
    required this.classId,
    this.average,
    required this.termsCounted,
    this.alreadyTo,
    required this.alreadyPromoted,
  });

  factory PnPromoStudent.fromMap(Map<String, dynamic> m) => PnPromoStudent(
        id: pnS(m['id']),
        first: pnS(m['first']),
        last: pnS(m['last']),
        adm: pnSn(m['adm']),
        gender: pnSn(m['gender']),
        classId: pnS(m['class_id']),
        average: pnDn(m['average']),
        termsCounted: pnI(m['terms_counted']),
        alreadyTo: pnSn(m['already_to']),
        alreadyPromoted: pnB(m['already_promoted']),
      );

  String get fullName => '$first $last'.trim();
}

class PnPromoData {
  final double passMark;
  final double margin;
  final bool balance;
  final List<PnPromoClass> classes;
  final List<PnPromoStudent> students;
  const PnPromoData({required this.passMark, required this.margin, required this.balance, required this.classes, required this.students});

  factory PnPromoData.fromMap(Map<String, dynamic> m) => PnPromoData(
        passMark: pnD(m['pass_mark']),
        margin: pnD(m['margin']),
        balance: m['balance'] != false,
        classes: pnList(m['classes']).map(PnPromoClass.fromMap).toList(),
        students: pnList(m['students']).map(PnPromoStudent.fromMap).toList(),
      );
}

class PnPromotionRun {
  final String id;
  final String from;
  final String to;
  final double passMark;
  final String? note;
  final String status;
  final int promoted;
  final int repeated;
  final int graduated;
  final int skipped;
  final DateTime? createdAt;
  const PnPromotionRun({
    required this.id,
    required this.from,
    required this.to,
    required this.passMark,
    this.note,
    required this.status,
    required this.promoted,
    required this.repeated,
    required this.graduated,
    required this.skipped,
    this.createdAt,
  });

  factory PnPromotionRun.fromMap(Map<String, dynamic> m) => PnPromotionRun(
        id: pnS(m['id']),
        from: pnS(m['from']),
        to: pnS(m['to']),
        passMark: pnD(m['pass_mark']),
        note: pnSn(m['note']),
        status: pnS(m['status']),
        promoted: pnI(m['promoted']),
        repeated: pnI(m['repeated']),
        graduated: pnI(m['graduated']),
        skipped: pnI(m['skipped']),
        createdAt: pnDt(m['created_at']),
      );

  bool get isUndone => status == 'undone';
}

// ============================================================ students

class PnStudentRow {
  final String id;
  final String firstName;
  final String lastName;
  final String? admissionNumber;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? photo;
  final String status;
  final String? classId;
  final String? className;
  const PnStudentRow({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.admissionNumber,
    this.gender,
    this.dateOfBirth,
    this.photo,
    required this.status,
    this.classId,
    this.className,
  });

  factory PnStudentRow.fromMap(Map<String, dynamic> m) => PnStudentRow(
        id: pnS(m['id']),
        firstName: pnS(m['first_name']),
        lastName: pnS(m['last_name']),
        admissionNumber: pnSn(m['admission_number']),
        gender: pnSn(m['gender']),
        dateOfBirth: pnDt(m['date_of_birth']),
        photo: pnSn(m['student_photo_url']),
        status: pnS(m['status']),
        classId: pnSn(m['class_id']),
        className: pnSn(m['class_name']),
      );

  String get fullName => '$firstName $lastName'.trim();
}

class PnStudentPage {
  final int total;
  final List<PnStudentRow> rows;
  const PnStudentPage({required this.total, required this.rows});
}

// ============================================================ money

class PnTeacherPay {
  final String teacherId;
  final String name;
  final String? phone;
  final String? photo;
  final String payType; // monthly | hourly | manual
  final double monthlyAmount;
  final double hourlyRate;
  final double weeksPerMonth;
  final String? notes;
  final int weeklyPeriods;
  final double paidMonth;
  final double paidOtherMonth;
  final DateTime? lastPaid;
  const PnTeacherPay({
    required this.teacherId,
    required this.name,
    this.phone,
    this.photo,
    required this.payType,
    required this.monthlyAmount,
    required this.hourlyRate,
    required this.weeksPerMonth,
    this.notes,
    required this.weeklyPeriods,
    required this.paidMonth,
    required this.paidOtherMonth,
    this.lastPaid,
  });

  factory PnTeacherPay.fromMap(Map<String, dynamic> m) => PnTeacherPay(
        teacherId: pnS(m['teacher_id']),
        name: pnS(m['name']),
        phone: pnSn(m['phone']),
        photo: pnSn(m['photo']),
        payType: pnS(m['pay_type']).isEmpty ? 'manual' : pnS(m['pay_type']),
        monthlyAmount: pnD(m['monthly_amount']),
        hourlyRate: pnD(m['hourly_rate']),
        weeksPerMonth: pnD(m['weeks_per_month']) <= 0 ? 4 : pnD(m['weeks_per_month']),
        notes: pnSn(m['notes']),
        weeklyPeriods: pnI(m['weekly_periods']),
        paidMonth: pnD(m['paid_month']),
        paidOtherMonth: pnD(m['paid_other_month']),
        lastPaid: pnDt(m['last_paid']),
      );

  /// What this teacher should receive for one month under their profile.
  double get expected {
    switch (payType) {
      case 'monthly':
        return monthlyAmount;
      case 'hourly':
        return hourlyRate * weeklyPeriods * weeksPerMonth;
      default:
        return 0;
    }
  }

  double get balance => (expected - paidMonth) < 0 ? 0 : expected - paidMonth;
  bool get hasProfile => payType != 'manual';
}

class PnTeacherPayment {
  final String id;
  final String teacherId;
  final String teacher;
  final String kind;
  final double amount;
  final String method;
  final String? purpose;
  final String? paidTo;
  final DateTime? paidAt;
  final String? place;
  final String? reference;
  final String? notes;
  final DateTime? periodMonth;
  final bool needsReview;
  final String status;
  final String? voidReason;
  const PnTeacherPayment({
    required this.id,
    required this.teacherId,
    required this.teacher,
    required this.kind,
    required this.amount,
    required this.method,
    this.purpose,
    this.paidTo,
    this.paidAt,
    this.place,
    this.reference,
    this.notes,
    this.periodMonth,
    required this.needsReview,
    required this.status,
    this.voidReason,
  });

  factory PnTeacherPayment.fromMap(Map<String, dynamic> m) => PnTeacherPayment(
        id: pnS(m['id']),
        teacherId: pnS(m['teacher_id']),
        teacher: pnS(m['teacher']),
        kind: pnS(m['kind']),
        amount: pnD(m['amount']),
        method: pnS(m['method']),
        purpose: pnSn(m['purpose']),
        paidTo: pnSn(m['paid_to']),
        paidAt: pnDt(m['paid_at']),
        place: pnSn(m['place']),
        reference: pnSn(m['reference']),
        notes: pnSn(m['notes']),
        periodMonth: pnDt(m['period_month']),
        needsReview: pnB(m['needs_review']),
        status: pnS(m['status']),
        voidReason: pnSn(m['void_reason']),
      );

  bool get isVoided => status == 'voided';
}

class PnExpense {
  final String id;
  final String category;
  final String description;
  final double amount;
  final DateTime? date;
  final String method;
  final String? paidTo;
  final String? place;
  final String source;
  final bool needsReview;
  const PnExpense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    this.date,
    required this.method,
    this.paidTo,
    this.place,
    required this.source,
    required this.needsReview,
  });

  factory PnExpense.fromMap(Map<String, dynamic> m) => PnExpense(
        id: pnS(m['id']),
        category: pnS(m['category']),
        description: pnS(m['description']),
        amount: pnD(m['amount']),
        date: pnDt(m['expense_date']),
        method: pnS(m['payment_method']),
        paidTo: pnSn(m['paid_to']),
        place: pnSn(m['place']),
        source: pnS(m['source']),
        needsReview: pnB(m['needs_review']),
      );
}

class PnCorrection {
  final String id;
  final double amount;
  final String method;
  final String type;
  final String status;
  final DateTime? paidAt;
  final DateTime? requestedAt;
  final String? reason;
  final String requestedBy;
  final String student;
  final String? admissionNumber;
  final String? className;
  final String? installment;
  final bool linkedAdmission;
  final String? reference;
  final String? resolution;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  const PnCorrection({
    required this.id,
    required this.amount,
    required this.method,
    required this.type,
    required this.status,
    this.paidAt,
    this.requestedAt,
    this.reason,
    required this.requestedBy,
    required this.student,
    this.admissionNumber,
    this.className,
    this.installment,
    required this.linkedAdmission,
    this.reference,
    this.resolution,
    this.resolvedAt,
    this.resolutionNote,
  });

  factory PnCorrection.fromMap(Map<String, dynamic> m) => PnCorrection(
        id: pnS(m['id']),
        amount: pnD(m['amount']),
        method: pnS(m['method']),
        type: pnS(m['type']),
        status: pnS(m['status']),
        paidAt: pnDt(m['paid_at']),
        requestedAt: pnDt(m['requested_at']),
        reason: pnSn(m['reason']),
        requestedBy: pnS(m['requested_by']),
        student: pnS(m['student']),
        admissionNumber: pnSn(m['admission_number']),
        className: pnSn(m['class']),
        installment: pnSn(m['installment']),
        linkedAdmission: pnB(m['linked_admission']),
        reference: pnSn(m['reference']),
        resolution: pnSn(m['resolution']),
        resolvedAt: pnDt(m['resolved_at']),
        resolutionNote: pnSn(m['resolution_note']),
      );

  bool get isResolved => resolvedAt != null;
}

class PnArrearsClass {
  final String classId;
  final String className;
  final int level;
  final int students;
  final double due;
  final double paid;
  final double overdue;
  final int debtors;
  const PnArrearsClass({
    required this.classId,
    required this.className,
    required this.level,
    required this.students,
    required this.due,
    required this.paid,
    required this.overdue,
    required this.debtors,
  });

  factory PnArrearsClass.fromMap(Map<String, dynamic> m) => PnArrearsClass(
        classId: pnS(m['class_id']),
        className: pnS(m['class']),
        level: pnI(m['level']),
        students: pnI(m['students']),
        due: pnD(m['due']),
        paid: pnD(m['paid']),
        overdue: pnD(m['overdue']),
        debtors: pnI(m['debtors']),
      );

  double get collectedRatio => due <= 0 ? 1 : (paid / due).clamp(0.0, 1.0).toDouble();
}

class PnArrearsRow {
  final String studentId;
  final String student;
  final String? admissionNumber;
  final String className;
  final double due;
  final double paid;
  final double overdue;
  final DateTime? lastPaid;
  const PnArrearsRow({
    required this.studentId,
    required this.student,
    this.admissionNumber,
    required this.className,
    required this.due,
    required this.paid,
    required this.overdue,
    this.lastPaid,
  });

  factory PnArrearsRow.fromMap(Map<String, dynamic> m) => PnArrearsRow(
        studentId: pnS(m['student_id']),
        student: pnS(m['student']),
        admissionNumber: pnSn(m['admission_number']),
        className: pnS(m['class']),
        due: pnD(m['due']),
        paid: pnD(m['paid']),
        overdue: pnD(m['overdue']),
        lastPaid: pnDt(m['last_paid']),
      );
}

class PnArrears {
  final List<PnArrearsClass> byClass;
  final int total;
  final List<PnArrearsRow> rows;
  const PnArrears({required this.byClass, required this.total, required this.rows});

  factory PnArrears.fromMap(Map<String, dynamic> m) => PnArrears(
        byClass: pnList(m['by_class']).map(PnArrearsClass.fromMap).toList(),
        total: pnI(m['total']),
        rows: pnList(m['rows']).map(PnArrearsRow.fromMap).toList(),
      );
}

// ============================================================ marks tracker

class PnTrackerRow {
  final String teacher;
  final String? phone;
  final String className;
  final String subject;
  final int expected;
  final int draft;
  final int submitted;
  final int approved;
  final int rejected;
  final double progress;
  const PnTrackerRow({
    required this.teacher,
    this.phone,
    required this.className,
    required this.subject,
    required this.expected,
    required this.draft,
    required this.submitted,
    required this.approved,
    required this.rejected,
    required this.progress,
  });

  factory PnTrackerRow.fromMap(Map<String, dynamic> m) => PnTrackerRow(
        teacher: pnS(m['teacher']),
        phone: pnSn(m['phone']),
        className: pnS(m['class']),
        subject: pnS(m['subject']),
        expected: pnI(m['expected']),
        draft: pnI(m['draft']),
        submitted: pnI(m['submitted']),
        approved: pnI(m['approved']),
        rejected: pnI(m['rejected']),
        progress: pnD(m['progress']),
      );

  bool get complete => expected > 0 && progress >= 1;
}

// ============================================================ settings

class PnSettings {
  final double passMark;
  final double margin;
  final double threshold;
  final bool balance;
  const PnSettings({required this.passMark, required this.margin, required this.threshold, required this.balance});

  static const defaults = PnSettings(passMark: 10, margin: 1, threshold: 200000, balance: true);

  factory PnSettings.fromMap(Map<String, dynamic> m) => PnSettings(
        passMark: pnD(m['pass_mark']),
        margin: pnD(m['borderline_margin']),
        threshold: pnD(m['payment_approval_threshold']),
        balance: m['balance_classes'] != false,
      );
}

/// A sequence option for pickers (any year).
class PnPeriodOption {
  final String id;
  final String name;
  final String termId;
  final String termName;
  final int order;
  const PnPeriodOption({required this.id, required this.name, required this.termId, required this.termName, required this.order});
}
