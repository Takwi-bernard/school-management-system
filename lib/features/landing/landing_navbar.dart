import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../auth/auth_branding_header.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import 'landing_model.dart';
import 'landing_providers.dart';
import 'landing_text.dart';

class LandingNavbar extends ConsumerWidget {
  final LandingModel school;
  final AppStrings strings;
  final Locale locale;
  final bool canToggleLanguage;
  final bool elevated;
  final VoidCallback onNavHome;
  final VoidCallback onNavAbout;
  final VoidCallback onNavAchievements;
  final VoidCallback onNavGallery;
  final VoidCallback onNavAdmissions;
  final VoidCallback onNavContact;

  const LandingNavbar({
    super.key,
    required this.school,
    required this.strings,
    required this.locale,
    required this.canToggleLanguage,
    required this.elevated,
    required this.onNavHome,
    required this.onNavAbout,
    required this.onNavAchievements,
    required this.onNavGallery,
    required this.onNavAdmissions,
    required this.onNavContact,
  });

  static String _dashboardRoute(String role) => switch (role) {
        'parent' => '/parent',
        'teacher' => '/teacher',
        'principal' => '/principal',
        'secretary' => '/secretary',
        'proprietor' => '/proprietor',
        _ => '/',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = LandingText(strings.isFrench);
    final isMobile = Responsive.isMobile(context);
    final session = ref.watch(sessionProfileProvider(school.schoolId));
    final profile = session.valueOrNull;
    final isSignedIn = profile != null;

    // Transparent and white over the hero; solid and dark-on-light once
    // the page has scrolled.
    final fg = elevated ? theme.colorScheme.onSurface : Colors.white;

    final navItems = <(String, IconData, VoidCallback)>[
      (strings.home, Icons.home_rounded, onNavHome),
      (strings.about, Icons.info_outline_rounded, onNavAbout),
      (strings.achievements, Icons.emoji_events_outlined, onNavAchievements),
      (strings.gallery, Icons.photo_library_outlined, onNavGallery),
      (strings.admissions, Icons.how_to_reg_outlined, onNavAdmissions),
      (strings.contact, Icons.mail_outline_rounded, onNavContact),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context).clamp(16.0, 56.0).toDouble()),
      decoration: BoxDecoration(
        color: elevated ? theme.colorScheme.surface.withValues(alpha: 0.97) : Colors.transparent,
        boxShadow: elevated ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 6))] : const [],
      ),
      child: Row(children: [
        SchoolLogo(url: school.logoUrl, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            school.schoolName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (isMobile ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (!isMobile && MediaQuery.sizeOf(context).width >= 1000)
          for (final item in navItems) _NavLink(label: item.$1, color: fg, onTap: item.$3),
        if (canToggleLanguage) ...[
          const SizedBox(width: 6),
          _LanguagePill(locale: locale, elevated: elevated),
        ],
        const SizedBox(width: 10),
        if (!isMobile && MediaQuery.sizeOf(context).width >= 1000)
          _AuthButton(
            isSignedIn: isSignedIn,
            text: text,
            strings: strings,
            dashboardRoute: isSignedIn ? _dashboardRoute(profile?.role ?? '') : '/',
            elevated: elevated,
          )
        else
          IconButton(
            tooltip: text.menu,
            icon: Icon(Icons.menu_rounded, color: fg),
            onPressed: () => _openMenu(context, navItems, text, isSignedIn, isSignedIn ? _dashboardRoute(profile?.role ?? '') : '/'),
          ),
      ]),
    );
  }

  void _openMenu(
    BuildContext context,
    List<(String, IconData, VoidCallback)> items,
    LandingText text,
    bool isSignedIn,
    String dashboardRoute,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final item in items)
                ListTile(
                  leading: Icon(item.$2),
                  title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onTap: () {
                    Navigator.pop(sheet);
                    item.$3();
                  },
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: Icon(isSignedIn ? Icons.dashboard_rounded : Icons.login_rounded),
                  label: Text(isSignedIn ? text.dashboard : strings.signIn),
                  onPressed: () {
                    Navigator.pop(sheet);
                    isSignedIn ? context.go(dashboardRoute) : context.push('/sign-in');
                  },
                ),
              ),
              if (isSignedIn) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.logout_rounded),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  label: Text(text.signOut),
                  onPressed: () async {
                    Navigator.pop(sheet);
                    await _signOut(context);
                  },
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

Future<void> _signOut(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  await container.read(authControllerProvider.notifier).signOut();
  if (context.mounted) context.go('/');
}

/// Text link with a small animated underline.
class _NavLink extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NavLink({required this.label, required this.color, required this.onTap});

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label, style: TextStyle(color: widget.color, fontWeight: FontWeight.w600, fontSize: 14.5)),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 2,
              width: _hover ? 22 : 0,
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final bool isSignedIn;
  final LandingText text;
  final AppStrings strings;
  final String dashboardRoute;
  final bool elevated;
  const _AuthButton({required this.isSignedIn, required this.text, required this.strings, required this.dashboardRoute, required this.elevated});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    if (isSignedIn) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 42), shape: shape),
          onPressed: () => context.go(dashboardRoute),
          child: Text(text.dashboard),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: text.signOut,
          icon: Icon(Icons.logout_rounded, color: elevated ? cs.error : Colors.white),
          onPressed: () => _signOut(context),
        ),
      ]);
    }

    // On the hero the button is white; once scrolled it takes the
    // school's colour.
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: shape,
        backgroundColor: elevated ? cs.primary : Colors.white,
        foregroundColor: elevated ? cs.onPrimary : cs.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      onPressed: () => context.push('/sign-in'),
      child: Text(strings.signIn),
    );
  }
}

class _LanguagePill extends ConsumerWidget {
  final Locale locale;
  final bool elevated;
  const _LanguagePill({required this.locale, required this.elevated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final selectedBg = elevated ? cs.primary : Colors.white;
    final selectedFg = elevated ? cs.onPrimary : cs.primary;
    final idleFg = elevated ? cs.onSurface : Colors.white;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: elevated ? cs.surfaceContainerHighest.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: elevated ? cs.outlineVariant : Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final code in const ['en', 'fr'])
          GestureDetector(
            onTap: () => ref.read(localeOverrideProvider.notifier).state = Locale(code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: locale.languageCode == code ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                code.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: locale.languageCode == code ? selectedFg : idleFg,
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
