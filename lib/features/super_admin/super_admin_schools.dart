import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'super_admin_academic.dart';
import 'super_admin_branding.dart';
import 'super_admin_models.dart';
import 'super_admin_providers.dart';

Color? _tryParseHex(String hex) {
  var v = hex.trim().replaceAll('#', '');
  if (v.length == 6) v = 'FF$v';
  if (v.length != 8) return null;
  final parsed = int.tryParse(v, radix: 16);
  return parsed == null ? null : Color(parsed);
}

class SchoolsSection extends ConsumerWidget {
  const SchoolsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolsListProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 500;
            final title = const Text('Schools', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800));
            final button = FilledButton.icon(
              onPressed: () async {
                final created = await showDialog<bool>(context: context, builder: (_) => const _SchoolFormDialog());
                if (created == true) ref.invalidate(schoolsListProvider);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Onboard a School'),
            );
            if (narrow) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), SizedBox(width: double.infinity, child: button)]);
            }
            return Row(children: [Expanded(child: title), button]);
          }),
          const SizedBox(height: 4),
          Text('Every school registered on the platform.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent)),
              data: (schools) {
                if (schools.isEmpty) return Center(child: Text('No schools onboarded yet.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))));
                return LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth > 1100 ? 3 : constraints.maxWidth > 700 ? 2 : 1;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: columns == 1 ? 1.3 : 1.45),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('${widget.school.isActive ? 'Deactivate' : 'Activate'} ${widget.school.schoolName}?', style: const TextStyle(color: Colors.white)),
        content: Text(
          widget.school.isActive ? 'Everyone at this school loses access to the platform immediately.' : 'This school regains access to the platform.',
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
      await ref.read(superAdminRepositoryProvider).toggleSchoolStatus(widget.school.id);
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
    final primary = _tryParseHex(s.primaryColor) ?? Colors.indigo;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 12, height: 12, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: primary, shape: BoxShape.circle)),
            Expanded(child: Text(s.schoolName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: (s.isActive ? Colors.green : Colors.red).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(s.status, style: TextStyle(color: s.isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${s.schoolCode} · ${s.domain}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          if (s.phone != null && s.phone!.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.phone!, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11))),
          if (s.city != null && s.city!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${s.city}${s.country != null && s.country!.isNotEmpty ? ', ${s.country}' : ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
            ),
          const Spacer(),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              SizedBox(
                width: 85,
                child: OutlinedButton(
                  onPressed: () async {
                    final changed = await showDialog<bool>(context: context, builder: (_) => _SchoolFormDialog(existing: s));
                    if (changed == true) ref.invalidate(schoolsListProvider);
                  },
                  child: const Text('Edit', style: TextStyle(fontSize: 13)),
                ),
              ),
              SizedBox(
                width: 95,
                child: OutlinedButton(
                  onPressed: () => showDialog(context: context, builder: (_) => _SchoolAdminsDialog(school: s)),
                  child: const Text('Admins', style: TextStyle(fontSize: 13)),
                ),
              ),
              SizedBox(
                width: 100,
                child: FilledButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BrandingPage(school: s))),
                  child: const Text('Branding', style: TextStyle(fontSize: 13)),
                ),
              ),
              SizedBox(
                width: 100,
                child: FilledButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AcademicStructurePage(school: s))),
                  child: const Text('Academic', style: TextStyle(fontSize: 13)),
                ),
              ),
              IconButton(
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(s.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_outlined, color: s.isActive ? Colors.green : Colors.white38, size: 28),
                onPressed: _busy ? null : _toggleStatus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CREATE / EDIT SCHOOL
// ============================================================

class _SchoolFormDialog extends ConsumerStatefulWidget {
  final SchoolSummary? existing;
  const _SchoolFormDialog({this.existing});

  @override
  ConsumerState<_SchoolFormDialog> createState() => _SchoolFormDialogState();
}

class _SchoolFormDialogState extends ConsumerState<_SchoolFormDialog> {
  int _step = 0;
  static const _titles = ['Identity', 'Location', 'Branding', 'Done'];

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _domain;
  late final TextEditingController _website;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _motto;
  late final TextEditingController _primaryHex;
  late final TextEditingController _secondaryHex;
  String _languageMode = 'bilingual';

  bool _saving = false;
  String? _error;
  SchoolSummary? _result;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.schoolName ?? '');
    _code = TextEditingController(text: e?.schoolCode ?? '');
    _domain = TextEditingController(text: e?.domain ?? '');
    _website = TextEditingController(text: e?.website ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _country = TextEditingController(text: e?.country ?? '');
    _motto = TextEditingController(text: e?.motto ?? '');
    _primaryHex = TextEditingController(text: e?.primaryColor ?? '#1A73E8');
    _secondaryHex = TextEditingController(text: e?.secondaryColor ?? '#0D47A1');
    _languageMode = e?.languageMode ?? 'bilingual';
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _domain, _website, _email, _phone, _address, _city, _country, _motto, _primaryHex, _secondaryHex]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty) {
      setState(() {
        _step = 0;
        _error = 'School name and code are required.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      final schoolName = _name.text.trim();
      final schoolCode = _code.text.trim();
      final domain = _domain.text.trim();
      final languageMode = _languageMode;
      final motto = _motto.text.trim();
      final website = _website.text.trim();
      final email = _email.text.trim();
      final phone = _phone.text.trim();
      final address = _address.text.trim();
      final city = _city.text.trim();
      final country = _country.text.trim();
      final primaryColor = _primaryHex.text.trim();
      final secondaryColor = _secondaryHex.text.trim();

      final SchoolSummary saved;
      if (_isEdit) {
        saved = await repo.updateSchool(
          schoolId: widget.existing!.id,
          schoolName: schoolName,
          schoolCode: schoolCode,
          domain: domain,
          languageMode: languageMode,
          motto: motto,
          website: website,
          email: email,
          phone: phone,
          address: address,
          city: city,
          country: country,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
        );
      } else {
        saved = await repo.createSchool(
          schoolName: schoolName,
          schoolCode: schoolCode,
          domain: domain,
          languageMode: languageMode,
          motto: motto,
          website: website,
          email: email,
          phone: phone,
          address: address,
          city: city,
          country: country,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
        );
      }
      setState(() {
        _result = saved;
        _step = 3;
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
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_isEdit ? 'Edit' : 'Onboard'} School · ${_titles[_step]} (${_step + 1}/${_titles.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: (_step + 1) / _titles.length, minHeight: 5, backgroundColor: Colors.white12)),
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(
                  child: _step == 0
                      ? _identityStep()
                      : _step == 1
                          ? _locationStep()
                          : _step == 2
                              ? _brandingStep()
                              : _doneStep(),
                ),
              ),
              if (_error != null) ...[const SizedBox(height: 14), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))],
              const SizedBox(height: 20),
              Row(children: [
                if (_step > 0 && _step < 3) TextButton(onPressed: _saving ? null : () => setState(() => _step--), child: const Text('Back')),
                const Spacer(),
                if (_step < 2)
                  FilledButton(
                    onPressed: () {
                      if (_step == 0 && (_name.text.trim().isEmpty || _code.text.trim().isEmpty)) {
                        setState(() => _error = 'School name and code are required.');
                        return;
                      }
                      setState(() {
                        _error = null;
                        _step++;
                      });
                    },
                    child: const Text('Next'),
                  ),
                if (_step == 2)
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEdit ? 'Save Changes' : 'Create School'),
                  ),
                if (_step == 3) FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Done')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identityStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _darkField(_name, 'School name'),
        const SizedBox(height: 14),
        _darkField(_code, 'School code (e.g. SHC) - used in admission numbers'),
        const SizedBox(height: 14),
        _darkField(_domain, 'Domain (e.g. sacredheart.com) - leave blank to derive from the name'),
        const SizedBox(height: 14),
        _darkField(_website, 'Website (optional - defaults to the domain)'),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _languageMode,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Language mode', labelStyle: TextStyle(color: Colors.white38)),
          items: const [
            DropdownMenuItem(value: 'bilingual', child: Text('Bilingual (English + French)')),
            DropdownMenuItem(value: 'english', child: Text('English only')),
            DropdownMenuItem(value: 'french', child: Text('French only')),
          ],
          onChanged: (v) => setState(() => _languageMode = v ?? 'bilingual'),
        ),
      ]);

  Widget _locationStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _darkField(_email, 'Email'),
        const SizedBox(height: 14),
        _darkField(_phone, 'Phone'),
        const SizedBox(height: 14),
        _darkField(_address, 'Address'),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: _darkField(_city, 'City')), const SizedBox(width: 10), Expanded(child: _darkField(_country, 'Country'))]),
      ]);

  Widget _brandingStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _darkField(_motto, 'Motto (optional)'),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: _hexColorField('Primary color', _primaryHex)), const SizedBox(width: 14), Expanded(child: _hexColorField('Secondary color', _secondaryHex))]),
        const SizedBox(height: 8),
        Text(
          'Logo, hero banner, gallery, mission/vision/history are managed from the "Branding" button once the school exists.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
        ),
      ]);

  Widget _doneStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
        const SizedBox(height: 12),
        Text('${_result?.schoolName ?? ''} ${_isEdit ? 'updated' : 'created'}.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Domain: ${_result?.domain ?? ''}', style: const TextStyle(color: Colors.white70)),
      ]);

  Widget _darkField(TextEditingController controller, String label) => TextField(
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

  Widget _hexColorField(String label, TextEditingController controller) {
    return StatefulBuilder(builder: (context, setLocalState) {
      final color = _tryParseHex(controller.text) ?? Colors.grey;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24))),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => setLocalState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '#1A73E8',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ]),
      ]);
    });
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
                    if (admins.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No admin accounts created yet.', style: TextStyle(color: Colors.white54)));
                    return ListView(
                      shrinkWrap: true,
                      children: admins
                          .map((a) => Container(
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
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final creds = await showDialog<NewAdminCredentials>(context: context, builder: (_) => _CreateAdminDialog(schoolId: school.id));
                      if (creds != null) {
                        ref.invalidate(schoolAdminsProvider(school.id));
                        if (context.mounted) await showDialog(context: context, builder: (_) => _AdminCredentialsDialog(credentials: creds, schoolName: school.schoolName));
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
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))],
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create')),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) =>
      TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white38)));
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
            child: const Text('Shown only now. Copy and send these before closing.', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
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