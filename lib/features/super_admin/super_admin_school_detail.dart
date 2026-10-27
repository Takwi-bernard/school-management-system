import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'super_admin_academic.dart';
import 'super_admin_branding.dart';
import 'super_admin_models.dart';
import 'super_admin_providers.dart';
import 'super_admin_schools.dart';
import 'super_admin_theme.dart';
import 'super_admin_ui.dart';

const _adminRoles = ['principal', 'proprietor', 'secretary'];

String _plural(String role) => switch (role) {
      'principal' => 'Principals',
      'proprietor' => 'Proprietors',
      _ => 'Secretaries',
    };

IconData _roleIcon(String role) => switch (role) {
      'principal' => Icons.school_rounded,
      'proprietor' => Icons.business_center_rounded,
      _ => Icons.assignment_ind_rounded,
    };

void _refreshPeople(WidgetRef ref, String schoolId) {
  ref.invalidate(schoolAdminsProvider(schoolId));
  ref.invalidate(schoolMetricsProvider);
  ref.invalidate(allAdminsProvider);
  ref.invalidate(platformOverviewProvider);
  ref.invalidate(auditLogProvider);
}

// ============================================================
// SCHOOL DETAIL PAGE
// ============================================================

class SchoolDetailPage extends ConsumerWidget {
  final String schoolId;
  const SchoolDetailPage({super.key, required this.schoolId});

