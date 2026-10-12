import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../../core/status_colors.dart';
import 'proprietor_charts.dart';
import 'proprietor_format.dart';
import 'proprietor_strings.dart';

/// Visual kit for the Proprietor module.
///
/// Colour rule (same as the Secretary and Parent modules): decoration
/// uses the school's own primary colour and neutral surface tones only.
/// Green / amber / red appear ONLY where they carry meaning (gain, warn,
/// loss), via core/status_colors.dart.

/// Neutral tone used for "spending" series, so income (the school's
/// colour) always stands out against it without a second brand colour.
Color prSpendColor(BuildContext context) => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.42);

/// Categorical palette derived from the school's own colours: primary,
/// secondary and tonal steps of each, never arbitrary rainbow hues.
List<Color> prPalette(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return [
    cs.primary,
    cs.secondary,
    cs.primary.withValues(alpha: 0.62),
    cs.secondary.withValues(alpha: 0.62),
    cs.primary.withValues(alpha: 0.36),
    cs.secondary.withValues(alpha: 0.36),
    cs.outline,
    cs.outlineVariant,
  ];
}

// ============================================================ layout

/// Scrollable page with pull-to-refresh, a readable max width and
/// consistent padding.
class PrPage extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double maxWidth;
  const PrPage({super.key, required this.children, this.onRefresh, this.maxWidth = 1180});

  static double padding(BuildContext context) {
    if (Responsive.isMobile(context)) return 16;
    if (Responsive.isTablet(context)) return 24;
    return 32;
  }

  @override
  Widget build(BuildContext context) {
    final pad = padding(context);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class PrHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PrHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.4)),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline, height: 1.35)),
      ],
    ]);
    return PrReveal(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: LayoutBuilder(builder: (context, c) {
          if (trailing == null) return Align(alignment: Alignment.centerLeft, child: text);
          if (c.maxWidth < 560) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 12), trailing!]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: text), const SizedBox(width: 16), trailing!]);
        }),
      ),
    );
  }
}

class PrSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PrSectionTitle({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.35)),
              ),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Lays children out in 1..[max] equal columns by available width.
class PrGrid extends StatelessWidget {
  final List<Widget> children;
  final int max;
  final double minTile;
  final double spacing;
  const PrGrid({super.key, required this.children, this.max = 4, this.minTile = 240, this.spacing = 14});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minTile).floor().clamp(1, max).toInt();
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (var i = 0; i < children.length; i++) SizedBox(width: w, child: PrReveal(index: i, child: children[i])),
        ],
      );
    });
  }
}

// ============================================================ motion

/// One-shot entrance (fade + rise) with a stagger by [index]. Plays once
/// when the widget is first built; replays only if its key changes.
class PrReveal extends StatelessWidget {
  final Widget child;
  final int index;
  const PrReveal({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 60).clamp(0, 420).toInt();
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Curves.linear,
      builder: (context, t, child) {
        final p = Curves.easeOutCubic.transform(((t * total - delay) / 420).clamp(0.0, 1.0).toDouble());
        return Opacity(opacity: p, child: Transform.translate(offset: Offset(0, (1 - p) * 14), child: child));
      },
      child: child,
    );
  }
}

/// Animated number: counts up from zero on first show and glides
/// between values when live data changes.
class PrCountUp extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle? style;
  const PrCountUp({super.key, required this.value, required this.format, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Shimmering placeholder block.
class PrSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const PrSkeleton({super.key, this.height = 16, this.width, this.radius = 10});

  @override
  State<PrSkeleton> createState() => _PrSkeletonState();
}

class _PrSkeletonState extends State<PrSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + t * 3, 0),
              end: Alignment(-0.5 + t * 3, 0),
              colors: [base.withValues(alpha: 0.06), base.withValues(alpha: 0.12), base.withValues(alpha: 0.06)],
            ),
          ),
        );
      },
    );
  }
}

/// Full-page skeleton used while a screen's first data loads.
class PrPageSkeleton extends StatelessWidget {
  const PrPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PrPage(children: [
      const PrSkeleton(height: 28, width: 220),
      const SizedBox(height: 10),
      const PrSkeleton(height: 14, width: 320),
      const SizedBox(height: 24),
      const PrSkeleton(height: 150, radius: 22),
      const SizedBox(height: 14),
      PrGrid(children: List.generate(4, (_) => const PrSkeleton(height: 104, radius: 20)), max: 4, minTile: 220),
      const SizedBox(height: 14),
      const PrSkeleton(height: 280, radius: 22),
    ]);
  }
}

// ============================================================ cards

class PrCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const PrCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return _Pressable(onTap: onTap!, child: box);
  }
}

/// Subtle hover/press feedback: a 1.5% scale and a soft shadow.
class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _Pressable({required this.onTap, required this.child});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _hot = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scale = _down ? 0.985 : (_hot ? 1.012 : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hot = true),
      onExit: (_) => setState(() => _hot = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: _hot ? [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 8))] : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A chart (or any visual) inside a titled card, with an optional legend.
class PrChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final List<PrLegendItem> legend;
  const PrChartCard({super.key, required this.title, this.subtitle, required this.child, this.trailing, this.legend = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.35)),
                ),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
        if (legend.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 6, children: legend),
        ],
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class PrLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const PrLegendItem({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ============================================================ stat tiles

/// Month-over-month change chip. [higherIsBetter] false for spending.
class PrDeltaChip extends StatelessWidget {
  final double? delta;
  final bool higherIsBetter;
  final AppStrings strings;
  const PrDeltaChip({super.key, required this.delta, required this.strings, this.higherIsBetter = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (delta == null) {
      return Text(strings.prNoComparison, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline));
    }
    final up = delta! >= 0;
    final good = (up && higherIsBetter) || (!up && !higherIsBetter);
    final neutral = delta!.abs() < 0.5;
    final color = neutral ? theme.colorScheme.outline : (good ? kSettled : kOverdue);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(neutral ? Icons.remove_rounded : (up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded), size: 12, color: color),
          const SizedBox(width: 2),
          Text(pSigned(delta!), style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ]),
      ),
      const SizedBox(width: 6),
      Flexible(child: Text(strings.prVsLastMonth, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline), overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class PrStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String Function(double) format;
  final Widget? footer;
  final List<double>? spark;
  final VoidCallback? onTap;
  const PrStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
    this.footer,
    this.spark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PrCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 14),
        PrCountUp(value: value, format: format, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        if (spark != null && spark!.length > 1) ...[
          const SizedBox(height: 10),
          PrSparkline(values: spark!, color: cs.primary, height: 30),
        ],
        if (footer != null) ...[const SizedBox(height: 10), footer!],
      ]),
    );
  }
}

// ============================================================ small widgets

class PrProgressBar extends StatelessWidget {
  final double value; // 0..1 (can exceed 1)
  final Color? color;
  final double height;
  const PrProgressBar({super.key, required this.value, this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(children: [
          Container(height: height, color: cs.onSurface.withValues(alpha: 0.08)),
          FractionallySizedBox(widthFactor: v, child: Container(height: height, color: c)),
        ]),
      ),
    );
  }
}

/// Segmented bar splitting a whole into proportional parts.
class PrSplitBar extends StatelessWidget {
  final List<PrSlice> parts;
  final double height;
  const PrSplitBar({super.key, required this.parts, this.height = 14});

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<double>(0, (a, p) => a + p.value);
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          if (total <= 0) return Container(height: height, color: cs.onSurface.withValues(alpha: 0.08));
          return SizedBox(
            height: height,
            child: Row(children: [
              for (final p in parts)
                if (p.value > 0) Expanded(flex: (p.value / total * 1000 * t).round().clamp(1, 1000).toInt(), child: Container(color: p.color)),
              Expanded(flex: ((1 - t) * 1000).round(), child: const SizedBox()),
            ]),
          );
        },
      ),
    );
  }
}

class PrPills<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  const PrPills({super.key, required this.values, required this.selected, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final v in values)
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: v == selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: v == selected ? cs.primary : cs.outlineVariant),
            ),
            child: Text(
              label(v),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: v == selected ? cs.onPrimary : cs.onSurfaceVariant),
            ),
          ),
        ),
    ]);
  }
}

class PrAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final bool onDark;
  const PrAvatar({super.key, this.photoUrl, required this.name, this.radius = 20, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundColor: cs.primary, backgroundImage: NetworkImage(photoUrl!));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: onDark ? cs.onInverseSurface.withValues(alpha: 0.16) : cs.primary,
      child: Text(initial, style: TextStyle(color: onDark ? cs.onInverseSurface : cs.onPrimary, fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
    );
  }
}

class PrEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  const PrEmpty({super.key, required this.icon, required this.title, this.description, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (description != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(description!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.4)),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class PrError extends StatelessWidget {
  final Object error;
  final AppStrings strings;
  final VoidCallback onRetry;
  const PrError({super.key, required this.error, required this.strings, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 14),
          Text(strings.prSomethingWrong, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(strings.prCheckConnection, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(strings.prRetry)),
        ]),
      ),
    );
  }
}

/// Pulsing "Live" indicator shown in the header while realtime is on.
class PrLiveDot extends StatefulWidget {
  final String label;
  final Color color;
  const PrLiveDot({super.key, required this.label, required this.color});

  @override
  State<PrLiveDot> createState() => _PrLiveDotState();
}

class _PrLiveDotState extends State<PrLiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 14,
        height: 14,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(alignment: Alignment.center, children: [
            Container(
              width: 14 * _c.value,
              height: 14 * _c.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: (1 - _c.value) * 0.5)),
            ),
            Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
          ]),
        ),
      ),
      const SizedBox(width: 6),
      Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.color)),
    ]);
  }
}

void prSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Debounces a text field into a callback.
class PrDebouncer {
  PrDebouncer([this.delay = const Duration(milliseconds: 320)]);
  final Duration delay;
  Timer? _t;
  void run(VoidCallback action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }

  void dispose() => _t?.cancel();
}

/// Copy helper used by a few screens.
Future<void> prCopy(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) prSnack(context, message);
}

/// Money text with the school-wide format.
Text prMoneyText(num v, TextStyle? style) => Text(pMoney(v), style: style);