import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_providers.dart';
import 'teacher_dashboard_tab.dart';
import 'teacher_models.dart';
import 'teacher_profile.dart';
import 'teacher_providers.dart';
import 'teacher_timetable.dart';

/// The three top-level destinations a teacher moves between day to
/// day. Everything else (class list, marks entry, attendance,
/// assignment detail) is a drill-down workflow reached FROM the
/// dashboard and stays a pushed full-screen route with a back arrow -
/// that's intentional, not an oversight: it keeps the sidebar short
/// and stable instead of growing a new entry per assignment.
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
    final destination = ref.watch(teacherActiveDestinationProvider);
    final items = _items();
    final content = KeyedSubtree(
      key: ValueKey(destination),
      child: _bodyFor(destination),
    );

    if (Responsive.isMobile(context)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(items.firstWhere((i) => i.destination == destination).label),
        ),
        drawer: Drawer(
          width: 288,
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
        body: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: content),
      );
    }

    final collapsed = Responsive.isTablet(context);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
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
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: content),
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

/// Shared between the desktop sidebar, the tablet icon rail and the
/// mobile drawer, so all three stay visually identical - only the
/// width and label visibility change.
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
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

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
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
        ),
        Divider(height: 1, color: borderColor),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: collapsed ? 12 : 14),
            children: [
              for (final item in items) ...[
                _NavTile(
                  item: item,
                  collapsed: collapsed,
                  selected: item.destination == active,
                  onTap: () => onSelect(item.destination),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),
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
                        color: theme.colorScheme.error,
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
                              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                          Text(strings.teacher,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: strings.signOut,
                      child: IconButton(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        color: theme.colorScheme.error,
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
    final theme = Theme.of(context);
    if (logoUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(11)),
        child: Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: size * 0.55),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: size * 0.55),
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
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
      child: profile.photoUrl == null
          ? Text(_initials(profile.fullName),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.65, color: theme.colorScheme.primary))
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

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.collapsed, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Active state is tinted with the SCHOOL's own primary color (from
    // the seeded ColorScheme), never a hardcoded hex - so it always
    // matches this school's branding and can't clash with another
    // school's palette. Inactive/chrome colors come from Material's
    // neutral surface tones for the same reason.
    final fg = selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 14, vertical: 12),
          alignment: collapsed ? Alignment.center : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: collapsed
              ? Icon(selected ? item.activeIcon : item.icon, color: fg, size: 22)
              : Row(
                  children: [
                    Icon(selected ? item.activeIcon : item.icon, color: fg, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: fg,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          )),
                    ),
                  ],
                ),
        ),
      ),
    );

    return collapsed ? Tooltip(message: item.label, child: tile) : tile;
  }
}