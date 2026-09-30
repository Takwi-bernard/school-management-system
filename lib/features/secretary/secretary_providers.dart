import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_providers.dart';
import 'secretary_models.dart';
import 'secretary_repository.dart';

final secretaryRepositoryProvider = Provider<SecretaryRepository>((ref) {
  return SecretaryRepository(ref.watch(supabaseClientProvider));
});

final secretaryProfileProvider = FutureProvider<SecretaryProfile?>((ref) {
  return ref.watch(secretaryRepositoryProvider).getProfile();
});

final enrollClassesProvider = FutureProvider.family<List<EnrollClass>, String>((ref, schoolId) {
  return ref.watch(secretaryRepositoryProvider).getClasses(schoolId);
});

// schoolId is only a cache key here - the Edge Function derives the real
// school from the signed-in user.
final awaitingRegistrationsProvider = FutureProvider.family<List<AwaitingRegistration>, String>((ref, schoolId) {
  return ref.watch(secretaryRepositoryProvider).listAwaitingRegistrations();
});