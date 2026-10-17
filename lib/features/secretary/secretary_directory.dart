import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../principal/principal_core.dart';
import '../proprietor/proprietor_ui.dart';
import 'secretary_format.dart';
import 'secretary_models.dart';
import 'secretary_providers.dart';
import 'secretary_strings.dart';
import 'secretary_ui.dart';

/// Front-desk directory: browse or search every student at the school,
/// independent of any fee workflow. From a student's detail sheet the
/// secretary can jump straight to collecting their fees.
class StudentDirectoryPage extends ConsumerStatefulWidget {
  final AppStrings strings;
  final void Function(String query) onCollectFees;
  const StudentDirectoryPage({super.key, required this.strings, required this.onCollectFees});

  @override
  ConsumerState<StudentDirectoryPage> createState() => _StudentDirectoryPageState();
}

class _StudentDirectoryPageState extends ConsumerState<StudentDirectoryPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<DirectoryStudent> _students = [];
  bool _loading = true;
  Object? _error;
  int _requestToken = 0;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    final token = ++_requestToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(secretaryRepositoryProvider).listStudents(query.trim());
      if (!mounted || token != _requestToken) return;
      setState(() => _students = result);
    } catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() => _error = e);
    } finally {
      if (mounted && token == _requestToken) setState(() => _loading = false);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    // Anything under 2 characters means "browse everyone".
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(trimmed.length < 2 ? '' : trimmed));
    setState(() {});
  }

  void _showDetails(DirectoryStudent st) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    pnSheet<void>(
      context,
      (sheetContext) => PnSheetBody(
        title: st.fullName,
        subtitle: '${st.className ?? '-'}${st.departmentName != null ? ' · ${st.departmentName}' : ''}',
        children: [
          Center(child: PrAvatar(name: st.fullName, radius: 38)),
          const SizedBox(height: 16),
          PrCard(
            color: cs.surface,
            child: Column(children: [
              SxKeyValue(label: _s.sAdmissionNumberLabel, value: st.admissionNumber, strong: true),
              const Divider(height: 8),
              SxKeyValue(label: _s.sGenderLabel, value: genderLabel(_s, st.gender)),
              if (st.dateOfBirth != null) SxKeyValue(label: _s.sReviewBornLabel, value: formatDate(st.dateOfBirth!)),
              const Divider(height: 8),
              SxKeyValue(
                label: _s.sReviewGuardianLabel,
                value: st.guardianName != null ? '${st.guardianName}${st.guardianPhone != null ? '\n${st.guardianPhone}' : ''}' : _s.sNoGuardianOnFile,
              ),
            ]),
          ),
        ],
        actions: [
          TextButton(onPressed: () => Navigator.pop(sheetContext), child: Text(closeLabel(_s))),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(sheetContext);
              widget.onCollectFees(st.admissionNumber);
            },
            icon: const Icon(Icons.payments_rounded, size: 18),
            label: Text(_s.sViewCollectFeesLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fr = _s.isFrench;

    Widget content;
    if (_loading && _students.isEmpty) {
      content = const SxSkeletonList(rows: 6, height: 74);
    } else if (_error != null && _students.isEmpty) {
      content = SxError(error: _error!, strings: _s, onRetry: () => _load(_controller.text.trim()));
    } else if (_students.isEmpty) {
      content = PrCard(child: SxEmpty(icon: Icons.groups_2_outlined, title: _s.sDirectoryEmptyMessage));
    } else {
      content = LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 2 : 1;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: 0, children: [
          for (var i = 0; i < _students.length; i++)
            SizedBox(
              width: w,
              child: SxRow(
                index: i < 12 ? i : 0,
                leading: PrAvatar(name: _students[i].fullName, radius: 22),
                title: _students[i].fullName,
                lines: [
                  '${_students[i].admissionNumber} · ${_students[i].className ?? '-'}',
                  _students[i].guardianName ?? '',
                ],
                trailing: Icon(Icons.chevron_right_rounded, color: cs.outline),
                onTap: () => _showDetails(_students[i]),
              ),
            ),
        ]);
      });
    }

    return PrPage(
      onRefresh: () => _load(_controller.text.trim()),
      children: [
        PrHeader(
          title: _s.sDirectory,
          subtitle: _s.sDirectoryDescription,
          trailing: _students.isEmpty ? null : PnChip(label: '${_students.length} ${fr ? 'élèves' : 'students'}', color: cs.primary, icon: Icons.groups_2_rounded),
        ),
        PnSearch(controller: _controller, hint: _s.sSearchStudentHint, onChanged: _onChanged),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _loading && _students.isNotEmpty ? 14 : 0,
          padding: const EdgeInsets.only(top: 8),
          child: _loading && _students.isNotEmpty ? const LinearProgressIndicator(minHeight: 3) : null,
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }
}
