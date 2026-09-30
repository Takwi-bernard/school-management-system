import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import '../parent/parent_models.dart' show buildSchoolTheme;
import 'secretary_enrollment.dart';
import 'secretary_payments.dart';
import 'secretary_providers.dart';

class SecretaryHome extends ConsumerWidget {
  const SecretaryHome({super.key});

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
            if (session.role != 'secretary') {
              return Scaffold(body: Center(child: Text('This account is a ${session.role} account, not Secretary.')));
            }
            return Theme(
              data: buildSchoolTheme(school.primaryColor, school.secondaryColor),
              child: _SecretaryShell(landing: school, strings: AppStrings(locale)),
            );
          },
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String title;
  final String description;
  final int index;
  const _NavItem({required this.icon, required this.title, required this.description, required this.index});
}

class _SecretaryShell extends ConsumerStatefulWidget {
  final LandingModel landing;
  final AppStrings strings;
  const _SecretaryShell({required this.landing, required this.strings});

  @override
  ConsumerState<_SecretaryShell> createState() => _SecretaryShellState();
}

class _SecretaryShellState extends ConsumerState<_SecretaryShell> {
  int? _selected;
  int _pageKey = 0; // forces a fresh page (e.g. a cleared wizard) when re-selected

  void _select(int index) => setState(() {
        _selected = index;
        _pageKey++;
      });

  List<_NavItem> get _items {
    final fr = widget.strings.isFrench;
    return [
      _NavItem(
        icon: Icons.person_add_alt_1_rounded,
        title: fr ? 'Inscrire un enfant' : 'Enroll a Child',
        description: fr ? 'Trouver ou créer le parent, puis inscrire l\'enfant.' : 'Find or create the parent, then enroll the child.',
        index: 0,
      ),
      _NavItem(
        icon: Icons.hourglass_top_rounded,
        title: fr ? 'Frais d\'inscription en attente' : 'Awaiting Registration Payment',
        description: fr ? 'Encaisser les frais d\'inscription en attente.' : 'Collect registration fees still outstanding.',
        index: 1,
      ),
      _NavItem(
        icon: Icons.payments_outlined,
        title: fr ? 'Encaisser les frais scolaires' : 'Collect School Fees',
        description: fr ? 'Rechercher un élève et encaisser une tranche.' : 'Look up a student and collect an installment.',
        index: 2,
      ),
    ];
  }

  Widget _bodyFor(int? index) {
    switch (index) {
      case 0:
        return EnrollChildPage(key: ValueKey('enroll-$_pageKey'), schoolId: widget.landing.schoolId, landing: widget.landing);
      case 1:
        return AwaitingRegistrationsPage(key: ValueKey('awaiting-$_pageKey'), schoolId: widget.landing.schoolId, landing: widget.landing);
      case 2:
        return CollectSchoolFeesPage(key: ValueKey('fees-$_pageKey'), landing: widget.landing);
      default:
        return _WelcomePane(items: _items, onPick: _select);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final body = _bodyFor(_selected);

    if (isMobile) {
      return Scaffold(
        appBar: _AppBar(landing: widget.landing),
        drawer: Drawer(child: _Sidebar(strings: widget.strings, items: _items, isDrawer: true, onPick: _select)),
        body: body,
      );
    }
    return Scaffold(
      appBar: _AppBar(landing: widget.landing, showMenuIcon: false),
      body: Row(children: [
        SizedBox(width: 300, child: _Sidebar(strings: widget.strings, items: _items, isDrawer: false, onPick: _select)),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ]),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final LandingModel landing;
  final bool showMenuIcon;
  const _AppBar({required this.landing, this.showMenuIcon = true});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      automaticallyImplyLeading: showMenuIcon,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 12,
      title: Row(children: [
        if (landing.logoUrl.isNotEmpty)
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Image.network(landing.logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 20)),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(landing.schoolName,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final AppStrings strings;
  final List<_NavItem> items;
  final bool isDrawer;
  final void Function(int) onPick;
  const _Sidebar({required this.strings, required this.items, required this.isDrawer, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(secretaryProfileProvider).valueOrNull;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.88), theme.colorScheme.secondary],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(strings.welcomeBack, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(profile?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items
                  .map((item) => ListTile(
                        leading: Icon(item.icon, color: Colors.white),
                        title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        subtitle: Text(item.description,
                            style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          if (isDrawer) Navigator.pop(context);
                          onPick(item.index);
                        },
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
        ]),
      ),
    );
  }
}

class _WelcomePane extends StatelessWidget {
  final List<_NavItem> items;
  final void Function(int) onPick;
  const _WelcomePane({required this.items, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      children: [
        Text('What would you like to do?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onPick(item.index),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Icon(item.icon, size: 28, color: theme.colorScheme.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(item.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ]),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}