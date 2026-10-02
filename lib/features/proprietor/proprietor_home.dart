import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import '../parent/parent_models.dart' show buildSchoolTheme;
import 'proprietor_providers.dart';
import 'proprietor_sections.dart';

class ProprietorHome extends ConsumerWidget {
  const ProprietorHome({super.key});

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
          data: (session) {
            if (session == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/sign-in'));
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (session.role != 'proprietor') {
              return Scaffold(body: Center(child: Text('This account is a ${session.role} account, not Proprietor.')));
            }
            return Theme(
              data: buildSchoolTheme(school.primaryColor, school.secondaryColor),
              child: _ProprietorShell(landing: school),
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

class _ProprietorShell extends ConsumerStatefulWidget {
  final LandingModel landing;
  const _ProprietorShell({required this.landing});

  @override
  ConsumerState<_ProprietorShell> createState() => _ProprietorShellState();
}

class _ProprietorShellState extends ConsumerState<_ProprietorShell> {
  int _selected = 0;

  List<_NavItem> get _items => const [
        _NavItem(icon: Icons.dashboard_outlined, title: 'Overview', description: 'Snapshot of the whole school', index: 0),
        _NavItem(icon: Icons.account_balance_wallet_outlined, title: 'Financial Overview', description: 'Income, expenditure, net position', index: 1),
        _NavItem(icon: Icons.trending_up_rounded, title: 'Income History', description: 'Every payment received', index: 2),
        _NavItem(icon: Icons.receipt_long_outlined, title: 'Expenditure', description: 'Record and review school expenses', index: 3),
        _NavItem(icon: Icons.insights_rounded, title: 'Growth & Statistics', description: 'Students over time, by class', index: 4),
        _NavItem(icon: Icons.groups_outlined, title: 'School Actors', description: 'Staff and parents currently active', index: 5),
             _NavItem(icon: Icons.auto_awesome_rounded, title: 'AI Insights', description: 'AI-generated feedback and suggestions', index: 6),
      ];

  Widget _bodyFor(int index) {
    switch (index) {
      case 0:
        return OverviewSection(schoolId: widget.landing.schoolId);
      case 1:
        return FinancialOverviewSection(schoolId: widget.landing.schoolId);
      case 2:
        return IncomeHistorySection(schoolId: widget.landing.schoolId);
      case 3:
        return ExpenditureSection(schoolId: widget.landing.schoolId, landing: widget.landing);
      case 4:
        return GrowthStatisticsSection(schoolId: widget.landing.schoolId);
      case 6:
        return AiInsightsSection(schoolId: widget.landing.schoolId);
      default:
        return ActiveActorsSection(schoolId: widget.landing.schoolId);
        
    }
  }

  @override
  Widget build(BuildContext context) {
        ref.watch(proprietorRealtimeProvider(widget.landing.schoolId)); // keeps the channel alive for this shell's lifetime
    final isMobile = Responsive.isMobile(context);
    final body = _bodyFor(_selected);

    if (isMobile) {
      return Scaffold(
        appBar: _AppBar(landing: widget.landing),
        drawer: Drawer(child: _Sidebar(items: _items, selected: _selected, isDrawer: true, onPick: (i) => setState(() => _selected = i))),
        body: body,
      );
    }
    return Scaffold(
      appBar: _AppBar(landing: widget.landing, showMenuIcon: false),
      body: Row(children: [
        SizedBox(width: 290, child: _Sidebar(items: _items, selected: _selected, isDrawer: false, onPick: (i) => setState(() => _selected = i))),
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
            width: 34, height: 34, padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
            child: Image.network(landing.logoUrl, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 18)),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(landing.schoolName, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final List<_NavItem> items;
  final int selected;
  final bool isDrawer;
  final void Function(int) onPick;
  const _Sidebar({required this.items, required this.selected, required this.isDrawer, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(proprietorProfileProvider).valueOrNull;

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
              const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(profile?.fullName ?? 'Proprietor', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) {
                final isSelected = item.index == selected;
                return Container(
                  color: isSelected ? Colors.white.withValues(alpha: 0.12) : null,
                  child: ListTile(
                    leading: Icon(item.icon, color: Colors.white),
                    title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(item.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      onPick(item.index);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.white),
            title: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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