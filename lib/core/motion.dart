import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Fades and slides a section up into place the first time it scrolls
/// into view. Only plays once per widget instance (won't re-trigger
/// every time you scroll past it), which is what makes a page feel
/// "alive" without becoming distracting.
class RevealOnScroll extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const RevealOnScroll({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ObjectKey(widget),
      onVisibilityChanged: (info) {
        if (!_visible && info.visibleFraction > 0.12) {
          Future.delayed(widget.delay, () {
            if (mounted) setState(() => _visible = true);
          });
        }
      },
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, 0.06),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Subtle lift-and-shadow on hover (web/desktop) - a no-op on touch
/// devices since there's no hover concept there, so it never gets in
/// the way on mobile.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double liftPixels;
  final VoidCallback? onTap;

  const HoverLift({super.key, required this.child, this.liftPixels = 6, this.onTap});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovering ? -widget.liftPixels : 0, 0),
          decoration: BoxDecoration(
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Elevates the navbar with a soft shadow once the page has scrolled
/// past a small threshold - a standard modern-site cue that content
/// is moving underneath a "docked" bar.
class ScrollElevation extends StatefulWidget {
  final ScrollController controller;
  final Widget Function(BuildContext context, bool elevated) builder;

  const ScrollElevation({super.key, required this.controller, required this.builder});

  @override
  State<ScrollElevation> createState() => _ScrollElevationState();
}

class _ScrollElevationState extends State<ScrollElevation> {
  bool _elevated = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    final next = widget.controller.offset > 8;
    if (next != _elevated) setState(() => _elevated = next);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _elevated);
}