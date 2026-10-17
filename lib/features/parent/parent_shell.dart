import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../../shared/sign_out_button.dart';
import '../landing/landing_model.dart';
import '../principal/principal_core.dart';
import '../principal/principal_kit.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_admissions_tab.dart';
import 'parent_children_tab.dart';
import 'parent_dashboard_tab.dart';
import 'parent_fees_tab.dart';
import 'parent_models.dart';
import 'parent_navigation.dart';
import 'parent_payment_history_tab.dart';
import 'parent_profile_tab.dart';
import 'parent_providers.dart';
import 'parent_report_card_tab.dart';
import 'parent_review_child_tab.dart';
import 'parent_ui.dart';

/// Same architecture as the Teacher shell: every destination is content
/// shown INSIDE the shell (the sidebar and school theme are never lost),
/// held in [parentContentStackProvider]. A dark, theme-derived sidebar
/// (inverseSurface) so it can never clash with a school's brand colour,
/// a drawer on mobile, a collapsed rail on tablets.
///
/// Messages is still a placeholder for a page that does not exist yet.
class ParentShell extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ParentShell({super.key, required this.schoolId, required this.landing, required this.strings});

  List<_NavGroup> _groups() {
    final fr = strings.isFrench;
    return [
      _NavGroup(title: '', items: [
        _ParentNavItem(
          key: 'home',
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
          title: strings.dashboard,
          content: (context) => ParentDashboardTab(schoolId: schoolId, landing: landing, strings: strings),
        ),
        _ParentNavItem(
          key: 'children',
          icon: Icons.family_restroom_outlined,
          activeIcon: Icons.family_restroom_rounded,
          title: strings.myChildren,
          content: (context) => ParentChildrenTab(schoolId: schoolId, landing: landing, strings: strings),
        ),
      ]),
      _NavGroup(title: fr ? 'Scolarité' : 'Learning', items: [
        _ParentNavItem(
          key: 'report_cards',
          icon: Icons.assessment_outlined,
          activeIcon: Icons.assessment_rounded,
          title: strings.reportCards,
          childContent: (context, child) => ParentReportCardTab(child: child, landing: landing, strings: strings),
        ),
        _ParentNavItem(
          key: 'review',
          icon: Icons.rate_review_outlined,
          activeIcon: Icons.rate_review_rounded,
          title: strings.reviewMyChild,
          childContent: (context, child) => ParentReviewChildTab(child: child, landing: landing, strings: strings),
        ),
      ]),
      _NavGroup(title: fr ? 'Paiements' : 'Payments', items: [
        _ParentNavItem(
          key: 'fees',
          icon: Icons.payments_outlined,
          activeIcon: Icons.payments_rounded,
          title: strings.schoolFees,
          childContent: (context, child) => ParentFeesTab(child: child, landing: landing, strings: strings),
        ),
        _ParentNavItem(
          key: 'payment_history',
          icon: Icons.history_rounded,
          activeIcon: Icons.history_rounded,
          title: strings.paymentHistory,
          content: (context) => ParentPaymentHistoryTab(landing: landing, strings: strings),
        ),
      ]),
      _NavGroup(title: fr ? 'Inscription' : 'Enrollment', items: [
        _ParentNavItem(
          key: 'admissions',
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          title: strings.admissions,
          content: (context) => ParentAdmissionsTab(schoolId: schoolId, landing: landing, strings: strings),
        ),
      ]),
      _NavGroup(title: '', items: [
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
      ]),
    ];
  }

  /// With more than one enrolled child, ask which one first (the picker
  /// runs on every tap, so tapping the item again is how a parent
  /// switches child).
  void _pickChildThen(BuildContext context, List<EnrolledChild> children, void Function(EnrolledChild) onPicked) {
    if (children.isEmpty) {
      prSnack(context, strings.isFrench ? 'Vous n\'avez pas encore d\'enfant inscrit.' : 'You do not have an enrolled child yet.');
      return;
    }
    if (children.length == 1) {
      onPicked(children.first);
      return;
    }
    pnSheet<void>(
      context,
      (sheetContext) => PnSheetBody(
        title: strings.isFrench ? 'Quel enfant ?' : 'Which child?',
        subtitle: strings.isFrench ? 'Choisissez l\'enfant à afficher.' : 'Choose the child you want to look at.',
        children: [
          for (final c in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PrCard(
                padding: const EdgeInsets.all(12),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onPicked(c);
                },
                child: Row(children: [
                  ParentChildAvatar(child: c, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (c.className != null && c.className!.isNotEmpty) Text(c.className!, style: TextStyle(fontSize: 12.5, color: Theme.of(sheetContext).colorScheme.outline)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Theme.of(sheetContext).colorScheme.outline),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  void _select(WidgetRef ref, BuildContext context, _ParentNavItem item, List<EnrolledChild> children) {
    if (item.content != null) {
      ref.read(parentActiveNavKeyProvider.notifier).state = item.key;
      showParentContent(ref, ParentContentPage(title: item.title, builder: item.content!));
    } else if (item.childContent != null) {
      _pickChildThen(context, children, (child) {
        ref.read(parentActiveNavKeyProvider.notifier).state = item.key;
        showParentContent(
          ref,
          ParentContentPage(title: '${item.title} · ${child.fullName}', builder: (ctx) => item.childContent!(ctx, child)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enrolledAsync = ref.watch(enrolledChildrenProvider);
    final children = enrolledAsync.valueOrNull ?? <EnrolledChild>[];
    final groups = _groups();
    final all = [for (final g in groups) ...g.items];
    final activeKey = ref.watch(parentActiveNavKeyProvider);
    final stack = ref.watch(parentContentStackProvider);
    final canvas = cs.surfaceContainerLowest;

    // First build: nothing pushed yet - show Home.
    if (stack.isEmpty) {
      Future.microtask(() => _select(ref, context, all.first, children));
    }

    final currentTitle = stack.isEmpty ? all.first.title : stack.last.title;
    final canGoBack = stack.length > 1;

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero).animate(a), child: child),
      ),
      child: Container(
        key: ValueKey('$activeKey-${stack.length}-${stack.isEmpty ? '' : stack.last.title}'),
        color: canvas,
        child: stack.isEmpty ? const SizedBox() : stack.last.builder(context),
      ),
    );

    final isMobile = Responsive.isMobile(context);
    final collapsed = Responsive.isTablet(context);

    PreferredSizeWidget appBar = AppBar(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: isMobile && !canGoBack,
      leading: canGoBack
          ? IconButton(
              tooltip: strings.isFrench ? 'Retour' : 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => popParentContent(ref),
            )
          : null,
      titleSpacing: canGoBack || isMobile ? 4 : 18,
      shape: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
      title: Row(children: [
        if (!isMobile && landing.logoUrl.isNotEmpty)
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: cs.outlineVariant)),
            child: Image.network(landing.logoUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: cs.primary, size: 18)),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(currentTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            Text(landing.schoolName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, fontSize: 11.5)),
          ]),
        ),
      ]),
    );

    Widget sidebar({required bool isCollapsed, required bool inDrawer}) => _SidebarContent(
          collapsed: isCollapsed,
          strings: strings,
          groups: groups,
          activeKey: activeKey,
          onSelect: (item) {
            if (inDrawer) Navigator.of(context).pop();
            _select(ref, context, item, children);
          },
        );

    if (isMobile) {
      return Scaffold(
        backgroundColor: canvas,
        appBar: appBar,
        drawer: Drawer(width: 288, backgroundColor: cs.inverseSurface, child: sidebar(isCollapsed: false, inDrawer: true)),
        body: content,
      );
    }

    return Scaffold(
      backgroundColor: canvas,
      appBar: appBar,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: collapsed ? 84 : 280,
          color: cs.inverseSurface,
          child: sidebar(isCollapsed: collapsed, inDrawer: false),
        ),
        Expanded(child: ClipRect(child: content)),
      ]),
    );
  }
}

