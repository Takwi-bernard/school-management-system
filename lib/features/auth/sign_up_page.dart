import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../landing/landing_providers.dart';
import 'auth_branding_header.dart';

/// Only Parent and Teacher can publicly register - Principal,
/// Secretary, and Proprietor accounts are created internally
/// (onboarding / by the Principal), never through public sign-up.
class SignUpPage extends ConsumerWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('We couldn\'t reach the server. Please check your connection.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => ref.invalidate(landingProvider),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (school) {
        final strings = AppStrings(locale);

        return AuthScaffold(
          school: school,
          maxWidth: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthBrandingHeader(school: school, subtitle: strings.chooseAccountType),
              const SizedBox(height: 24),
              HoverLift(
                onTap: () => context.push('/sign-up/parent'),
                child: _AccountTypeCard(
                  icon: Icons.family_restroom,
                  title: strings.parent,
                  description: strings.parentAccountDesc,
                ),
              ),
              const SizedBox(height: 14),
              HoverLift(
                onTap: () => context.push('/sign-up/teacher'),
                child: _AccountTypeCard(
                  icon: Icons.school_outlined,
                  title: strings.teacher,
                  description: strings.teacherAccountDesc,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(strings.alreadyHaveAccount),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _AccountTypeCard({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: theme.colorScheme.onPrimary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(description, style: theme.textTheme.bodySmall),
          ]),
        ),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ]),
    );
  }
}