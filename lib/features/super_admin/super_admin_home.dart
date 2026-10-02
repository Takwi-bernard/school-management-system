import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'super_admin_providers.dart';
import 'super_admin_schools.dart';

class _NavItem {
  final IconData icon;
  final String title;
  final int index;
  const _NavItem(this.icon, this.title, this.index);
}

class SuperAdminHome extends ConsumerStatefulWidget {
  const SuperAdminHome({super.key});

  @override
  ConsumerState<SuperAdminHome> createState() => _SuperAdminHomeState();
}

class _SuperAdminHomeState extends ConsumerState<SuperAdminHome> {
  int _selected = 0;

  static const _items = [
    _NavItem(Icons.school_outlined, 'Schools', 0),
    // Future sections land here: Branding, Academic Structure, Fees
  ];

  Widget _body(int index) {
    switch (index) {
      case 0:
        return const SchoolsSection();
      default:
        return const Center(child: Text('Coming soon.', style: TextStyle(color: Colors.white54)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(superAdminProfileProvider).valueOrNull;

    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;

        final sidebar = Container(
          width: isMobile ? double.infinity : 260,
          color: const Color(0xFF111827),
          child: SafeArea(
            bottom: !isMobile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PLATFORM ADMIN', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(profile?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                if (isMobile)
                  ..._items.map((item) => ListTile(
                        leading: Icon(item.icon, color: Colors.white70),
                        title: Text(item.title, style: const TextStyle(color: Colors.white)),
                        selected: item.index == _selected,
                        onTap: () => setState(() => _selected = item.index),
                      ))
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _items.map((item) {
                        final selected = item.index == _selected;
                        return Container(
                          color: selected ? Colors.white.withValues(alpha: 0.08) : null,
                          child: ListTile(
                            leading: Icon(item.icon, color: Colors.white70),
                            title: Text(item.title, style: const TextStyle(color: Colors.white)),
                            onTap: () => setState(() => _selected = item.index),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.white70),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                  onTap: () => Supabase.instance.client.auth.signOut(),
                ),
                if (!isMobile) const SizedBox(height: 8),
              ],
            ),
          ),
        );

        if (isMobile) {
          return Column(children: [sidebar, const Divider(color: Colors.white12, height: 1), Expanded(child: _body(_selected))]);
        }

        return Row(children: [
          sidebar,
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(child: _body(_selected)),
        ]);
      }),
    );
  }
}