/// Round child photo that signs the private-bucket link first and falls
/// back to the initial. Shared by every Parent screen.
class ParentChildAvatar extends StatelessWidget {
  final EnrolledChild child;
  final double radius;
  const ParentChildAvatar({super.key, required this.child, this.radius = 24});

  @override
  Widget build(BuildContext context) => _ChildPhoto(stored: child.photoUrl, name: child.fullName, radius: radius);
}

class _ChildPhoto extends ConsumerWidget {
  final String? stored;
  final String name;
  final double radius;
  const _ChildPhoto({required this.stored, required this.name, required this.radius});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PnAvatar(stored: stored, name: name, radius: radius);
}

class _NavGroup {
  final String title;
  final List<_ParentNavItem> items;
  const _NavGroup({required this.title, required this.items});
}

class _ParentNavItem {
  final String key;
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final Widget Function(BuildContext)? content;
  final Widget Function(BuildContext, EnrolledChild)? childContent;
  _ParentNavItem({
    required this.key,
    required this.icon,
    required this.activeIcon,
    required this.title,
    this.content,
    this.childContent,
  }) : assert(
          [content, childContent].where((x) => x != null).length == 1,
          'exactly one of content/childContent must be set',
        );
}

class _ComingSoon extends StatelessWidget {
  final AppStrings strings;
  const _ComingSoon({required this.strings});

