import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import 'landing_model.dart';

/// Bundles Hero + Statistics + About + Principal Message + Achievements +
/// Admissions CTA in page order. Each is a private widget below so the
/// section boundary stays clear without needing a separate file per
/// section - none of these carry meaningful internal state.
class LandingContentSections extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;

  const LandingContentSections({
    super.key,
    required this.school,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Hero(school: school, strings: strings),
        if (school.statistics.isNotEmpty) _Statistics(school: school),
        _About(school: school, strings: strings),
        if (school.principalMessage.isNotEmpty)
          _PrincipalMessage(school: school, strings: strings),
        if (school.achievements.isNotEmpty)
          _Achievements(school: school, strings: strings),
        _AdmissionsCta(strings: strings),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  const _Hero({required this.school, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return Container(
      height: isMobile ? 420 : 560,
      width: double.infinity,
      decoration: BoxDecoration(
        image: school.heroImageUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(school.heroImageUrl), fit: BoxFit.cover)
            : null,
        gradient: school.heroImageUrl.isEmpty
            ? LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                school.schoolName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 28 : 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (school.motto.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  school.motto,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: isMobile ? 15 : 19),
                ),
              ],
              const SizedBox(height: 26),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(onPressed: () {}, child: Text(strings.applyNow)),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: Text(strings.learnMore),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Statistics extends StatelessWidget {
  final LandingModel school;
  const _Statistics({required this.school});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = Responsive.columns(context, max: 4);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.primary,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.pagePadding(context),
        vertical: 44,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 24,
        children: [
          for (final stat in school.statistics)
            SizedBox(
              width: MediaQuery.sizeOf(context).width / columns - 32,
              child: Column(
                children: [
                  Text(
                    stat.value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stat.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _About extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  const _About({required this.school, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.ourSchool,
            style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.secondary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(school.schoolName,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        if (school.history.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(school.history, maxLines: 8, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
        ],
      ],
    );

    final cards = Column(
      children: [
        if (school.mission.isNotEmpty)
          _InfoCard(title: strings.mission, content: school.mission, icon: Icons.flag_rounded),
        if (school.mission.isNotEmpty && school.vision.isNotEmpty)
          const SizedBox(height: 16),
        if (school.vision.isNotEmpty)
          _InfoCard(title: strings.vision, content: school.vision, icon: Icons.visibility_rounded),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.pagePadding(context),
        vertical: isMobile ? 56 : 88,
      ),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              intro,
              const SizedBox(height: 28),
              cards,
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: intro),
              const SizedBox(width: 60),
              Expanded(flex: 4, child: cards),
            ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  const _InfoCard({required this.title, required this.content, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: theme.colorScheme.onPrimary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(content, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

class _PrincipalMessage extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  const _PrincipalMessage({required this.school, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.primary,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(children: [
            Icon(Icons.format_quote_rounded,
                size: 44, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(strings.principalMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Text(school.principalMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.9), height: 1.6)),
          ]),
        ),
      ),
    );
  }
}

class _Achievements extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  const _Achievements({required this.school, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = Responsive.columns(context, max: 3);

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: Responsive.pagePadding(context), vertical: 72),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(strings.achievements,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(strings.achievementsTitle,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 28),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: school.achievements.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns, crossAxisSpacing: 20, mainAxisSpacing: 20, mainAxisExtent: 320),
          itemBuilder: (context, i) {
            final a = school.achievements[i];
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (a.imageUrl != null && a.imageUrl!.isNotEmpty)
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Image.network(a.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _achievementPlaceholder(theme)),
                  )
                else
                  _achievementPlaceholder(theme),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(a.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                      ),
                    ]),
                  ),
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _achievementPlaceholder(ThemeData theme) => Container(
        height: 150,
        width: double.infinity,
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: Center(
          child: Icon(Icons.emoji_events_rounded, size: 44, color: theme.colorScheme.primary),
        ),
      );
}

class _AdmissionsCta extends StatelessWidget {
  final AppStrings strings;
  const _AdmissionsCta({required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: 64),
      color: theme.colorScheme.secondaryContainer,
      child: Center(
        child: Column(children: [
          Text(strings.admissions,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {}, // -> admissions/parent registration flow
            icon: const Icon(Icons.how_to_reg_rounded),
            label: Text(strings.startAdmission),
          ),
        ]),
      ),
    );
  }
}