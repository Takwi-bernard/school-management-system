import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_model.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_enrollment.dart';
import 'parent_link_child_page.dart';
import 'parent_navigation.dart';
import 'parent_ui.dart';

/// Admissions destination: pick between a new enrollment and linking a
/// child the school already admitted. Both flows open inside the shell.
class ParentAdmissionsTab extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ParentAdmissionsTab({super.key, required this.schoolId, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = strings.isFrench;
    return PrPage(
      maxWidth: 640,
      children: [
        PrHeader(
          title: fr ? 'Ajouter un enfant' : 'Add a Child',
          subtitle: fr ? 'Choisissez l\'option qui correspond à votre situation.' : 'Choose the option that matches your situation.',
        ),
        const SizedBox(height: 18),
        PrReveal(
          child: PaOptionTile(
            icon: Icons.person_add_alt_1_rounded,
            title: fr ? 'Inscrire un nouvel enfant' : 'Enroll a New Child',
            subtitle: fr
                ? 'Votre enfant n\'est pas encore inscrit dans cette école. Remplissez le formulaire d\'inscription.'
                : 'Your child isn\'t enrolled at this school yet. Fill out the enrollment form.',
            onTap: () => pushParentContent(
              ref,
              ParentContentPage(title: strings.enrollMyChild, builder: (ctx) => EnrollChildPage(schoolId: schoolId)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrReveal(
          index: 1,
          child: PaOptionTile(
            icon: Icons.qr_code_2_rounded,
            title: fr ? 'J\'ai un numéro d\'admission' : 'I Have an Admission Number',
            subtitle: fr
                ? 'L\'école a déjà inscrit votre enfant pour vous. Ajoutez-le à votre compte avec son numéro d\'admission.'
                : 'The school already enrolled your child for you. Add them to your account using their admission number.',
            onTap: () => pushParentContent(
              ref,
              ParentContentPage(title: fr ? 'Retrouver mon enfant' : 'Find My Child', builder: (ctx) => LinkChildPage(schoolId: schoolId)),
            ),
          ),
        ),
      ],
    );
  }
}
