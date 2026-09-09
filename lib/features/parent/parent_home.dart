import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser_chrome.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/school_color.dart';
import '../auth/auth_gate.dart';
import '../landing/landing_providers.dart';
import 'parent_shell.dart';

/// Session gate only now - shell/sidebar moved to parent_shell.dart,
/// dashboard content to parent_dashboard_tab.dart. Mirrors
/// TeacherHome's shape. Parents don't have an approval-gate step
/// (self-registered, per the role table) so there's no pending-
/// approval branch here the way teacher has one.
class ParentHome extends ConsumerWidget {
  const ParentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (school) {
        final sessionAsync = ref.watch(sessionProfileProvider(school.schoolId));

        return sessionAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (session) {
            if (session == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/sign-in'));
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (session.role != 'parent') {
              return Scaffold(
                body: Center(child: Text('This account is a ${session.role} account, not Parent.')),
              );
            }

            // FIX: same blue-fallback bug already found (and fixed)
            // elsewhere - was school['primary_color'] as String? ??
            // '#1A73E8' equivalent via the old _parseColor in
            // parent_models.dart. Shared parseSchoolColor falls back
            // to neutral gray + a console warning instead.
            final primary = parseSchoolColor(school.primaryColor, debugLabel: 'ParentShell primary');
            final secondary = parseSchoolColor(school.secondaryColor, debugLabel: 'ParentShell secondary');
            updateBrowserChromeColor(primary);

            final theme = ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary),
            );

            return Theme(
              data: theme,
              child: ParentShell(schoolId: school.schoolId, landing: school, strings: AppStrings(locale)),
            );
          },
        );
      },
    );
  }
}