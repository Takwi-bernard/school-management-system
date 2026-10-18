import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import 'landing_model.dart';
import 'landing_text.dart';

/// Hero + Statistics + About + Principal message + Achievements +
/// Admissions, in page order.
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
    final text = LandingText(strings.isFrench);
    return Column(children: [
      _Hero(school: school, strings: strings, text: text, onApply: onAdmissionCta, onLearnMore: onLearnMore),
      if (school.statistics.isNotEmpty) _Statistics(school: school),
      KeyedSubtree(key: aboutKey, child: RevealOnScroll(child: _About(school: school, strings: strings, text: text))),
      if (school.principalMessage.isNotEmpty) RevealOnScroll(child: _PrincipalMessage(school: school, strings: strings)),
      if (school.achievements.isNotEmpty)
        KeyedSubtree(key: achievementsKey, child: RevealOnScroll(child: _Achievements(school: school, strings: strings, text: text))),
      KeyedSubtree(key: admissionsKey, child: RevealOnScroll(child: _Admissions(strings: strings, text: text, onTap: onAdmissionCta))),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Section heading shared by About / Achievements / Gallery / Updates
// ---------------------------------------------------------------------------

class SectionHeading extends StatelessWidget {
  final String overline;
  final String title;
  final CrossAxisAlignment alignment;
  const SectionHeading({super.key, required this.overline, required this.title, this.alignment = CrossAxisAlignment.start});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: alignment, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 22, height: 3, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Text(
          overline.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, letterSpacing: 1.4),
        ),
      ]),
      const SizedBox(height: 10),
      Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6, height: 1.15)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// HERO
// ---------------------------------------------------------------------------

class _Hero extends StatefulWidget {
  final LandingModel school;
  final AppStrings strings;
  final LandingText text;
  final VoidCallback onApply;
  final VoidCallback onLearnMore;
  const _Hero({required this.school, required this.strings, required this.text, required this.onApply, required this.onLearnMore});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with TickerProviderStateMixin {
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();
  late final _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _enter.dispose();
    _bounce.dispose();
    super.dispose();
  }