  SchoolSummary? _find(List<SchoolSummary>? list) {
    if (list == null) return null;
    for (final s in list) {
      if (s.id == schoolId) return s;
    }
    return null;
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, SchoolSummary s) async {
    final ok = await saConfirm(
      context,
      title: '${s.isActive ? 'Suspend' : 'Reactivate'} ${s.schoolName}?',
      message: s.isActive
          ? 'Everyone at this school will lose access to the platform immediately. Their data is kept and you can reactivate the school at any time.'
          : 'The school and all its users will regain access to the platform.',
      confirmLabel: s.isActive ? 'Suspend school' : 'Reactivate',
      danger: s.isActive,
      icon: s.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
    );
    if (!ok) return;
    try {
      await ref.read(superAdminRepositoryProvider).toggleSchoolStatus(s.id);
      ref.invalidate(schoolsListProvider);
      ref.invalidate(platformOverviewProvider);
      ref.invalidate(auditLogProvider);
      if (context.mounted) saToast(context, s.isActive ? 'School suspended.' : 'School reactivated.');
    } catch (e) {
      if (context.mounted) saToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolsListProvider);
    final school = _find(async.valueOrNull);
    final metrics = ref.watch(schoolMetricsProvider).valueOrNull?[schoolId];

    if (school == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => SaErrorState(e, onRetry: () => ref.invalidate(schoolsListProvider)),
          data: (_) => const SaEmpty(icon: Icons.search_off_rounded, title: 'School not found', message: 'It may have been removed.'),
        ),
      );
    }

    final accent = parseHexColor(school.primaryColor) ?? Sa.primary;
    final site = school.website != null && school.website!.isNotEmpty ? school.website! : 'https://${school.domain}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('School'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(schoolsListProvider);
              _refreshPeople(ref, school.id);
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SaPage(
        title: school.schoolName,
        subtitle: '${school.schoolCode} · ${school.domain}',
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              final changed = await showDialog<bool>(context: context, builder: (_) => SchoolFormDialog(existing: school));
              if (changed == true) {
                ref.invalidate(schoolsListProvider);
                ref.invalidate(platformOverviewProvider);
              }
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit details'),
          ),
          SaChip(school.isActive ? 'Active' : 'Suspended', tone: school.isActive ? SaTone.success : SaTone.danger),
        ],
        children: [
          SaGrid(minItemWidth: 220, children: [
            SaStatTile(icon: Icons.school_rounded, label: 'Students', value: metrics?.students ?? 0, tone: SaTone.info),
            SaStatTile(icon: Icons.co_present_rounded, label: 'Teachers', value: metrics?.teachers ?? 0, tone: SaTone.success),
            SaStatTile(icon: Icons.family_restroom_rounded, label: 'Parents', value: metrics?.parents ?? 0, tone: SaTone.warning),
            SaStatTile(icon: Icons.admin_panel_settings_rounded, label: 'Admin accounts', value: metrics?.admins ?? 0, tone: SaTone.primary),
          ]),
          const SizedBox(height: 26),
          const SaSectionTitle('Set up this school'),
          SaGrid(minItemWidth: 300, children: [
            _ManageCard(
              icon: Icons.palette_rounded,
              title: 'Website and branding',
              text: 'Logo, banner, gallery, story, achievements and events shown on the school website.',
              color: accent,
              onTap: () => Navigator.push(context, saRoute(BrandingPage(school: school))),
            ),
            _ManageCard(
              icon: Icons.account_tree_rounded,
              title: 'Academic structure',
              text: 'Departments, classes, subjects, coefficients, years, terms, sequences and fees.',
              color: Sa.info,
              onTap: () => Navigator.push(context, saRoute(AcademicStructurePage(school: school))),
            ),
            _ManageCard(
              icon: Icons.open_in_new_rounded,
              title: 'School website address',
              text: site,
              color: Sa.success,
              onTap: () => saCopy(context, site, label: 'Address copied'),
              trailingLabel: 'Tap to copy',
            ),
          ]),
          const SizedBox(height: 26),
          _PeoplePanel(school: school),
          const SizedBox(height: 26),
          const SaSectionTitle('School details'),
          SaCard(
            child: Column(children: [
              SaKeyValue('School ID', school.id, copyable: true),
              const Divider(),
              SaKeyValue('Email', school.email, copyable: true),
              SaKeyValue('Phone', school.phone, copyable: true),
              SaKeyValue('Address', school.address),
              SaKeyValue('City', [if (school.city != null && school.city!.isNotEmpty) school.city!, if (school.country != null && school.country!.isNotEmpty) school.country!].join(', ')),
              const Divider(),
              SaKeyValue('Language', switch (school.languageMode) { 'english' => 'English only', 'french' => 'French only', _ => 'Bilingual (English + French)' }),
              SaKeyValue('Motto', school.motto),
              SaKeyValue('Created', saDate(school.createdAt)),
            ]),
          ),
          const SizedBox(height: 26),
          SaCard(
            child: LayoutBuilder(builder: (context, c) {
              final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(school.isActive ? 'Suspend this school' : 'Reactivate this school', style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  school.isActive ? 'Blocks every user of this school from signing in. Nothing is deleted.' : 'This school is suspended. Reactivate it to let its users sign in again.',
                  style: const TextStyle(color: Sa.muted, fontSize: 13),
                ),
              ]);
              final button = FilledButton(
                style: school.isActive ? FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)) : null,
                onPressed: () => _toggleStatus(context, ref, school),
                child: Text(school.isActive ? 'Suspend school' : 'Reactivate school'),
              );
              if (c.maxWidth < 520) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 14), button]);
              return Row(children: [Expanded(child: text), const SizedBox(width: 16), button]);
            }),
          ),
        ],
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  final VoidCallback onTap;
  final String? trailingLabel;
  const _ManageCard({required this.icon, required this.title, required this.text, required this.color, required this.onTap, this.trailingLabel});

  @override
  Widget build(BuildContext context) => SaCard(
        accent: color,
        onTap: onTap,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.muted, fontSize: 12.5, height: 1.4)),
              if (trailingLabel != null) ...[const SizedBox(height: 6), Text(trailingLabel!, style: const TextStyle(color: Sa.faint, fontSize: 11.5))],
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Sa.faint),
        ]),
      );
}

// ============================================================
// PEOPLE PANEL  (several principals / proprietors / secretaries per school)
// ============================================================

class _PeoplePanel extends ConsumerWidget {
  final SchoolSummary school;
  const _PeoplePanel({required this.school});

