import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../principal/principal_kit.dart' show PnEmpty;
import '../proprietor/proprietor_ui.dart';
import 'secretary_strings.dart';

/// Visual kit for the Secretary module. It sits on top of the shared
/// Proprietor/Principal building blocks (PrPage, PrCard, PrReveal,
/// PrSkeleton...) so the Secretary looks and moves exactly like the
/// rest of the staff app, and adds the few widgets only the Secretary
/// needs (list rows, step header, option tiles, success badge).

/// Clean, human message from any error. Edge-function messages are
/// already written for people, so they are shown as they are; only the
/// `Exception:` prefix is removed.
String sxMessage(Object e) {
  var raw = e.toString().replaceFirst(RegExp(r'^(Exception|Error|PostgrestException|FunctionException)[:\s]*'), '').trim();
  raw = raw.replaceAll(RegExp(r'\s+'), ' ');
  if (raw.isEmpty) return 'Something went wrong.';
  return raw.length > 280 ? '${raw.substring(0, 280)}…' : raw;
}

// ============================================================ states

class SxError extends StatelessWidget {
  final Object error;
  final AppStrings strings;
  final VoidCallback? onRetry;
  const SxError({super.key, required this.error, required this.strings, this.onRetry});

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
          SelectableText(sxMessage(error), textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.45)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(strings.tryAgain)),
          ],
        ]),
      ),
    );
  }
}

class SxSkeletonList extends StatelessWidget {
  final int rows;
  final double height;
  const SxSkeletonList({super.key, this.rows = 4, this.height = 78});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: PrSkeleton(height: height, radius: 18)),
      ]);
}

/// Renders an AsyncValue with skeleton, friendly error and empty state.
class SxAsync<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final AppStrings strings;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final int rows;
  const SxAsync({
    super.key,
    required this.value,
    required this.strings,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.empty,
    this.rows = 4,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      loading: () => SxSkeletonList(rows: rows),
      error: (e, _) => SxError(error: e, strings: strings, onRetry: onRetry),
      data: (d) {
        if (isEmpty != null && empty != null && isEmpty!(d)) return PrCard(child: empty!);
        return builder(d);
      },
    );
  }
}

/// Empty state with the shared look.
class SxEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  const SxEmpty({super.key, required this.icon, required this.title, this.text, this.action});

  @override
  Widget build(BuildContext context) => PnEmpty(icon: icon, title: title, text: text, action: action);
}

// ============================================================ rows & tiles

/// A tappable list row: leading visual, title, subtitle lines and a
/// trailing widget. Wraps to its content, never a fixed height.
class SxRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final List<String> lines;
  final Widget? trailing;
  final Widget? bottom;
  final VoidCallback? onTap;
  final int index;
  const SxRow({
    super.key,
    required this.leading,
    required this.title,
    this.lines = const [],
    this.trailing,
    this.bottom,
    this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PrReveal(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PrCard(
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  for (final l in lines)
                    if (l.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(l, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.3)),
                      ),
                ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), Flexible(flex: 0, child: trailing!)],
            ]),
            if (bottom != null) ...[const SizedBox(height: 12), bottom!],
          ]),
        ),
      ),
    );
  }
}

/// Round icon on a soft tint, used as a row's leading visual.
class SxIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const SxIconBadge({super.key, required this.icon, this.color, this.size = 44});

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

/// Selectable option (payment method, gender...). Highlights with the
/// school colour when [selected] and animates the change.
class SxOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  const SxOptionTile({super.key, required this.icon, required this.title, this.subtitle, this.selected = false, this.enabled = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.6), width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          SxIconBadge(icon: icon, size: 40, color: enabled ? cs.primary : cs.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: fg)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.3)),
                ),
            ]),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: selected ? 1 : 0,
            child: Icon(Icons.check_circle_rounded, color: cs.primary),
          ),
        ]),
      ),
    );
  }
}

/// Label / value line used in receipts and review summaries.
class SxKeyValue extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const SxKeyValue({super.key, required this.label, required this.value, this.strong = false});

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

/// Animated tick shown when a payment or an enrollment succeeds.
class SxSuccessBadge extends StatelessWidget {
  final double size;
  const SxSuccessBadge({super.key, this.size = 76});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, t, _) => Transform.scale(
        scale: t.clamp(0.0, 1.2).toDouble(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, color: cs.primary, size: size * 0.55),
        ),
      ),
    );
  }
}

// ============================================================ stepper

/// Horizontal progress header for the enrollment wizard. Shows dots
/// with the current step title; collapses to a bar on narrow screens.
class SxStepper extends StatelessWidget {
  final List<String> titles;
  final int current;
  const SxStepper({super.key, required this.titles, required this.current});

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
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: i == current ? FontWeight.w900 : FontWeight.w600,
                    color: i == current ? cs.onSurface : cs.outline,
                  ),
                ),
              ),
          ]),
      ]);
    });
  }
}
