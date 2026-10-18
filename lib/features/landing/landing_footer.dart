import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../auth/auth_branding_header.dart';
import 'landing_content.dart' show SectionHeading;
import 'landing_model.dart';
import 'landing_text.dart';

class LandingFooterSection extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  final List<(String, VoidCallback)> links;

  const LandingFooterSection({super.key, required this.school, required this.strings, this.links = const []});

  @override
  Widget build(BuildContext context) {
    final text = LandingText(strings.isFrench);
    return Column(children: [
      if (school.announcements.isNotEmpty || school.events.isNotEmpty) RevealOnScroll(child: _Updates(school: school, strings: strings, text: text)),
      RevealOnScroll(child: _Contact(school: school, text: text)),
      _Footer(school: school, strings: strings, text: text, links: links),
    ]);
  }
}

// ---------------------------------------------------------------------------
// ANNOUNCEMENTS + EVENTS
// ---------------------------------------------------------------------------

class _Updates extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  final LandingText text;
  const _Updates({required this.school, required this.strings, required this.text});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hasA = school.announcements.isNotEmpty;
    final hasE = school.events.isNotEmpty;

    final announcements = hasA
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ListTitle(title: strings.announcements, icon: Icons.campaign_outlined),
            for (final a in school.announcements.take(3))
              _UpdateCard(title: a.title, body: a.content, meta: a.publishedAt == null ? null : text.date(a.publishedAt!), text: text),
          ])
        : const SizedBox.shrink();

    final events = hasE
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ListTitle(title: strings.upcomingEvents, icon: Icons.event_outlined),
            for (final e in school.events.take(3))
              _UpdateCard(
                title: e.title,
                body: [e.description, e.location].where((s) => s != null && s.isNotEmpty).join(' · '),
                date: e.eventDate,
                text: text,
              ),
          ])
        : const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: isMobile ? 56 : 88),
      child: isMobile || !(hasA && hasE)
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (hasA) announcements,
              if (hasA && hasE) const SizedBox(height: 40),
              if (hasE) events,
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: announcements),
              const SizedBox(width: 48),
              Expanded(child: events),
            ]),
    );
  }
}

class _ListTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ListTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3)),
      ]),
    );
  }
}

/// A tappable card that grows in place for long text. Events show a
/// small date badge; announcements show their date as a caption.
class _UpdateCard extends StatefulWidget {
  final String title;
  final String body;
  final String? meta;
  final DateTime? date;
  final LandingText text;
  const _UpdateCard({required this.title, required this.body, this.meta, this.date, required this.text});

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canExpand = widget.body.length > 110;

    return HoverLift(
      liftPixels: 3,
      onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.date != null) ...[
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('${widget.date!.day}', style: TextStyle(color: cs.onPrimary, fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
                Text(widget.text.month(widget.date!).toUpperCase(), style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.9), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ]),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.meta != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(widget.meta!, style: theme.textTheme.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800))),
                Text(widget.title, maxLines: _expanded ? null : 2, overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (widget.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(widget.body, maxLines: _expanded ? null : 2, overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5)),
                ],
                if (canExpand) ...[
                  const SizedBox(height: 8),
                  Text(_expanded ? widget.text.showLess : widget.text.readMore, style: theme.textTheme.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CONTACT - tap a card to copy its value
// ---------------------------------------------------------------------------

class _Contact extends StatelessWidget {
  final LandingModel school;
  final LandingText text;
  const _Contact({required this.school, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(IconData, String, String)>[
      if (school.phone.isNotEmpty) (Icons.phone_rounded, text.phone, school.phone),
      if (school.email.isNotEmpty) (Icons.email_rounded, text.email, school.email),
      if (school.address.isNotEmpty) (Icons.location_on_rounded, text.address, school.address),
      if (school.website.isNotEmpty) (Icons.language_rounded, text.website, school.website),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    final isMobile = Responsive.isMobile(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: isMobile ? 56 : 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeading(overline: text.getInTouch, title: text.contactTitle),
        const SizedBox(height: 28),
        LayoutBuilder(builder: (context, box) {
          const gap = 16.0;
          final cols = box.maxWidth < 560 ? 1 : (box.maxWidth < 900 ? 2 : (items.length >= 4 ? 4 : items.length));
          final w = ((box.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final it in items) SizedBox(width: w, child: _ContactCard(icon: it.$1, label: it.$2, value: it.$3, text: text)),
          ]);
        }),
      ]),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final LandingText text;
  const _ContactCard({required this.icon, required this.label, required this.value, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return HoverLift(
      liftPixels: 4,
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('${text.copied}: $value'), duration: const Duration(seconds: 2)));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          const SizedBox(height: 14),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 8),
          Text(text.tapToCopy, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FOOTER
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  final LandingModel school;
  final AppStrings strings;
  final LandingText text;
  final List<(String, VoidCallback)> links;
  const _Footer({required this.school, required this.strings, required this.text, required this.links});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);
    final deep = Color.lerp(cs.primary, Colors.black, 0.62) ?? cs.primary;
    final fg = Colors.white;
    final dim = Colors.white.withValues(alpha: 0.65);

    final brand = Column(crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
      SchoolLogo(url: school.logoUrl, size: 60),
      const SizedBox(height: 14),
      Text(school.schoolName, textAlign: isMobile ? TextAlign.center : TextAlign.start, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3)),
      if (school.motto.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(school.motto, textAlign: isMobile ? TextAlign.center : TextAlign.start, style: TextStyle(color: dim, fontStyle: FontStyle.italic, height: 1.4)),
      ],
    ]);

    final quick = Column(crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
      Text(text.quickLinks.toUpperCase(), style: TextStyle(color: dim, fontWeight: FontWeight.w800, letterSpacing: 1.3, fontSize: 12)),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 2, alignment: isMobile ? WrapAlignment.center : WrapAlignment.start, children: [
        for (final l in links) TextButton(onPressed: l.$2, style: TextButton.styleFrom(foregroundColor: fg, padding: const EdgeInsets.symmetric(horizontal: 10)), child: Text(l.$1)),
      ]),
    ]);

    return Container(
      width: double.infinity,
      color: deep,
      padding: EdgeInsets.fromLTRB(Responsive.pagePadding(context), 48, Responsive.pagePadding(context), 24),
      child: Column(children: [
        if (isMobile) ...[
          brand,
          if (links.isNotEmpty) ...[const SizedBox(height: 26), quick],
        ] else
          Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: brand)),
            if (links.isNotEmpty) Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: quick)),
          ]),
        const SizedBox(height: 32),
        Divider(color: Colors.white.withValues(alpha: 0.14)),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 6, spacing: 16, children: [
          Text('© ${DateTime.now().year} ${school.schoolName}. ${strings.allRightsReserved}.', style: TextStyle(color: dim, fontSize: 12.5)),
          Text(strings.poweredBy, style: TextStyle(color: dim, fontSize: 12.5)),
        ]),
      ]),
    );
  }
}