  /// Each piece of the hero eases in a little after the one before it.
  Widget _step(int i, Widget child) {
    final double start = (0.10 * i).clamp(0.0, 0.6).toDouble();
    final double end = (start + 0.5).clamp(0.0, 1.0).toDouble();
    final curve = CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: _enter.drive(curve),
      child: SlideTransition(position: _enter.drive(curve).drive(Tween(begin: const Offset(0, 0.12), end: Offset.zero)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);
    final school = widget.school;
    final strings = widget.strings;
    final height = MediaQuery.sizeOf(context).height;
    final heroHeight = (height * (isMobile ? 0.86 : 0.9)).clamp(isMobile ? 540.0 : 600.0, 820.0).toDouble();
    final hasImage = school.heroImageUrl.isNotEmpty;
    final deep = Color.lerp(cs.primary, Colors.black, 0.4) ?? cs.primary;
    final align = isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          // Background: the photo with a slow zoom, or the school colours.
          if (hasImage)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.08),
              duration: const Duration(seconds: 14),
              curve: Curves.easeOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Image(
                image: ResizeImage(NetworkImage(school.heroImageUrl), width: 1600),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primary, deep]))),
              ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primary, deep], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            ),
          // Scrim: keeps the text readable over any photo, darker at the
          // top (navbar) and bottom.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: hasImage ? 0.55 : 0.15),
                  Colors.black.withValues(alpha: hasImage ? 0.30 : 0.0),
                  Colors.black.withValues(alpha: hasImage ? 0.70 : 0.25),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(Responsive.pagePadding(context), 96, Responsive.pagePadding(context), 72),
            child: Align(
              alignment: isMobile ? Alignment.center : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: align, children: [
                  _step(
                    0,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            school.currentAcademicYear != null ? widget.text.academicYear(school.currentAcademicYear!) : strings.ourSchool,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _step(
                    1,
                    Text(
                      school.schoolName,
                      textAlign: isMobile ? TextAlign.center : TextAlign.start,
                      style: TextStyle(color: Colors.white, fontSize: isMobile ? 36 : 64, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1.2),
                    ),
                  ),
                  if (school.motto.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _step(
                      2,
                      Text(
                        school.motto,
                        textAlign: isMobile ? TextAlign.center : TextAlign.start,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: isMobile ? 16 : 21, fontStyle: FontStyle.italic, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 34),
                  _step(
                    3,
                    Wrap(spacing: 14, runSpacing: 14, alignment: isMobile ? WrapAlignment.center : WrapAlignment.start, children: [
                      HoverLift(
                        liftPixels: 3,
                        onTap: widget.onApply,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(strings.applyNow, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18, color: cs.primary),
                          ]),
                        ),
                      ),
                      HoverLift(
                        liftPixels: 3,
                        onTap: widget.onLearnMore,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.4),
                          ),
                          child: Text(strings.learnMore, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          // Scroll cue.
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _bounce,
                builder: (context, child) => Transform.translate(offset: Offset(0, 8 * Curves.easeInOut.transform(_bounce.value)), child: child),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.8), size: 32),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STATISTICS - numbers count up the first time they scroll into view
// ---------------------------------------------------------------------------

class _Statistics extends StatelessWidget {
  final LandingModel school;
  const _Statistics({required this.school});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final count = school.statistics.length;
    final columns = Responsive.columns(context, max: count.clamp(1, 4).toInt()).clamp(1, count).toInt();

    return Container(
      width: double.infinity,
      color: cs.surface,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: 44),
      child: LayoutBuilder(builder: (context, box) {
        const gap = 14.0;
        final w = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, alignment: WrapAlignment.center, children: [
          for (final stat in school.statistics)
            SizedBox(
              width: w.floorToDouble(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _CountUp(value: stat.value, style: theme.textTheme.displaySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  ),
                  const SizedBox(height: 6),
                  Text(stat.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]);
      }),
    );
  }
}

/// Counts up to the number inside [value] ("1,200+", "98%", "25"); any
/// text that has no number is shown as-is.
class _CountUp extends StatefulWidget {
  final String value;
  final TextStyle? style;
  const _CountUp({required this.value, this.style});

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp> {
  bool _started = false;
  static final _pattern = RegExp(r'^(\D*)(\d[\d,]*)(.*)$');

  @override
  Widget build(BuildContext context) {
    final match = _pattern.firstMatch(widget.value.trim());
    final target = match == null ? null : int.tryParse(match.group(2)!.replaceAll(',', ''));
    final useCommas = match != null && match.group(2)!.contains(',');

    String format(int n) {
      if (!useCommas) return '$n';
      final s = n.toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }

    return VisibilityDetector(
      key: ObjectKey(widget),
      onVisibilityChanged: (info) {
        if (!_started && info.visibleFraction > 0.3 && mounted) setState(() => _started = true);
      },
      child: (match == null || target == null)
          ? Text(widget.value, style: widget.style)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _started ? target.toDouble() : 0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text('${match.group(1)}${format(v.round())}${match.group(3)}', style: widget.style),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// ABOUT
// ---------------------------------------------------------------------------

class _About extends StatefulWidget {
  final LandingModel school;
  final AppStrings strings;
  final LandingText text;
  const _About({required this.school, required this.strings, required this.text});

  @override
  State<_About> createState() => _AboutState();
}

class _AboutState extends State<_About> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final school = widget.school;
    final strings = widget.strings;
    final longHistory = school.history.length > 420;

    final intro = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeading(overline: strings.ourSchool, title: school.schoolName),
      if (school.history.isNotEmpty) ...[
        const SizedBox(height: 20),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Text(
            school.history,
            maxLines: (_expanded || !longHistory) ? null : 7,
            overflow: (_expanded || !longHistory) ? TextOverflow.visible : TextOverflow.fade,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.7, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        if (longHistory)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(_expanded ? widget.text.showLess : widget.text.readMore),
          ),
      ],
    ]);

    final cards = Column(children: [
      if (school.mission.isNotEmpty) _InfoCard(title: strings.mission, content: school.mission, icon: Icons.flag_rounded),
      if (school.mission.isNotEmpty && school.vision.isNotEmpty) const SizedBox(height: 16),
      if (school.vision.isNotEmpty) _InfoCard(title: strings.vision, content: school.vision, icon: Icons.visibility_rounded),
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: isMobile ? 56 : 96),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [intro, const SizedBox(height: 28), cards])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: intro),
              const SizedBox(width: 64),
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
    final cs = theme.colorScheme;
    return HoverLift(
      liftPixels: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(content, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6, color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PRINCIPAL MESSAGE
// ---------------------------------------------------------------------------

class _PrincipalMessage extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  const _PrincipalMessage({required this.school, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final deep = Color.lerp(cs.primary, Colors.black, 0.35) ?? cs.primary;
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primary, deep], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Stack(children: [
        Positioned(right: -80, top: -80, child: _Orb(size: 300, color: Colors.white.withValues(alpha: 0.06))),
        Positioned(left: -60, bottom: -100, child: _Orb(size: 260, color: cs.secondary.withValues(alpha: 0.18))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: isMobile ? 60 : 88),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(children: [
                Icon(Icons.format_quote_rounded, size: 56, color: Colors.white.withValues(alpha: 0.55)),
                const SizedBox(height: 12),
                Text(
                  school.principalMessage,
                  textAlign: TextAlign.center,
                  style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)?.copyWith(color: cs.onPrimary, height: 1.6, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 26),
                Container(width: 40, height: 3, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 14),
                Text(strings.principalMessage.toUpperCase(), style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85), fontWeight: FontWeight.w800, letterSpacing: 1.6, fontSize: 13)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

// ---------------------------------------------------------------------------
// ACHIEVEMENTS - cards grow in place; layout is a Wrap so a grown card
// never overflows (the old fixed-height grid clipped expanded text)
// ---------------------------------------------------------------------------

class _Achievements extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  final LandingText text;
  const _Achievements({required this.school, required this.strings, required this.text});

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.columns(context, max: 3);
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: isMobile ? 56 : 88),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeading(overline: strings.achievements, title: strings.achievementsTitle),
        const SizedBox(height: 32),
        LayoutBuilder(builder: (context, box) {
          const gap = 22.0;
          final cols = box.maxWidth < 520 ? 1 : columns;
          final w = ((box.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
          return Wrap(spacing: gap, runSpacing: gap, crossAxisAlignment: WrapCrossAlignment.start, children: [
            for (final a in school.achievements) SizedBox(width: w, child: _AchievementCard(achievement: a, text: text)),
          ]);
        }),
      ]),
    );
  }
}

class _AchievementCard extends StatefulWidget {
  final LandingAchievement achievement;
  final LandingText text;
  const _AchievementCard({required this.achievement, required this.text});

  @override
  State<_AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<_AchievementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final a = widget.achievement;
    final canExpand = a.description.length > 110;

    return HoverLift(
      onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 170,
              width: double.infinity,
              child: (a.imageUrl != null && a.imageUrl!.isNotEmpty)
                  ? Image.network(a.imageUrl!, fit: BoxFit.cover, cacheWidth: 600, errorBuilder: (_, __, ___) => _placeholder(cs))
                  : _placeholder(cs),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, maxLines: _expanded ? null : 2, overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(a.description, maxLines: _expanded ? null : 3, overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55, color: cs.onSurfaceVariant)),
                if (canExpand) ...[
                  const SizedBox(height: 10),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_expanded ? widget.text.showLess : widget.text.readMore, style: theme.textTheme.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
                    Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: cs.primary),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.primary.withValues(alpha: 0.08),
        child: Center(child: Icon(Icons.emoji_events_rounded, size: 46, color: cs.primary)),
      );
}

// ---------------------------------------------------------------------------
// ADMISSIONS
// ---------------------------------------------------------------------------

class _Admissions extends StatelessWidget {
  final AppStrings strings;
  final LandingText text;
  final VoidCallback onTap;
  const _Admissions({required this.strings, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    final copy = Column(crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
      Text(strings.admissions, textAlign: isMobile ? TextAlign.center : TextAlign.start, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      const SizedBox(height: 10),
      Text(text.admissionsLead, textAlign: isMobile ? TextAlign.center : TextAlign.start, style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.55)),
    ]);

    final button = HoverLift(
      onTap: onTap,
      liftPixels: 3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.how_to_reg_rounded, color: cs.onPrimary),
          const SizedBox(width: 10),
          Text(strings.startAdmission, style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: isMobile ? 48 : 72),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 28 : 48),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
        ),
        child: isMobile
            ? Column(children: [copy, const SizedBox(height: 24), button])
            : Row(children: [Expanded(child: copy), const SizedBox(width: 40), button]),
      ),
    );
  }
}
