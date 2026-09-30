import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_providers.dart';
import '../auth/auth_gate.dart' show authStateChangesProvider;
import 'parent_models.dart';
import 'parent_repository.dart';

/// The id of whoever is signed in right now (null when signed out).
/// parentProfileProvider (and everything below that derives from it)
/// depends on this, so cached data from a previous parent is dropped -
/// not shown - the moment a different person signs in on the same tab.
final parentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});

final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  return ParentRepository(ref.watch(supabaseClientProvider));
});

final parentProfileProvider = FutureProvider<ParentProfile?>((ref) {
  ref.watch(parentUserIdProvider);
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

final examPeriodsForYearProvider = FutureProvider.family<List<ExamPeriodOption>, String>((ref, academicYearId) {
  return ref.watch(parentRepositoryProvider).getExamPeriodsForYear(academicYearId);
});

/// Every selectable reporting period for the year, in order: each
/// term's sequences first (by sequence_order), then the term itself
/// as a whole - a school can publish either kind independently, so
/// both need to be real, separately-queryable options.
final reportPeriodsForYearProvider = FutureProvider.family<List<ReportPeriodOption>, String>((ref, academicYearId) async {
  final terms = await ref.watch(termsForYearProvider(academicYearId).future);
  final periods = await ref.watch(examPeriodsForYearProvider(academicYearId).future);

  final options = <ReportPeriodOption>[];
  for (final term in terms) {
    final sequences = periods.where((p) => p.academicTermId == term.id).toList()
      ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    for (final s in sequences) {
      options.add(ReportPeriodOption(
        scope: 'sequence',
        termId: term.id,
        examPeriodId: s.id,
        label: '${term.termName} \u00b7 ${s.periodName}',
        sortKey: term.termOrder * 100 + s.sequenceOrder,
        isCurrentTerm: term.isCurrent,
      ));
    }
    options.add(ReportPeriodOption(
      scope: 'term',
      termId: term.id,
      label: '${term.termName} \u00b7 Full Term',
      sortKey: term.termOrder * 100 + 99,
      isCurrentTerm: term.isCurrent,
    ));
  }
  options.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  return options;
});

final reportCardProvider =
    FutureProvider.family<ReportCardSummary?, ({String studentId, String scope, String termId, String? examPeriodId})>((ref, params) {
  return ref.watch(parentRepositoryProvider).getReportCard(
        studentId: params.studentId,
        scope: params.scope,
        termId: params.termId,
        examPeriodId: params.examPeriodId,
      );
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

final officialBrandingProvider = FutureProvider.family<Map<String, String>, String>((ref, schoolId) {
  return ref.watch(parentRepositoryProvider).getOfficialBranding(schoolId);
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

/// The unfinished child capture from sign-up, if any - offered as a
/// "continue where you left off?" prompt at the start of enrollment.
final childDraftProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final profile = await ref.watch(parentProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(parentRepositoryProvider).getChildDraft(profile.parentId);
});