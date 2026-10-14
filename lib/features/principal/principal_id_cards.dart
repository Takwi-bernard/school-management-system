import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_model.dart';
import '../parent/parent_providers.dart' show officialBrandingProvider;
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_card_art.dart';
import 'principal_core.dart';
import 'principal_kit.dart';
import 'principal_models.dart';
import 'principal_providers.dart' hide officialBrandingProvider;

// CR80 physical size, used to lay the cards out on the A4 sheet.
const _cardWpdf = 85.6 * PdfPageFormat.mm;
const _cardHpdf = 54.0 * PdfPageFormat.mm;

final _classCardDataProvider = FutureProvider.family<List<IdCardStudentData>, String>((ref, classId) {
  return ref.watch(principalRepositoryProvider).getIdCardDataForClass(classId);
});

class IdCardManagementPage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const IdCardManagementPage({super.key, required this.schoolId, required this.landing, required this.strings});

  @override
  ConsumerState<IdCardManagementPage> createState() => _IdCardManagementPageState();
}

class _IdCardManagementPageState extends ConsumerState<IdCardManagementPage> {
  ManagedClass? _class;
  bool _showHistory = false;
  String _query = '';
  final _search = TextEditingController();
  final _classSearch = TextEditingController();
  String _classQuery = '';

  Future<PnCardSchool>? _schoolFuture;
  final _photos = PnCardPhotoCache();
  final ValueNotifier<String?> _progress = ValueNotifier<String?>(null);

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _search.dispose();
    _classSearch.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<PnCardSchool> _school() {
    return _schoolFuture ??= _loadSchool();
  }

  Future<PnCardSchool> _loadSchool() async {
    final l = widget.landing;
    Map<String, String> assets = const {};
    try {
      assets = await ref.read(officialBrandingProvider(widget.schoolId).future);
    } catch (_) {}
    final logo = await PnCardSchool.fetchImage(l.logoUrl, maxWidth: 400);
    final stamp = await PnCardSchool.fetchImage(assets['principal_stamp'], maxWidth: 400);
    return PnCardSchool(
      name: l.schoolName,
      motto: l.motto,
      address: l.address,
      phone: l.phone,
      email: l.email,
      academicYear: l.currentAcademicYear ?? '',
      languageMode: l.languageMode,
      primary: pnHex(l.primaryColor, const Color(0xFF1A73E8)),
      secondary: pnHex(l.secondaryColor, const Color(0xFFF59E0B)),
      logo: logo,
      stamp: stamp,
      seed: l.schoolId.hashCode & 0xFFFF,
    );
  }

  // ------------------------------------------------------------ PDF

