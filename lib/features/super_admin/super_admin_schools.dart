import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'super_admin_models.dart';
import 'super_admin_providers.dart';

class SchoolsSection extends ConsumerWidget {
  const SchoolsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolsListProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('Schools', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            FilledButton.icon(
              onPressed: () async {
                final created = await showDialog<bool>(context: context, builder: (_) => const _CreateSchoolWizard());
                if (created == true) ref.invalidate(schoolsListProvider);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Onboard a School'),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Every school currently registered on the platform.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          const SizedBox(height: 24),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent)),
              data: (schools) {
                if (schools.isEmpty) {
                  return Center(
                    child: Text('No schools onboarded yet.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                  );
                }
                return LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth > 1100 ? 3 : constraints.maxWidth > 700 ? 2 : 1;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.9),
                    itemCount: schools.length,
                    itemBuilder: (context, i) => _SchoolCard(school: schools[i]),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolCard extends ConsumerStatefulWidget {
  final SchoolSummary school;
  const _SchoolCard({required this.school});

  @override
  ConsumerState<_SchoolCard> createState() => _SchoolCardState();
}

class _SchoolCardState extends ConsumerState<_SchoolCard> {
  bool _busy = false;

  Future<void> _toggleStatus() async {
    final newStatus = widget.school.isActive ? 'inactive' : 'active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('${widget.school.isActive ? 'Deactivate' : 'Activate'} ${widget.school.schoolName}?', style: const TextStyle(color: Colors.white)),
        content: Text(
          widget.school.isActive
              ? 'Everyone at this school loses access to the platform immediately.'
              : 'This school regains access to the platform.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.school.isActive ? 'Deactivate' : 'Activate')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(superAdminRepositoryProvider).setSchoolStatus(schoolId: widget.school.id, status: newStatus);
      ref.invalidate(schoolsListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.school;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(s.schoolName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: (s.isActive ? Colors.green : Colors.red).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(s.isActive ? 'Active' : 'Inactive', style: TextStyle(color: s.isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${s.schoolCode} · ${s.domain}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          const Spacer(),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => showDialog(context: context, builder: (_) => _SchoolAdminsDialog(school: s)),
                child: const Text('Admin Accounts'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(s.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_outlined, color: s.isActive ? Colors.green : Colors.white38, size: 28),
              onPressed: _busy ? null : _toggleStatus,
            ),
          ]),
        ],
      ),
    );
  }
}

// ============================================================
// CREATE SCHOOL - section-by-section wizard, not one long form
// ============================================================

class _CreateSchoolWizard extends ConsumerStatefulWidget {
  const _CreateSchoolWizard();

  @override
  ConsumerState<_CreateSchoolWizard> createState() => _CreateSchoolWizardState();
}

class _CreateSchoolWizardState extends ConsumerState<_CreateSchoolWizard> {
  int _step = 0;
  static const _titles = ['School Identity', 'Branding', 'Done'];

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _domainController = TextEditingController();
  final _mottoController = TextEditingController();
  Color _primary = const Color(0xFF1A73E8);
  Color _secondary = const Color(0xFF0D47A1);

  bool _saving = false;
  String? _error;
  SchoolSummary? _created;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _domainController.dispose();
    _mottoController.dispose();
    super.dispose();
  }

  String _colorToHex(Color c) => '#${c.value.toRadixString(16).substring(2).toUpperCase()}';

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty || _codeController.text.trim().isEmpty) {
      setState(() => _error = 'School name and code are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final school = await ref.read(superAdminRepositoryProvider).createSchool(
            schoolName: _nameController.text.trim(),
            schoolCode: _codeController.text.trim(),
            domain: _domainController.text.trim().isEmpty ? _nameController.text.trim() : _domainController.text.trim(),
            motto: _mottoController.text.trim().isEmpty ? null : _mottoController.text.trim(),
            primaryColor: _colorToHex(_primary),
            secondaryColor: _colorToHex(_secondary),
          );
      setState(() {
        _created = school;
        _step = 2;
      });
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Onboard a School · Step ${_step + 1} of ${_titles.length}: ${_titles[_step]}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: (_step + 1) / _titles.length, minHeight: 5, backgroundColor: Colors.white12),
              ),
              const SizedBox(height: 24),
              if (_step == 0) _identityStep(),
              if (_step == 1) _brandingStep(),
              if (_step == 2) _doneStep(),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              Row(children: [
                if (_step > 0 && _step < 2)
                  TextButton(onPressed: _saving ? null : () => setState(() => _step--), child: const Text('Back')),
                const Spacer(),
                if (_step == 0)
                  FilledButton(
                    onPressed: () {
                      if (_nameController.text.trim().isEmpty || _codeController.text.trim().isEmpty) {
                        setState(() => _error = 'School name and code are required.');
                        return;
                      }
                      setState(() {
                        _error = null;
                        _step = 1;
                      });
                    },
                    child: const Text('Next'),
                  ),
                if (_step == 1)
                  FilledButton(
                    onPressed: _saving ? null : _create,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create School'),
                  ),
                if (_step == 2) FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Done')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identityStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _darkField(_nameController, 'School name'),
      const SizedBox(height: 14),
      _darkField(_codeController, 'School code (e.g. SHC) - used in admission numbers'),
      const SizedBox(height: 14),
      _darkField(_domainController, 'Domain (e.g. sacredheart) - leave blank to derive from the name'),
    ]);
  }

  Widget _brandingStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _darkField(_mottoController, 'Motto (optional)'),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: _colorPicker('Primary color', _primary, (c) => setState(() => _primary = c))),
        const SizedBox(width: 14),
        Expanded(child: _colorPicker('Secondary color', _secondary, (c) => setState(() => _secondary = c))),
      ]),
    ]);
  }

  Widget _doneStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
      const SizedBox(height: 12),
      Text('${_created?.schoolName ?? ''} created.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 4),
      Text('Domain: ${_created?.domain ?? ''}', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 16),
      Text('Next, open "Admin Accounts" on this school\'s card to create its Proprietor, Principal, and Secretary logins.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
    ]);
  }

  Widget _darkField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _colorPicker(String label, Color value, void Function(Color) onChanged) {
    const palette = [
      Color(0xFF1A73E8), Color(0xFF0D47A1), Color(0xFFD32F2F), Color(0xFF388E3C),
      Color(0xFFF57C00), Color(0xFF7B1FA2), Color(0xFF00897B), Color(0xFF455A64),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: palette.map((c) {
        final selected = c.value == value.value;
        return GestureDetector(
          onTap: () => onChanged(c),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: selected ? Border.all(color: Colors.white, width: 2.5) : null),
          ),
        );
      }).toList()),
    ]);
  }
}

