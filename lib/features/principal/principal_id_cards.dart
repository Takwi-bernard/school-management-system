import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../../core/responsive.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// Standard CR80 ID card size (85.6mm x 54mm), converted to points.
const _cardWidth = 85.6 * PdfPageFormat.mm;
const _cardHeight = 54.0 * PdfPageFormat.mm;
const _cardFormat = PdfPageFormat(_cardWidth, _cardHeight, marginAll: 0);

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

  PdfColor _parseColor(String hex) {
    var v = hex.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    final intVal = int.tryParse(v, radix: 16) ?? 0xFF1A73E8;
    return PdfColor.fromInt(intVal);
  }

  Future<void> _generateSingle(BuildContext context, WidgetRef ref, String studentId) async {
    try {
      final data = await ref.read(principalRepositoryProvider).getIdCardData(studentId);
      final bytes = await _buildIdCardPdf([data]);
      final principal = await ref.read(principalProfileProvider.future);
      if (principal != null) {
        await ref.read(principalRepositoryProvider).recordIdCardGeneration(widget.schoolId, studentId, principal.principalId);
        ref.invalidate(generatedIdCardsForClassProvider(_class!.id));
      }
      await Printing.sharePdf(bytes: bytes, filename: 'id_card_${data.admissionNumber}.pdf');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _generateWholeClass(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Generate ID cards for all of ${_class!.className}?'),
        content: const Text('This creates one PDF containing every enrolled student\'s card (front and back).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final students = await ref.read(studentsForClassProvider(_class!.id).future);
      final allData = await Future.wait(students.map((s) => ref.read(principalRepositoryProvider).getIdCardData(s.id)));
      final bytes = await _buildIdCardPdf(allData);

      final principal = await ref.read(principalProfileProvider.future);
      if (principal != null) {
        for (final s in students) {
          await ref.read(principalRepositoryProvider).recordIdCardGeneration(widget.schoolId, s.id, principal.principalId);
        }
        ref.invalidate(generatedIdCardsForClassProvider(_class!.id));
      }
      await Printing.sharePdf(bytes: bytes, filename: 'id_cards_${_class!.className}.pdf');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
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

    for (final s in students) {
      pw.MemoryImage? photo;
      if (s.photoUrl != null) {
        try {
          final res = await http.get(Uri.parse(s.photoUrl!));
          if (res.statusCode == 200) photo = pw.MemoryImage(res.bodyBytes);
        } catch (_) {}
      }

      // FRONT
      doc.addPage(pw.Page(
        pageFormat: _cardFormat,
        build: (context) => pw.Container(
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
        ),
      ));

      // BACK
      doc.addPage(pw.Page(
        pageFormat: _cardFormat,
        build: (context) => pw.Container(
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
                      pw.Text(
                        'If found, please return to ${widget.landing.schoolName}.',
                        style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              if (branding.principalStamp != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6, right: 8),
                  child: pw.Align(alignment: pw.Alignment.bottomRight, child: pw.SizedBox(width: 32, height: 32, child: pw.Image(branding.principalStamp!))),
                ),
            ],
          ),
        ),
      ));
    }

    return doc.save();
  }

  pw.Widget _cardField(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Text('$label: $value', style: const pw.TextStyle(fontSize: 7)),
      );

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
                onPressed: () => _generateWholeClass(context, ref),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Generate All Cards for This Class'),
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
                                    OutlinedButton.icon(onPressed: () => _generateSingle(context, ref, s.id), icon: const Icon(Icons.badge_outlined, size: 16), label: const Text('Generate Card')),
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
                        final generatedAsync = ref.watch(generatedIdCardsForClassProvider(_class!.id));
                        return generatedAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('$e'),
                          data: (records) {
                            if (records.isEmpty) return const Center(child: Text('No ID cards generated for this class yet.'));
                            return ListView.separated(
                              itemCount: records.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final r = records[i];
                                return ListTile(
                                  tileColor: theme.colorScheme.surfaceContainerHighest,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  title: Text(r.studentName),
                                  subtitle: Text('Generated ${_fmtDate(r.generatedAt)}'),
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