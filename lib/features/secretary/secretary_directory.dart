import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import 'secretary_format.dart';
import 'secretary_models.dart';
import 'secretary_providers.dart';
import 'secretary_strings.dart';
import 'secretary_ui.dart';

/// Front-desk directory: browse or search every student at the school,
/// independent of any fee workflow. From a student's detail card the
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
      if (!mounted || token != _requestToken) return; // a newer search superseded this one
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

  void _showDetails(DirectoryStudent s) {
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool selectable = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(label, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13))),
            Expanded(
              child: selectable
                  ? SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w700))
                  : Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_s.sStudentDetailsTitle),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              row(_s.fullName, s.fullName),
              row(_s.sAdmissionNumberLabel, s.admissionNumber, selectable: true),
              row(_s.sClassLabel, '${s.className ?? '-'}${s.departmentName != null ? ' · ${s.departmentName}' : ''}'),
              row(_s.sGenderLabel, genderLabel(_s, s.gender)),
              if (s.dateOfBirth != null) row(_s.sReviewBornLabel, formatDate(s.dateOfBirth!)),
              row(_s.sReviewGuardianLabel, s.guardianName != null ? '${s.guardianName}${s.guardianPhone != null ? ' · ${s.guardianPhone}' : ''}' : _s.sNoGuardianOnFile),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(closeLabel(_s))),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onCollectFees(s.admissionNumber);
            },
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: Text(_s.sViewCollectFeesLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    if (_loading && _students.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _students.isEmpty) {
      content = SecretaryErrorView(error: _error!, strings: _s, onRetry: () => _load(_controller.text.trim()));
    } else if (_students.isEmpty) {
      content = SecretaryEmptyState(icon: Icons.groups_outlined, title: _s.sDirectoryEmptyMessage);
    } else {
      content = RefreshIndicator(
        onRefresh: () => _load(_controller.text.trim()),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _students.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final s = _students[i];
            final initial = s.fullName.trim().isNotEmpty ? s.fullName.trim()[0].toUpperCase() : '?';
            return SecretaryCard(
              onTap: () => _showDetails(s),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(initial, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${s.admissionNumber} · ${s.className ?? '-'}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    if (s.guardianName != null)
                      Text(s.guardianName!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            );
          },
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SecretaryPageHeader(
          title: _s.sDirectory,
          subtitle: _s.sDirectoryDescription,
          trailing: IconButton(tooltip: _s.tryAgain, icon: const Icon(Icons.refresh_rounded), onPressed: () => _load(_controller.text.trim())),
        ),
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            labelText: _s.sSearchStudentHint,
            border: const OutlineInputBorder(),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      _load('');
                      setState(() {});
                    },
                  ),
          ),
        ),
        if (_loading && _students.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        const SizedBox(height: 14),
        Expanded(child: content),
      ]),
    );
  }
}