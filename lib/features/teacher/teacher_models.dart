/// All Teacher module data models in one file (matches the
/// consolidation pattern already used for Landing/Auth).

class TeacherProfile {
  final String teacherId; // teachers.id (profile row, not auth uid)
  final String userId;
  final String schoolId;
  final String fullName;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String employmentType; // may be null in DB, defaulted here
  final String approvalStatus; // 'pending' | 'approved' | 'rejected'

  const TeacherProfile({
    required this.teacherId,
    required this.userId,
    required this.schoolId,
    required this.fullName,
    this.phone,
    this.email,
    this.photoUrl,
    this.employmentType = 'full_time',
    required this.approvalStatus,
  });

  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected';

  TeacherProfile copyWith({String? fullName, String? phone, String? photoUrl}) {
    return TeacherProfile(
      teacherId: teacherId,
      userId: userId,
      schoolId: schoolId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      employmentType: employmentType,
      approvalStatus: approvalStatus,
    );
  }

  factory TeacherProfile.fromMap(Map<String, dynamic> map) {
    final user = map['users'] as Map<String, dynamic>?;
    return TeacherProfile(
      teacherId: map['id'] as String,
      userId: map['user_id'] as String,
      schoolId: map['school_id'] as String,
      fullName: map['full_name'] as String? ?? '',
      phone: map['phone'] as String?,
      email: user?['email'] as String?,
      photoUrl: map['photo_url'] as String?,
      employmentType: map['employment_type'] as String? ?? 'full_time',
      approvalStatus: map['approval_status'] as String? ?? 'pending',
    );
  }
}

/// One subject+class the Principal has assigned to this teacher.
/// coefficient is resolved via subject_departments (NOT a column on
/// teacher_assignments - that table has no such column).
class TeachingAssignment {
  final String id;
  final String subjectId;
  final String subjectName;
  final String classId;
  final String className;
  final String academicYearId;
  final int periodsPerWeek;
  final int coefficient;

  const TeachingAssignment({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.classId,
    required this.className,
    required this.academicYearId,
    required this.periodsPerWeek,
    required this.coefficient,
  });

  factory TeachingAssignment.fromMap(Map<String, dynamic> map) {
    final subject = map['subjects'] as Map<String, dynamic>?;
    final klass = map['classes'] as Map<String, dynamic>?;
    // subject_departments is fetched separately and merged in the
    // repository (see _resolveCoefficients) since it needs the
    // class's department_id, not directly joinable in one hop.
    return TeachingAssignment(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      subjectName: subject?['subject_name'] as String? ?? '',
      classId: map['class_id'] as String,
      className: klass?['class_name'] as String? ?? '',
      academicYearId: map['academic_year_id'] as String,
      periodsPerWeek: (map['periods_per_week'] as num?)?.toInt() ?? 0,
      coefficient: (map['_coefficient'] as num?)?.toInt() ?? 1,
    );
  }
}

class RosterStudent {
  final String studentId;
  final String admissionNumber;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String gender;

  const RosterStudent({
    required this.studentId,
    required this.admissionNumber,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    required this.gender,
  });

  String get fullName => '$firstName $lastName';

  factory RosterStudent.fromMap(Map<String, dynamic> map) {
    final student = map['students'] as Map<String, dynamic>? ?? map;
    return RosterStudent(
      studentId: student['id'] as String,
      admissionNumber: student['admission_number'] as String? ?? '',
      firstName: student['first_name'] as String? ?? '',
      lastName: student['last_name'] as String? ?? '',
      photoUrl: student['photo_url'] as String?,
      gender: student['gender'] as String? ?? '',
    );
  }
}

/// Mirrors mark_status exactly: draft/submitted/approved/rejected.
/// There is no 'confirmed' or 'published' mark status - "published"
/// is a report_cards concept, not a per-mark one.
class MarkEntry {
  final String? id;
  final String studentId;
  final String subjectId;
  final String classId;
  final String examPeriodId;
  final double score;
  final String status;
  final String? remarks;

  const MarkEntry({
    this.id,
    required this.studentId,
    required this.subjectId,
    required this.classId,
    required this.examPeriodId,
    required this.score,
    this.status = 'draft',
    this.remarks,
  });

  factory MarkEntry.fromMap(Map<String, dynamic> map) {
    return MarkEntry(
      id: map['id'] as String?,
      studentId: map['student_id'] as String,
      subjectId: map['subject_id'] as String,
      classId: map['class_id'] as String,
      examPeriodId: map['exam_period_id'] as String,
      score: (map['score'] as num).toDouble(),
      status: map['status'] as String? ?? 'draft',
      remarks: map['remarks'] as String?,
    );
  }
}

class ExamPeriod {
  final String id;
  final String name;
  final bool isOpen;
  final DateTime? dueDate;

  const ExamPeriod({
    required this.id,
    required this.name,
    required this.isOpen,
    this.dueDate,
  });

  factory ExamPeriod.fromMap(Map<String, dynamic> map) {
    return ExamPeriod(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      isOpen: map['is_open'] as bool? ?? false,
      dueDate: map['marks_due_date'] != null
          ? DateTime.tryParse(map['marks_due_date'] as String)
          : null,
    );
  }
}

class AttendanceEntry {
  final String studentId;
  final DateTime date;
  final String status; // present/absent/late/excused
  final String? remarks;

  const AttendanceEntry({
    required this.studentId,
    required this.date,
    required this.status,
    this.remarks,
  });
}

class TeacherTimetableEntry {
  final String id;
  final int dayOfWeek; // 1-7
  final String startTime;
  final String endTime;
  final String subjectName;
  final String className;
  final String? roomName;

  const TeacherTimetableEntry({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.className,
    this.roomName,
  });

  factory TeacherTimetableEntry.fromMap(Map<String, dynamic> map) {
    final assignment = map['teacher_assignments'] as Map<String, dynamic>?;
    final subject = assignment?['subjects'] as Map<String, dynamic>?;
    final klass = assignment?['classes'] as Map<String, dynamic>?;
    return TeacherTimetableEntry(
      id: map['id'] as String,
      dayOfWeek: (map['day_of_week'] as num).toInt(),
      startTime: (map['start_time'] as String).substring(0, 5),
      endTime: (map['end_time'] as String).substring(0, 5),
      subjectName: subject?['subject_name'] as String? ?? '',
      className: klass?['class_name'] as String? ?? '',
      roomName: map['room_name'] as String?,
    );
  }
}