  Future<void> _create(BuildContext context, WidgetRef ref, {String? role}) async {
    final creds = await showDialog<NewAdminCredentials>(context: context, builder: (_) => CreateAdminDialog(schoolId: school.id, initialRole: role));
    if (creds == null) return;
    _refreshPeople(ref, school.id);
    if (context.mounted) {
      await showDialog(context: context, builder: (_) => AdminCredentialsDialog(credentials: creds, school: school, title: 'Account created successfully'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolAdminsProvider(school.id));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SaSectionTitle(
        'People and access',
        trailing: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(44, 40)),
          onPressed: () => _create(context, ref),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Add account'),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Text(
          'A school can have several principals, proprietors and secretaries, for example one per section. They all work in the same school space and see the same data.',
          style: TextStyle(color: Sa.muted, fontSize: 13, height: 1.45),
        ),
      ),
      async.when(
        loading: () => const SaCard(child: Column(children: [SaSkeleton(height: 44), SizedBox(height: 10), SaSkeleton(height: 44)])),
        error: (e, _) => SaCard(child: SaErrorState(e, onRetry: () => ref.invalidate(schoolAdminsProvider(school.id)))),
        data: (admins) {
          return Column(children: [
            for (final role in _adminRoles) ...[
              _RoleGroup(school: school, role: role, accounts: admins.where((a) => a.role == role).toList(), onAdd: () => _create(context, ref, role: role)),
              const SizedBox(height: 14),
            ],
          ]);
        },
      ),
    ]);
  }
}

