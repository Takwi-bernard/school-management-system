import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_providers.dart';
import '../principal/principal_core.dart';
import '../principal/principal_kit.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_navigation.dart';
import 'parent_providers.dart';
import 'parent_ui.dart';

/// Link a child the school already admitted: admission number plus date
/// of birth (both required, the number alone is guessable), confirm it is
/// the right child, then link.
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
      initialDate: _dateOfBirth ?? DateTime(now.year - 10),
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
        setState(() => _error = strings.isFrench ? 'Une erreur est survenue. Veuillez réessayer.' : 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _confirmLink(AppStrings strings) async {
    setState(() {
      _linking = true;
      _error = null;
    });
    try {
      await ref.read(parentRepositoryProvider).linkChildToParent(_found!['student_id'] as String);
      ref.invalidate(enrolledChildrenProvider);
      if (!mounted) return;
      prSnack(context, strings.isFrench ? 'Enfant ajouté à votre compte.' : 'Child added to your account.');
      popParentContent(ref);
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
    final cs = theme.colorScheme;
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final fr = strings.isFrench;

    return PrPage(
      maxWidth: 560,
      children: [
        PrHeader(
          title: fr ? 'Retrouver mon enfant' : 'Find My Child',
          subtitle: fr
              ? 'Si l\'école a déjà inscrit votre enfant, entrez son numéro d\'admission et sa date de naissance pour l\'ajouter à votre compte.'
              : 'If the school already enrolled your child, enter their admission number and date of birth to add them to your account.',
          trailing: IconButton(onPressed: () => popParentContent(ref), icon: const Icon(Icons.close_rounded), tooltip: fr ? 'Fermer' : 'Close'),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          child: _found == null
              ? PrCard(
                  key: const ValueKey('form'),
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: _admissionNumber,
                      textCapitalization: TextCapitalization.characters,
                      decoration: pnDeco(fr ? 'Numéro d\'admission' : 'Admission Number', icon: Icons.badge_outlined),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickDateOfBirth,
                      child: InputDecorator(
                        decoration: pnDeco(fr ? 'Date de naissance de l\'enfant' : 'Child\'s date of birth', icon: Icons.cake_outlined),
                        child: Text(
                          _dateOfBirth == null ? ' ' : paDate(_dateOfBirth!),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      PnNotice(text: _error!, icon: Icons.error_outline_rounded, color: cs.error),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _searching ? null : () => _search(strings),
                        icon: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_rounded),
                        label: Text(fr ? 'Rechercher' : 'Find My Child'),
                      ),
                    ),
                  ]),
                )
              : PrCard(
                  key: const ValueKey('found'),
                  padding: const EdgeInsets.all(22),
                  child: Column(children: [
                    PnAvatar(stored: _found!['photo_path'] as String?, name: '${_found!['first_name']} ${_found!['last_name']}', radius: 40),
                    const SizedBox(height: 12),
                    Text('${_found!['first_name']} ${_found!['last_name']}', textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    if ((_found!['class_name'] as String?) != null) ...[
                      const SizedBox(height: 2),
                      Text(_found!['class_name'] as String, style: TextStyle(color: cs.outline)),
                    ],
                    const SizedBox(height: 10),
                    Text(fr ? 'Est-ce bien votre enfant ?' : 'Is this your child?', style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline)),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      PnNotice(text: _error!, icon: Icons.error_outline_rounded, color: cs.error),
                    ],
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _linking ? null : () => setState(() {
                                _found = null;
                                _error = null;
                              }),
                          child: Text(fr ? 'Non, réessayer' : 'No, try again'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _linking ? null : () => _confirmLink(strings),
                          child: _linking
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(fr ? 'Oui, c\'est mon enfant' : 'Yes, this is my child', textAlign: TextAlign.center),
                        ),
                      ),
                    ]),
                  ]),
                ),
        ),
      ],
    );
  }
}
