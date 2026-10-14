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
import '../proprietor/proprietor_ui.dart';
import 'principal_admissions.dart';
import 'principal_arrears.dart';
import 'principal_calendar.dart';
import 'principal_cards.dart';
import 'principal_classes.dart';
import 'principal_comments.dart';
import 'principal_core.dart';
import 'principal_corrections.dart';
import 'principal_expenses.dart';
import 'principal_hub_models.dart' show PnOverview;
import 'principal_hub_providers.dart';
import 'principal_id_cards.dart';
import 'principal_marks.dart';
import 'principal_overview.dart';
import 'principal_promotion.dart';
import 'principal_providers.dart';
import 'principal_settings.dart';
import 'principal_students.dart';
import 'principal_teacher_pay.dart';
import 'principal_teachers.dart';
import 'principal_timetable.dart';
import 'principal_tracker.dart';

class PrincipalHome extends ConsumerWidget {
  const PrincipalHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);
    final strings = AppStrings(ref.watch(activeLocaleProvider));

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: PrError(error: e, strings: strings, onRetry: () => ref.invalidate(landingProvider))),
      data: (school) {
        final sessionAsync = ref.watch(sessionProfileProvider(school.schoolId));
        return sessionAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: PrError(error: e, strings: strings, onRetry: () => ref.invalidate(sessionProfileProvider(school.schoolId)))),
          data: (session) {
            if (session == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/sign-in'));
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (session.role != 'principal') {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(strings.pn('This account is not a Principal account.', 'Ce compte n\'est pas un compte Directeur.'), textAlign: TextAlign.center),
                  ),
                ),
              );
            }
            return Theme(
              data: buildSchoolTheme(school.primaryColor, school.secondaryColor),
              child: _PrincipalShell(landing: school, strings: strings),
            );
          },
        );
      },
    );
  }
}

class _NavItem {
  final String key;
  final IconData icon;
  final IconData activeIcon;
  final String title;
  const _NavItem({required this.key, required this.icon, required this.activeIcon, required this.title});
}

class _NavGroup {
  final String title;
  final List<_NavItem> items;
  const _NavGroup({required this.title, required this.items});
}

class _PrincipalShell extends ConsumerStatefulWidget {
  final LandingModel landing;
  final AppStrings strings;
  const _PrincipalShell({required this.landing, required this.strings});

  @override
  ConsumerState<_PrincipalShell> createState() => _PrincipalShellState();
}

class _PrincipalShellState extends ConsumerState<_PrincipalShell> {
  String _selected = PnNav.overview;
  bool _signingOut = false;

  AppStrings get _s => widget.strings;
  String get _schoolId => widget.landing.schoolId;

  void _navigate(String key) => setState(() => _selected = key);