class _RoleGroup extends ConsumerWidget {
  final SchoolSummary school;
  final String role;
  final List<SchoolAdminAccount> accounts;
  final VoidCallback onAdd;
  const _RoleGroup({required this.school, required this.role, required this.accounts, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = accounts.where((a) => a.isActive).length;
    return SaCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
          child: Row(children: [
            Icon(_roleIcon(role), color: Sa.primaryHi, size: 20),
            const SizedBox(width: 10),
            Text(_plural(role), style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w800, fontSize: 14.5)),
            const SizedBox(width: 10),
            SaChip('$activeCount active', tone: activeCount == 0 ? SaTone.warning : SaTone.neutral),
            const Spacer(),
            TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 18), label: Text('Add ${role == 'secretary' ? 'secretary' : role}')),
          ]),
        ),
        if (accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Align(alignment: Alignment.centerLeft, child: Text('No account yet.', style: TextStyle(color: Sa.faint, fontSize: 13))),
          )
        else
          for (final a in accounts) ...[
            const Divider(),
            _AccountRow(school: school, account: a),
          ],
      ]),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  final SchoolSummary school;
  final SchoolAdminAccount account;
  const _AccountRow({required this.school, required this.account});

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => EditAdminDialog(account: account));
    if (changed == true) {
      _refreshPeople(ref, school.id);
      if (context.mounted) saToast(context, 'Details updated.');
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await saConfirm(
      context,
      title: 'Reset password?',
      message: '${account.fullName} will no longer be able to sign in with their old password. You will see the new password once, so you can hand it over.',
      confirmLabel: 'Reset password',
      icon: Icons.lock_reset_rounded,
    );
    if (!ok) return;
    try {
      final creds = await ref.read(superAdminRepositoryProvider).resetAdminPassword(role: account.role, id: account.id);
      ref.invalidate(auditLogProvider);
      if (context.mounted) await showDialog(context: context, builder: (_) => AdminCredentialsDialog(credentials: creds, school: school, title: 'New password ready'));
    } catch (e) {
      if (context.mounted) saToast(context, '$e', error: true);
    }
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref, bool active) async {
    final ok = await saConfirm(
      context,
      title: active ? 'Reactivate ${account.fullName}?' : 'Deactivate ${account.fullName}?',
      message: active
          ? 'They will be able to sign in again.'
          : 'They will be signed out and can no longer sign in. Everything they created stays in the school. You can reactivate them at any time.',
      confirmLabel: active ? 'Reactivate' : 'Deactivate',
      danger: !active,
      icon: active ? Icons.person_add_alt_1_rounded : Icons.person_off_rounded,
    );
    if (!ok) return;
    try {
      await ref.read(superAdminRepositoryProvider).setAdminActive(role: account.role, id: account.id, isActive: active);
      _refreshPeople(ref, school.id);
      if (context.mounted) saToast(context, active ? 'Account reactivated.' : 'Account deactivated.');
    } catch (e) {
      if (context.mounted) saToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = account;
    return Opacity(
      opacity: a.isActive ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
        child: Row(children: [
          SaAvatar(a.fullName, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(a.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w700, fontSize: 14))),
                if (!a.isActive) ...[const SizedBox(width: 8), const SaChip('Inactive', tone: SaTone.danger)],
              ]),
              const SizedBox(height: 2),
              Text(
                [if (a.email != null && a.email!.isNotEmpty) a.email!, if (a.phone != null && a.phone!.isNotEmpty) a.phone!].join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Sa.muted, fontSize: 12.5),
              ),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.more_vert_rounded, color: Sa.muted),
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _edit(context, ref);
                case 'copy':
                  saCopy(context, a.email ?? '', label: 'Email copied');
                case 'reset':
                  _reset(context, ref);
                case 'toggle':
                  _setActive(context, ref, !a.isActive);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit_outlined, size: 20), title: Text('Edit details'), contentPadding: EdgeInsets.zero)),
              if (a.email != null && a.email!.isNotEmpty) const PopupMenuItem(value: 'copy', child: ListTile(dense: true, leading: Icon(Icons.copy_rounded, size: 20), title: Text('Copy email'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'reset', child: ListTile(dense: true, leading: Icon(Icons.lock_reset_rounded, size: 20), title: Text('Reset password'), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  dense: true,
                  leading: Icon(a.isActive ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined, size: 20, color: a.isActive ? Sa.danger : Sa.success),
                  title: Text(a.isActive ? 'Deactivate' : 'Reactivate', style: TextStyle(color: a.isActive ? Sa.danger : Sa.success)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

// ============================================================
// CREATE ADMIN  (role picker, then a sign-up form)
// ============================================================

class CreateAdminDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String? initialRole;
  const CreateAdminDialog({super.key, required this.schoolId, this.initialRole});

  @override
  ConsumerState<CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends ConsumerState<CreateAdminDialog> {
  String? _role;
  String _lang = 'en';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = true;
  bool _saving = false;
  String? _error;

  static const _roles = [
    ('principal', 'Principal', 'Runs a school section: staff, students, results and the school website.', Icons.school_rounded),
    ('proprietor', 'Proprietor', 'Owner view: finances, performance and oversight.', Icons.business_center_rounded),
    ('secretary', 'Secretary', 'Daily office work: admissions, records and fees.', Icons.assignment_ind_rounded),
  ];

  String get _roleLabel => _roles.firstWhere((r) => r.$1 == _role).$2;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    _password.text = _generate();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String _generate() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    const symbols = '@#\$%&*!?';
    final rnd = Random.secure();
    String pick(String s) => s[rnd.nextInt(s.length)];
    final chars = [pick(upper), pick(lower), pick(digits), pick(symbols)];
    const all = upper + lower + digits + symbols;
    while (chars.length < 14) {
      chars.add(pick(all));
    }
    chars.shuffle(rnd);
    return chars.join();
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter the full name.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a login email, for example name@yourschool.com.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'The password must be at least 8 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final creds = await ref.read(superAdminRepositoryProvider).createSchoolAdmin(
            schoolId: widget.schoolId,
            role: _role!,
            fullName: _name.text.trim(),
            email: email,
            phone: _phone.text.trim(),
            password: _password.text,
            language: _lang,
          );
      if (mounted) Navigator.pop(context, creds);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return SaDialog(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Add an account',
        subtitle: 'Who is this account for?',
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
        child: Column(children: [
          for (final r in _roles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SaCard(
                onTap: () => setState(() => _role = r.$1),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Sa.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(r.$4, color: Sa.primaryHi, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.$2, style: const TextStyle(color: Sa.text, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(r.$3, style: const TextStyle(color: Sa.muted, fontSize: 12.5)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Sa.faint),
                ]),
              ),
            ),
        ]),
      );
    }

    return SaDialog(
      icon: Icons.how_to_reg_rounded,
      title: 'Sign up a $_roleLabel',
      subtitle: 'Creates a real login. They can sign in right away.',
      actions: [
        if (widget.initialRole == null) TextButton(onPressed: _saving ? null : () => setState(() => _role = null), child: const Text('Back')),
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create account'),
        ),
      ],
      child: Column(children: [
        SaField(controller: _name, label: 'Full name', icon: Icons.person_outline_rounded),
        const SizedBox(height: 14),
        SaField(controller: _email, label: 'Login email', icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        SaField(controller: _phone, label: 'Phone (optional)', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        SaField(
          controller: _password,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: !_showPassword,
          suffix: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: _showPassword ? 'Hide' : 'Show', onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20)),
            IconButton(tooltip: 'Generate a new one', onPressed: () => setState(() => _password.text = _generate()), icon: const Icon(Icons.autorenew_rounded, size: 20)),
          ]),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _lang,
          dropdownColor: Sa.cardHi,
          style: const TextStyle(color: Sa.text),
          decoration: const InputDecoration(labelText: 'Language', prefixIcon: Icon(Icons.translate_rounded, color: Sa.faint, size: 20)),
          items: const [DropdownMenuItem(value: 'en', child: Text('English')), DropdownMenuItem(value: 'fr', child: Text('Français'))],
          onChanged: (v) => setState(() => _lang = v ?? 'en'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Sa.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Sa.danger, fontSize: 13)),
          ),
        ],
      ]),
    );
  }
}

