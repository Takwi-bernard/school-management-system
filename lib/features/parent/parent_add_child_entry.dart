import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'parent_enrollment.dart';
import 'parent_link_child_page.dart';
import 'parent_models.dart';

/// Reached from the same place "Enroll My Child" always was (dashboard
/// button, sidebar Admissions item) - now offers a second path first,
/// for a child school staff already admitted (and maybe already paid
/// for) on the parent's behalf, before jumping into the full form.
class AddChildEntryPage extends ConsumerWidget {
  final String schoolId;
  const AddChildEntryPage({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final landing = ref.watch(landingProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(strings.enrollMyChild)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(Responsive.pagePadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (landing != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: brandedSubpageHeader(context, schoolName: landing.schoolName, logoUrl: landing.logoUrl),
                    ),
                  Text(
                    strings.isFrench ? 'Comment souhaitez-vous continuer ?' : 'How would you like to continue?',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  _OptionCard(
                    icon: Icons.person_add_alt_1_rounded,
                    title: strings.isFrench ? 'Inscrire un nouvel enfant' : 'Enroll a New Child',
                    description: strings.isFrench
                        ? 'Votre enfant n\'est pas encore inscrit dans cette école. Remplissez le formulaire d\'inscription.'
                        : 'Your child isn\'t enrolled at this school yet. Fill out the enrollment form.',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EnrollChildPage(schoolId: schoolId)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _OptionCard(
                    icon: Icons.qr_code_2_rounded,
                    title: strings.isFrench ? 'J\'ai un numéro d\'admission' : 'I Have an Admission Number',
                    description: strings.isFrench
                        ? 'L\'école a déjà inscrit votre enfant pour vous. Ajoutez-le à votre compte avec son numéro d\'admission.'
                        : 'The school already enrolled your child for you. Add them to your account using their admission number.',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LinkChildPage(schoolId: schoolId)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  const _OptionCard({required this.icon, required this.title, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
