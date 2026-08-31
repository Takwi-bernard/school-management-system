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

final childFeesProvider = FutureProvider.family<List<FeeSummary>, ({String studentId, String academicYearId})>(
  (ref, params) {
    return ref
        .watch(parentRepositoryProvider)
        .getChildFees(studentId: params.studentId, academicYearId: params.academicYearId);
  },
);

final paymentHistoryProvider = FutureProvider<List<PaymentTransaction>>((ref) async {
  final profile = await ref.watch(parentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(parentRepositoryProvider).getPaymentHistory(profile.parentId);
});