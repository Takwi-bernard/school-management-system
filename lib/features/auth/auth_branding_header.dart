import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../landing/landing_model.dart';

/// Shared animated header (logo, school name, motto) used across
/// every auth screen - reused rather than duplicated, and gives every
/// auth page the same "this belongs to Sacred Heart Academy" identity
/// the landing page already establishes.
class AuthBrandingHeader extends StatelessWidget {
  final LandingModel school;
  final String subtitle;

  const AuthBrandingHeader({super.key, required this.school, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RevealOnScroll(
      child: Column(
        children: [
          if (school.logoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                school.logoUrl,
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.school_rounded,
                    size: 56, color: theme.colorScheme.primary),
              ),
            )
          else
            Icon(Icons.school_rounded, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            school.schoolName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (school.motto.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              school.motto,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.outline),
            ),
          ],
          const SizedBox(height: 22),
          Text(subtitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Consistent card/scaffold wrapper for every auth page - dynamic
/// school theme, centered card, gradient backdrop matching the
/// landing page's visual language instead of a flat white screen.
class AuthScaffold extends StatelessWidget {
  final LandingModel school;
  final Widget child;
  final double maxWidth;

  const AuthScaffold({
    super.key,
    required this.school,
    required this.child,
    this.maxWidth = 460,
  });

  @override
  Widget build(BuildContext context) {
    final primary = _parseColor(school.primaryColor);
    final secondary = _parseColor(school.secondaryColor);
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.06),
                theme.colorScheme.secondary.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
                // FIX: there was previously no way to return to the
                // public landing page from any auth screen - a
                // visitor who clicked Sign In "just to look" had no
                // way back. Always visible, goes home explicitly.
                // Redesigned as a soft glass pill rather than a plain
                // filled circle, matching the rest of the page's style.
                Positioned(
                  top: 8,
                  left: 8,
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_rounded, size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Text('Home',
                                    style: theme.textTheme.labelLarge
                                        ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF1A73E8);
  }
}