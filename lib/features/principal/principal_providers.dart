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