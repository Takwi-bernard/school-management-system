import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import 'parent_enrollment.dart';
import 'parent_link_child_page.dart';
import 'parent_navigation.dart';

/// The Admissions sidebar destination - was the last item still
/// escaping the shell via a router push (its own Scaffold, sidebar
/// gone). Now a normal in-shell tab, same as every other item: picking
/// either option pushes the real flow onto the shell's own content
/// stack instead of the app's Navigator.
class ParentAdmissionsTab extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ParentAdmissionsTab({super.key, required this.schoolId, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.isFrench ? 'Ajouter un enfant' : 'Add a Child',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              strings.isFrench
                  ? 'Choisissez l\'option qui correspond à votre situation.'
                  : 'Choose the option that matches your situation.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            _OptionCard(
              icon: Icons.person_add_alt_1_rounded,
              title: strings.isFrench ? 'Inscrire un nouvel enfant' : 'Enroll a New Child',
              description: strings.isFrench
                  ? 'Votre enfant n\'est pas encore inscrit dans cette école. Remplissez le formulaire d\'inscription.'
                  : 'Your child isn\'t enrolled at this school yet. Fill out the enrollment form.',
              onTap: () => pushParentContent(
                ref,
                ParentContentPage(
                  title: strings.enrollMyChild,
                  builder: (ctx) => EnrollChildPage(schoolId: schoolId),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _OptionCard(
              icon: Icons.qr_code_2_rounded,
              title: strings.isFrench ? 'J\'ai un numéro d\'admission' : 'I Have an Admission Number',
              description: strings.isFrench
                  ? 'L\'école a déjà inscrit votre enfant pour vous. Ajoutez-le à votre compte avec son numéro d\'admission.'
                  : 'The school already enrolled your child for you. Add them to your account using their admission number.',
              onTap: () => pushParentContent(
                ref,
                ParentContentPage(
                  title: strings.isFrench ? 'Retrouver mon enfant' : 'Find My Child',
                  builder: (ctx) => LinkChildPage(schoolId: schoolId),
                ),
              ),
            ),
          ],
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
