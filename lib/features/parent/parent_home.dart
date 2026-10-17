import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser_chrome.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/school_color.dart';
import '../auth/auth_gate.dart';
import '../landing/landing_providers.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_shell.dart';
import 'parent_ui.dart';

/// Session gate only - the shell/sidebar lives in parent_shell.dart and
/// the dashboard in parent_dashboard_tab.dart. Parents self-register, so
/// there is no approval-gate step here the way teachers have one.
class ParentHome extends ConsumerWidget {
  const ParentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);
    final strings = AppStrings(locale);

    Widget loader() => const Scaffold(body: Padding(padding: EdgeInsets.all(24), child: PrPageSkeleton()));
    Widget failure(Object e, VoidCallback retry) => Scaffold(
          body: Center(child: Padding(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: PaError(error: e, strings: strings, onRetry: retry)))),
        );

    return landing.when(
      skipLoadingOnReload: true,
      loading: loader,
      error: (e, _) => failure(e, () => ref.invalidate(landingProvider)),
      data: (school) {
        final sessionAsync = ref.watch(sessionProfileProvider(school.schoolId));

        return sessionAsync.when(
          skipLoadingOnReload: true,
          loading: loader,
          error: (e, _) => failure(e, () => ref.invalidate(sessionProfileProvider(school.schoolId))),
          data: (session) {
            if (session == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/sign-in'));
              return loader();
            }
            if (session.role != 'parent') {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      strings.isFrench ? 'Ce compte est un compte ${session.role}, pas Parent.' : 'This account is a ${session.role} account, not Parent.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            // Shared parser: falls back to neutral gray + a console
            // warning instead of a misleading default blue.
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