  @override
  Widget build(BuildContext context) {
    return PrPage(maxWidth: 640, children: [
      PrReveal(child: PrCard(child: PaEmpty(icon: Icons.hourglass_top_rounded, title: strings.comingSoonTitle, text: strings.comingSoonDescription))),
    ]);
  }
}

class _SidebarContent extends ConsumerWidget {
  final bool collapsed;
  final AppStrings strings;
  final List<_NavGroup> groups;
  final String activeKey;
  final ValueChanged<_ParentNavItem> onSelect;
  const _SidebarContent({required this.collapsed, required this.strings, required this.groups, required this.activeKey, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onInverseSurface;
    final border = fg.withValues(alpha: 0.12);
    final profile = ref.watch(parentProfileProvider).valueOrNull;
    final name = profile?.fullName ?? '';

    final tiles = <Widget>[];
    for (final g in groups) {
      if (g.title.isNotEmpty) {
        tiles.add(collapsed
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: border, height: 1))
            : Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                child: Text(g.title.toUpperCase(), style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ));
      }
      for (final item in g.items) {
        tiles.add(Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: _NavTile(item: item, collapsed: collapsed, selected: item.key == activeKey, fg: fg, onTap: () => onSelect(item)),
        ));
      }
    }

    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(collapsed ? 12 : 20, 18, collapsed ? 12 : 20, 14),
          child: collapsed
              ? Center(child: PrAvatar(name: name, radius: 22, onDark: true))
              : Row(children: [
                  PrAvatar(name: name, radius: 22, onDark: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(strings.welcomeBack.replaceAll(',', ''), style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 12)),
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 15.5, fontWeight: FontWeight.w800)),
                      Text(strings.isFrench ? 'Parent' : 'Parent', style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 11.5)),
                    ]),
                  ),
                ]),
        ),
        Divider(color: border, height: 1),
        Expanded(child: ListView(padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 8), children: tiles)),
        Divider(color: border, height: 1),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 16, vertical: 10),
          child: collapsed
              ? Center(child: SignOutIconButton(strings: strings, color: fg.withValues(alpha: 0.85)))
              : Row(children: [
                  Expanded(child: Text(strings.signOut, style: TextStyle(color: fg.withValues(alpha: 0.85), fontWeight: FontWeight.w700))),
                  SignOutIconButton(strings: strings, color: fg.withValues(alpha: 0.85)),
                ]),
        ),
      ]),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _ParentNavItem item;
  final bool collapsed;
  final bool selected;
  final Color fg;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.collapsed, required this.selected, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? fg : fg.withValues(alpha: 0.78);
    final icon = Icon(selected ? item.activeIcon : item.icon, color: color, size: 22);
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(color: selected ? fg.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
      child: collapsed
          ? SizedBox(height: 46, child: Center(child: icon))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                icon,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5)),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  height: selected ? 18 : 0,
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(4)),
                ),
              ]),
            ),
    );
    final ink = InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: tile);
    return collapsed ? Tooltip(message: item.title, child: ink) : ink;
  }
}
