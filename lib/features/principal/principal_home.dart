import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import 'principal_classes.dart';
import 'principal_models.dart';
import 'principal_providers.dart';
import 'principal_teachers.dart';
import 'principal_marks.dart';
import 'principal_report_card.dart';
class PrincipalHome extends ConsumerWidget {
  const PrincipalHome({super.key});

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
            if (session.role != 'principal') {
              return Scaffold(body: Center(child: Text('This account is a ${session.role} account, not Principal.')));
            }
            return Theme(
              data: buildSchoolTheme(school.primaryColor, school.secondaryColor),
              child: _PrincipalShell(schoolId: school.schoolId, landing: school, strings: AppStrings(locale)),
            );
          },
        );
      },
    );
  }
}

class _NavGroup {
  final IconData icon;
  final String title;
  final List<_NavLeaf> items;
  const _NavGroup({required this.icon, required this.title, required this.items});
}

class _NavLeaf {
  final String title;
  final String description;
  final VoidCallback onTap;
  const _NavLeaf({required this.title, required this.description, required this.onTap});
}

class _PrincipalShell extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const _PrincipalShell({required this.schoolId, required this.landing, required this.strings});

  @override
  ConsumerState<_PrincipalShell> createState() => _PrincipalShellState();
}

class _PrincipalShellState extends ConsumerState<_PrincipalShell> {
  Widget _body = const _WelcomePane();

