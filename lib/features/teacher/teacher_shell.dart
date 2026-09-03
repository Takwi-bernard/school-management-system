import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_providers.dart';
import 'teacher_dashboard_tab.dart';
import 'teacher_models.dart';
import 'teacher_profile.dart';
import 'teacher_providers.dart';
import 'teacher_timetable.dart';

/// Fixed, theme-independent ink tones for the sidebar. Deliberately
/// NOT derived from the school's seed color: the sidebar's whole job
/// is to read as a distinct navigation plane from the content canvas
/// beneath it, for every school, regardless of how light or dark
/// their brand color is. Text/icons on it are always white-based for
/// guaranteed contrast; the school's own primary color only ever
/// shows up as the slim accent bar on the active item.
const _sidebarInk = Color(0xFF14161B);
const _sidebarInkBorder = Color(0x1AFFFFFF); // white @ 10%
const _sidebarHoverFill = Color(0x0DFFFFFF); // white @ 5%
const _sidebarSelectedFill = Color(0x14FFFFFF); // white @ 8%
const _sidebarDanger = Color(0xFFFF8A80);

enum TeacherDestination { dashboard, timetable, profile }

final teacherActiveDestinationProvider =
    StateProvider<TeacherDestination>((ref) => TeacherDestination.dashboard);

class TeacherShell extends ConsumerWidget {
  final TeacherProfile profile;
  final String schoolName;
  final String logoUrl;
  final AppStrings strings;

  const TeacherShell({
    super.key,
    required this.profile,
    required this.schoolName,
    required this.logoUrl,
    required this.strings,
  });

  List<_NavItem> _items() => [
        _NavItem(TeacherDestination.dashboard, Icons.space_dashboard_outlined,
            Icons.space_dashboard_rounded, strings.dashboard),
        _NavItem(TeacherDestination.timetable, Icons.calendar_month_outlined,
            Icons.calendar_month_rounded, strings.myTimetable),
        _NavItem(TeacherDestination.profile, Icons.person_outline_rounded,
            Icons.person_rounded, strings.myProfile),
      ];

  Widget _bodyFor(TeacherDestination destination) {
    switch (destination) {
      case TeacherDestination.dashboard:
        return TeacherDashboardTab(profile: profile);
      case TeacherDestination.timetable:
        return const TeacherTimetableTab();
      case TeacherDestination.profile:
        return TeacherProfileTab(profile: profile);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final destination = ref.watch(teacherActiveDestinationProvider);
    final items = _items();
    final canvas = theme.colorScheme.surfaceContainerLowest;
    final content = Container(
      key: ValueKey(destination),
      color: canvas,
      child: _bodyFor(destination),
    );

    if (Responsive.isMobile(context)) {
      return Scaffold(
        backgroundColor: canvas,
        appBar: AppBar(
          title: Text(items.firstWhere((i) => i.destination == destination).label),
        ),
        drawer: Drawer(
          width: 288,
          backgroundColor: _sidebarInk,
          child: SafeArea(
            child: _SidebarContent(
              collapsed: false,
              schoolName: schoolName,
              logoUrl: logoUrl,
              profile: profile,
              strings: strings,
              items: items,
              active: destination,
              onSelect: (d) {
                ref.read(teacherActiveDestinationProvider.notifier).state = d;
                Navigator.of(context).pop();
              },
              onSignOut: () => _signOut(context, ref),
            ),
          ),
        ),
        body: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: content),
      );
    }

    final collapsed = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: canvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: _sidebarInk,
            child: SizedBox(
              width: collapsed ? 84 : 264,
              child: _SidebarContent(
                collapsed: collapsed,
                schoolName: schoolName,
                logoUrl: logoUrl,
                profile: profile,
                strings: strings,
                items: items,
                active: destination,
                onSelect: (d) => ref.read(teacherActiveDestinationProvider.notifier).state = d,
                onSignOut: () => _signOut(context, ref),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: content),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final TeacherDestination destination;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.destination, this.icon, this.activeIcon, this.label);
}

class _SidebarContent extends StatelessWidget {
  final bool collapsed;
  final String schoolName;
  final String logoUrl;
  final TeacherProfile profile;
  final AppStrings strings;
  final List<_NavItem> items;
  final TeacherDestination active;
  final ValueChanged<TeacherDestination> onSelect;
  final VoidCallback onSignOut;

  const _SidebarContent({
    required this.collapsed,
    required this.schoolName,
    required this.logoUrl,
    required this.profile,
    required this.strings,
    required this.items,
    required this.active,
    required this.onSelect,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 22, horizontal: collapsed ? 14 : 20),
          child: collapsed
              ? _Logo(logoUrl: logoUrl, size: 40)
              : Row(
                  children: [
                    _Logo(logoUrl: logoUrl, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        schoolName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, height: 1.2),
                      ),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1, color: _sidebarInkBorder),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: collapsed ? 12 : 14),
            children: [
              for (final item in items) ...[
                _NavTile(
                  item: item,
                  collapsed: collapsed,
                  selected: item.destination == active,
                  primary: theme.colorScheme.primary,
                  onTap: () => onSelect(item.destination),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: _sidebarInkBorder),
        Padding(
          padding: EdgeInsets.all(collapsed ? 12 : 16),
          child: collapsed
              ? Column(
                  children: [
                    _Avatar(profile: profile, radius: 18),
                    const SizedBox(height: 10),
                    Tooltip(
                      message: strings.signOut,
                      child: IconButton(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        color: _sidebarDanger,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _Avatar(profile: profile, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(strings.teacher, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: strings.signOut,
                      child: IconButton(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        color: _sidebarDanger,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  final String logoUrl;
  final double size;
  const _Logo({required this.logoUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(11)),
        child: Icon(Icons.school_rounded, color: Colors.white, size: size * 0.55),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Container(
        color: Colors.white.withValues(alpha: 0.9),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, size: size * 0.55),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final TeacherProfile profile;
  final double radius;
  const _Avatar({required this.profile, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
      child: profile.photoUrl == null
          ? Text(_initials(profile.fullName),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.65, color: Colors.white))
          : null,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool collapsed;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.collapsed,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.selected ? Colors.white : Colors.white70;
    final fill = widget.selected ? _sidebarSelectedFill : (_hovered ? _sidebarHoverFill : Colors.transparent);

    final row = widget.collapsed
        ? Icon(widget.selected ? widget.item.activeIcon : widget.item.icon, color: fg, size: 22)
        : Row(
            children: [
              Icon(widget.selected ? widget.item.activeIcon : widget.item.icon, color: fg, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.item.label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
            ],
          );

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 14, vertical: 12),
                alignment: widget.collapsed ? Alignment.center : Alignment.centerLeft,
                decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
                child: row,
              ),
              if (widget.selected)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(color: widget.primary, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return widget.collapsed ? Tooltip(message: widget.item.label, child: tile) : tile;
  }
}