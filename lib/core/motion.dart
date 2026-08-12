import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// FIX: previously triggered once and never reset, so scrolling back
/// up (or back down past a section again) did nothing. Now toggles
/// visibility on EVERY crossing, in either scroll direction, so
/// sections consistently animate in/out as you scroll past them.
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
        final shouldBeVisible = info.visibleFraction > 0.12;
        if (shouldBeVisible != _visible && mounted) {
          setState(() => _visible = shouldBeVisible);
        }
      },
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, 0.06),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/// FIX: previously only responded to mouse hover, so touch/mobile got
/// zero feedback (desktop-only motion). Now ALSO responds to
/// tap-down/tap-up with the same lift+shadow animation, so mobile
/// gets equivalent motion via press feedback instead of hover.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double liftPixels;
  final VoidCallback? onTap;

  const HoverLift({super.key, required this.child, this.liftPixels = 6, this.onTap});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _active = false;

  void _setActive(bool value) {
    if (_active != value && mounted) setState(() => _active = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setActive(true),
      onExit: (_) => _setActive(false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setActive(true),
        onTapUp: (_) => _setActive(false),
        onTapCancel: () => _setActive(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _active ? -widget.liftPixels : 0, 0),
          decoration: BoxDecoration(
            boxShadow: _active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
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