import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_providers.dart';
import 'principal_hub_models.dart';
import 'principal_hub_repository.dart';

final principalHubRepositoryProvider = Provider<PrincipalHubRepository>((ref) {
  return PrincipalHubRepository(ref.watch(supabaseClientProvider));
});

/// Bumped whenever live data changes; paged lists watch it and reload.
final pnTickProvider = StateProvider<int>((ref) => 0);

final pnOverviewProvider = FutureProvider<PnOverview>((ref) {
  return ref.watch(principalHubRepositoryProvider).getOverview();
});

final pnCalendarProvider = FutureProvider<List<PnYear>>((ref) {
  return ref.watch(principalHubRepositoryProvider).getCalendar();
});

final pnClassesProvider = FutureProvider.family<List<PnClass>, String>((ref, schoolId) {
  return ref.watch(principalHubRepositoryProvider).getClasses(schoolId);
});

final pnSettingsProvider = FutureProvider.family<PnSettings, String>((ref, schoolId) {
  return ref.watch(principalHubRepositoryProvider).getSettings(schoolId);
});

typedef PnBoardKey = ({String classId, String scope, String yearId, String? termId, String? periodId});

final pnBoardProvider = FutureProvider.family<PnBoard, PnBoardKey>((ref, k) {
  return ref.watch(principalHubRepositoryProvider).getBoard(
        classId: k.classId,
        scope: k.scope,
        yearId: k.yearId,
        termId: k.termId,
        periodId: k.periodId,
      );
});

final pnPromotionHistoryProvider = FutureProvider<List<PnPromotionRun>>((ref) {
  return ref.watch(principalHubRepositoryProvider).getPromotionHistory();
});

typedef PnPayKey = ({String yearId, int year, int month});

final pnTeacherPayProvider = FutureProvider.family<List<PnTeacherPay>, PnPayKey>((ref, k) {
  return ref.watch(principalHubRepositoryProvider).getTeacherPay(yearId: k.yearId, month: DateTime(k.year, k.month, 1));
});

final pnCorrectionsProvider = FutureProvider.family<List<PnCorrection>, bool>((ref, includeResolved) {
  return ref.watch(principalHubRepositoryProvider).getCorrections(includeResolved: includeResolved);
});

typedef PnArrearsKey = ({String yearId, String? classId});

final pnArrearsProvider = FutureProvider.family<PnArrears, PnArrearsKey>((ref, k) {
  return ref.watch(principalHubRepositoryProvider).getArrears(yearId: k.yearId, classId: k.classId);
});

final pnTrackerProvider = FutureProvider.family<List<PnTrackerRow>, String>((ref, periodId) {
  return ref.watch(principalHubRepositoryProvider).getMarksTracker(periodId);
});

final pnReviewSummaryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, periodId) {
  return ref.watch(principalHubRepositoryProvider).getMarksReviewSummary(periodId);
});

/// One realtime channel for the whole Principal shell. Bursts of changes
/// are coalesced (800 ms) into a single refresh of the live numbers.
final pnRealtimeProvider = Provider.family<void, String>((ref, schoolId) {
  final client = ref.watch(supabaseClientProvider);
  Timer? debounce;

  void refresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 800), () {
      ref.invalidate(pnOverviewProvider);
      ref.invalidate(pnCorrectionsProvider);
      ref.invalidate(pnTeacherPayProvider);
      ref.invalidate(pnArrearsProvider);
      ref.invalidate(pnTrackerProvider);
      ref.read(pnTickProvider.notifier).state++;
    });
  }

  PostgresChangeFilter f() => PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'school_id', value: schoolId);

  var channel = client.channel('principal-live-$schoolId');
  for (final table in const [
    'payments',
    'marks',
    'class_comments',
    'admission_requests',
    'teachers',
    'report_cards',
    'teacher_payments',
    'expenses',
    'class_enrollments',
    'exam_periods',
  ]) {
    channel = channel.onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: table, filter: f(), callback: (_) => refresh());
  }
  channel.subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });
});
