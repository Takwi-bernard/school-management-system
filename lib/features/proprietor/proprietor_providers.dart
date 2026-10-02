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

final schoolSnapshotProvider = FutureProvider.family<SchoolSnapshot, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getSnapshot(schoolId);
});

final financialOverviewProvider = FutureProvider.family<FinancialOverview, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getFinancialOverview(schoolId);
});

final incomeHistoryProvider = FutureProvider.family<List<IncomeRecord>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getIncomeHistory(schoolId);
});

final expensesProvider = FutureProvider.family<List<ExpenseRecord>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getExpenses(schoolId);
});

final enrollmentByClassProvider = FutureProvider.family<List<ClassEnrollmentCount>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getEnrollmentByClass(schoolId);
});

final growthByYearProvider = FutureProvider.family<List<YearGrowthPoint>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getGrowthByYear(schoolId);
});

final activeActorsProvider = FutureProvider.family<ActiveActors, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getActiveActors(schoolId);
});