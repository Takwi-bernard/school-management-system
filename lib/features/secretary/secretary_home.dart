import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import '../parent/parent_models.dart' show buildSchoolTheme;
import '../principal/principal_core.dart';
import '../principal/principal_kit.dart';
import '../proprietor/proprietor_ui.dart';
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

    Widget loader() => const Scaffold(body: Padding(padding: EdgeInsets.all(24), child: PrPageSkeleton()));

    return landing.when(
      loading: loader,
      error: (e, _) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: SxError(error: e, strings: strings, onRetry: () => ref.invalidate(landingProvider))))),
      data: (school) {
        final sessionAsync = ref.watch(sessionProfileProvider(school.schoolId));
        return sessionAsync.when(
          loading: loader,
          error: (e, _) => Scaffold(
            body: Center(
              child: Padding(padding: const EdgeInsets.all(24), child: SxError(error: e, strings: strings, onRetry: () => ref.invalidate(sessionProfileProvider(school.schoolId)))),
            ),
          ),
          data: (session) {
            if (session == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/sign-in'));
              return loader();
            }
            if (session.role != 'secretary') {
              final msg = strings.isFrench ? 'Ce compte est un compte ${session.role}, pas Secrétaire.' : 'This account is a ${session.role} account, not Secretary.';
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
  final IconData activeIcon;
  final String title;
  final int index;
  const _NavItem({required this.icon, required this.activeIcon, required this.title, required this.index});
}

class _NavGroup {
  final String title;
  final List<_NavItem> items;
  const _NavGroup({required this.title, required this.items});
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

  List<_NavGroup> _groups() => [
        _NavGroup(title: '', items: [
          _NavItem(icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, title: _s.sOverview, index: kNavOverview),
        ]),
        _NavGroup(title: _s.isFrench ? 'Élèves' : 'Students', items: [
          _NavItem(icon: Icons.person_add_alt_1_outlined, activeIcon: Icons.person_add_alt_1_rounded, title: _s.sEnrollChild, index: kNavEnroll),
          _NavItem(icon: Icons.hourglass_top_outlined, activeIcon: Icons.hourglass_top_rounded, title: _s.sAwaitingRegistration, index: kNavAwaiting),
          _NavItem(icon: Icons.groups_2_outlined, activeIcon: Icons.groups_2_rounded, title: _s.sDirectory, index: kNavDirectory),
        ]),
        _NavGroup(title: _s.isFrench ? 'Encaissements' : 'Collections', items: [
          _NavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments_rounded, title: _s.sCollectFees, index: kNavFees),
          _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, title: _s.sMyCollections, index: kNavCollections),
        ]),
        _NavGroup(title: '', items: [
          _NavItem(icon: Icons.account_circle_outlined, activeIcon: Icons.account_circle_rounded, title: _s.myProfile, index: kNavProfile),
        ]),
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
    final confirmed = await pnConfirm(
      context,
      _s,
      title: _s.signOutConfirmTitle,
      message: _s.signOutConfirmMessage,
      confirmLabel: _s.signOut,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _signingOut = true);
    final started = DateTime.now();
    try {
      await ref.read(authControllerProvider.notifier).signOut();
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
    final cs = theme.colorScheme;
    final profile = ref.watch(secretaryProfileProvider).valueOrNull;
    final awaitingCount = ref.watch(secretaryDashboardProvider(_schoolId)).valueOrNull?.awaitingRegistrationCount ?? 0;
    final groups = _groups();

    Widget sidebar({required bool collapsed, required bool isDrawer}) => _Sidebar(
          groups: groups,
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
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero).animate(animation), child: child),
      ),
      child: KeyedSubtree(key: ValueKey('$_selected-$_pageKey'), child: _bodyFor(_selected)),
    );

    return Stack(fit: StackFit.expand, children: [
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 760;
        final isTablet = width >= 760 && width < 1100;

        final appBar = AppBar(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: isMobile,
          titleSpacing: 14,
          shape: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
          title: Row(children: [
            if (widget.landing.logoUrl.isNotEmpty)
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: cs.outlineVariant)),
                child: Image.network(widget.landing.logoUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: cs.primary, size: 18)),
              ),
            Expanded(child: Text(widget.landing.schoolName, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          ]),
          actions: [
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _navigate(kNavProfile),
                  child: PnAvatar(stored: profile?.photoUrl, name: profile?.fullName ?? '', radius: 16, bucket: pnStaffPhotos),
                ),
              )
            else
              Padding(padding: const EdgeInsets.only(right: 16), child: PrLiveDot(label: _s.isFrench ? 'En direct' : 'Live', color: kSettled)),
          ],
        );

        if (isMobile) {
          return Scaffold(appBar: appBar, drawer: Drawer(child: sidebar(collapsed: false, isDrawer: true)), body: body);
        }
        return Scaffold(
          appBar: appBar,
          body: Row(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 220), width: isTablet ? 84 : 288, child: sidebar(collapsed: isTablet, isDrawer: false)),
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

