import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import 'landing_model.dart';
import 'landing_providers.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    // Below this width even the mobile layout gets tight (small phones
    // in portrait) - shrink further rather than truncating the name.
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    final navItems = <(String, VoidCallback)>[
      (strings.home, onNavHome),
      (strings.about, onNavAbout),
      (strings.achievements, onNavAchievements),
      (strings.gallery, onNavGallery),
      (strings.admissions, onNavAdmissions),
      (strings.contact, onNavContact),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: elevated ? 0.98 : 0.9),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Logo shrinks on very narrow screens instead of eating into
          // the space the school name needs.
          if (school.logoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                school.logoUrl,
                width: isNarrow ? 32 : 40,
                height: isNarrow ? 32 : 40,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.school_rounded, color: theme.colorScheme.primary),
              ),
            ),
          const SizedBox(width: 10),
          // FIX: previously truncated to a single line with ellipsis,
          // which could cut a long school name mid-word on small
          // screens. Now allowed to wrap to two lines and shrinks font
          // size on very narrow phones instead of clipping.
          Expanded(
            child: Text(
              school.schoolName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: (isMobile ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
            ),
          ),
          const SizedBox(width: 8),
          if (!isMobile)
            for (final item in navItems)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextButton(onPressed: item.$2, child: Text(item.$1)),
              ),
          if (canToggleLanguage) _LanguageToggle(locale: locale),
          const SizedBox(width: 10),
          if (!isMobile)
            FilledButton(
              onPressed: () => context.push('/sign-in'),
              child: Text(strings.signIn),
            )
          else
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _openMobileMenu(context, navItems, strings),
            ),
        ],
      ),
    );
  }

  void _openMobileMenu(
    BuildContext context,
    List<(String, VoidCallback)> navItems,
    AppStrings strings,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in navItems)
              ListTile(
                title: Text(item.$1),
                onTap: () {
                  Navigator.pop(context);
                  item.$2();
                },
              ),
            const Divider(),
            ListTile(
              title: Text(strings.signIn),
              trailing: const Icon(Icons.login_rounded),
              onTap: () {
                Navigator.pop(context);
                context.push('/sign-in');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  final Locale locale;
  const _LanguageToggle({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Language',
      initialValue: locale.languageCode,
      onSelected: (value) =>
          ref.read(localeOverrideProvider.notifier).state = Locale(value),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'fr', child: Text('Français')),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.language_rounded, size: 22),
      ),
    );
  }
}