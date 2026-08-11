import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import 'landing_model.dart';
import 'landing_providers.dart';

class LandingNavbar extends ConsumerWidget {
  final LandingModel school;
  final AppStrings strings;
  final Locale locale;
  final bool canToggleLanguage;

  const LandingNavbar({
    super.key,
    required this.school,
    required this.strings,
    required this.locale,
    required this.canToggleLanguage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    final navLabels = [
      strings.home,
      strings.about,
      strings.achievements,
      strings.gallery,
      strings.admissions,
      strings.contact,
    ];

    return Container(
      height: 80,
      color: theme.colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context)),
      child: Row(
        children: [
          if (school.logoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                school.logoUrl,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.school_rounded, color: theme.colorScheme.primary),
              ),
            ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              school.schoolName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          if (!isMobile)
            for (final label in navLabels)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: TextButton(onPressed: () {}, child: Text(label)),
              ),
          if (canToggleLanguage) _LanguageToggle(locale: locale),
          const SizedBox(width: 12),
          if (!isMobile)
            FilledButton(
              onPressed: () => _showSignInRoles(context, strings),
              child: Text(strings.signIn),
            )
          else
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _openMobileMenu(context, navLabels, strings),
            ),
        ],
      ),
    );
  }

  void _openMobileMenu(BuildContext context, List<String> navLabels, AppStrings strings) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in navLabels)
              ListTile(title: Text(label), onTap: () => Navigator.pop(context)),
            const Divider(),
            ListTile(
              title: Text(strings.signIn),
              trailing: const Icon(Icons.login_rounded),
              onTap: () {
                Navigator.pop(context);
                _showSignInRoles(context, strings);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSignInRoles(BuildContext context, AppStrings strings) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.signIn,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(strings.selectRole),
              const SizedBox(height: 16),
              _RoleTile(icon: Icons.family_restroom, label: strings.parent),
              _RoleTile(icon: Icons.school_rounded, label: strings.teacher),
              _RoleTile(icon: Icons.manage_accounts, label: strings.principal),
              _RoleTile(icon: Icons.assignment_ind, label: strings.secretary),
              _RoleTile(icon: Icons.business, label: strings.proprietor),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RoleTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.pop(context);
        // Authentication module will handle this route later.
      },
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
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.language_rounded),
      ),
    );
  }
}