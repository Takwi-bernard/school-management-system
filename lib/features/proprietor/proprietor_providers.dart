import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_providers.dart';
import '../landing/landing_providers.dart' show activeLocaleProvider;
import 'proprietor_models.dart';
import 'proprietor_repository.dart';

/// Rebuilt when the language changes, so AI answers come back in the
/// language the proprietor is currently reading.
final proprietorRepositoryProvider = Provider<ProprietorRepository>((ref) {
  final locale = ref.watch(activeLocaleProvider);
  return ProprietorRepository(
    ref.watch(supabaseClientProvider),
    lang: locale.languageCode == 'fr' ? 'fr' : 'en',
  );
});

/// Bumped whenever live data changes. Paginated ledgers watch it and
/// reload from the first page; aggregates are invalidated directly.
final proprietorTickProvider = StateProvider<int>((ref) => 0);

final proprietorProfileProvider = FutureProvider<ProprietorProfile?>((ref) {
  return ref.watch(proprietorRepositoryProvider).getProfile();
});

/// Keyed by the number of months of history requested.
final financeProvider = FutureProvider.family<FinanceSummary, int>((ref, months) {
  return ref.watch(proprietorRepositoryProvider).getFinance(months: months);
});

final schoolStatsProvider = FutureProvider<SchoolStats>((ref) {
  return ref.watch(proprietorRepositoryProvider).getSchoolStats();
});

final budgetsProvider = FutureProvider.family<List<ExpenseBudget>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getBudgets(schoolId);
});

final latestReportProvider = FutureProvider.family<AiSchoolReport?, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getLatestReport(schoolId);
});

final reportHistoryProvider = FutureProvider.family<List<AiSchoolReport>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getReportHistory(schoolId);
});

/// One realtime channel per school. Changes are coalesced (800 ms) so a
/// burst of inserts causes one refresh, not twenty.
final proprietorRealtimeProvider = Provider.family<void, String>((ref, schoolId) {
  final client = ref.watch(supabaseClientProvider);
  Timer? debounce;

  void refreshAll() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 800), () {
      ref.invalidate(financeProvider);
      ref.invalidate(schoolStatsProvider);
      ref.invalidate(budgetsProvider(schoolId));
      ref.read(proprietorTickProvider.notifier).state++;
    });
  }

  PostgresChangeFilter f() => PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'school_id', value: schoolId);

  var channel = client.channel('proprietor-live-$schoolId');
  for (final table in const ['payments', 'expenses', 'expense_budgets', 'students', 'class_enrollments', 'admission_requests', 'teachers']) {
    channel = channel.onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: table, filter: f(), callback: (_) => refreshAll());
  }
  channel.subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });
});