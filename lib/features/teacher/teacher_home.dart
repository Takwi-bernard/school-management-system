import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_providers.dart';
import 'teacher_assignment_detail.dart';
import 'teacher_models.dart';
import 'teacher_profile.dart';
import 'teacher_providers.dart';
import 'teacher_timetable.dart';

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
              ? _TeacherDashboard(profile: profile, schoolName: landing.schoolName, logoUrl: landing.logoUrl, strings: strings)
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
                              color: Colors.white,
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

class _TeacherDashboard extends ConsumerWidget {
  final TeacherProfile profile;
  final String schoolName;
  final String logoUrl;
  final AppStrings strings;

  const _TeacherDashboard({required this.profile, required this.schoolName, required this.logoUrl, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: 14),
                child: Row(children: [
                  if (logoUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(logoUrl, width: 36, height: 36, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary)),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(schoolName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month_outlined),
                    tooltip: strings.myTimetable,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherTimetablePage())),
                  ),
                  HoverLift(
                    liftPixels: 2,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherProfilePage(profile: profile))),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                      child: profile.photoUrl == null
                          ? Text(_initials(profile.fullName),
                              style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary, fontSize: 13))
                          : null,
                    ),
                  ),
                ]),
              ),
              RevealOnScroll(
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context)),
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.welcomeBack, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70)),
                      Text(profile.fullName,
                          style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context)),
                child: assignmentsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (assignments) {
                    final subjectCount = assignments.map((a) => a.subjectId).toSet().length;
                    final classCount = assignments.map((a) => a.classId).toSet().length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RevealOnScroll(
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: isMobile ? 0.95 : 1.6,
                            children: [
                              _StatCard(icon: Icons.menu_book_outlined, label: strings.subjectsLabel, value: '$subjectCount'),
                              _StatCard(icon: Icons.class_outlined, label: strings.classesLabel, value: '$classCount'),
                              _StatCard(icon: Icons.assignment_outlined, label: strings.assignmentsLabel, value: '${assignments.length}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(strings.myTeaching, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        if (assignments.isEmpty)
                          RevealOnScroll(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                                  child: Icon(Icons.assignment_late_outlined, size: 30, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(strings.noAssignmentsTitle,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                  strings.noAssignmentsDescription,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                                ),
                              ]),
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
                              return RevealOnScroll(
                                delay: Duration(milliseconds: i * 60),
                                child: HoverLift(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => TeacherAssignmentDetailPage(profile: profile, assignment: a)),
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
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
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
                                        child: Text('${strings.coefficientShort} ${a.coefficient}', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 30),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