// ============================================================
// SCHOOL ADMIN ACCOUNTS
// ============================================================

class _SchoolAdminsDialog extends ConsumerWidget {
  final SchoolSummary school;
  const _SchoolAdminsDialog({required this.school});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolAdminsProvider(school.id));

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${school.schoolName} · Admin Accounts', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Flexible(
                child: async.when(
                  loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent)),
                  data: (admins) {
                    if (admins.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No admin accounts created yet for this school.', style: TextStyle(color: Colors.white54)),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: admins.map((a) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              Text('${a.role[0].toUpperCase()}${a.role.substring(1)} · ${a.email ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ]),
                          ),
                        ]),
                      )).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final creds = await showDialog<NewAdminCredentials>(
                        context: context,
                        builder: (_) => _CreateAdminDialog(schoolId: school.id),
                      );
                      if (creds != null) {
                        ref.invalidate(schoolAdminsProvider(school.id));
                        if (context.mounted) {
                          await showDialog(context: context, builder: (_) => _AdminCredentialsDialog(credentials: creds, schoolName: school.schoolName));
                        }
                      }
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Create Admin Account'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateAdminDialog extends ConsumerStatefulWidget {
  final String schoolId;
  const _CreateAdminDialog({required this.schoolId});

  @override
  ConsumerState<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends ConsumerState<_CreateAdminDialog> {
  String _role = 'principal';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = 'Enter a name and a valid email.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final creds = await ref.read(superAdminRepositoryProvider).createSchoolAdmin(
            schoolId: widget.schoolId,
            role: _role,
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
          );
      if (mounted) Navigator.pop(context, creds);
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Create Admin Account', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: _role,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Role', labelStyle: TextStyle(color: Colors.white38)),
            items: const [
              DropdownMenuItem(value: 'principal', child: Text('Principal')),
              DropdownMenuItem(value: 'proprietor', child: Text('Proprietor')),
              DropdownMenuItem(value: 'secretary', child: Text('Secretary')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'principal'),
          ),
          const SizedBox(height: 12),
          _field(_name, 'Full name'),
          const SizedBox(height: 12),
          _field(_email, 'Email (their login)'),
          const SizedBox(height: 12),
          _field(_phone, 'Phone'),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) => TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white38)),
      );
}

class _AdminCredentialsDialog extends StatelessWidget {
  final NewAdminCredentials credentials;
  final String schoolName;
  const _AdminCredentialsDialog({required this.credentials, required this.schoolName});

  String get _signInUrl => Uri.base.origin;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Account created', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Text('Shown only now. Copy and send these to the person before closing.', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          _row('Role', credentials.role),
          _row('Sign in at', _signInUrl),
          _row('Email', credentials.email),
          _row('Temporary password', credentials.temporaryPassword, bold: true),
        ]),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(
            text: '$schoolName\nRole: ${credentials.role}\nSign in: $_signInUrl\nEmail: ${credentials.email}\nPassword: ${credentials.temporaryPassword}',
          )),
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          SelectableText(value, style: TextStyle(color: Colors.white, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 17 : 14)),
        ]),
      );
}