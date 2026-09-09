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