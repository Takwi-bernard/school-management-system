import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'super_admin_activity.dart';
import 'super_admin_overview.dart';
import 'super_admin_people.dart';
import 'super_admin_providers.dart';
import 'super_admin_schools.dart';
import 'super_admin_settings.dart';
import 'super_admin_theme.dart';
import 'super_admin_ui.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final String subtitle;
  const _NavItem(this.icon, this.activeIcon, this.title, this.subtitle);
}

class SuperAdminHome extends ConsumerStatefulWidget {
  const SuperAdminHome({super.key});

  @override
  ConsumerState<SuperAdminHome> createState() => _SuperAdminHomeState();
}

class _SuperAdminHomeState extends ConsumerState<SuperAdminHome> {
  int _selected = 0;

  static const _items = [
    _NavItem(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Overview', 'Platform at a glance'),
    _NavItem(Icons.apartment_outlined, Icons.apartment_rounded, 'Schools', 'Onboard and manage schools'),
    _NavItem(Icons.groups_outlined, Icons.groups_rounded, 'People', 'Admin accounts across schools'),
    _NavItem(Icons.history_rounded, Icons.history_rounded, 'Activity', 'Who changed what, and when'),
    _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'Settings', 'Your account and security'),
  ];

  void _go(int i) => setState(() => _selected = i);

  Widget _body() {
    switch (_selected) {
      case 0:
        return OverviewSection(onNavigate: _go);
      case 1:
        return const SchoolsSection();
      case 2:
        return const PeopleSection();
      case 3:
        return const ActivitySection();
      default:
        return const SettingsSection();
    }
  }

  Widget _brand() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Sa.primary, Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Sa.primary.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('School Platform', style: TextStyle(color: Sa.text, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
              Text('Administration', style: TextStyle(color: Sa.faint, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  Widget _navTile(int i, {required bool closeDrawer}) {
    final item = _items[i];
    final selected = i == _selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _go(i);
            if (closeDrawer) Navigator.pop(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Sa.primary.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Sa.primary.withValues(alpha: 0.35) : Colors.transparent),
            ),
            child: Row(children: [
              Icon(selected ? item.activeIcon : item.icon, color: selected ? Sa.primaryHi : Sa.muted, size: 21),
              const SizedBox(width: 12),
              Text(item.title, style: TextStyle(color: selected ? Sa.text : Sa.muted, fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _userCard() {
    final profile = ref.watch(superAdminProfileProvider).valueOrNull;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: Sa.border)),
      child: Row(children: [
        SaAvatar(profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Admin', size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile?.fullName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.text, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.faint, fontSize: 11)),
          ]),
        ),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded, size: 19),
          onPressed: () async {
            final ok = await saConfirm(context, title: 'Sign out?', message: 'You will need to sign in again to manage the platform.', confirmLabel: 'Sign out', icon: Icons.logout_rounded);
            if (ok) await Supabase.instance.client.auth.signOut();
          },
        ),
      ]),
    );
  }

  Widget _sidebar({required bool closeDrawer}) => SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _brand(),
          Expanded(child: ListView(children: [for (var i = 0; i < _items.length; i++) _navTile(i, closeDrawer: closeDrawer)])),
          _userCard(),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: KeyedSubtree(key: ValueKey(_selected), child: _body()),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      if (!wide) {
        return Scaffold(
          appBar: AppBar(title: Text(_items[_selected].title)),
          drawer: Drawer(backgroundColor: Sa.sidebar, child: _sidebar(closeDrawer: true)),
          body: content,
        );
      }
      return Scaffold(
        body: Row(children: [
          Container(
            width: 264,
            decoration: const BoxDecoration(color: Sa.sidebar, border: Border(right: BorderSide(color: Sa.border))),
            child: _sidebar(closeDrawer: false),
          ),
          Expanded(child: content),
        ]),
      );
    });
  }
}