  List<_NavGroup> _groups() => [
        _NavGroup(title: '', items: [
          _NavItem(key: PnNav.overview, icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, title: _s.pn('Overview', 'Vue d\'ensemble')),
        ]),
        _NavGroup(title: _s.pn('Academics', 'Scolarité'), items: [
          _NavItem(key: PnNav.calendar, icon: Icons.event_note_outlined, activeIcon: Icons.event_note_rounded, title: _s.pn('Academic calendar', 'Calendrier scolaire')),
          _NavItem(key: PnNav.marksWindow, icon: Icons.lock_open_outlined, activeIcon: Icons.lock_open_rounded, title: _s.pn('Marks entry window', 'Fenêtre de saisie')),
          _NavItem(key: PnNav.tracker, icon: Icons.track_changes_outlined, activeIcon: Icons.track_changes_rounded, title: _s.pn('Marks tracker', 'Suivi des notes')),
          _NavItem(key: PnNav.marksReview, icon: Icons.grading_outlined, activeIcon: Icons.grading_rounded, title: _s.pn('Review marks', 'Réviser les notes')),
          _NavItem(key: PnNav.comments, icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, title: _s.pn('Review comments', 'Réviser les commentaires')),
          _NavItem(key: PnNav.cards, icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events_rounded, title: _s.pn('Rankings & report cards', 'Classements et bulletins')),
          _NavItem(key: PnNav.promotion, icon: Icons.trending_up_rounded, activeIcon: Icons.trending_up_rounded, title: _s.pn('Promotion', 'Promotion')),
        ]),
        _NavGroup(title: _s.pn('Students & staff', 'Élèves et personnel'), items: [
          _NavItem(key: PnNav.students, icon: Icons.groups_2_outlined, activeIcon: Icons.groups_2_rounded, title: _s.pn('Students', 'Élèves')),
          _NavItem(key: PnNav.admissions, icon: Icons.how_to_reg_outlined, activeIcon: Icons.how_to_reg_rounded, title: _s.pn('Admissions', 'Admissions')),
          _NavItem(key: PnNav.teachers, icon: Icons.badge_outlined, activeIcon: Icons.badge_rounded, title: _s.pn('Teachers', 'Enseignants')),
          _NavItem(key: PnNav.slots, icon: Icons.assignment_ind_outlined, activeIcon: Icons.assignment_ind_rounded, title: _s.pn('Teaching assignments', 'Affectations')),
        ]),
        _NavGroup(title: _s.pn('School setup', 'Organisation'), items: [
          _NavItem(key: PnNav.classes, icon: Icons.class_outlined, activeIcon: Icons.class_rounded, title: _s.pn('Departments & classes', 'Départements et classes')),
          _NavItem(key: PnNav.subjects, icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, title: _s.pn('Subjects', 'Matières')),
          _NavItem(key: PnNav.fees, icon: Icons.request_quote_outlined, activeIcon: Icons.request_quote_rounded, title: _s.pn('School fees', 'Frais scolaires')),
          _NavItem(key: PnNav.idCards, icon: Icons.contact_mail_outlined, activeIcon: Icons.contact_mail_rounded, title: _s.pn('ID cards', 'Cartes d\'élève')),
        ]),
        _NavGroup(title: _s.pn('Timetable', 'Emploi du temps'), items: [
          _NavItem(key: PnNav.ttSettings, icon: Icons.tune_outlined, activeIcon: Icons.tune_rounded, title: _s.pn('Timetable settings', 'Paramètres')),
          _NavItem(key: PnNav.ttGenerate, icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded, title: _s.pn('Generate with AI', 'Générer avec l\'IA')),
          _NavItem(key: PnNav.ttView, icon: Icons.calendar_view_week_outlined, activeIcon: Icons.calendar_view_week_rounded, title: _s.pn('View & download', 'Consulter et télécharger')),
        ]),
        _NavGroup(title: _s.pn('Money', 'Finances'), items: [
          _NavItem(key: PnNav.corrections, icon: Icons.rule_outlined, activeIcon: Icons.rule_rounded, title: _s.pn('Payment corrections', 'Corrections de paiement')),
          _NavItem(key: PnNav.arrears, icon: Icons.hourglass_bottom_outlined, activeIcon: Icons.hourglass_bottom_rounded, title: _s.pn('Fee arrears', 'Frais impayés')),
          _NavItem(key: PnNav.teacherPay, icon: Icons.payments_outlined, activeIcon: Icons.payments_rounded, title: _s.pn('Teacher pay', 'Paie des enseignants')),
          _NavItem(key: PnNav.expenses, icon: Icons.north_east_rounded, activeIcon: Icons.north_east_rounded, title: _s.pn('Expenses', 'Dépenses')),
        ]),
        _NavGroup(title: '', items: [
          _NavItem(key: PnNav.settings, icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, title: _s.pn('Settings', 'Paramètres généraux')),
        ]),
      ];