// ============================================================ sidebar

class _Sidebar extends StatelessWidget {
  final List<_NavGroup> groups;
  final int selected;
  final bool collapsed;
  final SecretaryProfile? profile;
  final int awaitingCount;
  final AppStrings strings;
  final void Function(int) onPick;
  final VoidCallback onSignOut;

  const _Sidebar({
    required this.groups,
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
    final bg = theme.colorScheme.inverseSurface;
    final fg = theme.colorScheme.onInverseSurface;
    final name = profile?.fullName ?? '';

    Widget iconFor(_NavItem item, bool active) {
      final icon = Icon(active ? item.activeIcon : item.icon, color: active ? fg : fg.withValues(alpha: 0.72), size: 22);
      if (item.index == kNavAwaiting && awaitingCount > 0) return Badge(label: Text('$awaitingCount'), child: icon);
      return icon;
    }

    final children = <Widget>[];
    for (final g in groups) {
      if (g.title.isNotEmpty) {
        children.add(collapsed
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: fg.withValues(alpha: 0.12), height: 1))
            : Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                child: Text(g.title.toUpperCase(), style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ));
      }
      for (final item in g.items) {
        final active = item.index == selected;
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: _NavTile(title: item.title, active: active, collapsed: collapsed, fg: fg, icon: iconFor(item, active), onTap: () => onPick(item.index)),
        ));
      }
    }

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 12 : 20, 18, collapsed ? 12 : 20, 14),
            child: collapsed
                ? Center(child: PnAvatar(stored: profile?.photoUrl, name: name, radius: 22, bucket: pnStaffPhotos, onDark: true))
                : Row(children: [
                    PnAvatar(stored: profile?.photoUrl, name: name, radius: 22, bucket: pnStaffPhotos, onDark: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(strings.welcomeBack, style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 12)),
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 15.5, fontWeight: FontWeight.w800)),
                        Text(strings.sSecretaryRole, style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 11.5)),
                      ]),
                    ),
                  ]),
          ),
          Divider(color: fg.withValues(alpha: 0.12), height: 1),
          Expanded(child: ListView(padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 8), children: children)),
          Divider(color: fg.withValues(alpha: 0.12), height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 10),
            child: collapsed
                ? Tooltip(
                    message: strings.signOut,
                    child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onSignOut, child: SizedBox(height: 48, child: Icon(Icons.logout_rounded, color: fg.withValues(alpha: 0.8)))),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onSignOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(children: [
                        Icon(Icons.logout_rounded, color: fg.withValues(alpha: 0.8), size: 20),
                        const SizedBox(width: 14),
                        Text(strings.signOut, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final bool active;
  final bool collapsed;
  final Color fg;
  final Widget icon;
  final VoidCallback onTap;
  const _NavTile({required this.title, required this.active, required this.collapsed, required this.fg, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(color: active ? fg.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
      child: collapsed
          ? SizedBox(height: 46, child: Center(child: icon))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                icon,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: active ? fg : fg.withValues(alpha: 0.82), fontWeight: active ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  height: active ? 18 : 0,
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(4)),
                ),
              ]),
            ),
    );
    final ink = InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: tile);
    return collapsed ? Tooltip(message: title, child: ink) : ink;
  }
}

// ============================================================ overview

