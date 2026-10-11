import 'dart:async';
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
import 'secretary_collections.dart';
import 'secretary_directory.dart';
import 'secretary_enrollment.dart';
import 'secretary_format.dart';
import 'secretary_models.dart';
import 'secretary_payments.dart';
import 'secretary_profile.dart';
import 'secretary_providers.dart';
import 'secretary_strings.dart';
import 'secretary_ui.dart';

const int kNavOverview = 0;
const int kNavEnroll = 1;
const int kNavAwaiting = 2;
const int kNavFees = 3;
const int kNavDirectory = 4;
const int kNavCollections = 5;
const int kNavProfile = 6;

class SecretaryHome extends ConsumerWidget {
  const SecretaryHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);
    final strings = AppStrings(locale);

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
              final msg = strings.isFrench
                  ? "Ce compte est un compte ${session.role}, pas Secrétaire."
                  : 'This account is a ${session.role} account, not Secretary.';
              return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(msg, textAlign: TextAlign.center))));
            }
            return Theme(
              data: buildSchoolTheme(school.primaryColor, school.secondaryColor),
              child: _SecretaryShell(landing: school, strings: strings),
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
  int _selected = kNavOverview;
  int _pageKey = 0;
  String? _feesPrefill;
  bool _signingOut = false;

  AppStrings get _s => widget.strings;
  String get _schoolId => widget.landing.schoolId;

  void _navigate(int index, {String? feesQuery}) {
    setState(() {
      _selected = index;
      _pageKey++;
      _feesPrefill = index == kNavFees ? feesQuery : null;
    });
  }

  List<_NavItem> _items() => [
        _NavItem(icon: Icons.dashboard_outlined, title: _s.sOverview, description: _s.sOverviewDescription, index: kNavOverview),
        _NavItem(icon: Icons.person_add_alt_1_rounded, title: _s.sEnrollChild, description: _s.sEnrollChildDescription, index: kNavEnroll),
        _NavItem(icon: Icons.hourglass_top_rounded, title: _s.sAwaitingRegistration, description: _s.sAwaitingRegistrationDescription, index: kNavAwaiting),
        _NavItem(icon: Icons.payments_outlined, title: _s.sCollectFees, description: _s.sCollectFeesDescription, index: kNavFees),
        _NavItem(icon: Icons.groups_outlined, title: _s.sDirectory, description: _s.sDirectoryDescription, index: kNavDirectory),
        _NavItem(icon: Icons.receipt_long_outlined, title: _s.sMyCollections, description: _s.sMyCollectionsDescription, index: kNavCollections),
        _NavItem(icon: Icons.account_circle_outlined, title: _s.myProfile, description: _s.personalInformation, index: kNavProfile),
      ];

  Widget _bodyFor(int index) {
    switch (index) {
      case kNavEnroll:
        return EnrollChildPage(schoolId: _schoolId, landing: widget.landing, strings: _s);
      case kNavAwaiting:
        return AwaitingRegistrationsPage(schoolId: _schoolId, landing: widget.landing, strings: _s);
      case kNavFees:
        return CollectSchoolFeesPage(landing: widget.landing, strings: _s, initialQuery: _feesPrefill);
      case kNavDirectory:
        return StudentDirectoryPage(strings: _s, onCollectFees: (q) => _navigate(kNavFees, feesQuery: q));
      case kNavCollections:
        return MyCollectionsPage(schoolId: _schoolId, strings: _s);
      case kNavProfile:
        return SecretaryProfilePage(schoolId: _schoolId, strings: _s);
      default:
        return SecretaryOverviewPage(schoolId: _schoolId, strings: _s, onNavigate: _navigate);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_s.signOutConfirmTitle),
        content: Text(_s.signOutConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_s.signOut)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    final started = DateTime.now();
    try {
      await ref.read(authControllerProvider.notifier).signOut();
      // Keep the spinner visible long enough to read - it never just flashes.
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(secretaryProfileProvider).valueOrNull;
    final awaitingCount = ref.watch(secretaryDashboardProvider(_schoolId)).valueOrNull?.awaitingRegistrationCount ?? 0;
    final items = _items();

    Widget sidebar({required bool collapsed, required bool isDrawer}) => _Sidebar(
          items: items,
          selected: _selected,
          collapsed: collapsed,
          profile: profile,
          awaitingCount: awaitingCount,
          strings: _s,
          onPick: (i) {
            if (isDrawer) Navigator.pop(context);
            _navigate(i);
          },
          onSignOut: () {
            if (isDrawer) Navigator.pop(context);
            _confirmSignOut();
          },
        );

    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey('$_selected-$_pageKey'), child: _bodyFor(_selected)),
    );

    return Stack(fit: StackFit.expand, children: [
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 760;
        final isTablet = width >= 760 && width < 1100;

        final appBar = AppBar(
          backgroundColor: theme.colorScheme.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          automaticallyImplyLeading: isMobile,
          titleSpacing: 12,
          title: Row(children: [
            if (widget.landing.logoUrl.isNotEmpty)
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                child: Image.network(widget.landing.logoUrl,
                    fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 18)),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.landing.schoolName,
                  overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
          actions: [
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _navigate(kNavProfile),
                  child: SecretaryAvatar(photoUrl: profile?.photoUrl, fullName: profile?.fullName ?? '', radius: 16),
                ),
              ),
          ],
        );

        if (isMobile) {
          return Scaffold(
            appBar: appBar,
            drawer: Drawer(child: sidebar(collapsed: false, isDrawer: true)),
            body: body,
          );
        }

        return Scaffold(
          appBar: appBar,
          body: Row(children: [
            SizedBox(width: isTablet ? 84 : 300, child: sidebar(collapsed: isTablet, isDrawer: false)),
            const VerticalDivider(width: 1),
            Expanded(child: ClipRect(child: body)),
          ]),
        );
      }),
      if (_signingOut)
        Positioned.fill(
          child: Material(
            color: Colors.black54,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(_s.signingOut, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selected;
  final bool collapsed;
  final SecretaryProfile? profile;
  final int awaitingCount;
  final AppStrings strings;
  final void Function(int) onPick;
  final VoidCallback onSignOut;

  const _Sidebar({
    required this.items,
    required this.selected,
    required this.collapsed,
    required this.profile,
    required this.awaitingCount,
    required this.strings,
    required this.onPick,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Derived from the theme's own inverse surface so contrast is
    // guaranteed against ANY school's seeded palette.
    final bg = theme.colorScheme.inverseSurface;
    final fg = theme.colorScheme.onInverseSurface;

    Widget iconFor(_NavItem item) {
      final icon = Icon(item.icon, color: fg);
      if (item.index == kNavAwaiting && awaitingCount > 0) {
        return Badge(label: Text('$awaitingCount'), child: icon);
      }
      return icon;
    }

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.all(collapsed ? 12 : 20),
            child: collapsed
                ? Center(child: SecretaryAvatar(photoUrl: profile?.photoUrl, fullName: profile?.fullName ?? '', radius: 22))
                : Row(children: [
                    SecretaryAvatar(photoUrl: profile?.photoUrl, fullName: profile?.fullName ?? '', radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(strings.welcomeBack, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12)),
                        Text(profile?.fullName ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(strings.sSecretaryRole, style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11)),
                      ]),
                    ),
                  ]),
          ),
          Divider(color: fg.withValues(alpha: 0.15), height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) {
                final isSelected = item.index == selected;
                final bgSel = isSelected ? fg.withValues(alpha: 0.12) : Colors.transparent;
                if (collapsed) {
                  return Tooltip(
                    message: item.title,
                    child: InkWell(
                      onTap: () => onPick(item.index),
                      child: Container(color: bgSel, height: 52, alignment: Alignment.center, child: iconFor(item)),
                    ),
                  );
                }
                return Container(
                  color: bgSel,
                  child: ListTile(
                    leading: iconFor(item),
                    title: Text(item.title, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                    subtitle: Text(item.description, style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => onPick(item.index),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(color: fg.withValues(alpha: 0.15), height: 1),
          if (collapsed)
            Tooltip(
              message: strings.signOut,
              child: InkWell(onTap: onSignOut, child: SizedBox(height: 56, child: Icon(Icons.logout_rounded, color: fg))),
            )
          else
            ListTile(
              leading: Icon(Icons.logout_rounded, color: fg),
              title: Text(strings.signOut, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
              onTap: onSignOut,
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ============================================================
// OVERVIEW - the real dashboard (live counts, quick actions)
// ============================================================

class SecretaryOverviewPage extends ConsumerWidget {
  final String schoolId;
  final AppStrings strings;
  final void Function(int index, {String? feesQuery}) onNavigate;
  const SecretaryOverviewPage({super.key, required this.schoolId, required this.strings, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashAsync = ref.watch(secretaryDashboardProvider(schoolId));
    final profile = ref.watch(secretaryProfileProvider).valueOrNull;

    Future<void> refresh() async {
      ref.invalidate(secretaryDashboardProvider(schoolId));
      try {
        await ref.read(secretaryDashboardProvider(schoolId).future);
      } catch (_) {}
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        children: [
          Text(strings.welcomeBack, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          Text(profile?.fullName ?? strings.sSecretaryRole, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(strings.sOverviewDescription, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 20),
          dashAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SizedBox(height: 220, child: SecretaryErrorView(error: e, strings: strings, onRetry: () => ref.invalidate(secretaryDashboardProvider(schoolId)))),
            data: (d) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!d.mobileMoneyConfigured)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(child: Text(strings.sMobileMoneyUnavailableMessage, style: theme.textTheme.bodySmall)),
                  ]),
                ),
              _Flow(
                children: [
                  SecretaryStatCard(
                    icon: Icons.hourglass_top_rounded,
                    value: '${d.awaitingRegistrationCount}',
                    label: strings.sAwaitingRegistrationStat,
                    color: Colors.orange,
                  ),
                  SecretaryStatCard(
                    icon: Icons.receipt_long_outlined,
                    value: '${d.collectedTodayCount}',
                    label: strings.sCollectedToday,
                    color: theme.colorScheme.primary,
                  ),
                  SecretaryStatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    value: formatMoney(d.collectedTodayTotal),
                    label: strings.sCollectedToday,
                    color: Colors.green.shade700,
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Text(strings.sQuickActions, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _Flow(children: [
            _QuickAction(icon: Icons.person_add_alt_1_rounded, title: strings.sEnrollChild, description: strings.sEnrollChildDescription, onTap: () => onNavigate(kNavEnroll)),
            _QuickAction(icon: Icons.hourglass_top_rounded, title: strings.sAwaitingRegistration, description: strings.sAwaitingRegistrationDescription, onTap: () => onNavigate(kNavAwaiting)),
            _QuickAction(icon: Icons.payments_outlined, title: strings.sCollectFees, description: strings.sCollectFeesDescription, onTap: () => onNavigate(kNavFees)),
            _QuickAction(icon: Icons.groups_outlined, title: strings.sDirectory, description: strings.sDirectoryDescription, onTap: () => onNavigate(kNavDirectory)),
          ]),
        ],
      ),
    );
  }
}

/// Lays children out in 1/2/3 columns by available width, without a
/// fixed aspect ratio - so a card can never overflow its content.
class _Flow extends StatelessWidget {
  final List<Widget> children;
  const _Flow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 12.0;
      final w = constraints.maxWidth;
      final columns = w > 900 ? 3 : (w > 560 ? 2 : 1);
      final itemWidth = (w - spacing * (columns - 1)) / columns;
      return Wrap(spacing: spacing, runSpacing: spacing, children: children.map((c) => SizedBox(width: itemWidth, child: c)).toList());
    });
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.title, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SecretaryCard(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 26, color: theme.colorScheme.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }
}