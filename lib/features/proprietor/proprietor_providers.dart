import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_providers.dart';
import 'proprietor_models.dart';
import 'proprietor_repository.dart';

final proprietorRepositoryProvider = Provider<ProprietorRepository>((ref) {
  return ProprietorRepository(ref.watch(supabaseClientProvider));
});

final proprietorProfileProvider = FutureProvider<ProprietorProfile?>((ref) {
  return ref.watch(proprietorRepositoryProvider).getProfile();
});

final schoolOverviewProvider = FutureProvider.family<SchoolOverview, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getOverview(schoolId);
});

final enrollmentByClassProvider = FutureProvider.family<List<ClassEnrollmentCount>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getEnrollmentByClass(schoolId);
});

final recentPaymentsProvider = FutureProvider.family<List<RecentPayment>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getRecentPayments(schoolId);
});