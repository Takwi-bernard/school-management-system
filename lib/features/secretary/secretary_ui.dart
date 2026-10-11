import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import 'secretary_strings.dart';

/// Shared, self-contained visual kit for the Secretary module. It
/// mirrors the design bar the Teacher module's own kit established
/// (page headers, cards, empty/error states, stat tiles) but is a
/// fresh, independent set of widgets - not imported from Teacher - so
/// this module can keep evolving without any risk of touching
/// Teacher's already-polished code.

class SecretaryPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SecretaryPageHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class SecretaryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const SecretaryCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: content),
    );
  }
}

class SecretaryEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  const SecretaryEmptyState({super.key, required this.icon, required this.title, this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: theme.colorScheme.outline),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ]),
      ),
    );
  }
}

class SecretaryErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final AppStrings strings;
  const SecretaryErrorView({super.key, required this.error, required this.onRetry, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, size: 44, color: theme.colorScheme.error),
          const SizedBox(height: 14),
          Text('$error'.replaceFirst('Exception: ', ''), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(strings.tryAgain)),
        ]),
      ),
    );
  }
}

class SecretaryStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  const SecretaryStatCard({super.key, required this.icon, required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: tint, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class SecretaryAvatar extends StatelessWidget {
  final String? photoUrl;
  final String fullName;
  final double radius;
  const SecretaryAvatar({super.key, this.photoUrl, required this.fullName, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initial = fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : '?';
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(photoUrl!));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.15),
      child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
    );
  }
}