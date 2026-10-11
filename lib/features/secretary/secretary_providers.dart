import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_providers.dart';
import '../landing/landing_providers.dart' show activeLocaleProvider;
import 'secretary_models.dart';
import 'secretary_repository.dart';

/// Rebuilt whenever the active language changes, so every Edge Function
/// call carries the language the secretary is currently reading.
final secretaryRepositoryProvider = Provider<SecretaryRepository>((ref) {
  final locale = ref.watch(activeLocaleProvider);
  return SecretaryRepository(
    ref.watch(supabaseClientProvider),
    lang: locale.languageCode == 'fr' ? 'fr' : 'en',
  );
});

final secretaryProfileProvider = FutureProvider<SecretaryProfile?>((ref) {
  return ref.watch(secretaryRepositoryProvider).getProfile();
});

final enrollClassesProvider = FutureProvider.family<List<EnrollClass>, String>((ref, schoolId) {
  return ref.watch(secretaryRepositoryProvider).getClasses(schoolId);
});

// schoolId is only a cache key here - the Edge Function derives the
// real school from the signed-in user.
final awaitingRegistrationsProvider = FutureProvider.family<List<AwaitingRegistration>, String>((ref, schoolId) {
  return ref.watch(secretaryRepositoryProvider).listAwaitingRegistrations();
});

final secretaryDashboardProvider = FutureProvider.family<SecretaryDashboard, String>((ref, schoolId) {
  return ref.watch(secretaryRepositoryProvider).getDashboard();
});

final myPaymentsProvider = FutureProvider.family<List<MyPayment>, String>((ref, schoolId) {
  return ref.watch(secretaryRepositoryProvider).listMyPayments();
});