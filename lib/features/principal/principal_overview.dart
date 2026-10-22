import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_charts.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

/// Navigation keys shared by the shell and the overview shortcuts.
class PnNav {
  static const overview = 'overview';
  static const calendar = 'calendar';
  static const cards = 'cards';
  static const promotion = 'promotion';
  static const tracker = 'tracker';
  static const marksWindow = 'marks_window';
  static const marksReview = 'marks_review';
  static const comments = 'comments';
  static const students = 'students';
  static const admissions = 'admissions';
  static const teachers = 'teachers';
  static const slots = 'slots';
  static const classes = 'classes';
  static const subjects = 'subjects';
  static const fees = 'fees';
  static const corrections = 'corrections';
  static const teacherPay = 'teacher_pay';
  static const expenses = 'expenses';
  static const arrears = 'arrears';
  static const idCards = 'id_cards';
  static const ttSettings = 'tt_settings';
  static const ttGenerate = 'tt_generate';
  static const ttView = 'tt_view';
  static const settings = 'settings';
  static const insights = 'insights';
  static const siteStats = 'site_stats';
  static const siteAnnouncements = 'site_announcements';
  static const siteEvents = 'site_events';
  static const siteDocuments = 'site_documents';
}

class PrincipalOverviewPage extends ConsumerWidget {
  final String schoolId;
  final AppStrings strings;
  final String? principalName;
  final void Function(String) onNavigate;
  const PrincipalOverviewPage({super.key, required this.schoolId, required this.strings, this.principalName, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings;
    final async = ref.watch(pnOverviewProvider);

    Future<void> refresh() async {
      ref.invalidate(pnOverviewProvider);
      try {
        await ref.read(pnOverviewProvider.future);
      } catch (_) {}
    }

    if (async.isLoading && !async.hasValue) return const PrPageSkeleton();
    if (async.hasError && !async.hasValue) {
      return PrError(error: async.error!, strings: s, onRetry: () => ref.invalidate(pnOverviewProvider));
    }
    final o = async.requireValue;
    final first = (principalName ?? '').trim().isEmpty ? '' : ', ${principalName!.trim().split(' ').first}';

    return PrPage(
      onRefresh: refresh,
      children: [
        PrHeader(
          title: '${pGreeting(s)}$first',
          subtitle: s.pn('Everything happening in your school, in one place.', 'Tout ce qui se passe dans votre école, au même endroit.'),
          trailing: IconButton.filledTonal(onPressed: refresh, tooltip: s.pn('Refresh', 'Actualiser'), icon: const Icon(Icons.refresh_rounded)),
        ),
        PrReveal(child: _YearHero(o: o, strings: s, onNavigate: onNavigate)),
        const SizedBox(height: 16),
        PrGrid(minTile: 240, children: [
          PrStatTile(
            icon: Icons.groups_2_outlined,
            label: s.pn('Students enrolled', 'Élèves inscrits'),
            value: o.students.toDouble(),
            format: (v) => v.round().toString(),
            footer: Text(
              o.capacity > 0 ? '${o.capacityUsed.toStringAsFixed(0)}% ${s.pn('of capacity', 'de la capacité')}' : '${o.classes} ${s.pn('classes', 'classes')}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            onTap: () => onNavigate(PnNav.students),
          ),
          PrStatTile(
            icon: Icons.south_west_rounded,
            label: s.pn('Collected this month', 'Encaissé ce mois'),
            value: o.money.collectedMonth,
            format: pMoney,
            footer: Text('${s.pn('Today', 'Aujourd\'hui')}: ${pMoney(o.money.collectedToday)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
            onTap: () => onNavigate(PnNav.arrears),
          ),
          PrStatTile(
            icon: Icons.hourglass_bottom_rounded,
            label: s.pn('Fees overdue', 'Frais en retard'),
            value: o.money.arrears,
            format: pMoney,
            footer: Text('${o.money.debtors} ${s.pn('students owe fees', 'élèves redoivent des frais')}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
            onTap: () => onNavigate(PnNav.arrears),
          ),
          PrStatTile(
            icon: Icons.badge_outlined,
            label: s.pn('Teachers', 'Enseignants'),
            value: o.teachers.toDouble(),
            format: (v) => v.round().toString(),
            footer: Text('${s.pn('Paid this month', 'Payé ce mois')}: ${pMoney(o.money.teacherPayMonth)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
            onTap: () => onNavigate(PnNav.teacherPay),
          ),
        ]),
        const SizedBox(height: 16),
        _Attention(o: o, strings: s, onNavigate: onNavigate),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final fill = PrReveal(child: _ClassFill(o: o, strings: s, onTap: () => onNavigate(PnNav.classes)));
          final side = Column(children: [
            PrReveal(index: 1, child: _MoneyPanel(o: o, strings: s, onNavigate: onNavigate)),
            const SizedBox(height: 14),
            PrReveal(index: 2, child: _GenderPanel(o: o, strings: s)),
          ]);
          if (!wide) return Column(children: [fill, const SizedBox(height: 14), side]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 6, child: fill),
            const SizedBox(width: 14),
            Expanded(flex: 5, child: side),
          ]);
        }),
        const SizedBox(height: 8),
        PrSectionTitle(title: s.pn('Quick actions', 'Actions rapides')),
        PrGrid(minTile: 230, max: 4, children: [
          _Quick(icon: Icons.emoji_events_outlined, title: s.pn('Rankings & report cards', 'Classements et bulletins'), desc: s.pn('Generate, rank and publish', 'Générer, classer et publier'), onTap: () => onNavigate(PnNav.cards)),
          _Quick(icon: Icons.trending_up_rounded, title: s.pn('Promote students', 'Promouvoir les élèves'), desc: s.pn('Move classes up at year end', 'Passage en classe supérieure'), onTap: () => onNavigate(PnNav.promotion)),
          _Quick(icon: Icons.payments_outlined, title: s.pn('Pay a teacher', 'Payer un enseignant'), desc: s.pn('Cash, transfer or mobile money', 'Espèces, virement ou mobile money'), onTap: () => onNavigate(PnNav.teacherPay)),
          _Quick(icon: Icons.event_note_outlined, title: s.pn('Academic calendar', 'Calendrier scolaire'), desc: s.pn('Years, terms and sequences', 'Années, trimestres et séquences'), onTap: () => onNavigate(PnNav.calendar)),
        ]),
      ],
    );
  }
}

