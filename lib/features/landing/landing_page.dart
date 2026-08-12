import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../auth/auth_gate.dart';
import 'landing_providers.dart';
import 'landing_navbar.dart';
import 'landing_content.dart';
import 'landing_gallery.dart';
import 'landing_footer.dart';

/// Keys every nav item can scroll to. Shared between the navbar and
/// the sections themselves so "Home" / "About" / etc. actually work.
class LandingSectionKeys {
  final home = GlobalKey();
  final about = GlobalKey();
  final achievements = GlobalKey();
  final gallery = GlobalKey();
  final admissions = GlobalKey();
  final contact = GlobalKey();
}

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  final _scrollController = ScrollController();
  final _sectionKeys = LandingSectionKeys();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  /// "Apply Now" / "Start Admission" logic:
  /// - not signed in -> parent sign-up (admission requires a parent account)
  /// - signed in as parent -> parent dashboard/admission portal
  /// - signed in as anything else -> not applicable, tell them so
  Future<void> _handleAdmissionCta(BuildContext context, String schoolId) async {
    final profile = await ref.read(sessionProfileProvider(schoolId).future);

    if (!context.mounted) return;

    if (profile == null) {
      context.push('/sign-up/parent');
      return;
    }

    if (profile.role == 'parent') {
      context.push('/parent');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admission is managed from a parent account.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);

    return landing.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Unable to load school website.\n$error')),
      ),
      data: (school) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          recordSchoolLanguageMode(ref, school.languageMode);
        });

        final strings = AppStrings(locale);
        final canToggleLanguage = school.languageMode == 'bilingual';
        final primary = _parseColor(school.primaryColor);
        final secondary = _parseColor(school.secondaryColor);

        final schoolTheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primary,
            primary: primary,
            secondary: secondary,
          ),
        );

        return Theme(
          data: schoolTheme,
          child: Scaffold(
            body: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      // Spacer so content starts below the floating navbar.
                      const SizedBox(height: 80),
                      KeyedSubtree(
                        key: _sectionKeys.home,
                        child: LandingContentSections(
                          school: school,
                          strings: strings,
                          aboutKey: _sectionKeys.about,
                          achievementsKey: _sectionKeys.achievements,
                          admissionsKey: _sectionKeys.admissions,
                          onLearnMore: () => _scrollTo(_sectionKeys.about),
                          onAdmissionCta: () => _handleAdmissionCta(context, school.schoolId),
                        ),
                      ),
                      KeyedSubtree(
                        key: _sectionKeys.gallery,
                        child: LandingGallerySection(
                          gallery: school.gallery,
                          strings: strings,
                        ),
                      ),
                      KeyedSubtree(
                        key: _sectionKeys.contact,
                        child: LandingFooterSection(school: school, strings: strings),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ScrollElevation(
                    controller: _scrollController,
                    builder: (context, elevated) => LandingNavbar(
                      school: school,
                      strings: strings,
                      locale: locale,
                      canToggleLanguage: canToggleLanguage,
                      elevated: elevated,
                      onNavHome: () => _scrollTo(_sectionKeys.home),
                      onNavAbout: () => _scrollTo(_sectionKeys.about),
                      onNavAchievements: () => _scrollTo(_sectionKeys.achievements),
                      onNavGallery: () => _scrollTo(_sectionKeys.gallery),
                      onNavAdmissions: () => _scrollTo(_sectionKeys.admissions),
                      onNavContact: () => _scrollTo(_sectionKeys.contact),
                    ),
                  ),
                ),
              ],
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