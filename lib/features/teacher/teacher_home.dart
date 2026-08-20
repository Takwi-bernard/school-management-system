import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_providers.dart';
import 'teacher_assignment_detail.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';
import 'teacher_timetable.dart';

/// Entry point for the whole Teacher module. Branches internally
/// between the pending-approval screen and the real dashboard -
/// combined in one file/widget rather than a separate router-level
/// gate, since it's really one decision, not two pages.
class TeacherHome extends ConsumerWidget {
  const TeacherHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (school) {
        // Security gate: confirms there's a valid session AND that it
        // belongs to THIS school (not a leftover session from a
        // different school's site) before showing anything teacher-
        // specific. Signs out and redirects to sign-in if not - same
        // check every other role's RoleGate uses.
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
              return Scaffold(
                body: Center(child: Text('This account is a ${session.role} account, not Teacher.')),
              );
            }
            return const _TeacherProfileGate();
          },
        );
      },
    );
  }
}

/// Once the session is confirmed valid for this school and this role,
/// fetch the richer teacher-specific profile (approval status, etc).
class _TeacherProfileGate extends ConsumerWidget {
  const _TeacherProfileGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider).value!;
    final profileAsync = ref.watch(teacherProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Your teacher profile could not be found.')));
        }

        final theme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _parseColor(landing.primaryColor)),
        );

        return Theme(
          data: theme,
          child: profile.isApproved
              ? _TeacherDashboard(profile: profile, schoolName: landing.schoolName, logoUrl: landing.logoUrl)
              : _PendingApproval(
                  schoolName: landing.schoolName,
                  motto: landing.motto,
                  logoUrl: landing.logoUrl,
                  principalEmail: landing.email,
                  rejected: profile.isRejected,
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

  const _PendingApproval({
    required this.schoolName,
    required this.motto,
    required this.logoUrl,
    required this.principalEmail,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      body: SafeArea(
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
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 20)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (logoUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(logoUrl, width: 72, height: 72, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, size: 56, color: theme.colorScheme.primary)),
                        )
                      else
                        Icon(Icons.school_rounded, size: 56, color: theme.colorScheme.primary),
                      const SizedBox(height: 14),
                      Text(schoolName, textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      if (motto.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(motto, textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 28),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: rejected
                              ? theme.colorScheme.errorContainer
                              : theme.colorScheme.primaryContainer,
                        ),
                        child: Icon(
                          rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
                          size: 34,
                          color: rejected ? theme.colorScheme.error : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        rejected ? 'Application Not Approved' : 'Approval Pending',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        rejected
                            ? 'Your teacher application for this school was not approved. If you believe this is a mistake, please contact the Principal.'
                            : 'Your account has been created, but you have not yet been approved as a teacher of this school. Please wait for the Principal to approve your account, or contact them directly below.',
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(children: [
                            Text('Contact the school', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            SelectableText(principalEmail,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                          ]),
                        ),
                      const SizedBox(height: 22),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(authControllerProvider.notifier).signOut();
                          if (context.mounted) context.go('/');
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign Out'),
                      ),
                    ],
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

class _TeacherDashboard extends ConsumerWidget {
  final TeacherProfile profile;
  final String schoolName;
  final String logoUrl;

  const _TeacherDashboard({required this.profile, required this.schoolName, required this.logoUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(schoolName),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'My Timetable',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherTimetablePage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (assignments) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.pagePadding(context)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome, ${profile.fullName}',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Here are the subjects and classes assigned to you.',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    if (assignments.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(children: [
                              Icon(Icons.assignment_late_outlined, size: 44, color: theme.colorScheme.outline),
                              const SizedBox(height: 12),
                              const Text('No teaching assignments yet.', textAlign: TextAlign.center),
                            ]),
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: assignments.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isMobile ? 3.4 : 3.0,
                        ),
                        itemBuilder: (context, i) {
                          final a = assignments[i];
                          return HoverLift(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeacherAssignmentDetailPage(profile: profile, assignment: a),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.menu_book_outlined, color: theme.colorScheme.onPrimary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(a.subjectName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                    Text(a.className, style: theme.textTheme.bodySmall),
                                  ]),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                                  child: Text('Coef. ${a.coefficient}', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                              ]),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
