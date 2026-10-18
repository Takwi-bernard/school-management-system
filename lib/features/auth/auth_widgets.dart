import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../landing/landing_providers.dart';

String routeForRole(String role) => switch (role) {
      'parent' => '/parent',
      'teacher' => '/teacher',
      'principal' => '/principal',
      'secretary' => '/secretary',
      'proprietor' => '/proprietor',
      _ => '/',
    };

/// Shown while the school is loading.
class AuthLoadingView extends StatelessWidget {
  const AuthLoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Shown when the school could not be loaded.
class AuthLoadFailedView extends ConsumerWidget {
  const AuthLoadFailedView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = ref.watch(activeLocaleProvider).languageCode == 'fr';
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              fr ? 'Impossible de joindre le serveur. Vérifiez votre connexion.' : "We couldn't reach the server. Please check your connection.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => ref.invalidate(landingProvider), child: Text(fr ? 'Réessayer' : 'Try again')),
          ]),
        ),
      ),
    );
  }
}

/// "—— OR ——" divider.
class AuthOrDivider extends StatelessWidget {
  final String label;
  const AuthOrDivider({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(label, style: Theme.of(context).textTheme.labelSmall)),
        const Expanded(child: Divider()),
      ]);
}
