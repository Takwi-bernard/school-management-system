import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'super_admin_theme.dart';

// =====================================================================
// Shared building blocks for the Super Admin portal.
// =====================================================================

enum SaTone { neutral, primary, success, warning, danger, info }

Color saToneColor(SaTone t) => switch (t) {
      SaTone.neutral => Sa.muted,
      SaTone.primary => Sa.primaryHi,
      SaTone.success => Sa.success,
      SaTone.warning => Sa.warning,
      SaTone.danger => Sa.danger,
      SaTone.info => Sa.info,
    };

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String saDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

String saDateTime(DateTime d) {
  final l = d.toLocal();
  final h = l.hour.toString().padLeft(2, '0');
  final m = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${_months[l.month - 1]} ${l.year}, $h:$m';
}

String saAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return saDate(d);
}

String saInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String saRoleLabel(String role) {
  if (role.isEmpty) return '';
  return '${role[0].toUpperCase()}${role.substring(1)}';
}

String saCount(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

void saToast(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: error ? Sa.danger : Sa.success, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message.replaceFirst('Exception: ', ''))),
    ]),
    duration: Duration(seconds: error ? 5 : 3),
  ));
}

Future<void> saCopy(BuildContext context, String text, {String label = 'Copied'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) saToast(context, label);
}

/// Pushed routes live above the portal's Theme widget, so every page opened
/// from the portal goes through this helper to keep the portal's look.
Route<T> saRoute<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => Theme(data: superAdminTheme(), child: page));

// ---------------------------------------------------------------- reveal animation

class SaReveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const SaReveal({super.key, required this.child, this.delayMs = 0});

  @override
  State<SaReveal> createState() => _SaRevealState();
}

class _SaRevealState extends State<SaReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delayMs == 0) {
      _c.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, (1 - _a.value) * 14), child: child),
      ),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------- page scaffold

class SaPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  const SaPage({super.key, required this.title, this.subtitle, this.actions = const [], required this.children, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final pad = c.maxWidth < 600 ? 16.0 : 28.0;
      final narrow = c.maxWidth < 640;
      final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Sa.text, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(color: Sa.muted, fontSize: 14)),
        ],
      ]);
      final header = narrow || actions.isEmpty
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              titleBlock,
              if (actions.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: actions)],
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ]);

      final body = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SaReveal(child: header),
              const SizedBox(height: 22),
              ...children,
            ]),
          ),
        ),
      );
      if (onRefresh == null) return body;
      return RefreshIndicator(color: Sa.primaryHi, backgroundColor: Sa.card, onRefresh: onRefresh!, child: body);
    });
  }
}

class SaSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SaSectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(color: Sa.text, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
          if (trailing != null) trailing!,
        ]),
      );
}

// ---------------------------------------------------------------- card

class SaCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;
  const SaCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.accent});

  @override
  State<SaCard> createState() => _SaCardState();
}

class _SaCardState extends State<SaCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hover && interactive ? Sa.cardHi : Sa.card,
          borderRadius: BorderRadius.circular(Sa.radius),
          border: Border.all(color: _hover && interactive ? (widget.accent ?? Sa.primaryHi).withValues(alpha: 0.5) : Sa.border),
          boxShadow: _hover && interactive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))] : const [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Sa.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: widget.onTap, child: Padding(padding: widget.padding, child: widget.child)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- stat tile

class SaStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final num value;
  final String? note;
  final SaTone tone;
  const SaStatTile({super.key, required this.icon, required this.label, required this.value, this.note, this.tone = SaTone.primary});

  @override
  Widget build(BuildContext context) {
    final c = saToneColor(tone);
    return SaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: c, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Sa.muted, fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(saCount(v), style: const TextStyle(color: Sa.text, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
        ),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(note!, style: const TextStyle(color: Sa.faint, fontSize: 12)),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------- chips, avatar

class SaChip extends StatelessWidget {
  final String label;
  final SaTone tone;
  final IconData? icon;
  const SaChip(this.label, {super.key, this.tone = SaTone.neutral, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = saToneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class SaAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const SaAvatar(this.name, {super.key, this.size = 40, this.color});

  static const _palette = [Color(0xFF6366F1), Color(0xFF0EA5E9), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF14B8A6)];

  @override
  Widget build(BuildContext context) {
    final c = color ?? _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.65)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(saInitials(name), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

// ---------------------------------------------------------------- states

class SaEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const SaEmpty({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, color: Sa.faint, size: 30),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Sa.text, fontSize: 16, fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: Sa.muted, fontSize: 13))),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

class SaErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const SaErrorState(this.error, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) => SaEmpty(
        icon: Icons.cloud_off_rounded,
        title: 'Something went wrong',
        message: '$error'.replaceFirst('Exception: ', ''),
        action: onRetry == null ? null : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Try again')),
      );
}

class SaSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const SaSkeleton({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  State<SaSkeleton> createState() => _SaSkeletonState();
}

class _SaSkeletonState extends State<SaSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04 + 0.05 * _c.value), borderRadius: BorderRadius.circular(widget.radius)),
        ),
      );
}

