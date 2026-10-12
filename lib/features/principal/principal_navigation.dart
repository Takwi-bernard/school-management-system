import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_providers.dart';
import '../auth/auth_gate.dart' show authStateChangesProvider;

/// A single page shown inside PrincipalShell's content area - same
/// pattern as ParentContentPage/TeacherContentPage. The Principal
/// module used to swap a local `_body` widget via setState with no
/// history; this stack gives it the same back-button behavior every
/// other module already has.
class PrincipalContentPage {
  final String title;
  final WidgetBuilder builder;
  const PrincipalContentPage({required this.title, required this.builder});
}

/// The id of whoever is signed in right now (null when signed out).
/// Everything below depends on this, so switching accounts on the
/// same device drops whatever was open instead of leaking it across
/// sessions.
final principalUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});

/// Empty stack = showing the Home dashboard. One entry = a sidebar
/// destination. More than one = that destination pushed a detail view
/// on top of itself.
final principalContentStackProvider = StateProvider<List<PrincipalContentPage>>((ref) {
  ref.watch(principalUserIdProvider);
  return const <PrincipalContentPage>[];
});

/// Which sidebar item is highlighted - 'home' when the stack is empty.
final principalActiveNavKeyProvider = StateProvider<String>((ref) {
  ref.watch(principalUserIdProvider);
  return 'home';
});

/// Tapping a sidebar item: replace whatever was open with this one
/// destination (not stacked on top of the previous selection - picking
/// a different sidebar item starts fresh, same as the parent/teacher
/// shells).
void selectPrincipalNav(WidgetRef ref, String key, PrincipalContentPage page) {
  ref.read(principalActiveNavKeyProvider.notifier).state = key;
  ref.read(principalContentStackProvider.notifier).state = [page];
}

/// A page pushing a further detail view on top of itself (e.g. a list
/// screen opening one record's full page).
void pushPrincipalContent(WidgetRef ref, PrincipalContentPage page) {
  final stack = ref.read(principalContentStackProvider);
  ref.read(principalContentStackProvider.notifier).state = [...stack, page];
}

/// Back one level. Popping the last remaining page returns to Home,
/// same as closing a sidebar destination entirely.
void popPrincipalContent(WidgetRef ref) {
  final stack = ref.read(principalContentStackProvider);
  if (stack.isEmpty) return;
  final next = stack.sublist(0, stack.length - 1);
  ref.read(principalContentStackProvider.notifier).state = next;
  if (next.isEmpty) {
    ref.read(principalActiveNavKeyProvider.notifier).state = 'home';
  }
}

void goToPrincipalHome(WidgetRef ref) {
  ref.read(principalActiveNavKeyProvider.notifier).state = 'home';
  ref.read(principalContentStackProvider.notifier).state = const [];
}