class SecretaryOverviewPage extends ConsumerWidget {
  final String schoolId;
  final AppStrings strings;
  final void Function(int index, {String? feesQuery}) onNavigate;
  const SecretaryOverviewPage({super.key, required this.schoolId, required this.strings, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dashAsync = ref.watch(secretaryDashboardProvider(schoolId));
    final recentAsync = ref.watch(myPaymentsProvider(schoolId));
    final profile = ref.watch(secretaryProfileProvider).valueOrNull;
    final fr = strings.isFrench;

    Future<void> refresh() async {
      ref.invalidate(secretaryDashboardProvider(schoolId));
      ref.invalidate(myPaymentsProvider(schoolId));
      try {
        await ref.read(secretaryDashboardProvider(schoolId).future);
      } catch (_) {}
    }

    final firstName = (profile?.fullName ?? '').trim().split(RegExp(r'\s+')).first;

    return PrPage(
      onRefresh: refresh,
      children: [
        PrReveal(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, Color.lerp(cs.primary, cs.inverseSurface, 0.45) ?? cs.primary]),
            ),
            child: Row(children: [
              PnAvatar(stored: profile?.photoUrl, name: profile?.fullName ?? '', radius: 30, bucket: pnStaffPhotos, onDark: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(strings.welcomeBack, style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.78), fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(firstName.isEmpty ? strings.sSecretaryRole : firstName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Text(strings.sOverviewDescription, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.82), fontSize: 12.5, height: 1.35)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        dashAsync.when(
          skipLoadingOnReload: true,
          loading: () => PrGrid(children: List.generate(3, (_) => const PrSkeleton(height: 112, radius: 20)), max: 3, minTile: 220),
          error: (e, _) => SxError(error: e, strings: strings, onRetry: () => ref.invalidate(secretaryDashboardProvider(schoolId))),
          data: (d) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!d.mobileMoneyConfigured)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PrReveal(child: PnNotice(text: strings.sMobileMoneyUnavailableMessage, icon: Icons.info_outline_rounded, color: pnWarn())),
              ),
            PrGrid(max: 3, minTile: 220, children: [
              PrStatTile(
                icon: Icons.hourglass_top_rounded,
                label: strings.sAwaitingRegistrationStat,
                value: d.awaitingRegistrationCount.toDouble(),
                format: (v) => v.round().toString(),
                onTap: () => onNavigate(kNavAwaiting),
              ),
              PrStatTile(
                icon: Icons.receipt_long_rounded,
                label: strings.sCollectedToday,
                value: d.collectedTodayCount.toDouble(),
                format: (v) => v.round().toString(),
                onTap: () => onNavigate(kNavCollections),
              ),
              PrStatTile(
                icon: Icons.account_balance_wallet_rounded,
                label: fr ? 'Total encaissé aujourd\'hui' : 'Collected today (total)',
                value: d.collectedTodayTotal,
                format: formatMoney,
                onTap: () => onNavigate(kNavCollections),
              ),
            ]),
          ]),
        ),
        PrSectionTitle(title: strings.sQuickActions),
        PrGrid(max: 2, minTile: 340, children: [
          _QuickAction(icon: Icons.person_add_alt_1_rounded, title: strings.sEnrollChild, description: strings.sEnrollChildDescription, onTap: () => onNavigate(kNavEnroll)),
          _QuickAction(icon: Icons.payments_rounded, title: strings.sCollectFees, description: strings.sCollectFeesDescription, onTap: () => onNavigate(kNavFees)),
          _QuickAction(icon: Icons.hourglass_top_rounded, title: strings.sAwaitingRegistration, description: strings.sAwaitingRegistrationDescription, onTap: () => onNavigate(kNavAwaiting)),
          _QuickAction(icon: Icons.groups_2_rounded, title: strings.sDirectory, description: strings.sDirectoryDescription, onTap: () => onNavigate(kNavDirectory)),
        ]),
        const SizedBox(height: 22),
        PnPanel(
          title: strings.sMyCollections,
          subtitle: fr ? 'Vos derniers encaissements' : 'Your latest collections',
          trailing: TextButton(onPressed: () => onNavigate(kNavCollections), child: Text(fr ? 'Tout voir' : 'See all')),
          child: recentAsync.when(
            skipLoadingOnReload: true,
            loading: () => const SxSkeletonList(rows: 3, height: 52),
            error: (e, _) => SxError(error: e, strings: strings, onRetry: () => ref.invalidate(myPaymentsProvider(schoolId))),
            data: (list) {
              if (list.isEmpty) return PnEmpty(icon: Icons.receipt_long_outlined, title: strings.sNoCollectionsYetMessage);
              final shown = list.take(5).toList();
              return Column(children: [
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SxIconBadge(icon: _methodIcon(shown[i].method), size: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(shown[i].childName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text('${paymentMethodLabel(strings, shown[i].method)} · ${formatTime(shown[i].createdAt)}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text(formatMoney(shown[i].amount), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ]),
                  ),
              ]);
            },
          ),
        ),
      ],
    );
  }
}

IconData _methodIcon(String m) {
  switch (m) {
    case 'cash':
      return Icons.payments_rounded;
    case 'bank_transfer':
      return Icons.account_balance_rounded;
    default:
      return Icons.smartphone_rounded;
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
    return PrCard(
      onTap: onTap,
      child: Row(children: [
        SxIconBadge(icon: icon, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.3)),
          ]),
        ),
        Icon(Icons.arrow_forward_rounded, size: 20, color: theme.colorScheme.outline),
      ]),
    );
  }
}
