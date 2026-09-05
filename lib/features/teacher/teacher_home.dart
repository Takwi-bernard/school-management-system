import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';
import 'teacher_shell.dart';

class TeacherHome extends ConsumerWidget {
  const TeacherHome({super.key});

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
            if (session.role != 'teacher') {
              // FLAG: bare unstyled fallback - fine as a rare
              // mis-routed-account guard, but worth a proper error
              // card (icon + message + "go to your dashboard" link)
              // in a later pass if it's ever hit in practice.
              return Scaffold(
                body: Center(child: Text('This account is a ${session.role} account, not Teacher.')),
              );
            }
            return _TeacherProfileGate(locale: locale);
          },
        );
      },
    );
  }
}

class _TeacherProfileGate extends ConsumerWidget {
  final Locale locale;
  const _TeacherProfileGate({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider).value!;
    final profileAsync = ref.watch(teacherProfileProvider);
    final strings = AppStrings(locale);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (profile) {
        if (profile == null) {
          return Scaffold(body: Center(child: Text(strings.profileNotFound)));
        }

        final primary = _parseColor(landing.primaryColor);
        final secondary = _parseColor(landing.secondaryColor);
        final theme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary),
        );

        return Theme(
          data: theme,
          child: profile.isApproved
              ? TeacherShell(
                  profile: profile,
                  schoolName: landing.schoolName,
                  logoUrl: landing.logoUrl,
                  strings: strings,
                )
              : _PendingApproval(
                  schoolName: landing.schoolName,
                  motto: landing.motto,
                  logoUrl: landing.logoUrl,
                  principalEmail: landing.email,
                  rejected: profile.isRejected,
                  strings: strings,
                ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    var v = hex.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    return Color(int.tryParse(v, radix: 16) ?? 0xFF1A73E8);
  }
}

class _PendingApproval extends ConsumerWidget {
  final String schoolName;
  final String motto;
  final String logoUrl;
  final String principalEmail;
  final bool rejected;
  final AppStrings strings;

  const _PendingApproval({
    required this.schoolName,
    required this.motto,
    required this.logoUrl,
    required this.principalEmail,
    required this.rejected,
    required this.strings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.colorScheme.secondary.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: RevealOnScroll(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 44, offset: const Offset(0, 22)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (logoUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(logoUrl, width: 76, height: 76, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, size: 56, color: theme.colorScheme.primary)),
                          )
                        else
                          Icon(Icons.school_rounded, size: 56, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(schoolName, textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        if (motto.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(motto, textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 30),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.85, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: rejected
                                  ? [theme.colorScheme.error, theme.colorScheme.error.withValues(alpha: 0.7)]
                                  : [theme.colorScheme.primary, theme.colorScheme.secondary]),
                            ),
                            child: Icon(
                              rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
                              size: 38,
                              // onError/onPrimary instead of a fixed white:
                              // if a school picks a very light primary/error
                              // tone, Material computes the correct contrast
                              // color automatically instead of assuming white
                              // always reads well.
                              color: rejected ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          rejected ? strings.applicationNotApproved : strings.approvalPending,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          rejected ? strings.rejectedMessage : strings.pendingApprovalMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 22),
                        if (principalEmail.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(children: [
                              Text(strings.contactSchool, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              SelectableText(principalEmail,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                            ]),
                          ),
                        const SizedBox(height: 22),
                        HoverLift(
                          onTap: () async {
                            await ref.read(authControllerProvider.notifier).signOut();
                            if (context.mounted) context.go('/');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.logout_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(strings.signOut),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}