// ============================================================ hero

class _YearHero extends StatelessWidget {
  final PnOverview o;
  final AppStrings strings;
  final void Function(String) onNavigate;
  const _YearHero({required this.o, required this.strings, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final on = cs.onPrimary;
    final s = strings;
    final y = o.year;

    double progress = 0;
    if (y?.start != null && y?.end != null) {
      final total = y!.end!.difference(y.start!).inHours;
      final done = DateTime.now().difference(y.start!).inHours;
      progress = total <= 0 ? 0 : (done / total).clamp(0.0, 1.0).toDouble();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), cs.primary)]),
      ),
      child: y == null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.pn('No active academic year', 'Aucune année scolaire active'), style: theme.textTheme.titleLarge?.copyWith(color: on, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(s.pn('Create and activate an academic year to start enrolling, entering marks and collecting fees.', 'Créez et activez une année scolaire pour commencer les inscriptions, la saisie des notes et l\'encaissement des frais.'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: on.withValues(alpha: 0.8), height: 1.4)),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: on, foregroundColor: cs.primary),
                onPressed: () => onNavigate(PnNav.calendar),
                icon: const Icon(Icons.add_rounded),
                label: Text(s.pn('Create academic year', 'Créer une année scolaire')),
              ),
            ])
          : LayoutBuilder(builder: (context, c) {
              final stacked = c.maxWidth < 640;
              final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.pn('Current academic year', 'Année scolaire en cours'), style: theme.textTheme.labelLarge?.copyWith(color: on.withValues(alpha: 0.78), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(y.name, style: theme.textTheme.displaySmall?.copyWith(color: on, fontWeight: FontWeight.w900, letterSpacing: -1)),
                const SizedBox(height: 6),
                Text(
                  o.term == null ? s.pn('No current term set', 'Aucun trimestre en cours') : o.term!.name,
                  style: theme.textTheme.titleMedium?.copyWith(color: on.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
                ),
              ]);
              final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(y.start == null ? '' : pDate(y.start!), style: TextStyle(color: on.withValues(alpha: 0.78), fontSize: 12, fontWeight: FontWeight.w600))),
                  Text(y.end == null ? '' : pDate(y.end!), style: TextStyle(color: on.withValues(alpha: 0.78), fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 10, backgroundColor: on.withValues(alpha: 0.2), color: on),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _HeroPill(
                    icon: Icons.lock_open_rounded,
                    text: o.openSequences > 0 ? '${o.openSequences} ${s.pn('sequence(s) open for marks', 'séquence(s) ouverte(s) aux notes')}' : s.pn('No sequence open', 'Aucune séquence ouverte'),
                  ),
                  if (o.nextMarksDue != null) _HeroPill(icon: Icons.event_outlined, text: '${s.pn('Marks due', 'Notes à rendre le')} ${pDate(o.nextMarksDue!)}'),
                  if (y.daysLeft != null && y.daysLeft! >= 0) _HeroPill(icon: Icons.hourglass_empty_rounded, text: '${y.daysLeft} ${s.pn('days left', 'jours restants')}'),
                ]),
              ]);
              if (stacked) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 18), right]);
              return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 5, child: left),
                const SizedBox(width: 28),
                Expanded(flex: 6, child: right),
              ]);
            }),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: on.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: on),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: TextStyle(color: on, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

// ============================================================ attention

class _Item {
  final IconData icon;
  final String text;
  final Color color;
  final String target;
  final int? count;
  const _Item({required this.icon, required this.text, required this.color, required this.target, this.count});
}

class _Attention extends StatelessWidget {
  final PnOverview o;
  final AppStrings strings;
  final void Function(String) onNavigate;
  const _Attention({required this.o, required this.strings, required this.onNavigate});

  List<_Item> _items() {
    final s = strings;
    final i = o.inbox;
    final out = <_Item>[];
    final warn = pnWarn();
    if (i.corrections > 0) {
      out.add(_Item(icon: Icons.rule_rounded, text: s.pn('Payment corrections waiting for your decision', 'Corrections de paiement en attente de votre décision'), color: pnBad(), target: PnNav.corrections, count: i.corrections));
    }
    if (i.admissions > 0) {
      out.add(_Item(icon: Icons.how_to_reg_outlined, text: s.pn('Admissions to review', 'Admissions à examiner'), color: warn, target: PnNav.admissions, count: i.admissions));
    }
    if (i.marks > 0) {
      out.add(_Item(icon: Icons.grading_outlined, text: s.pn('Marks submitted by teachers', 'Notes soumises par les enseignants'), color: warn, target: PnNav.marksReview, count: i.marks));
    }
    if (i.comments > 0) {
      out.add(_Item(icon: Icons.chat_bubble_outline_rounded, text: s.pn('Teacher comments to approve', 'Commentaires d\'enseignants à approuver'), color: warn, target: PnNav.comments, count: i.comments));
    }
    if (i.teachersPending > 0) {
      out.add(_Item(icon: Icons.person_add_alt_1_outlined, text: s.pn('Teachers waiting for approval', 'Enseignants en attente d\'approbation'), color: warn, target: PnNav.teachers, count: i.teachersPending));
    }
    if (i.cardsStale > 0) {
      out.add(_Item(icon: Icons.sync_problem_rounded, text: s.pn('Report cards out of date after mark changes', 'Bulletins obsolètes après modification des notes'), color: warn, target: PnNav.cards, count: i.cardsStale));
    }
    if (o.money.flagged > 0) {
      out.add(_Item(icon: Icons.flag_outlined, text: s.pn('Large payments flagged to the proprietor', 'Gros paiements signalés au propriétaire'), color: Colors.grey, target: PnNav.expenses, count: o.money.flagged));
    }
    final y = o.year;
    if (y != null && y.daysLeft != null && y.daysLeft! <= 45 && !o.nextYearExists) {
      out.add(_Item(
        icon: Icons.event_repeat_rounded,
        text: s.pn('The year ends in ${y.daysLeft! < 0 ? 0 : y.daysLeft} days. Prepare next year and promote students.', 'L\'année se termine dans ${y.daysLeft! < 0 ? 0 : y.daysLeft} jours. Préparez la prochaine année et promouvez les élèves.'),
        color: pnWarn(),
        target: PnNav.calendar,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final theme = Theme.of(context);
    final s = strings;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: PrReveal(
          child: PnNotice(text: s.pn('You are all caught up. Nothing is waiting for your decision.', 'Tout est à jour. Rien n\'attend votre décision.'), icon: Icons.check_circle_outline_rounded, color: pnGood()),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PrSectionTitle(title: s.pn('Needs your attention', 'À traiter')),
        PrReveal(
          child: PrCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (var k = 0; k < items.length; k++) ...[
                if (k > 0) Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                InkWell(
                  onTap: () => onNavigate(items[k].target),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: items[k].color.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: Icon(items[k].icon, size: 16, color: items[k].color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(items[k].text, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                      if (items[k].count != null) ...[
                        PnChip(label: '${items[k].count}', color: items[k].color),
                        const SizedBox(width: 6),
                      ],
                      Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

// ============================================================ panels

class _ClassFill extends StatelessWidget {
  final PnOverview o;
  final AppStrings strings;
  final VoidCallback onTap;
  const _ClassFill({required this.o, required this.strings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final list = [...o.classFill]..sort((a, b) => b.ratio.compareTo(a.ratio));
    final shown = list.take(8).toList();

    return PnPanel(
      title: s.pn('Class capacity', 'Capacité des classes'),
      subtitle: s.pn('Fullest classes first', 'Classes les plus remplies en premier'),
      trailing: TextButton(onPressed: onTap, child: Text(s.pn('Manage', 'Gérer'))),
      child: shown.isEmpty
          ? PrEmpty(icon: Icons.class_outlined, title: s.pn('No classes yet', 'Aucune classe pour l\'instant'))
          : Column(children: [
              for (final c in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Text(c.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                      Text(c.max > 0 ? '${c.enrolled} / ${c.max}' : '${c.enrolled}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, fontWeight: FontWeight.w700)),
                      if (c.isFull) ...[const SizedBox(width: 8), PnChip(label: s.pn('Full', 'Pleine'), color: pnWarn())],
                    ]),
                    const SizedBox(height: 6),
                    PrProgressBar(value: c.ratio, height: 7, color: c.isFull ? pnWarn() : cs.primary),
                  ]),
                ),
            ]),
    );
  }
}

class _MoneyPanel extends StatelessWidget {
  final PnOverview o;
  final AppStrings strings;
  final void Function(String) onNavigate;
  const _MoneyPanel({required this.o, required this.strings, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = strings;
    Widget row(IconData icon, String label, String value, String target) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onNavigate(target),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ),
        );
    return PnPanel(
      title: s.pn('Money at a glance', 'L\'argent en un coup d\'œil'),
      child: Column(children: [
        row(Icons.south_west_rounded, s.pn('Collected today', 'Encaissé aujourd\'hui'), pMoney(o.money.collectedToday), PnNav.arrears),
        const Divider(height: 1),
        row(Icons.hourglass_bottom_rounded, s.pn('Overdue fees', 'Frais en retard'), pMoney(o.money.arrears), PnNav.arrears),
        const Divider(height: 1),
        row(Icons.payments_outlined, s.pn('Teacher pay this month', 'Salaires versés ce mois'), pMoney(o.money.teacherPayMonth), PnNav.teacherPay),
        const Divider(height: 1),
        row(Icons.rule_rounded, s.pn('Corrections to review', 'Corrections à examiner'), '${o.inbox.corrections}', PnNav.corrections),
      ]),
    );
  }
}

class _GenderPanel extends StatelessWidget {
  final PnOverview o;
  final AppStrings strings;
  const _GenderPanel({required this.o, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final male = o.gender.entries.where((e) => e.key.toLowerCase().startsWith('m')).fold<int>(0, (a, e) => a + e.value);
    final female = o.gender.entries.where((e) => e.key.toLowerCase().startsWith('f')).fold<int>(0, (a, e) => a + e.value);
    return PnPanel(
      title: s.pn('Boys and girls', 'Garçons et filles'),
      child: (male + female) == 0
          ? Text(s.pn('No enrolled students yet.', 'Aucun élève inscrit pour l\'instant.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PrSplitBar(parts: [PrSlice(label: '', value: male.toDouble(), color: cs.primary), PrSlice(label: '', value: female.toDouble(), color: cs.secondary)]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: PrLegendItem(label: '${s.pn('Boys', 'Garçons')}: $male', color: cs.primary)),
                Expanded(child: PrLegendItem(label: '${s.pn('Girls', 'Filles')}: $female', color: cs.secondary)),
              ]),
            ]),
    );
  }
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  const _Quick({required this.icon, required this.title, required this.desc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrCard(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 24, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(desc, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
      ]),
    );
  }
}