class SaCardSkeleton extends StatelessWidget {
  final int count;
  final double minWidth;
  const SaCardSkeleton({super.key, this.count = 3, this.minWidth = 300});

  @override
  Widget build(BuildContext context) => SaGrid(
        minItemWidth: minWidth,
        children: List.generate(
          count,
          (_) => const SaCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SaSkeleton(width: 140, height: 18),
              SizedBox(height: 12),
              SaSkeleton(width: 200, height: 12),
              SizedBox(height: 22),
              SaSkeleton(height: 12),
              SizedBox(height: 8),
              SaSkeleton(width: 120, height: 12),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------- grid

class SaGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  const SaGrid({super.key, required this.children, this.minItemWidth = 300, this.spacing = 14});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / minItemWidth).floor().clamp(1, 6);
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < children.length; i++) SizedBox(width: w, child: SaReveal(delayMs: 40 * (i % 8), child: children[i])),
          ],
        );
      });
}

// ---------------------------------------------------------------- inputs

class SaField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const SaField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Sa.text),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon, color: Sa.faint, size: 20),
          suffixIcon: suffix,
        ),
      );
}

class SaSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const SaSearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Sa.text),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, color: Sa.faint),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      );
}

class SaSegmented<T> extends StatelessWidget {
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  const SaSegmented({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Sa.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final e in options.entries)
            GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: e.key == value ? Sa.primary : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                child: Text(e.value, style: TextStyle(color: e.key == value ? Colors.white : Sa.muted, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      );
}

// ---------------------------------------------------------------- dialog

class SaDialog extends StatelessWidget {
  final IconData? icon;
  final SaTone tone;
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;
  const SaDialog({super.key, this.icon, this.tone = SaTone.primary, required this.title, this.subtitle, required this.child, this.actions = const [], this.maxWidth = 460});

  @override
  Widget build(BuildContext context) {
    final c = saToneColor(tone);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (icon != null) ...[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: c, size: 22),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: Sa.text, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: const TextStyle(color: Sa.muted, fontSize: 13))],
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            Flexible(child: SingleChildScrollView(child: child)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 22),
              Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: actions),
            ],
          ]),
        ),
      ),
    );
  }
}

Future<bool> saConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
  IconData icon = Icons.help_outline_rounded,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => SaDialog(
      icon: icon,
      tone: danger ? SaTone.danger : SaTone.primary,
      title: title,
      maxWidth: 420,
      child: Text(message, style: const TextStyle(color: Sa.muted, fontSize: 14, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r == true;
}

/// Small label : value row used in detail panels.
class SaKeyValue extends StatelessWidget {
  final String label;
  final String? value;
  final bool copyable;
  const SaKeyValue(this.label, this.value, {super.key, this.copyable = false});

  @override
  Widget build(BuildContext context) {
    final v = (value == null || value!.trim().isEmpty) ? '-' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Sa.faint, fontSize: 13))),
        Expanded(child: SelectableText(v, style: const TextStyle(color: Sa.text, fontSize: 13.5, fontWeight: FontWeight.w500))),
        if (copyable && v != '-')
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => saCopy(context, v, label: '$label copied'),
            child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 15, color: Sa.faint)),
          ),
      ]),
    );
  }
}