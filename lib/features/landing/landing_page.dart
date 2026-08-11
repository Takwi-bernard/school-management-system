import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import 'landing_providers.dart';
import 'landing_navbar.dart';
import 'landing_content.dart';
import 'landing_gallery.dart';
import 'landing_footer.dart';

class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);

    return landing.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Unable to load school website.\n$error')),
      ),
      data: (school) {
        // Once we know the school's real language_mode, this may trigger
        // a one-time re-fetch in French for French-only schools (see
        // landing_providers.dart for why the first request is always
        // made in English).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          recordSchoolLanguageMode(ref, school.languageMode);
        });

        final strings = AppStrings(locale);
        final canToggleLanguage = school.languageMode == 'bilingual';

        final schoolTheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _parseColor(school.primaryColor),
            primary: _parseColor(school.primaryColor),
            secondary: _parseColor(school.secondaryColor),
          ),
        );

        return Theme(
          data: schoolTheme,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  LandingNavbar(
                    school: school,
                    strings: strings,
                    locale: locale,
                    canToggleLanguage: canToggleLanguage,
                  ),
                  LandingContentSections(school: school, strings: strings),
                  LandingGallerySection(gallery: school.gallery, strings: strings),
                  LandingFooterSection(school: school, strings: strings),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF1A73E8);
  }
}