  Future<Uint8List> _buildPdf(List<IdCardStudentData> students) async {
    final school = await _school();
    final doc = pw.Document();
    const rowsPerPage = 4;
    final rows = <pw.Widget>[];
    var done = 0;

    Future<void> flush() async {
      if (rows.isEmpty) return;
      final pageRows = List<pw.Widget>.of(rows);
      rows.clear();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 20),
          build: (_) => pw.Column(children: [
            pw.Expanded(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly, children: pageRows)),
            pw.Text(school.label('Cut along the grey borders.', 'Découper le long des bordures grises.'), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ]),
        ),
      );
    }

    for (final st in students) {
      _progress.value = _s.pn('Drawing card ${done + 1} of ${students.length}…', 'Création de la carte ${done + 1} sur ${students.length}…');
      final photo = await _photos.get(st.photoUrl);
      final front = await pnRenderCard(school: school, student: st, photo: photo, front: true);
      final back = await pnRenderCard(school: school, student: st, photo: photo, front: false);
      pw.Widget card(Uint8List png) => pw.Container(
            width: _cardWpdf,
            height: _cardHpdf,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.4)),
            child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill),
          );
      rows.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [card(front), pw.SizedBox(width: 10), card(back)]));
      done++;
      if (rows.length == rowsPerPage) await flush();
      // let the UI breathe between cards
      await Future<void>.delayed(Duration.zero);
    }
    await flush();
    _progress.value = _s.pn('Building the PDF…', 'Assemblage du PDF…');
    return doc.save();
  }

  Future<void> _generate(List<IdCardStudentData> students, String label, {bool whole = false}) async {
    final s = _s;
    if (_progress.value != null) return;
    _progress.value = s.pn('Preparing…', 'Préparation…');
    try {
      final bytes = await _buildPdf(students);
      final repo = ref.read(principalRepositoryProvider);
      String? url;
      try {
        url = await repo.uploadGeneratedPdf(schoolId: widget.schoolId, bytes: bytes, filenamePrefix: 'id_cards_${_class!.className.replaceAll(' ', '_')}');
        final principal = await ref.read(principalProfileProvider.future);
        if (principal != null) {
          await repo.recordIdCardGeneration(schoolId: widget.schoolId, classId: _class!.id, label: label, studentCount: students.length, pdfUrl: url, principalId: principal.principalId);
          ref.invalidate(generatedIdCardBatchesProvider(_class!.id));
        }
      } catch (_) {
        // saving to history is a bonus; the PDF itself is still delivered
        url = null;
      }
      await Printing.sharePdf(bytes: bytes, filename: '${label.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')}.pdf');
      if (mounted) {
        prSnack(
          context,
          url != null
              ? s.pn('Cards ready. You can reopen them anytime under “Generated”.', 'Cartes prêtes. Vous pouvez les rouvrir à tout moment dans « Générées ».')
              : s.pn('Cards ready, but they could not be saved to the history.', 'Cartes prêtes, mais elles n’ont pas pu être enregistrées dans l’historique.'),
        );
      }
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      _progress.value = null;
    }
  }

  Future<void> _generateClass(List<IdCardStudentData> all) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Generate ${all.length} cards for ${_class!.className}?', 'Générer ${all.length} cartes pour ${_class!.className} ?'),
      message: s.pn('One PDF is created with every student’s card, front and back, laid out four per sheet.', 'Un PDF est créé avec la carte de chaque élève, recto et verso, quatre par feuille.'),
      confirmLabel: s.pn('Generate', 'Générer'),
    );
    if (!ok || !mounted) return;
    await _generate(all, '${_class!.className} - ${s.pn('Whole class', 'Classe entière')}', whole: true);
  }

  Future<void> _deleteBatch(IdCardBatch b) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Delete “${b.label}”?', 'Supprimer « ${b.label} » ?'),
      message: s.pn('The saved PDF is permanently removed.', 'Le PDF enregistré sera définitivement supprimé.'),
      confirmLabel: s.pn('Delete', 'Supprimer'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(principalRepositoryProvider).deleteIdCardBatch(b.id, b.pdfUrl);
      ref.invalidate(generatedIdCardBatchesProvider(_class!.id));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  void _preview(IdCardStudentData st) {
    pnSheet<void>(
      context,
      (_) => _PreviewSheet(
        strings: _s,
        student: st,
        schoolFuture: _school(),
        photos: _photos,
        onPdf: () {
          Navigator.pop(context);
          _generate([st], '${st.fullName} - ID');
        },
      ),
    );
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return PrPage(
      maxWidth: 960,
      children: [
        PnStage(stageKey: _class?.id ?? 'classes', child: _class == null ? _classes(s) : _classStage(s, _class!)),
      ],
    );
  }

  Widget _classes(AppStrings s) {
    final classes = ref.watch(managedClassesProvider(widget.schoolId));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PrHeader(
        title: s.pn('ID cards', 'Cartes d’élève'),
        subtitle: s.pn('Choose a class, preview the card, then print one student or the whole class.', 'Choisissez une classe, prévisualisez la carte, puis imprimez pour un élève ou toute la classe.'),
      ),
      const SizedBox(height: 14),
      PnSearch(controller: _classSearch, hint: s.pn('Search a class', 'Rechercher une classe'), onChanged: (v) => setState(() => _classQuery = v)),
      const SizedBox(height: 14),
      PnAsync<List<ManagedClass>>(
        value: classes,
        strings: s,
        onRetry: () => ref.invalidate(managedClassesProvider(widget.schoolId)),
        isEmpty: (d) => d.isEmpty,
        empty: PnEmpty(icon: Icons.badge_outlined, title: s.pn('No classes yet', 'Aucune classe')),
        builder: (all) {
          final q = _classQuery.trim().toLowerCase();
          final list = all.where((c) => c.isActive && (q.isEmpty || c.className.toLowerCase().contains(q))).toList();
          if (list.isEmpty) return PnEmpty(icon: Icons.search_off_rounded, title: s.pn('No match', 'Aucun résultat'));
          return Column(children: [
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PnPickTile(
                  index: i,
                  icon: Icons.badge_rounded,
                  title: list[i].className,
                  subtitle: list[i].departmentName,
                  onTap: () => setState(() {
                    _class = list[i];
                    _showHistory = false;
                    _query = '';
                    _search.clear();
                  }),
                ),
              ),
          ]);
        },
      ),
    ]);
  }

  Widget _classStage(AppStrings s, ManagedClass cls) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final data = ref.watch(_classCardDataProvider(cls.id));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PnCrumbs(labels: [s.pn('ID cards', 'Cartes d’élève'), cls.className], onTap: (_) => setState(() => _class = null)),
      const SizedBox(height: 10),
      PnAsync<List<IdCardStudentData>>(
        value: data,
        strings: s,
        onRetry: () => ref.invalidate(_classCardDataProvider(cls.id)),
        isEmpty: (d) => d.isEmpty,
        empty: PnEmpty(icon: Icons.person_off_rounded, title: s.pn('No students enrolled', 'Aucun élève inscrit'), text: s.pn('Enrolled students of this class appear here.', 'Les élèves inscrits de cette classe apparaissent ici.')),
        builder: (all) {
          final noPhoto = all.where((x) => (x.photoUrl ?? '').isEmpty).length;
          final q = _query.trim().toLowerCase();
          final list = all.where((x) => q.isEmpty || x.fullName.toLowerCase().contains(q) || x.admissionNumber.toLowerCase().contains(q)).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PrReveal(
              child: PrCard(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth > 640;
                  final preview = SizedBox(
                    width: wide ? 340 : double.infinity,
                    child: _SamplePreview(schoolFuture: _school(), student: all.first, photos: _photos, strings: s),
                  );
                  final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cls.className, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(s.pn('${all.length} student${all.length == 1 ? '' : 's'}', '${all.length} élève${all.length == 1 ? '' : 's'}'), style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline)),
                    const SizedBox(height: 12),
                    if (noPhoto > 0) PnNotice(icon: Icons.photo_camera_back_rounded, color: pnWarn(), text: s.pn('$noPhoto student${noPhoto == 1 ? ' has' : 's have'} no photo yet. Their card prints with a placeholder.', '$noPhoto élève${noPhoto == 1 ? ' n’a' : 's n’ont'} pas encore de photo. Leur carte s’imprime avec un espace réservé.')),
                    if (noPhoto > 0) const SizedBox(height: 12),
                    ValueListenableBuilder<String?>(
                      valueListenable: _progress,
                      builder: (_, p, __) => FilledButton.icon(
                        onPressed: p != null ? null : () => _generateClass(all),
                        icon: p != null ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print_rounded, size: 18),
                        label: Text(p ?? s.pn('Generate all ${all.length} cards', 'Générer les ${all.length} cartes')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(s.pn('Tap the card to flip it. Print on thick paper and cut along the grey borders.', 'Touchez la carte pour la retourner. Imprimez sur papier épais et découpez le long des bordures grises.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.4)),
                  ]);
                  return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [preview, const SizedBox(width: 22), Expanded(child: info)]) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [preview, const SizedBox(height: 16), info]);
                }),
              ),
            ),
            const SizedBox(height: 16),
            PrPills<bool>(values: const [false, true], selected: _showHistory, label: (v) => v ? s.pn('Generated', 'Générées') : s.pn('Students', 'Élèves'), onChanged: (v) => setState(() => _showHistory = v)),
            const SizedBox(height: 12),
            if (_showHistory) _history(s, cls) else ...[
              PnSearch(controller: _search, hint: s.pn('Search by name or number', 'Rechercher par nom ou numéro'), onChanged: (v) => setState(() => _query = v)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                PnEmpty(icon: Icons.search_off_rounded, title: s.pn('No match', 'Aucun résultat'))
              else
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PrReveal(
                      index: i > 8 ? 8 : i,
                      child: PrCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          PrAvatar(photoUrl: list[i].photoUrl, name: list[i].fullName, radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(list[i].fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(list[i].admissionNumber, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                            ]),
                          ),
                          if ((list[i].photoUrl ?? '').isEmpty) Padding(padding: const EdgeInsets.only(right: 6), child: PnChip(label: s.pn('No photo', 'Sans photo'), color: pnWarn())),
                          IconButton(icon: const Icon(Icons.visibility_rounded, size: 20), tooltip: s.pn('Preview', 'Aperçu'), onPressed: () => _preview(list[i])),
                          ValueListenableBuilder<String?>(
                            valueListenable: _progress,
                            builder: (_, p, __) => IconButton(icon: const Icon(Icons.picture_as_pdf_rounded, size: 20), tooltip: s.pn('Generate PDF', 'Générer le PDF'), onPressed: p != null ? null : () => _generate([list[i]], '${list[i].fullName} - ID')),
                          ),
                        ]),
                      ),
                    ),
                  ),
            ],
          ]);
        },
      ),
    ]);
  }

  Widget _history(AppStrings s, ManagedClass cls) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(generatedIdCardBatchesProvider(cls.id));
    return PnAsync<List<IdCardBatch>>(
      value: async,
      strings: s,
      onRetry: () => ref.invalidate(generatedIdCardBatchesProvider(cls.id)),
      isEmpty: (d) => d.isEmpty,
      empty: PnEmpty(icon: Icons.history_rounded, title: s.pn('Nothing generated yet', 'Rien de généré'), text: s.pn('PDFs you generate for this class are kept here.', 'Les PDF générés pour cette classe sont conservés ici.')),
      builder: (list) => Column(children: [
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PrReveal(
              index: i > 8 ? 8 : i,
              child: PrCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(Icons.picture_as_pdf_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(list[i].label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${s.pn('${list[i].studentCount} card${list[i].studentCount == 1 ? '' : 's'}', '${list[i].studentCount} carte${list[i].studentCount == 1 ? '' : 's'}')} · ${pDateTime(list[i].generatedAt)}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.open_in_new_rounded, size: 20), tooltip: s.pn('Open', 'Ouvrir'), onPressed: () => launchUrl(Uri.parse(list[i].pdfUrl), mode: LaunchMode.externalApplication)),
                  IconButton(icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.error), tooltip: s.pn('Delete', 'Supprimer'), onPressed: () => _deleteBatch(list[i])),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ============================================================
// Card rendering widgets
// ============================================================

class _Faces {
  final Uint8List front;
  final Uint8List back;
  const _Faces(this.front, this.back);
}

Future<_Faces> _renderFaces(PnCardSchool school, IdCardStudentData st, PnCardPhotoCache photos) async {
  final photo = await photos.get(st.photoUrl);
  final front = await pnRenderCard(school: school, student: st, photo: photo, front: true);
  final back = await pnRenderCard(school: school, student: st, photo: photo, front: false);
  return _Faces(front, back);
}

class _SamplePreview extends StatefulWidget {
  final Future<PnCardSchool> schoolFuture;
  final IdCardStudentData student;
  final PnCardPhotoCache photos;
  final AppStrings strings;
  const _SamplePreview({required this.schoolFuture, required this.student, required this.photos, required this.strings});

  @override
  State<_SamplePreview> createState() => _SamplePreviewState();
}

class _SamplePreviewState extends State<_SamplePreview> {
  late Future<_Faces> _faces;

  @override
  void initState() {
    super.initState();
    _faces = widget.schoolFuture.then((s) => _renderFaces(s, widget.student, widget.photos));
  }

  @override
  void didUpdateWidget(covariant _SamplePreview old) {
    super.didUpdateWidget(old);
    if (old.student.studentId != widget.student.studentId) {
      _faces = widget.schoolFuture.then((s) => _renderFaces(s, widget.student, widget.photos));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FacesView(future: _faces, strings: widget.strings, onRetry: () => setState(() => _faces = widget.schoolFuture.then((s) => _renderFaces(s, widget.student, widget.photos))));
  }
}

class _FacesView extends StatelessWidget {
  final Future<_Faces> future;
  final AppStrings strings;
  final VoidCallback onRetry;
  const _FacesView({required this.future, required this.strings, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Faces>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return AspectRatio(aspectRatio: pnCardW / pnCardH, child: PnErrorBox(strings: strings, error: snap.error!, onRetry: onRetry));
        }
        if (!snap.hasData) return const AspectRatio(aspectRatio: pnCardW / pnCardH, child: PrSkeleton(height: double.infinity, radius: 18));
        return _FlipCard(front: snap.data!.front, back: snap.data!.back);
      },
    );
  }
}

class _FlipCard extends StatefulWidget {
  final Uint8List front;
  final Uint8List back;
  const _FlipCard({required this.front, required this.back});

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
  bool _back = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _flip() {
    _back = !_back;
    _back ? _c.forward() : _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_c.value);
            final angle = t * math.pi;
            final showBack = angle > math.pi / 2;
            final img = Image.memory(showBack ? widget.back : widget.front, fit: BoxFit.contain, gaplessPlayback: true, filterQuality: FilterQuality.medium);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(showBack ? math.pi : 0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 10))],
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: pnCardW / pnCardH, child: img)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PreviewSheet extends StatefulWidget {
  final AppStrings strings;
  final IdCardStudentData student;
  final Future<PnCardSchool> schoolFuture;
  final PnCardPhotoCache photos;
  final VoidCallback onPdf;
  const _PreviewSheet({required this.strings, required this.student, required this.schoolFuture, required this.photos, required this.onPdf});

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  late Future<_Faces> _faces;

  @override
  void initState() {
    super.initState();
    _faces = widget.schoolFuture.then((s) => _renderFaces(s, widget.student, widget.photos));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PnSheetBody(
      title: widget.student.fullName,
      subtitle: s.pn('Tap the card to flip it.', 'Touchez la carte pour la retourner.'),
      children: [
        _FacesView(future: _faces, strings: s, onRetry: () => setState(() => _faces = widget.schoolFuture.then((x) => _renderFaces(x, widget.student, widget.photos)))),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.pn('Close', 'Fermer'))),
        FilledButton.icon(onPressed: widget.onPdf, icon: const Icon(Icons.picture_as_pdf_rounded, size: 18), label: Text(s.pn('Generate PDF', 'Générer le PDF'))),
      ],
    );
  }
}