  Widget _bodyFor(String key) {
    switch (key) {
      case PnNav.calendar:
        return PrincipalCalendarPage(schoolId: _schoolId, strings: _s);
      case PnNav.marksWindow:
        return MarksWindowPage(schoolId: _schoolId, strings: _s);
      case PnNav.tracker:
        return PrincipalTrackerPage(strings: _s);
      case PnNav.marksReview:
        return MarksReviewPage(schoolId: _schoolId, strings: _s);
      case PnNav.comments:
        return PendingCommentsPage(schoolId: _schoolId, strings: _s);
      case PnNav.cards:
        return PrincipalCardsPage(schoolId: _schoolId, landing: widget.landing, strings: _s);
      case PnNav.promotion:
        return PrincipalPromotionPage(schoolId: _schoolId, strings: _s);
      case PnNav.students:
        return PrincipalStudentsPage(schoolId: _schoolId, strings: _s);
      case PnNav.admissions:
        return AdmissionsReviewPage(schoolId: _schoolId, strings: _s);
      case PnNav.teachers:
        return TeacherOverviewPage(schoolId: _schoolId, strings: _s);
      case PnNav.slots:
        return CreateTeachingSlotPage(schoolId: _schoolId, strings: _s);
      case PnNav.classes:
        return ManageClassesPage(schoolId: _schoolId, strings: _s);
      case PnNav.subjects:
        return SubjectBrowsePage(schoolId: _schoolId, strings: _s);
      case PnNav.fees:
        return ManageFeesEntryPage(schoolId: _schoolId, strings: _s);
      case PnNav.idCards:
        return IdCardManagementPage(schoolId: _schoolId, landing: widget.landing, strings: _s);
      case PnNav.ttSettings:
        return TimetableSettingsPage(schoolId: _schoolId, strings: _s);
      case PnNav.ttGenerate:
        return GenerateTimetablePage(schoolId: _schoolId, strings: _s);
      case PnNav.ttView:
        return ViewTimetablePage(schoolId: _schoolId, landing: widget.landing, strings: _s);
      case PnNav.corrections:
        return PrincipalCorrectionsPage(strings: _s);
      case PnNav.arrears:
        return PrincipalArrearsPage(schoolId: _schoolId, strings: _s);
      case PnNav.teacherPay:
        return PrincipalTeacherPayPage(schoolId: _schoolId, strings: _s);
      case PnNav.expenses:
        return PrincipalExpensesPage(schoolId: _schoolId, strings: _s);
      case PnNav.settings:
        return PrincipalSettingsPage(schoolId: _schoolId, strings: _s);
      default:
        final name = ref.watch(principalProfileProvider).valueOrNull?.fullName;
        return PrincipalOverviewPage(schoolId: _schoolId, strings: _s, principalName: name, onNavigate: _navigate);
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

  int _badgeFor(String key, PnOverview? o) {
    if (o == null) return 0;
    switch (key) {
      case PnNav.marksReview:
        return o.inbox.marks;
      case PnNav.comments:
        return o.inbox.comments;
      case PnNav.admissions:
        return o.inbox.admissions;
      case PnNav.teachers:
        return o.inbox.teachersPending;
      case PnNav.corrections:
        return o.inbox.corrections;
      case PnNav.cards:
        return o.inbox.cardsStale;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pnRealtimeProvider(_schoolId));

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profile = ref.watch(principalProfileProvider).valueOrNull;
    final groups = _groups();
    final overview = ref.watch(pnOverviewProvider).valueOrNull;

    Widget sidebar({required bool collapsed, required bool isDrawer}) => _Sidebar(
          groups: groups,
          selected: _selected,
          collapsed: collapsed,
          name: profile?.fullName ?? '',
          strings: _s,
          badgeFor: (k) => _badgeFor(k, overview),
          onPick: (k) {
            if (isDrawer) Navigator.pop(context);
            _navigate(k);
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
      child: KeyedSubtree(key: ValueKey(_selected), child: _bodyFor(_selected)),
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
            if (!isMobile) Padding(padding: const EdgeInsets.only(right: 16), child: PrLiveDot(label: _s.pn('Live', 'En direct'), color: kSettled)),
          ],
        );

        if (isMobile) {
          return Scaffold(appBar: appBar, drawer: Drawer(child: sidebar(collapsed: false, isDrawer: true)), body: body);
        }
        return Scaffold(
          appBar: appBar,
          body: Row(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 220), width: isTablet ? 84 : 300, child: sidebar(collapsed: isTablet, isDrawer: false)),
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
  final String selected;
  final bool collapsed;
  final String name;
  final AppStrings strings;
  final int Function(String) badgeFor;
  final void Function(String) onPick;
  final VoidCallback onSignOut;

  const _Sidebar({
    required this.groups,
    required this.selected,
    required this.collapsed,
    required this.name,
    required this.strings,
    required this.badgeFor,
    required this.onPick,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.inverseSurface;
    final fg = theme.colorScheme.onInverseSurface;

    Widget iconFor(_NavItem item, bool active) {
      final icon = Icon(active ? item.activeIcon : item.icon, color: active ? fg : fg.withValues(alpha: 0.72), size: 22);
      final n = badgeFor(item.key);
      if (n > 0) return Badge(label: Text('$n'), child: icon);
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
        final active = item.key == selected;
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: _NavTile(item: item, active: active, collapsed: collapsed, fg: fg, icon: iconFor(item, active), onTap: () => onPick(item.key)),
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
                ? Center(child: PrAvatar(name: name, radius: 22, onDark: true))
                : Row(children: [
                    PrAvatar(name: name, radius: 22, onDark: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(strings.welcomeBack, style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 12)),
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 15.5, fontWeight: FontWeight.w800)),
                        Text(strings.pn('Principal', 'Directeur'), style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 11.5)),
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
  final _NavItem item;
  final bool active;
  final bool collapsed;
  final Color fg;
  final Widget icon;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.active, required this.collapsed, required this.fg, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(color: active ? fg.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
      child: collapsed
          ? SizedBox(height: 46, child: Center(child: icon))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                icon,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
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
    return collapsed ? Tooltip(message: item.title, child: ink) : ink;
  }
}
