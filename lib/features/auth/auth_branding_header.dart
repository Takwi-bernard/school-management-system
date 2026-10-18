import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser_chrome.dart';
import '../../core/motion.dart';
import '../../core/school_color.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';

/// Width from which the auth screens use the two-panel layout (school
/// panel on the left, form on the right).
const double _kWideBreakpoint = 920;

bool authIsWide(BuildContext context) => MediaQuery.of(context).size.width >= _kWideBreakpoint;

/// A school logo shown at a fixed size whatever its shape: it is fitted
/// inside a square white tile with a little padding, never stretched or
/// cropped, so wide, tall or tiny logos all read the same.
class SchoolLogo extends StatelessWidget {
  final String url;
  final double size;
  const SchoolLogo({super.key, required this.url, this.size = 112});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallback = Icon(Icons.school_rounded, size: size * 0.5, color: cs.primary);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                opacity: (frame == null && !sync) ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: child,
              ),
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

/// Shared header for every auth screen. On a phone it shows the logo,
/// school name and motto above the form; on a wide screen those live in
/// the school panel instead, so only the page title is shown here.
class AuthBrandingHeader extends StatelessWidget {
  final LandingModel school;
  final String subtitle;

  const AuthBrandingHeader({super.key, required this.school, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = authIsWide(context);

    return RevealOnScroll(
      child: Column(
        crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (!wide) ...[
            SchoolLogo(url: school.logoUrl, size: 104),
            const SizedBox(height: 16),
            Text(
              school.schoolName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3),
            ),
            if (school.motto.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                school.motto,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.outline),
              ),
            ],
            const SizedBox(height: 22),
          ],
          Text(
            subtitle,
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.4),
          ),
        ],
      ),
    );
  }
}

/// Spinner that is readable on a filled (primary) button.
class AuthButtonSpinner extends StatelessWidget {
  const AuthButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: Theme.of(context).colorScheme.onPrimary),
      );
}

/// Page wrapper for every auth screen: the school's own theme (applied
/// to everything inside, buttons and fields included), the school panel
/// on wide screens, a back-to-home pill and, for bilingual schools, a
/// language switch.
class AuthScaffold extends ConsumerWidget {
  final LandingModel school;
  final Widget child;
  final double maxWidth;

  const AuthScaffold({super.key, required this.school, required this.child, this.maxWidth = 460});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = parseSchoolColor(school.primaryColor, debugLabel: 'AuthScaffold primary');
    final secondary = parseSchoolColor(school.secondaryColor, debugLabel: 'AuthScaffold secondary');
    updateBrowserChromeColor(primary);

    final base = ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary);
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: base,
      // Every field and button inside the auth screens picks these up,
      // so nothing needs its own colours.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: base.outlineVariant.withValues(alpha: 0.6))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primary, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: base.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: base.error, width: 1.8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );

    final locale = ref.watch(activeLocaleProvider);
    final fr = locale.languageCode == 'fr';
    final wide = authIsWide(context);

    final form = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, wide ? 48 : 64, 24, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: wide
              ? child
              : Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 20))],
                  ),
                  child: child,
                ),
        ),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          children: [
            if (wide)
              Row(children: [
                Expanded(flex: 5, child: _SchoolPanel(school: school)),
                Expanded(flex: 6, child: form),
              ])
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary.withValues(alpha: 0.07), theme.colorScheme.secondary.withValues(alpha: 0.12)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(child: form),
              ),
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: HoverLift(
                  liftPixels: 2,
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  child: _GlassPill(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.arrow_back_rounded, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(fr ? 'Accueil' : 'Home', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),
            if (school.languageMode == 'bilingual')
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: _GlassPill(
                    padding: const EdgeInsets.all(4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final code in const ['en', 'fr'])
                        GestureDetector(
                          onTap: () => ref.read(localeOverrideProvider.notifier).state = Locale(code),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: locale.languageCode == code ? theme.colorScheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              code.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: locale.languageCode == code ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _GlassPill({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10)});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Left side of the wide layout: the school's identity on its own colour.
class _SchoolPanel extends StatelessWidget {
  final LandingModel school;
  const _SchoolPanel({required this.school});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Color.lerp(cs.primary, Colors.black, 0.35) ?? cs.primary;
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primary, dark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Stack(children: [
        Positioned(right: -90, top: -90, child: _Orb(size: 320, color: cs.secondary.withValues(alpha: 0.22))),
        Positioned(left: -70, bottom: -110, child: _Orb(size: 300, color: Colors.white.withValues(alpha: 0.07))),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: RevealOnScroll(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SchoolLogo(url: school.logoUrl, size: 156),
                const SizedBox(height: 28),
                Text(
                  school.schoolName,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onPrimary, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.15),
                ),
                if (school.motto.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    school.motto,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85), fontSize: 16, fontStyle: FontStyle.italic, height: 1.4),
                  ),
                ],
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
