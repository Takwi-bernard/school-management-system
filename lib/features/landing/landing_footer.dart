import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import 'landing_model.dart';

class LandingFooterSection extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;

  const LandingFooterSection({super.key, required this.school, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (school.announcements.isNotEmpty || school.events.isNotEmpty)
        _Updates(school: school, strings: strings),
      _Contact(school: school, strings: strings),
      _Footer(school: school, strings: strings),
    ]);
  }
}

class _Updates extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  const _Updates({required this.school, required this.strings});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final announcements = school.announcements.isEmpty
        ? const SizedBox.shrink()
        : Expanded(child: _UpdateList(title: strings.announcements, subtitle: strings.latestNews, items: [
            for (final a in school.announcements) _UpdateCardData(title: a.title, body: a.content),
          ]));

    final events = school.events.isEmpty
        ? const SizedBox.shrink()
        : Expanded(child: _UpdateList(title: strings.upcomingEvents, subtitle: strings.upcomingEvents, items: [
            for (final e in school.events)
              _UpdateCardData(
                title: e.title,
                body: [e.description, e.location].where((s) => s != null && s.isNotEmpty).join(' · '),
              ),
          ]));

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: 64),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (school.announcements.isNotEmpty) announcements,
              if (school.announcements.isNotEmpty && school.events.isNotEmpty)
                const SizedBox(height: 40),
              if (school.events.isNotEmpty) events,
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (school.announcements.isNotEmpty) announcements,
              if (school.announcements.isNotEmpty && school.events.isNotEmpty)
                const SizedBox(width: 40),
              if (school.events.isNotEmpty) events,
            ]),
    );
  }
}

class _UpdateCardData {
  final String title;
  final String body;
  const _UpdateCardData({required this.title, required this.body});
}

class _UpdateList extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_UpdateCardData> items;
  const _UpdateList({required this.title, required this.subtitle, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      for (final item in items.take(3))
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (item.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
            ],
          ]),
        ),
    ]);
  }
}

class _Contact extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  const _Contact({required this.school, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContact = [school.email, school.phone, school.address, school.website]
        .any((s) => s.isNotEmpty);
    if (!hasContact) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLow,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: 56),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(strings.contact,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Wrap(spacing: 32, runSpacing: 16, children: [
          if (school.phone.isNotEmpty) _ContactItem(icon: Icons.phone_rounded, text: school.phone),
          if (school.email.isNotEmpty) _ContactItem(icon: Icons.email_rounded, text: school.email),
          if (school.address.isNotEmpty)
            _ContactItem(icon: Icons.location_on_rounded, text: school.address),
          if (school.website.isNotEmpty) _ContactItem(icon: Icons.language_rounded, text: school.website),
        ]),
      ]),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: theme.colorScheme.primary),
      const SizedBox(width: 8),
      Text(text, style: theme.textTheme.bodyMedium),
    ]);
  }
}

class _Footer extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  const _Footer({required this.school, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    final copyright = Text(
      '© ${DateTime.now().year} ${school.schoolName}. ${strings.allRightsReserved}.',
      style: theme.textTheme.bodySmall,
    );
    final powered = Text(strings.poweredBy, style: theme.textTheme.bodySmall);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: 28),
      child: isMobile
          ? Column(children: [copyright, const SizedBox(height: 8), powered])
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [copyright, powered],
            ),
    );
  }
}