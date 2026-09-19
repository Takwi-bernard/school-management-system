import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_providers.dart';
import 'principal_models.dart';
import 'principal_repository.dart';

final principalRepositoryProvider = Provider<PrincipalRepository>((ref) {
  return PrincipalRepository(ref.watch(supabaseClientProvider));
});

final principalProfileProvider = FutureProvider<PrincipalProfile?>((ref) {
  return ref.watch(principalRepositoryProvider).getProfile();
});

final departmentsProvider = FutureProvider.family<List<DepartmentOption>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getDepartments(schoolId);
});

final managedClassesProvider = FutureProvider.family<List<ManagedClass>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getClasses(schoolId);
});

final managedSubjectsProvider = FutureProvider.family<List<ManagedSubject>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getSubjects(schoolId);
});

final subjectOfferingsForClassProvider =
    FutureProvider.family<List<SubjectOfferingRow>, ({String schoolId, String classId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getSubjectOfferingsForClass(params.schoolId, params.classId);
});

final feeConfigProvider =
    FutureProvider.family<ManagedFeeConfig, ({String classId, String academicYearId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getFeeConfig(classId: params.classId, academicYearId: params.academicYearId);
});

final principalCurrentAcademicYearIdProvider = FutureProvider.family<String?, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getCurrentAcademicYearId(schoolId);
});

final pendingTeachersProvider = FutureProvider.family<List<PendingTeacher>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getPendingTeachers(schoolId);
});

final approvedTeachersProvider = FutureProvider.family<List<ApprovedTeacher>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getApprovedTeachers(schoolId);
});

final teacherAssignmentsProvider =
    FutureProvider.family<List<TeacherAssignmentInfo>, ({String teacherId, String academicYearId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getAssignmentsForTeacher(params.teacherId, params.academicYearId);
});

final examPeriodsProvider = FutureProvider.family<List<ExamPeriodOption>, String>((ref, academicYearId) {
  return ref.watch(principalRepositoryProvider).getExamPeriods(academicYearId);
});

final submittedMarksProvider = FutureProvider.family<List<SubmittedMark>, String>((ref, examPeriodId) {
  return ref.watch(principalRepositoryProvider).getSubmittedMarks(examPeriodId: examPeriodId);
});

final reportCardStatusProvider = FutureProvider.family<List<ReportCardStatus>, ({String classId, String termId, String academicYearId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getReportCardStatusForClass(
        classId: params.classId, termId: params.termId, academicYearId: params.academicYearId,
      );
});

final principalTermsForYearProvider = FutureProvider.family<List<AcademicTermOption>, String>((ref, academicYearId) {
  return ref.watch(principalRepositoryProvider).getTermsForYear(academicYearId);
});

final departmentsFullProvider = FutureProvider.family<List<DepartmentFull>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getDepartmentsFull(schoolId);
});

final subjectsForDepartmentProvider = FutureProvider.family<List<SubjectWithCoefficient>, String>((ref, departmentId) {
  return ref.watch(principalRepositoryProvider).getSubjectsForDepartment(departmentId);
});

final subjectBrowseListProvider =
    FutureProvider.family<List<SubjectBrowseItem>, ({String schoolId, String academicYearId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getSubjectBrowseList(params.schoolId, params.academicYearId);
});

final allTeachersProvider = FutureProvider.family<List<AllTeacherProfile>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getAllTeachers(schoolId);
});

final teacherOverviewProvider = FutureProvider.family<List<TeacherOverviewInfo>, ({String schoolId, String academicYearId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getTeacherOverview(params.schoolId, params.academicYearId);
});

final classesWithSubmittedMarksProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, examPeriodId) {
  return ref.watch(principalRepositoryProvider).getClassesWithSubmittedMarks(examPeriodId);
});

final subjectsWithSubmittedMarksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, ({String examPeriodId, String classId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getSubjectsWithSubmittedMarks(params.examPeriodId, params.classId);
});

final marksForClassSubjectProvider =
    FutureProvider.family<List<SubmittedMark>, ({String examPeriodId, String classId, String subjectId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getMarksForClassSubject(
        examPeriodId: params.examPeriodId, classId: params.classId, subjectId: params.subjectId,
      );
});
final pendingCommentsProvider = FutureProvider.family<List<PendingComment>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getPendingComments(schoolId);
});

final departmentsWithMarksProvider = FutureProvider.family<List<DepartmentFull>, ({String schoolId, String termId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getDepartmentsWithMarksForTerm(params.schoolId, params.termId);
});

final classesWithMarksForDeptProvider =
    FutureProvider.family<List<ManagedClass>, ({String schoolId, String termId, String departmentId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getClassesWithMarksForTerm(params.schoolId, params.termId, params.departmentId);
});

final generatedReportCardsProvider =
    FutureProvider.family<List<ReportCardStatus>, ({String classId, String termId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getGeneratedReportCards(params.classId, params.termId);
});

final admissionsForReviewProvider = FutureProvider.family<List<PendingAdmissionReview>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getAdmissionsForReview(schoolId);
});

final allStudentsProvider = FutureProvider.family<List<SchoolStudent>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getAllStudents(schoolId);
});

final departmentsWithPendingAdmissionsProvider = FutureProvider.family<List<DepartmentFull>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getDepartmentsWithPendingAdmissions(schoolId);
});

final classesWithPendingAdmissionsProvider =
    FutureProvider.family<List<ManagedClass>, ({String schoolId, String departmentId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getClassesWithPendingAdmissions(params.schoolId, params.departmentId);
});

final admissionsForClassProvider = FutureProvider.family<List<PendingAdmissionReview>, ({String schoolId, String classId})>((ref, params) {
  return ref.watch(principalRepositoryProvider).getAdmissionsForClass(params.schoolId, params.classId);
});

final studentDetailProvider = FutureProvider.family<StudentDetail, String>((ref, studentId) {
  return ref.watch(principalRepositoryProvider).getStudentDetail(studentId);
});

final studentsForClassProvider = FutureProvider.family<List<SchoolStudent>, String>((ref, classId) {
  return ref.watch(principalRepositoryProvider).getStudentsForClass(classId);
});

final generatedIdCardsForClassProvider = FutureProvider.family<List<IdCardGenerationRecord>, String>((ref, classId) {
  return ref.watch(principalRepositoryProvider).getGeneratedIdCardsForClass(classId);
});

final officialBrandingProvider = FutureProvider.family<Map<String, String>, String>((ref, schoolId) {
  return ref.watch(principalRepositoryProvider).getOfficialBranding(schoolId);
});

final generatedIdCardBatchesProvider = FutureProvider.family<List<IdCardBatch>, String>((ref, classId) {
  return ref.watch(principalRepositoryProvider).getGeneratedIdCardBatches(classId);
});

final departmentsWithMarksForPeriodProvider = FutureProvider.family<List<DepartmentFull>, ({String schoolId, String examPeriodId})>((ref, p) {
  return ref.watch(principalRepositoryProvider).getDepartmentsWithMarksForPeriod(p.schoolId, p.examPeriodId);
});

final classesWithMarksForPeriodProvider =
    FutureProvider.family<List<ManagedClass>, ({String schoolId, String examPeriodId, String departmentId})>((ref, p) {
  return ref.watch(principalRepositoryProvider).getClassesWithMarksForPeriod(p.schoolId, p.examPeriodId, p.departmentId);
});

final reportCardPdfDataProvider = FutureProvider.family<ReportCardPdfData, String>((ref, reportCardId) {
  return ref.watch(principalRepositoryProvider).getReportCardPdfData(reportCardId);
});