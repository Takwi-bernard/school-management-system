import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/responsive.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// Physical CR80 card size, used for LAYOUT sizing on the A4 sheet -
// not as the page format itself anymore.
const _cardW = 85.6 * PdfPageFormat.mm;
const _cardH = 54.0 * PdfPageFormat.mm;

class IdCardManagementPage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  const IdCardManagementPage({super.key, required this.schoolId, required this.landing});

  @override
  ConsumerState<IdCardManagementPage> createState() => _IdCardManagementPageState();
}

class _IdCardManagementPageState extends ConsumerState<IdCardManagementPage> {
  DepartmentFull? _department;
  ManagedClass? _class;
  bool _generating = false;

  PdfColor _parseColor(String hex) {
    var v = hex.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    return PdfColor.fromInt(int.tryParse(v, radix: 16) ?? 0xFF1A73E8);
  }

  Future<void> _generateAndStore({
    required List<IdCardStudentData> students,
    required String label,
  }) async {
    setState(() => _generating = true);
    try {
      final bytes = await _buildIdCardPdf(students);
      final pdfUrl = await ref.read(principalRepositoryProvider).uploadGeneratedPdf(
            schoolId: widget.schoolId,
            bytes: bytes,
            filenamePrefix: 'id_cards_${_class!.className.replaceAll(' ', '_')}',
          );

      final principal = await ref.read(principalProfileProvider.future);
      if (principal != null) {
        await ref.read(principalRepositoryProvider).recordIdCardGeneration(
              schoolId: widget.schoolId,
              classId: _class!.id,
              label: label,
              studentCount: students.length,
              pdfUrl: pdfUrl,
              principalId: principal.principalId,
            );
        ref.invalidate(generatedIdCardBatchesProvider(_class!.id));
      }

      if (mounted) {
        await Printing.sharePdf(bytes: bytes, filename: '${label.replaceAll(' ', '_')}.pdf');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved. You can reopen or redownload this from "Already Generated" at any time.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _generateSingle(SchoolStudent s) async {
    final data = await ref.read(principalRepositoryProvider).getIdCardData(s.id);
    await _generateAndStore(students: [data], label: '${data.fullName} ID Card');
  }

  Future<void> _generateWholeClass() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Generate ID cards for all of ${_class!.className}?'),
        content: const Text('One combined PDF will be created with every enrolled student\'s card, front and back, laid out for printing.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed != true) return;

    final students = await ref.read(studentsForClassProvider(_class!.id).future);
    final allData = await Future.wait(students.map((s) => ref.read(principalRepositoryProvider).getIdCardData(s.id)));
    await _generateAndStore(students: allData, label: '${_class!.className} - Whole Class');
  }

  Future<void> _delete(IdCardBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${batch.label}"?'),
        content: const Text('This permanently removes the saved PDF. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(principalRepositoryProvider).deleteIdCardBatch(batch.id, batch.pdfUrl);
    ref.invalidate(generatedIdCardBatchesProvider(_class!.id));
  }

  /// Front + back side by side, per student, several rows stacked on
  /// an A4 sheet - not one tiny CR80-sized page per side anymore.
  Future<Uint8List> _buildIdCardPdf(List<IdCardStudentData> students) async {
    final assets = await ref.read(officialBrandingProvider(widget.schoolId).future);
    final branding = await OfficialBranding.fetch(assets);

    pw.MemoryImage? logo;
    if (widget.landing.logoUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(widget.landing.logoUrl));
        if (res.statusCode == 200) logo = pw.MemoryImage(res.bodyBytes);
      } catch (_) {}
    }

    final primary = _parseColor(widget.landing.primaryColor);
    final secondary = _parseColor(widget.landing.secondaryColor);

    final doc = pw.Document();
    const rowsPerPage = 4; // fits comfortably on A4 with margins

    for (var pageStart = 0; pageStart < students.length; pageStart += rowsPerPage) {
      final pageStudents = students.skip(pageStart).take(rowsPerPage).toList();
      final rows = <pw.Widget>[];

      for (final s in pageStudents) {
        pw.MemoryImage? photo;
        if (s.photoUrl != null) {
          try {
            final res = await http.get(Uri.parse(s.photoUrl!));
            if (res.statusCode == 200) photo = pw.MemoryImage(res.bodyBytes);
          } catch (_) {}
        }

        rows.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 14),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _frontCard(s, photo, logo, primary, secondary),
                pw.SizedBox(width: 12),
                _backCard(s, primary, secondary, branding.principalStamp),
              ],
            ),
          ),
        );
      }

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: rows),
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _frontCard(IdCardStudentData s, pw.MemoryImage? photo, pw.MemoryImage? logo, PdfColor primary, PdfColor secondary) {
    return pw.Container(
      width: _cardW,
      height: _cardH,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            color: primary,
            child: buildCompactIdCardHeader(logo: logo, schoolName: widget.landing.schoolName, textColor: PdfColors.white),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 55,
                    height: 65,
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: primary, width: 1)),
                    child: photo != null
                        ? pw.Image(photo, fit: pw.BoxFit.cover)
                        : pw.Center(child: pw.Text('PHOTO', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey))),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(s.fullName.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        _cardField('Class', s.className),
                        _cardField('D.O.B', s.dateOfBirth != null ? _fmtDate(s.dateOfBirth!) : '-'),
                        _cardField('Adm. No', s.admissionNumber),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Container(width: double.infinity, height: 5, color: secondary),
        ],
      ),
    );
  }

  pw.Widget _backCard(IdCardStudentData s, PdfColor primary, PdfColor secondary, pw.MemoryImage? stamp) {
    return pw.Container(
      width: _cardW,
      height: _cardH,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
      child: pw.Column(
        children: [
          pw.Container(width: double.infinity, height: 5, color: secondary),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  _cardField('Guardian', s.guardianName ?? 'Not on file'),
                  _cardField('Guardian Phone', s.guardianPhone ?? '-'),
                  _cardField('Admitted', s.admissionDate != null ? _fmtDate(s.admissionDate!) : '-'),
                  pw.SizedBox(height: 8),
                  pw.Text('If found, please return to ${widget.landing.schoolName}.', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
                ],
              ),
            ),
          ),
          if (stamp != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6, right: 8),
              child: pw.Align(alignment: pw.Alignment.bottomRight, child: pw.SizedBox(width: 28, height: 28, child: pw.Image(stamp))),
            ),
        ],
      ),
    );
  }

  pw.Widget _cardField(String label, String value) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('$label: $value', style: const pw.TextStyle(fontSize: 7)));

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_class != null) {
      return Padding(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _class = null)),
                Text('${_class!.className} · ${_department!.departmentName}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _generating ? null : _generateWholeClass,
                icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.badge_outlined),
                label: Text(_generating ? 'Generating...' : 'Generate All Cards for This Class'),
              ),
              const SizedBox(height: 12),
              const TabBar(tabs: [Tab(text: 'Students'), Tab(text: 'Already Generated')]),
              Expanded(
                child: TabBarView(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final studentsAsync = ref.watch(studentsForClassProvider(_class!.id));
                        return studentsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('$e'),
                          data: (students) {
                            if (students.isEmpty) return const Center(child: Text('No students enrolled in this class.'));
                            return ListView.separated(
                              itemCount: students.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final s = students[i];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    CircleAvatar(backgroundImage: s.photoUrl != null ? NetworkImage(s.photoUrl!) : null, child: s.photoUrl == null ? Text(s.firstName.isNotEmpty ? s.firstName[0] : '?') : null),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
                                    OutlinedButton.icon(onPressed: _generating ? null : () => _generateSingle(s), icon: const Icon(Icons.badge_outlined, size: 16), label: const Text('Generate Card')),
                                  ]),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final batchesAsync = ref.watch(generatedIdCardBatchesProvider(_class!.id));
                        return batchesAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('$e'),
                          data: (batches) {
                            if (batches.isEmpty) return const Center(child: Text('No ID cards generated for this class yet.'));
                            return ListView.separated(
                              itemCount: batches.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final b = batches[i];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(b.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text('${b.studentCount} card${b.studentCount == 1 ? '' : 's'} · ${_fmtDate(b.generatedAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                      ]),
                                    ),
                                    IconButton(icon: const Icon(Icons.open_in_new_rounded), tooltip: 'Open', onPressed: () => launchUrl(Uri.parse(b.pdfUrl), mode: LaunchMode.externalApplication)),
                                    IconButton(icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error), tooltip: 'Delete', onPressed: () => _delete(b)),
                                  ]),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_department != null) {
      return Padding(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _department = null)),
              Text(_department!.departmentName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final classesAsync = ref.watch(managedClassesProvider(widget.schoolId));
                  return classesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (classes) {
                      final filtered = classes.where((c) => c.departmentId == _department!.id).toList();
                      if (filtered.isEmpty) return const Center(child: Text('No classes in this department.'));
                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _drillTile(filtered[i].className, () => setState(() => _class = filtered[i])),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID Card Generation', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Choose a department, then a class, then generate cards for one student or the whole class.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final departmentsAsync = ref.watch(departmentsFullProvider(widget.schoolId));
                return departmentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (departments) {
                    if (departments.isEmpty) return const Center(child: Text('No departments configured yet.'));
                    return ListView.separated(
                      itemCount: departments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _drillTile(departments[i].departmentName, () => setState(() => _department = departments[i])),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _drillTile(String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right_rounded)])),
      ),
    );
  }
}