  List<_NavGroup> _buildGroups() {
    final strings = widget.strings;
    return [
      _NavGroup(
        icon: Icons.class_outlined,
        title: strings.isFrench ? 'Classes et matières' : 'Classes & Subjects',
        items: [
          _NavLeaf(
            title: strings.isFrench ? 'Gérer les classes' : 'Manage Classes',
            description: strings.isFrench ? 'Créer, modifier et désactiver des classes.' : 'Create, edit, and deactivate classes.',
            onTap: () => setState(() => _body = ManageClassesPage(schoolId: widget.schoolId)),
          ),
          _NavLeaf(
            title: strings.isFrench ? 'Gérer les matières' : 'Manage Subjects',
            description: strings.isFrench ? 'Ajouter des matières et les assigner aux classes.' : 'Add subjects and assign them to classes.',
            onTap: () => setState(() => _body = ManageSubjectsPage(schoolId: widget.schoolId)),
          ),
          _NavLeaf(
            title: strings.isFrench ? 'Frais scolaires' : 'School Fees',
            description: strings.isFrench ? 'Définir les frais d\'inscription et les versements par classe.' : 'Set registration fees and installments per class.',
            onTap: () => setState(() => _body = ManageFeesEntryPage(schoolId: widget.schoolId)),
          ),
        ],
      ),
            _NavGroup(
        icon: Icons.people_outline_rounded,
        title: strings.isFrench ? 'Gestion des enseignants' : 'Teacher Management',
        items: [
          _NavLeaf(
            title: strings.isFrench ? 'Demandes en attente' : 'Pending Approvals',
            description: strings.isFrench ? 'Approuver ou refuser les nouvelles candidatures.' : 'Approve or reject new teacher applications.',
            onTap: () => setState(() => _body = PendingTeachersPage(schoolId: widget.schoolId)),
          ),
          _NavLeaf(
            title: strings.isFrench ? 'Enseignants' : 'Teachers',
            description: strings.isFrench ? 'Gérer les affectations de matières et de classes.' : 'Manage subject and class assignments.',
            onTap: () => setState(() => _body = ApprovedTeachersPage(schoolId: widget.schoolId)),
          ),
        ],
      ),
      _NavGroup(
        icon: Icons.family_restroom_outlined,
        title: strings.isFrench ? 'Admissions et élèves' : 'Admissions & Students',
        items: [
          _NavLeaf(
            title: strings.isFrench ? 'Bientôt disponible' : 'Coming soon',
            description: '',
            onTap: () {},
          ),
        ],
      ),
            _NavGroup(
        icon: Icons.assessment_outlined,
        title: strings.isFrench ? 'Bulletins et commentaires' : 'Report Cards & Comments',
        items: [
          _NavLeaf(
            title: strings.isFrench ? 'Gérer les bulletins' : 'Manage Report Cards',
            description: strings.isFrench ? 'Générer et publier les bulletins scolaires.' : 'Generate and publish report cards.',
            onTap: () => setState(() => _body = ReportCardManagementPage(schoolId: widget.schoolId)),
          ),
        ],
      ),
            _NavGroup(
        icon: Icons.grading_outlined,
        title: strings.isFrench ? 'Notes et évaluations' : 'Marks & Evaluations',
        items: [
          _NavLeaf(
            title: strings.isFrench ? 'Fenêtre de saisie' : 'Marks Entry Window',
            description: strings.isFrench ? 'Ouvrir ou fermer la saisie des notes.' : 'Open or close marks entry per sequence.',
            onTap: () => setState(() => _body = MarksWindowPage(schoolId: widget.schoolId)),
          ),
          _NavLeaf(
            title: strings.isFrench ? 'Réviser les notes' : 'Review Marks',
            description: strings.isFrench ? 'Approuver, renvoyer ou rejeter les notes soumises.' : 'Approve, send back, or discard submitted marks.',
            onTap: () => setState(() => _body = MarksReviewPage(schoolId: widget.schoolId)),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final groups = _buildGroups();

    if (isMobile) {
      return Scaffold(
        appBar: _StaticAppBar(landing: widget.landing),
        drawer: Drawer(child: _SidebarContent(landing: widget.landing, strings: widget.strings, groups: groups, isDrawer: true, onSelect: (b) => setState(() => _body = b))),
        body: _body,
      );
    }

    return Scaffold(
      appBar: _StaticAppBar(landing: widget.landing, showMenuIcon: false),
      body: Row(
        children: [
          SizedBox(
            width: 300,
            child: _SidebarContent(landing: widget.landing, strings: widget.strings, groups: groups, isDrawer: false, onSelect: (b) => setState(() => _body = b)),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _body),
        ],
      ),
    );
  }
}

class _StaticAppBar extends StatelessWidget implements PreferredSizeWidget {
  final LandingModel landing;
  final bool showMenuIcon;
  const _StaticAppBar({required this.landing, this.showMenuIcon = true});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      automaticallyImplyLeading: showMenuIcon,
      titleSpacing: 12,
      title: Row(
        children: [
          if (landing.logoUrl.isNotEmpty)
            Container(
              width: 36, height: 36, padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Image.network(landing.logoUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 20)),
            ),
          const SizedBox(width: 10),
          Expanded(child: Text(landing.schoolName, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _SidebarContent extends ConsumerWidget {
  final LandingModel landing;
  final AppStrings strings;
  final List<_NavGroup> groups;
  final bool isDrawer;
  final void Function(Widget) onSelect;
  const _SidebarContent({required this.landing, required this.strings, required this.groups, required this.isDrawer, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(principalProfileProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.88), theme.colorScheme.secondary],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: profileAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (profile) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.welcomeBack, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(profile?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: groups
                    .map((g) => Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Icon(g.icon, color: Colors.white),
                            title: Text(g.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            iconColor: Colors.white70,
                            collapsedIconColor: Colors.white70,
                            children: g.items
                                .map((item) => ListTile(
                                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                                      title: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                      subtitle: item.description.isEmpty
                                          ? null
                                          : Text(item.description, style: const TextStyle(color: Colors.white60, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      onTap: () {
                                        if (isDrawer) Navigator.pop(context);
                                        item.onTap();
                                      },
                                    ))
                                .toList(),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.white),
              title: Text(strings.signOut, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onTap: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _WelcomePane extends StatelessWidget {
  const _WelcomePane();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_customize_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Select a section from the menu to get started.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}