import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_providers.dart';
import 'landing_model.dart';
import 'landing_repository.dart';

final tenantResolverProvider = Provider<TenantResolver>((ref) {
  return TenantResolver(ref.watch(supabaseClientProvider));
});

final landingRepositoryProvider = Provider<LandingRepository>((ref) {
  return LandingRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(tenantResolverProvider),
  );
});

/// User's explicit language choice, if they've toggled it (bilingual
/// schools only). null means "use the school's default language" -
/// see activeLocaleProvider below.
final localeOverrideProvider = StateProvider<Locale?>((ref) => null);

/// The landing page always fetches in English first (a reasonable
/// default while we don't yet know the school), then re-fetches once
/// the active locale is known to be French. See landingProvider below.
final landingProvider = FutureProvider<LandingModel>((ref) async {
  final locale = ref.watch(activeLocaleProvider);
  final repository = ref.watch(landingRepositoryProvider);
  return repository.load(language: locale.languageCode);
});

/// FIX: previously hardcoded to Locale('en') regardless of the school's
/// own language_mode - a French-only school would show an English
/// interface on first load. This derives the default from the school
/// itself, falling back to English only while the school is still
/// loading (unavoidable - we don't know the school's language before
/// the first request resolves the tenant).
final activeLocaleProvider = Provider<Locale>((ref) {
  final override = ref.watch(localeOverrideProvider);
  if (override != null) return override;

  // Peek at whatever landing data we currently have (if any) without
  // creating a circular dependency - landingProvider itself reads
  // activeLocaleProvider, so on the very first load this is null and
  // we fall back to 'en' for that single request.
  final current = ref.watch(_lastKnownLanguageModeProvider);
  return current == 'french' ? const Locale('fr') : const Locale('en');
});

/// Set by the landing page once school data arrives, so subsequent
/// rebuilds (e.g. after a manual refresh) know the school's language
/// without re-deriving it from scratch. Kept private/internal.
final _lastKnownLanguageModeProvider = StateProvider<String?>((ref) => null);

void recordSchoolLanguageMode(WidgetRef ref, String languageMode) {
  final notifier = ref.read(_lastKnownLanguageModeProvider.notifier);
  if (notifier.state != languageMode) {
    notifier.state = languageMode;
  }
}