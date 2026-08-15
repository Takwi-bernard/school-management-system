import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import 'landing_model.dart';

/// Bundles Hero + Statistics + About + Principal Message + Achievements +
/// Admissions CTA in page order. Each is a private widget below so the
/// section boundary stays clear without needing a separate file per
/// section - none of these carry meaningful internal state besides the
/// achievement cards' own expand/collapse.
class LandingContentSections extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  final GlobalKey aboutKey;
  final GlobalKey achievementsKey;
  final GlobalKey admissionsKey;
  final VoidCallback onLearnMore;
  final VoidCallback onAdmissionCta;

  const LandingContentSections({
    super.key,
    required this.school,
    required this.strings,
    required this.aboutKey,
    required this.achievementsKey,
    required this.admissionsKey,
    required this.onLearnMore,
    required this.onAdmissionCta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Hero(
          school: school,
          strings: strings,
          onApply: onAdmissionCta,
          onLearnMore: onLearnMore,
        ),
        if (school.statistics.isNotEmpty)
          RevealOnScroll(child: _Statistics(school: school)),
        KeyedSubtree(
          key: aboutKey,
          child: RevealOnScroll(child: _About(school: school, strings: strings)),
        ),
        if (school.principalMessage.isNotEmpty)
          RevealOnScroll(child: _PrincipalMessage(school: school, strings: strings)),
        if (school.achievements.isNotEmpty)
          KeyedSubtree(
            key: achievementsKey,
            child: RevealOnScroll(child: _Achievements(school: school, strings: strings)),
          ),
        KeyedSubtree(
          key: admissionsKey,
          child: RevealOnScroll(child: _AdmissionsCta(strings: strings, onTap: onAdmissionCta)),
        ),
      ],
    );
  }
}

class _Hero extends StatefulWidget {
  final LandingModel school;
  final AppStrings strings;
  final VoidCallback onApply;
  final VoidCallback onLearnMore;
  const _Hero({
    required this.school,
    required this.strings,
    required this.onApply,
    required this.onLearnMore,
  });

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final school = widget.school;
    final strings = widget.strings;

    return ClipRect(
      child: Container(
        height: isMobile ? 480 : 640,
        width: double.infinity,
        decoration: BoxDecoration(
          // PERFORMANCE: ResizeImage decodes at a capped resolution
          // instead of the original file size - meaningfully less
          // data/CPU on a slow connection or low-end phone.
          image: school.heroImageUrl.isNotEmpty
              ? DecorationImage(
                  image: ResizeImage(NetworkImage(school.heroImageUrl), width: 1400),
                  fit: BoxFit.cover)
              : null,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: school.heroImageUrl.isEmpty ? 1 : 0),
              theme.colorScheme.secondary.withValues(alpha: school.heroImageUrl.isEmpty ? 1 : 0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Depth: a soft gradient scrim so text stays legible over
            // any photo, plus a subtle radial glow for polish.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context)),
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            strings.ourSchool.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          school.schoolName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 32 : 52,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        if (school.motto.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            school.motto,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: isMobile ? 15 : 20,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (school.currentAcademicYear != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  '${school.currentAcademicYear} Academic Year',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          alignment: WrapAlignment.center,
                          children: [
                            HoverLift(
                              liftPixels: 3,
                              onTap: widget.onApply,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  strings.applyNow,
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            HoverLift(
                              liftPixels: 3,
                              onTap: widget.onLearnMore,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white70, width: 1.4),
                                ),
                                child: Text(
                                  strings.learnMore,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Gentle bouncing scroll cue - a small modern touch that
            // signals "there is more below" without being gimmicky.
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 8),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  onEnd: () {},
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, value),
                    child: child,
                  ),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70, size: 30),
                ),
              ),
            ),
          ],
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
    // FIX: previously a Wrap with manually-computed item widths based
    // on the FULL screen width (not the actual available width),
    // which overflowed/misrendered with no visible card background.
    // A GridView with a fixed max item width is robust regardless of
    // screen size and gives each stat a real card, matching every
    // other section on the page.
    final columns = Responsive.columns(context, max: 4);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.85)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.pagePadding(context),
        vertical: 48,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: school.statistics.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 120,
        ),
        itemBuilder: (context, i) {
          final stat = school.statistics[i];
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.9)),
                ),
              ],
            ),
          );
        },
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
                color: theme.colorScheme.secondary, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Text(school.schoolName,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        if (school.history.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(school.history, maxLines: 8, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.65)),
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
        vertical: isMobile ? 56 : 96,
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
    return HoverLift(
      liftPixels: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                borderRadius: BorderRadius.circular(13)),
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
      ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(children: [
            Icon(Icons.format_quote_rounded,
                size: 46, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(strings.principalMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 22),
            Text(school.principalMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.92), height: 1.6)),
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
          horizontal: Responsive.pagePadding(context), vertical: 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(strings.achievements,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Text(strings.achievementsTitle,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 30),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: school.achievements.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns, crossAxisSpacing: 22, mainAxisSpacing: 22, mainAxisExtent: 340),
          itemBuilder: (context, i) => _AchievementCard(achievement: school.achievements[i]),
        ),
      ]),
    );
  }
}

/// Expandable: collapsed shows a 3-line preview + "Read more"; tapping
/// smoothly grows the card to reveal the full description in place.
class _AchievementCard extends StatefulWidget {
  final LandingAchievement achievement;
  const _AchievementCard({required this.achievement});

  @override
  State<_AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<_AchievementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.achievement;

    return HoverLift(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.imageUrl != null && a.imageUrl!.isNotEmpty)
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(a.imageUrl!, fit: BoxFit.cover, cacheWidth: 500,
                      errorBuilder: (_, __, ___) => _placeholder(theme)),
                )
              else
                _placeholder(theme),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(a.description,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_expanded ? 'Show less' : 'Read more',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                    Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 18, color: theme.colorScheme.primary),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            theme.colorScheme.primary.withValues(alpha: 0.12),
            theme.colorScheme.secondary.withValues(alpha: 0.12),
          ]),
        ),
        child: Center(
          child: Icon(Icons.emoji_events_rounded, size: 44, color: theme.colorScheme.primary),
        ),
      );
}

class _AdmissionsCta extends StatelessWidget {
  final AppStrings strings;
  final VoidCallback onTap;
  const _AdmissionsCta({required this.strings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: 72),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.secondaryContainer,
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Column(children: [
          Text(strings.admissions,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          HoverLift(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.how_to_reg_rounded, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 10),
                Text(strings.startAdmission,
                    style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}