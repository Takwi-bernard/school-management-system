import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../../shared/sign_out_button.dart';
import '../landing/landing_model.dart';
import 'parent_dashboard_tab.dart';
import 'parent_models.dart';
import 'parent_navigation.dart';
import 'parent_payment_history_tab.dart';
import 'parent_profile_tab.dart';
import 'parent_providers.dart';
import 'parent_review_child_tab.dart';

/// Same architecture as TeacherShell, deliberately - the parent
/// module had the SAME "Navigator.push escapes the shell" bug (see
/// the comment on buildSchoolTheme in parent_models.dart, which
/// worked around the color half of it but not the sidebar
/// disappearing). This fixes both at once, the same way.
///
/// Visual language is intentionally NOT copied from Teacher: parent
/// keeps its own more expressive style (RevealOnScroll, etc. - kept
/// on request). Only the STRUCTURE is shared: a dark, theme-derived
/// sidebar (inverseSurface, not a fixed color, not the mockup's
/// fixed navy) so it can never visually clash with a school's brand
/// color, plus hamburger+drawer on mobile instead of the mockup's
/// bottom nav bar.
///
/// Nav items below are a mix of three things, marked clearly:
/// - REAL, in-shell content (Home) - fully working now.
/// - LEGACY - existing real pages, still reached via context.push
///   for this pass (Fees, Admissions/Enroll, Report Cards, Review,
///   Payment History, Profile) - to be migrated in-shell next.
/// - STUB - placeholders for mockup items with no built page yet
///   (My Children list, Messages, Settings) - shows a plain "coming
///   soon" screen, same spirit as RoleGate's placeholder pattern
///   already used elsewhere in this app.
class ParentShell extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ParentShell({super.key, required this.schoolId, required this.landing, required this.strings});

  List<_ParentNavItem> _items(BuildContext context, WidgetRef ref, List<EnrolledChild> children) {
    return [
      _ParentNavItem(
        key: 'home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        title: strings.dashboard,
        content: (context) => ParentDashboardTab(schoolId: schoolId, landing: landing, strings: strings),
      ),
      _ParentNavItem(
        key: 'children',
        icon: Icons.family_restroom_outlined,
        activeIcon: Icons.family_restroom_rounded,
        title: strings.myChildren,
        content: (context) => _ComingSoon(strings: strings),
      ),
      _ParentNavItem(
        key: 'fees',
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments_rounded,
        title: strings.schoolFees,
        legacy: () => _pickChildThen(context, ref, children, (child) => context.push('/parent/fees', extra: child)),
      ),
      _ParentNavItem(
        key: 'admissions',
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment_rounded,
        title: strings.admissions,
        legacy: () => context.push('/parent/enroll', extra: schoolId),
      ),
      _ParentNavItem(
        key: 'report_cards',
        icon: Icons.assessment_outlined,
        activeIcon: Icons.assessment_rounded,
        title: strings.reportCards,
        legacy: () => _pickChildThen(context, ref, children, (child) => context.push('/parent/report-card', extra: child)),
      ),
      _ParentNavItem(
        key: 'review',
        icon: Icons.rate_review_outlined,
        activeIcon: Icons.rate_review_rounded,
        title: strings.reviewMyChild,
        childContent: (context, child) => ParentReviewChildTab(child: child, landing: landing, strings: strings),
      ),
      _ParentNavItem(
        key: 'payment_history',
        icon: Icons.history_rounded,
        activeIcon: Icons.history_rounded,
        title: strings.paymentHistory,
        content: (context) => ParentPaymentHistoryTab(landing: landing, strings: strings),
      ),
      _ParentNavItem(
        key: 'messages',
        icon: Icons.mail_outline_rounded,
        activeIcon: Icons.mail_rounded,
        title: strings.messages,
        content: (context) => _ComingSoon(strings: strings),
      ),
      _ParentNavItem(
        key: 'profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        title: strings.myProfile,
        content: (context) => const ParentProfileTab(),
      ),
      _ParentNavItem(
        key: 'settings',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        title: strings.settings,
        content: (context) => _ComingSoon(strings: strings),
      ),
    ];
  }

  /// If there's more than one enrolled child, ask which one first -
  /// unchanged from the original _ParentShell.
  void _pickChildThen(BuildContext context, WidgetRef ref, List<EnrolledChild> children, void Function(EnrolledChild) onPicked) {
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.isFrench
            ? 'Vous n\'avez pas encore d\'enfant inscrit.'
            : 'You do not have an enrolled child yet.')),
      );
      return;
    }
    if (children.length == 1) {
      onPicked(children.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children
              .map((c) => ListTile(
                    leading: CircleAvatar(child: Text(c.firstName.isNotEmpty ? c.firstName[0] : '?')),
                    title: Text(c.fullName),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPicked(c);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _select(WidgetRef ref, BuildContext context, _ParentNavItem item, List<EnrolledChild> children) {
    if (item.content != null) {
      ref.read(_parentActiveNavKeyProvider.notifier).state = item.key;
      showParentContent(ref, ParentContentPage(title: item.title, builder: item.content!));
    } else if (item.childContent != null) {
      // Picker runs fresh on every tap (matches the original app's
      // behavior) - so re-tapping this nav item is how a parent with
      // more than one child switches which child they're viewing.
      _pickChildThen(context, ref, children, (child) {
        ref.read(_parentActiveNavKeyProvider.notifier).state = item.key;
        showParentContent(
          ref,
          ParentContentPage(title: '${item.title} \u00b7 ${child.fullName}', builder: (ctx) => item.childContent!(ctx, child)),
        );
      });
    } else {
      item.legacy!();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final children = enrolledAsync.valueOrNull ?? [];
    final items = _items(context, ref, children);
    final activeKey = ref.watch(_parentActiveNavKeyProvider);
    final stack = ref.watch(parentContentStackProvider);
    final canvas = theme.colorScheme.surfaceContainerLowest;
    final sidebarInk = theme.colorScheme.inverseSurface;

    // First build: nothing pushed yet - show Home.
    if (stack.isEmpty) {
      Future.microtask(() => _select(ref, context, items.first, children));
    }

    final currentTitle = stack.isEmpty ? items.first.title : stack.last.title;
    final content = Container(
      key: ValueKey('$activeKey-${stack.length}'),
      color: canvas,
      child: stack.isEmpty ? const SizedBox() : stack.last.builder(context),
    );

    if (Responsive.isMobile(context)) {
      return Scaffold(
        backgroundColor: canvas,
        appBar: AppBar(title: Text(currentTitle)),
        drawer: Drawer(
          width: 288,
          backgroundColor: sidebarInk,
          child: SafeArea(
            child: _SidebarContent(
              collapsed: false,
              landing: landing,
              strings: strings,
              items: items,
              activeKey: activeKey,
              onSelect: (item) {
                _select(ref, context, item, children);
                Navigator.of(context).pop();
              },
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
            color: sidebarInk,
            child: SizedBox(
              width: collapsed ? 84 : 272,
              child: _SidebarContent(
                collapsed: collapsed,
                landing: landing,
                strings: strings,
                items: items,
                activeKey: activeKey,
                onSelect: (item) => _select(ref, context, item, children),
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

final _parentActiveNavKeyProvider = StateProvider<String>((ref) => 'home');

class _ParentNavItem {
  final String key;
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final Widget Function(BuildContext)? content;
  final VoidCallback? legacy;
  final Widget Function(BuildContext, EnrolledChild)? childContent;
  _ParentNavItem({
    required this.key,
    required this.icon,
    required this.activeIcon,
    required this.title,
    this.content,
    this.legacy,
    this.childContent,
  }) : assert(
          [content, legacy, childContent].where((x) => x != null).length == 1,
          'exactly one of content/legacy/childContent must be set',
        );
}

class _ComingSoon extends StatelessWidget {
  final AppStrings strings;
  const _ComingSoon({required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(strings.comingSoonTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(strings.comingSoonDescription,
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _SidebarContent extends ConsumerWidget {
  final bool collapsed;
  final LandingModel landing;
  final AppStrings strings;
  final List<_ParentNavItem> items;
  final String activeKey;
  final ValueChanged<_ParentNavItem> onSelect;
  const _SidebarContent({
    required this.collapsed,
    required this.landing,
    required this.strings,
    required this.items,
    required this.activeKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onInverseSurface;
    final border = ink.withValues(alpha: 0.14);
    final profileAsync = ref.watch(parentProfileProvider);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 22, horizontal: collapsed ? 14 : 20),
          child: collapsed
              ? _Logo(logoUrl: landing.logoUrl, ink: ink)
              : Row(
                  children: [
                    _Logo(logoUrl: landing.logoUrl, ink: ink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(landing.schoolName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15, height: 1.2)),
                    ),
                  ],
                ),
        ),
        Divider(height: 1, color: border),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: collapsed ? 12 : 14),
            children: [
              for (final item in items) ...[
                _NavTile(item: item, collapsed: collapsed, selected: item.key == activeKey, onTap: () => onSelect(item)),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: border),
        Padding(
          padding: EdgeInsets.all(collapsed ? 12 : 16),
          child: collapsed
              ? Column(
                  children: [
                    _Avatar(name: profileAsync.valueOrNull?.fullName ?? '', ink: ink),
                    const SizedBox(height: 10),
                    SignOutIconButton(strings: strings, color: scheme.error),
                  ],
                )
              : Row(
                  children: [
                    _Avatar(name: profileAsync.valueOrNull?.fullName ?? '', ink: ink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profileAsync.valueOrNull?.fullName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(strings.welcomeBack.replaceAll(',', ''),
                              style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 12)),
                        ],
                      ),
                    ),
                    SignOutIconButton(strings: strings, color: scheme.error),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  final String logoUrl;
  final Color ink;
  const _Logo({required this.logoUrl, required this.ink});

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    if (logoUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: ink.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
        child: Icon(Icons.school_rounded, color: ink, size: size * 0.55),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Container(
        color: ink.withValues(alpha: 0.92),
        child: Image.network(logoUrl, width: size, height: size, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, size: size * 0.55)),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color ink;
  const _Avatar({required this.name, required this.ink});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: ink.withValues(alpha: 0.14),
      child: Text(initials, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: ink)),
    );
  }
}

class _NavTile extends StatefulWidget {
  final _ParentNavItem item;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.collapsed, required this.selected, required this.onTap});

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onInverseSurface;
    final fg = widget.selected ? ink : ink.withValues(alpha: 0.7);
    final fill = widget.selected ? ink.withValues(alpha: 0.1) : (_hovered ? ink.withValues(alpha: 0.05) : Colors.transparent);

    final row = widget.collapsed
        ? Icon(widget.selected ? widget.item.activeIcon : widget.item.icon, color: fg, size: 22)
        : Row(children: [
            Icon(widget.selected ? widget.item.activeIcon : widget.item.icon, color: fg, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.item.title,
                  style: TextStyle(color: fg, fontSize: 14, fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500)),
            ),
          ]);

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Stack(children: [
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
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(4)),
                ),
              ),
          ]),
        ),
      ),
    );

    return widget.collapsed ? Tooltip(message: widget.item.title, child: tile) : tile;
  }
}