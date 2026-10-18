import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

// AuthScaffold / AuthBrandingHeader live in one place now; re-exported so
// existing imports of auth_gate.dart keep working.
export 'auth_branding_header.dart';

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

/// Redirects to the right dashboard the moment a valid session for
/// THIS school is found - covers a fresh email/password sign-in,
/// a returning already-signed-in visitor, AND Google's OAuth flow,
/// where the whole page reloads on redirect and Supabase may have
/// ALREADY established the session by the time a widget starts
/// listening.
///
/// ref.listen alone only fires on FUTURE changes, which would miss a
/// session that's already sitting there at registration time - and
/// this Riverpod version's ref.listen doesn't support a
/// fireImmediately parameter to cover that (confirmed: it doesn't
/// compile here). So this checks the CURRENT value directly right
/// after registering the listener - if the provider already resolved
/// to a signed-in profile, that's handled immediately; if it's still
/// loading, ref.listen above catches it normally once it completes.
/// [routeFor] returns null for a role this call site doesn't want to
/// redirect for.
void redirectIfSignedIn(
  WidgetRef ref,
  BuildContext context,
  String schoolId,
  String? Function(String role) routeFor,
) {
  void handle(UserProfile? profile) {
    if (profile == null) return;
    final route = routeFor(profile.role);
    if (route != null && context.mounted) context.go(route);
  }

  ref.listen(sessionProfileProvider(schoolId), (previous, next) {
    next.whenData(handle);
  });

  ref.read(sessionProfileProvider(schoolId)).whenData(handle);
}

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