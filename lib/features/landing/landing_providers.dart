import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_providers.dart';
import '../../core/web_prefs.dart';
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

const _prefLocale = 'pref_locale';
const _prefLanguageMode = 'pref_language_mode';

/// User's explicit language choice, if they've toggled it (bilingual
/// schools only). null means "use the school's default language" -
/// see activeLocaleProvider below.
///
/// The choice is remembered in the browser. That matters because a
/// Google sign-in leaves the app and comes back with a full page load,
/// which would otherwise forget the chosen language and show the
/// default one until the dashboard loaded.
final localeOverrideProvider = StateProvider<Locale?>((ref) {
  final saved = webPrefGet(_prefLocale);
  if (saved == 'fr' || saved == 'en') return Locale(saved!);
  return null;
});

/// The landing page always fetches in English first (a reasonable
/// default while we don't yet know the school), then re-fetches once
/// the active locale is known to be French. See landingProvider below.
final landingProvider = FutureProvider<LandingModel>((ref) async {
  final locale = ref.watch(activeLocaleProvider);
  final repository = ref.watch(landingRepositoryProvider);
  final model = await repository.load(language: locale.languageCode);

  // Remember the school's default language as soon as we know it - here,
  // not only when the landing page is on screen. Otherwise opening or
  // reloading /sign-in or /teacher directly would show a French-only
  // school in English, because the landing page never ran.
  try {
    final notifier = ref.read(_lastKnownLanguageModeProvider.notifier);
    if (notifier.state != model.languageMode) {
      notifier.state = model.languageMode;
    }
    webPrefSet(_prefLanguageMode, model.languageMode);
    // A saved choice only makes sense for a bilingual school; if the
    // school is now single-language, forget it.
    if (model.languageMode != 'bilingual' && ref.read(localeOverrideProvider) != null) {
      ref.read(localeOverrideProvider.notifier).state = null;
    }
  } catch (_) {
    // The provider was already rebuilt/disposed while loading (for
    // example the language was toggled) - nothing to record.
  }

  return model;
});

/// FIX: previously hardcoded to Locale('en') regardless of the school's
/// own language_mode - a French-only school would show an English
/// interface on first load. This derives the default from the school
/// itself, falling back to English only while the school is still
/// loading (unavoidable - we don't know the school's language before
/// the first request resolves the tenant).
final activeLocaleProvider = Provider<Locale>((ref) {
  // Keep the browser copy of the choice in step with it.
  ref.listen<Locale?>(localeOverrideProvider, (previous, next) {
    if (next == null) {
      webPrefRemove(_prefLocale);
    } else {
      webPrefSet(_prefLocale, next.languageCode);
    }
  });

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
final _lastKnownLanguageModeProvider = StateProvider<String?>((ref) => webPrefGet(_prefLanguageMode));

void recordSchoolLanguageMode(WidgetRef ref, String languageMode) {
  final notifier = ref.read(_lastKnownLanguageModeProvider.notifier);
  if (notifier.state != languageMode) {
    notifier.state = languageMode;
  }
  webPrefSet(_prefLanguageMode, languageMode);
}