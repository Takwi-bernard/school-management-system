import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../auth/auth_gate.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';
import 'teacher_shell.dart';
import 'teacher_sign_out.dart';
import 'teacher_ui.dart';

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
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      body: Stack(
        children: [
          // Soft decorative color washes in the corners, using the
          // SCHOOL's own primary/secondary - not fixed colors - so
          // this still feels distinctly theirs, not a generic
          // template screen.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.06),
                  theme.colorScheme.surface,
                  theme.colorScheme.secondary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -90, right: -70, child: _Blob(color: theme.colorScheme.primary, size: 260)),
          Positioned(bottom: -110, left: -90, child: _Blob(color: theme.colorScheme.secondary, size: 300)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: RevealOnScroll(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 620 : 560),
                    child: Container(
                      padding: EdgeInsets.all(isWide ? 44 : 32),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 50, offset: const Offset(0, 24)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (logoUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(logoUrl, width: 80, height: 80, fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, size: 56, color: theme.colorScheme.primary)),
                            )
                          else
                            Icon(Icons.school_rounded, size: 56, color: theme.colorScheme.primary),
                          const SizedBox(height: 18),
                          Text(schoolName, textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                          if (motto.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(motto, textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                          const SizedBox(height: 36),
                          // A LOOPING pulse for "pending" (still in
                          // progress) vs. a static icon for "rejected"
                          // (a finished, settled state) - the motion
                          // itself communicates which situation this is,
                          // before the teacher even reads the text.
                          rejected
                              ? _StatusIcon(theme: theme, rejected: true)
                              : _PulsingRing(
                                  color: theme.colorScheme.primary,
                                  child: _StatusIcon(theme: theme, rejected: false),
                                ),
                          const SizedBox(height: 28),
                          Text(
                            rejected ? strings.applicationNotApproved : strings.approvalPending,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            rejected ? strings.rejectedMessage : strings.pendingApprovalMessage,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          if (!rejected) ...[
                            const SizedBox(height: 32),
                            _ApprovalStepper(theme: theme, strings: strings),
                          ],
                          if (principalEmail.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            TeacherCard(
                              child: Row(children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(Icons.mail_outline_rounded, color: theme.colorScheme.primary, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(strings.contactSchool,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      SelectableText(principalEmail,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          ],
                          const SizedBox(height: 28),
                          TeacherSignOutButton(strings: strings),
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
    );
  }
}

/// Soft, out-of-focus color wash in a corner - purely decorative, and
/// built from the school's own primary/secondary so it's never the
/// same two colors for every school.
class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final ThemeData theme;
  final bool rejected;
  const _StatusIcon({required this.theme, required this.rejected});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        color: rejected ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
      ),
    );
  }
}

/// A slow, looping "breathing" ring - communicates "still waiting,
/// nothing is broken" at a glance, before the teacher reads a word.
class _PulsingRing extends StatefulWidget {
  final Color color;
  final Widget child;
  const _PulsingRing({required this.color, required this.child});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84 + t * 46,
                height: 84 + t * 46,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: (1 - t) * 0.22)),
              ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Created -> Awaiting Approval -> Full Access. Only shown while
/// pending (not rejected) - gives the teacher a sense of process and
/// where they stand in it, instead of an open-ended "please wait."
class _ApprovalStepper extends StatelessWidget {
  final ThemeData theme;
  final AppStrings strings;
  const _ApprovalStepper({required this.theme, required this.strings});

  @override
  Widget build(BuildContext context) {
    // (label, done, current)
    final steps = [
      (strings.stepAccountCreated, true, false),
      (strings.stepAwaitingApproval, false, true),
      (strings.stepFullAccess, false, false),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: steps[i].$2
                        ? theme.colorScheme.primary
                        : steps[i].$3
                            ? theme.colorScheme.primary.withValues(alpha: 0.14)
                            : theme.colorScheme.surfaceContainerHighest,
                    border: steps[i].$3 ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                  ),
                  child: steps[i].$2
                      ? Icon(Icons.check_rounded, size: 16, color: theme.colorScheme.onPrimary)
                      : steps[i].$3
                          ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary),
                              ),
                            )
                          : null,
                ),
                const SizedBox(height: 8),
                Text(steps[i].$1,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: steps[i].$3 ? FontWeight.w700 : FontWeight.w500,
                      color: steps[i].$3 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
          if (i != steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: SizedBox(
                width: 20,
                child: Divider(
                  height: 2,
                  thickness: 2,
                  color: steps[i].$2 ? theme.colorScheme.primary.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}