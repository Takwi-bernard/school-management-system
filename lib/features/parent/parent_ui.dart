import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../principal/principal_kit.dart' show PnEmpty;
import '../proprietor/proprietor_ui.dart';

/// Visual kit for the Parent module. Built on the shared Proprietor /
/// Principal building blocks (PrPage, PrCard, PrReveal, PrSkeleton...)
/// so the Parent app looks and moves like the rest of the product, plus
/// the few widgets only the Parent screens need.

String paMoney(num v) {
  final digits = v.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '$grouped FCFA';
}

String paDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

String paDateTime(DateTime d) {
  final l = d.toLocal();
  return '${paDate(l)} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Human message from any error: strips the "Exception:" prefix.
String paMessage(Object e) {
  var raw = e.toString().replaceFirst(RegExp(r'^(Exception|Error|StateError|Bad state|PostgrestException|FunctionException)[:\s]*'), '').trim();
  raw = raw.replaceAll(RegExp(r'\s+'), ' ');
  if (raw.isEmpty) return 'Something went wrong.';
  return raw.length > 280 ? '${raw.substring(0, 280)}…' : raw;
}

// ============================================================ states

class PaError extends StatelessWidget {
  final Object error;
  final AppStrings strings;
  final VoidCallback? onRetry;
  const PaError({super.key, required this.error, required this.strings, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PrReveal(
      child: PrCard(
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: cs.error.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: Icon(Icons.cloud_off_rounded, color: cs.error, size: 26),
          ),
          const SizedBox(height: 14),
          Text(strings.isFrench ? 'Impossible de charger cette page' : 'We could not load this page',
              textAlign: TextAlign.center, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SelectableText(paMessage(error), textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.45)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(strings.tryAgain)),
          ],
        ]),
      ),
    );
  }
}

class PaSkeletonList extends StatelessWidget {
  final int rows;
  final double height;
  const PaSkeletonList({super.key, this.rows = 3, this.height = 84});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: PrSkeleton(height: height, radius: 18)),
      ]);
}

/// AsyncValue renderer: skeleton, friendly error, optional empty state.
class PaAsync<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final AppStrings strings;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final int rows;
  final double rowHeight;
  const PaAsync({
    super.key,
    required this.value,
    required this.strings,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.empty,
    this.rows = 3,
    this.rowHeight = 84,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      loading: () => PaSkeletonList(rows: rows, height: rowHeight),
      error: (e, _) => PaError(error: e, strings: strings, onRetry: onRetry),
      data: (d) {
        if (isEmpty != null && empty != null && isEmpty!(d)) return PrReveal(child: PrCard(child: empty!));
        return builder(d);
      },
    );
  }
}

class PaEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  const PaEmpty({super.key, required this.icon, required this.title, this.text, this.action});

  @override
  Widget build(BuildContext context) => PnEmpty(icon: icon, title: title, text: text, action: action);
}

// ============================================================ pieces

class PaIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const PaIconBadge({super.key, required this.icon, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(size / 3)),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}

/// Gradient banner used at the top of the main screens. Only the
/// school's own colours are used, never an invented hue.
class PaHero extends StatelessWidget {
  final Widget? leading;
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? bottom;
  const PaHero({super.key, this.leading, required this.eyebrow, required this.title, this.subtitle, this.bottom});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PrReveal(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, Color.lerp(cs.primary, cs.inverseSurface, 0.45) ?? cs.primary]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 16)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(eyebrow, style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.78), fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4, height: 1.15)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.82), fontSize: 12.5, height: 1.35)),
                ],
              ]),
            ),
          ]),
          if (bottom != null) ...[const SizedBox(height: 18), bottom!],
        ]),
      ),
    );
  }
}

/// Number + label shown inside a [PaHero].
class PaHeroStat extends StatelessWidget {
  final String label;
  final String value;
  const PaHeroStat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.78), fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(color: cs.onPrimary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5))),
    ]);
  }
}

/// Selectable option tile (gender, class, relationship, subjects).
class PaOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  const PaOptionTile({super.key, required this.icon, required this.title, this.subtitle, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.6), width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          PaIconBadge(icon: icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null)
                Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.3))),
            ]),
          ),
          AnimatedOpacity(duration: const Duration(milliseconds: 160), opacity: selected ? 1 : 0, child: Icon(Icons.check_circle_rounded, color: cs.primary)),
        ]),
      ),
    );
  }
}

class PaKeyValue extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const PaKeyValue({super.key, required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 4, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.end,
            style: (strong ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)?.copyWith(fontWeight: strong ? FontWeight.w900 : FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}

class PaStatusBadge extends StatelessWidget {
  final double size;
  final IconData icon;
  final Color color;
  const PaStatusBadge({super.key, required this.icon, required this.color, this.size = 84});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, t, _) => Transform.scale(
        scale: t.clamp(0.0, 1.2).toDouble(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: size * 0.5),
        ),
      ),
    );
  }
}

/// Step header for wizards: segmented bar and the current step title.
class PaStepper extends StatelessWidget {
  final List<String> titles;
  final int current;
  const PaStepper({super.key, required this.titles, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 520;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < titles.length; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                height: 6,
                decoration: BoxDecoration(color: i <= current ? cs.primary : cs.onSurface.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
              ),
            ),
            if (i < titles.length - 1) const SizedBox(width: 6),
          ],
        ]),
        const SizedBox(height: 10),
        if (narrow)
          Text('${current + 1}/${titles.length} · ${titles[current]}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800))
        else
          Row(children: [
            for (var i = 0; i < titles.length; i++)
              Expanded(
                child: Text(
                  titles[i],
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: i == current ? FontWeight.w900 : FontWeight.w600, color: i == current ? cs.onSurface : cs.outline),
                ),
              ),
          ]),
      ]);
    });
  }
}
