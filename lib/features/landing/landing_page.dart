import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser_chrome.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/school_color.dart';
import '../auth/auth_gate.dart';
import 'landing_content.dart';
import 'landing_footer.dart';
import 'landing_gallery.dart';
import 'landing_navbar.dart';
import 'landing_providers.dart';
import 'landing_text.dart';

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
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.hasClients && _scrollController.offset > 700;
      if (show != _showTop && mounted) setState(() => _showTop = show);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
  }

  void _toTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
  }

  /// "Apply Now" / "Start Admission":
  /// - not signed in -> parent sign-up (admission needs a parent account)
  /// - signed in as parent -> parent dashboard
  /// - anyone else -> not applicable, say so
  Future<void> _handleAdmissionCta(BuildContext context, String schoolId, LandingText text) async {
    final profile = await ref.read(sessionProfileProvider(schoolId).future);
    if (!context.mounted) return;

    if (profile == null) {
      context.go('/sign-up/parent');
      return;
    }
    if (profile.role == 'parent') {
      context.go('/parent');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.parentOnly)));
  }

  static String? _routeForRole(String role) => switch (role) {
        'parent' => '/parent',
        'teacher' => '/teacher',
        'principal' => '/principal',
        'secretary' => '/secretary',
        'proprietor' => '/proprietor',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);
    final fr = locale.languageCode == 'fr';

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(LandingText(fr).loadFailed, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => ref.invalidate(landingProvider), child: Text(LandingText(fr).retry)),
            ]),
          ),
        ),
      ),
      data: (school) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          recordSchoolLanguageMode(ref, school.languageMode);
        });

        // A user who is already signed in (or has just come back from
        // Google) goes straight to their dashboard.
        redirectIfSignedIn(ref, context, school.schoolId, _routeForRole);

        final strings = AppStrings(locale);
        final text = LandingText(strings.isFrench);
        final canToggleLanguage = school.languageMode == 'bilingual';
        final primary = parseSchoolColor(school.primaryColor, debugLabel: 'LandingPage primary');
        final secondary = parseSchoolColor(school.secondaryColor, debugLabel: 'LandingPage secondary');
        updateBrowserChromeColor(primary);

        final schoolTheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary),
          snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        );

        final links = <(String, VoidCallback)>[
          (strings.home, () => _scrollTo(_sectionKeys.home)),
          (strings.about, () => _scrollTo(_sectionKeys.about)),
          if (school.achievements.isNotEmpty) (strings.achievements, () => _scrollTo(_sectionKeys.achievements)),
          if (school.gallery.isNotEmpty) (strings.gallery, () => _scrollTo(_sectionKeys.gallery)),
          (strings.admissions, () => _scrollTo(_sectionKeys.admissions)),
          (strings.contact, () => _scrollTo(_sectionKeys.contact)),
        ];

        return Theme(
          data: schoolTheme,
          child: Scaffold(
            body: Stack(children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(children: [
                  // The hero starts at the very top; the navbar floats over it.
                  KeyedSubtree(
                    key: _sectionKeys.home,
                    child: LandingContentSections(
                      school: school,
                      strings: strings,
                      aboutKey: _sectionKeys.about,
                      achievementsKey: _sectionKeys.achievements,
                      admissionsKey: _sectionKeys.admissions,
                      onLearnMore: () => _scrollTo(_sectionKeys.about),
                      onAdmissionCta: () => _handleAdmissionCta(context, school.schoolId, text),
                    ),
                  ),
                  KeyedSubtree(key: _sectionKeys.gallery, child: LandingGallerySection(gallery: school.gallery, strings: strings)),
                  KeyedSubtree(key: _sectionKeys.contact, child: LandingFooterSection(school: school, strings: strings, links: links)),
                ]),
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
              Positioned(
                right: 20,
                bottom: 20,
                child: AnimatedScale(
                  scale: _showTop ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: FloatingActionButton.small(tooltip: text.backToTop, onPressed: _toTop, child: const Icon(Icons.keyboard_arrow_up_rounded)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
