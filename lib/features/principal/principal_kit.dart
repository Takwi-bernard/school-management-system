import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';

/// Shared building blocks for the Principal screens that were rebuilt
/// in the second pass: consistent loading, error and empty states (in
/// both languages), breadcrumbs, animated stage changes, weekdays.

// ============================================================ async states

/// Wraps an [AsyncValue] with the same skeleton, error card and empty
/// state everywhere, so no screen ever shows a raw exception.
class PnAsync<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final AppStrings strings;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final int skeletonRows;

  const PnAsync({
    super.key,
    required this.value,
    required this.strings,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.empty,
    this.skeletonRows = 3,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      loading: () => PnSkeletonList(rows: skeletonRows),
      error: (e, _) => PnErrorBox(strings: strings, error: e, onRetry: onRetry),
      data: (d) {
        if (isEmpty != null && isEmpty!(d) && empty != null) return empty!;
        return builder(d);
      },
    );
  }
}

class PnSkeletonList extends StatelessWidget {
  final int rows;
  final double height;
  const PnSkeletonList({super.key, this.rows = 3, this.height = 76});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < rows; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: PrSkeleton(height: height, radius: 18)),
    ]);
  }
}

/// A friendly, bilingual error card with a retry button.
class PnErrorBox extends StatelessWidget {
  final AppStrings strings;
  final Object error;
  final VoidCallback? onRetry;
  const PnErrorBox({super.key, required this.strings, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.error.withValues(alpha: 0.25))),
      child: Column(children: [
        Icon(Icons.cloud_off_rounded, size: 34, color: cs.error),
        const SizedBox(height: 12),
        Text(strings.pn('We could not load this', 'Impossible de charger ceci'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(pnErr(strings, error), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(strings.pn('Try again', 'Réessayer'))),
        ],
      ]),
    );
  }
}

/// Empty state used inside lists and panels (smaller than PrEmpty).
class PnEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  const PnEmpty({super.key, required this.icon, required this.title, this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(text!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline, height: 1.45)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      ),
    );
  }
}

// ============================================================ navigation

/// Smooth stage change used by drill-down screens.
class PnStage extends StatelessWidget {
  final String stageKey;
  final Widget child;
  const PnStage({super.key, required this.stageKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(anim), child: child),
      ),
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
      child: KeyedSubtree(key: ValueKey(stageKey), child: child),
    );
  }
}

/// Clickable trail such as "Sequence 1 › Form 1A › Mathematics".
class PnCrumbs extends StatelessWidget {
  final List<String> labels;
  final void Function(int index) onTap; // index of the crumb pressed
  const PnCrumbs({super.key, required this.labels, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 2, runSpacing: 4, children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) Icon(Icons.chevron_right_rounded, size: 18, color: cs.outline),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: i == labels.length - 1 ? null : () => onTap(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              labels[i],
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: i == labels.length - 1 ? FontWeight.w900 : FontWeight.w600, color: i == labels.length - 1 ? cs.onSurface : cs.primary),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// A tappable row card: icon, title, subtitle, optional count and arrow.
class PnPickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int index;
  const PnPickTile({super.key, required this.icon, required this.title, this.subtitle, this.badge, this.badgeColor, this.trailing, this.onTap, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PrReveal(
      index: index > 8 ? 8 : index,
      child: PrCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 21, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          if (badge != null) ...[const SizedBox(width: 8), PnChip(label: badge!, color: badgeColor ?? cs.primary)],
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: cs.outline),
        ]),
      ),
    );
  }
}

// ============================================================ weekdays & time

String pnDayShort(AppStrings s, int d) {
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const fr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  return (s.isFrench ? fr : en)[(d - 1).clamp(0, 6).toInt()];
}

String pnDayLong(AppStrings s, int d) {
  const en = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const fr = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  return (s.isFrench ? fr : en)[(d - 1).clamp(0, 6).toInt()];
}

String pnHm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay pnParseHm(String v, {TimeOfDay fallback = const TimeOfDay(hour: 8, minute: 0)}) {
  final p = v.split(':');
  if (p.length < 2) return fallback;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return fallback;
  return TimeOfDay(hour: h.clamp(0, 23).toInt(), minute: m.clamp(0, 59).toInt());
}

int pnMinutes(String hm) {
  final t = pnParseHm(hm);
  return t.hour * 60 + t.minute;
}

String pnFromMinutes(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Seven selectable weekday chips, language aware.
class PnDayChips extends StatelessWidget {
  final AppStrings strings;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final List<int> days;
  const PnDayChips({super.key, required this.strings, required this.selected, required this.onChanged, this.days = const [1, 2, 3, 4, 5, 6, 7]});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final d in days)
        FilterChip(
          label: Text(pnDayShort(strings, d)),
          selected: selected.contains(d),
          showCheckmark: false,
          onSelected: (on) {
            final next = {...selected};
            on ? next.add(d) : next.remove(d);
            onChanged(next);
          },
        ),
    ]);
  }
}

// ============================================================ small helpers

/// Standard tall-screen aware padding for pages that do not use PrPage.
EdgeInsets pnPagePad(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final h = w < 700 ? 16.0 : (w < 1100 ? 24.0 : 32.0);
  return EdgeInsets.fromLTRB(h, 20, h, 40);
}

/// Initials-only avatar helper text.
String pnInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Soft tint for a subject name so the same subject always gets the
/// same hue across the timetable (kept low-saturation on purpose).
Color pnSubjectTint(String name, Brightness b) {
  var h = 0;
  for (final c in name.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0xFFFF;
  }
  final hue = (h % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, b == Brightness.dark ? 0.35 : 0.45, b == Brightness.dark ? 0.32 : 0.90).toColor();
}

Color pnSubjectInk(String name, Brightness b) {
  var h = 0;
  for (final c in name.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0xFFFF;
  }
  final hue = (h % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.50, b == Brightness.dark ? 0.82 : 0.26).toColor();
}

/// Watches the live tick so a page can reload quietly.
void pnListenTick(WidgetRef ref, void Function() onTick, StateProvider<int> tick) {
  ref.listen<int>(tick, (_, __) => onTick());
}