class EditAdminDialog extends ConsumerStatefulWidget {
  final SchoolAdminAccount account;
  const EditAdminDialog({super.key, required this.account});

  @override
  ConsumerState<EditAdminDialog> createState() => _EditAdminDialogState();
}

class _EditAdminDialogState extends ConsumerState<EditAdminDialog> {
  late final _name = TextEditingController(text: widget.account.fullName);
  late final _phone = TextEditingController(text: widget.account.phone ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter the full name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(superAdminRepositoryProvider).updateSchoolAdmin(role: widget.account.role, id: widget.account.id, fullName: _name.text.trim(), phone: _phone.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SaDialog(
      icon: Icons.edit_rounded,
      title: 'Edit ${saRoleLabel(widget.account.role).toLowerCase()}',
      subtitle: widget.account.email,
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
        ),
      ],
      child: Column(children: [
        SaField(controller: _name, label: 'Full name', icon: Icons.person_outline_rounded),
        const SizedBox(height: 14),
        SaField(controller: _phone, label: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Sa.danger, fontSize: 13))],
      ]),
    );
  }
}

class AdminCredentialsDialog extends StatelessWidget {
  final NewAdminCredentials credentials;
  final SchoolSummary school;
  final String title;
  const AdminCredentialsDialog({super.key, required this.credentials, required this.school, required this.title});

  String get _signInUrl => school.domain.isNotEmpty ? 'https://${school.domain}' : '';

  String get _text => [
        school.schoolName,
        'Role: ${saRoleLabel(credentials.role)}',
        if (_signInUrl.isNotEmpty) 'Sign in at: $_signInUrl',
        'Email: ${credentials.email}',
        'Password: ${credentials.temporaryPassword}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    return SaDialog(
      icon: Icons.check_circle_rounded,
      tone: SaTone.success,
      title: title,
      subtitle: '${credentials.fullName} · ${saRoleLabel(credentials.role)}',
      actions: [
        OutlinedButton.icon(onPressed: () => saCopy(context, _text, label: 'Login details copied'), icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('Copy all')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Sa.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.visibility_rounded, color: Sa.warning, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('The password is shown only now. Copy these details and hand them over before closing.', style: TextStyle(color: Sa.warning, fontSize: 12.5))),
          ]),
        ),
        const SizedBox(height: 14),
        if (_signInUrl.isNotEmpty) SaKeyValue('Sign in at', _signInUrl, copyable: true),
        SaKeyValue('Email', credentials.email, copyable: true),
        SaKeyValue('Password', credentials.temporaryPassword, copyable: true),
      ]),
    );
  }
}