import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

/// For a child already admitted (and possibly already paid for) by
/// school staff on the parent's behalf - not built yet on the staff
/// side, but this half needs to be ready for when it is. The parent
/// enters the child's admission number plus date of birth (both are
/// required together - the admission number alone is guessable), sees
/// enough to confirm it's really their child, then links.
class LinkChildPage extends ConsumerStatefulWidget {
  final String schoolId;
  const LinkChildPage({super.key, required this.schoolId});

  @override
  ConsumerState<LinkChildPage> createState() => _LinkChildPageState();
}

class _LinkChildPageState extends ConsumerState<LinkChildPage> {
  final _admissionNumber = TextEditingController();
  DateTime? _dateOfBirth;
  bool _searching = false;
  bool _linking = false;
  String? _error;
  Map<String, dynamic>? _found;

  @override
  void dispose() {
    _admissionNumber.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 10),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _search(AppStrings strings) async {
    if (_admissionNumber.text.trim().isEmpty || _dateOfBirth == null) {
      setState(() => _error = strings.isFrench
          ? 'Merci de renseigner le numéro d\'admission et la date de naissance.'
          : 'Please enter both the admission number and date of birth.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _found = null;
    });
    try {
      final result = await ref.read(parentRepositoryProvider).lookupChildByAdmissionNumber(
            schoolId: widget.schoolId,
            admissionNumber: _admissionNumber.text.trim(),
            dateOfBirth: _dateOfBirth!,
          );
      if (!mounted) return;
      if (result == null) {
        setState(() => _error = strings.isFrench
            ? 'Aucun enfant ne correspond à ces informations. Vérifiez le numéro d\'admission et la date de naissance.'
            : 'No child matches that information. Please check the admission number and date of birth.');
      } else {
        setState(() => _found = result);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = strings.isFrench
            ? 'Une erreur est survenue. Veuillez réessayer.'
            : 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _confirmLink(AppStrings strings) async {
    setState(() => _linking = true);
    try {
      await ref.read(parentRepositoryProvider).linkChildToParent(_found!['student_id'] as String);
      ref.invalidate(enrolledChildrenProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        strings.isFrench ? 'Enfant ajouté à votre compte.' : 'Child added to your account.',
      )));
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = strings.isFrench
            ? 'Impossible de lier cet enfant pour le moment. Veuillez réessayer.'
            : 'Could not link this child right now. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final landing = ref.watch(landingProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(strings.isFrench ? 'Retrouver mon enfant' : 'Find My Child')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(Responsive.pagePadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (landing != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: brandedSubpageHeader(context, schoolName: landing.schoolName, logoUrl: landing.logoUrl),
                    ),
                  Text(
                    strings.isFrench
                        ? 'Si l\'école a déjà inscrit votre enfant pour vous, entrez son numéro d\'admission et sa date de naissance ci-dessous pour l\'ajouter à votre compte.'
                        : 'If the school already enrolled your child for you, enter their admission number and date of birth below to add them to your account.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 24),
                  if (_found == null) ...[
                    TextField(
                      controller: _admissionNumber,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: strings.isFrench ? 'Numéro d\'admission' : 'Admission Number',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _pickDateOfBirth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              Icon(Icons.cake_outlined, color: theme.colorScheme.outline, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _dateOfBirth == null
                                      ? (strings.isFrench ? 'Date de naissance de l\'enfant' : 'Child\'s date of birth')
                                      : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                                  style: TextStyle(color: _dateOfBirth == null ? theme.colorScheme.outline : null),
                                ),
                              ),
                              Icon(Icons.calendar_today_outlined, size: 18, color: theme.colorScheme.outline),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: _searching ? null : () => _search(strings),
                      icon: _searching
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_rounded),
                      label: Text(strings.isFrench ? 'Rechercher' : 'Find My Child'),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: theme.colorScheme.surface,
                            backgroundImage: (_found!['photo_path'] as String?) != null
                                ? NetworkImage(_found!['photo_path'] as String)
                                : null,
                            onBackgroundImageError: (_found!['photo_path'] as String?) != null ? (_, __) {} : null,
                            child: (_found!['photo_path'] as String?) == null
                                ? Icon(Icons.person_outline, size: 36, color: theme.colorScheme.primary)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_found!['first_name']} ${_found!['last_name']}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if ((_found!['class_name'] as String?) != null) ...[
                            const SizedBox(height: 2),
                            Text(_found!['class_name'] as String, style: TextStyle(color: theme.colorScheme.outline)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.isFrench ? 'Est-ce bien votre enfant ?' : 'Is this your child?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _linking ? null : () => setState(() => _found = null),
                            child: Text(strings.isFrench ? 'Non, réessayer' : 'No, try again'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _linking ? null : () => _confirmLink(strings),
                            child: _linking
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(strings.isFrench ? 'Oui, c\'est mon enfant' : 'Yes, this is my child'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
