import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_providers.dart';
import 'parent_models.dart';
import 'parent_repository.dart';

final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  return ParentRepository(ref.watch(supabaseClientProvider));
});

final parentProfileProvider = FutureProvider<ParentProfile?>((ref) {
  return ref.watch(parentRepositoryProvider).getProfile();
});

final enrolledChildrenProvider = FutureProvider<List<EnrolledChild>>((ref) async {
  final profile = await ref.watch(parentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(parentRepositoryProvider).getEnrolledChildren(profile.parentId);
});

final pendingAdmissionsProvider = FutureProvider<List<PendingAdmission>>((ref) async {
  final profile = await ref.watch(parentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(parentRepositoryProvider).getPendingAdmissions(profile.parentId);
});

final availableClassesProvider = FutureProvider.family<List<ClassOption>, String>((ref, schoolId) {
  return ref.watch(parentRepositoryProvider).getAvailableClasses(schoolId);
});

final subjectOfferingsProvider = FutureProvider.family<List<SubjectOfferingOption>,
    ({String classId, String? departmentId})>((ref, params) {
  return ref
      .watch(parentRepositoryProvider)
      .getSubjectOfferings(classId: params.classId, departmentId: params.departmentId);
});

/// The CURRENT academic year's actual UUID for this school - needed
/// for admission_requests.academic_year_id, which is a foreign key,
/// not the "2025/2026" display string LandingModel exposes.
final currentAcademicYearIdProvider = FutureProvider.family<String?, String>((ref, schoolId) {
  return ref.watch(parentRepositoryProvider).getCurrentAcademicYearId(schoolId);
});

final childFeesProvider =
    FutureProvider.family<List<FeeSummary>, ({String studentId, String classId, String academicYearId})>(
  (ref, params) {
    return ref.watch(parentRepositoryProvider).getChildFees(
          studentId: params.studentId,
          classId: params.classId,
          academicYearId: params.academicYearId,
        );
  },
);

final registrationFeeProvider =
    FutureProvider.family<double?, ({String classId, String academicYearId})>((ref, params) {
  return ref
      .watch(parentRepositoryProvider)
      .getRegistrationFee(classId: params.classId, academicYearId: params.academicYearId);
});

final paymentHistoryProvider = FutureProvider<List<PaymentTransaction>>((ref) async {
  final profile = await ref.watch(parentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(parentRepositoryProvider).getPaymentHistory(profile.parentId);
});

final termsForYearProvider = FutureProvider.family<List<AcademicTermOption>, String>((ref, academicYearId) {
  return ref.watch(parentRepositoryProvider).getTermsForYear(academicYearId);
});

final reportCardProvider = FutureProvider.family<ReportCardSummary?, ({String studentId, String termId})>((ref, params) {
  return ref.watch(parentRepositoryProvider).getReportCard(studentId: params.studentId, termId: params.termId);
});

final attendanceSummaryProvider =
    FutureProvider.family<AttendanceSummary, ({String studentId, String academicYearId})>((ref, params) {
  return ref
      .watch(parentRepositoryProvider)
      .getAttendanceSummary(studentId: params.studentId, academicYearId: params.academicYearId);
});

final approvedCommentsProvider = FutureProvider.family<List<TeacherComment>, String>((ref, studentId) {
  return ref.watch(parentRepositoryProvider).getApprovedComments(studentId);
});

class ParentProfileActions {
  ParentProfileActions(this._ref);
  final Ref _ref;

  Future<void> updateProfile({required String fullName, required String phone}) async {
    final profile = await _ref.read(parentProfileProvider.future);
    if (profile == null) throw Exception('Profile not found.');
    await _ref.read(parentRepositoryProvider).updateProfile(parentId: profile.parentId, fullName: fullName, phone: phone);
    _ref.invalidate(parentProfileProvider);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final profile = await _ref.read(parentProfileProvider.future);
    if (profile == null || profile.email == null) throw Exception('Profile not found.');
    await _ref.read(parentRepositoryProvider).changePassword(
          email: profile.email!,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }
}

final parentProfileActionsProvider = Provider<ParentProfileActions>((ref) => ParentProfileActions(ref));