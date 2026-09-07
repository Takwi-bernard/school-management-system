import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../core/browser_chrome.dart';
import '../../core/motion.dart';
import '../../core/school_color.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

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
    // FIX: previously each of several files had its own private
    // _parseColor with a fallback of 0xFF1A73E8 - a real, plausible-
    // looking BLUE. If school.primaryColor ever failed to parse (empty,
    // null, unexpected format), you'd silently get that blue instead
    // of any indication something was wrong - which is exactly what
    // "the button is blue even though the school is orange" looks
    // like from the outside. Now shared, and falls back to an obvious
    // gray with a console warning instead.
    final primary = parseSchoolColor(school.primaryColor, debugLabel: 'AuthScaffold primary');
    final secondary = parseSchoolColor(school.secondaryColor, debugLabel: 'AuthScaffold secondary');
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary),
    );
    // Every auth page gets this automatically now, instead of each
    // page needing to remember to call it itself.
    updateBrowserChromeColor(primary);

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
}

/// Fires on every sign-in, sign-out, token refresh, and - critically -
/// when Supabase finishes parsing an OAuth redirect. sessionProfileProvider
/// below watches this so it recomputes at the right moment instead of
/// only checking currentSession once at first build (which can run
/// BEFORE Supabase has finished handling the redirect on web).
final authStateChangesProvider = StreamProvider<supa.AuthState>((ref) {
  return supa.Supabase.instance.client.auth.onAuthStateChange;
});

/// Checks whether there's an ALREADY-VALID Supabase session (e.g. the
/// person refreshed the page after signing in, or just landed back
/// from an OAuth redirect) and, if so, validates it belongs to the
/// CURRENT school - not just that a session exists. This is what
/// makes "stay signed in across a page reload / OAuth redirect" work
/// without weakening the tenant-isolation check.
final sessionProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, expectedSchoolId) async {
  // Re-run this provider whenever auth state actually changes, instead
  // of computing once and going stale.
  ref.watch(authStateChangesProvider);

  final session = supa.Supabase.instance.client.auth.currentSession;
  if (session == null) return null;

  final repo = ref.watch(authRepositoryProvider);
  final profile = await repo.fetchProfile(session.user.id);

  if (profile == null || profile.role == 'super_admin' || profile.schoolId != expectedSchoolId) {
    await repo.signOut();
    return null;
  }
  return profile;
});

/// Route guard + role placeholder in one. Used for every /parent,
/// /teacher, /principal, /secretary, /proprietor route until each
/// role's real dashboard is built.
class RoleGate extends ConsumerWidget {
  final String requiredRole;
  final String label;

  const RoleGate({super.key, required this.requiredRole, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (school) {
        final sessionAsync = ref.watch(sessionProfileProvider(school.schoolId));

        return sessionAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (profile) {
            if (profile == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/sign-in'));
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profile.role != requiredRole) {
              return Scaffold(
                body: Center(child: Text('This account is a ${profile.role} account, not $label.')),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: Text('$label Dashboard - ${school.schoolName}'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (context.mounted) context.go('/');
                    },
                  ),
                ],
              ),
              body: Center(
                child: Text('$label dashboard - coming next.', style: Theme.of(context).textTheme.titleMedium),
              ),
            );
          },
        );
      },
    );
  }
}