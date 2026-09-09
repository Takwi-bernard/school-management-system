import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single "screen" shown inside the parent shell's content area.
///
/// Mirrors teacher_navigation.dart exactly, same reasoning: a page
/// reached via Navigator.push (context.push/context.go from
/// go_router included) attaches to the app's ROOT navigator, above
/// ParentShell's own Theme/sidebar - so it doesn't inherit either.
/// That's the exact bug already found in the existing parent code
/// (see the comment on buildSchoolTheme in parent_models.dart, which
/// papers over the color half of this by rebuilding a Theme on every
/// single page - but does nothing for the sidebar disappearing).
/// Pushing here instead keeps both.
class ParentContentPage {
  final String title;
  final WidgetBuilder builder;
  const ParentContentPage({required this.title, required this.builder});
}

final parentContentStackProvider = StateProvider<List<ParentContentPage>>((ref) => []);

/// Nav items behave as top-level destinations here (unlike Teacher's
/// mix of tabs + drill-down) - selecting one REPLACES the stack
/// rather than pushing onto it, since every parent nav item is a
/// sibling destination, not a child of whatever was showing before.
void showParentContent(WidgetRef ref, ParentContentPage page) {
  ref.read(parentContentStackProvider.notifier).state = [page];
}

/// For a genuine drill-down FROM inside a shown page (e.g. tapping a
/// specific child from a "My Children" list) - adds on top instead of
/// replacing, so a back arrow returns to the list, not to Home.
void pushParentContent(WidgetRef ref, ParentContentPage page) {
  ref.read(parentContentStackProvider.notifier).update((stack) => [...stack, page]);
}

void popParentContent(WidgetRef ref) {
  ref.read(parentContentStackProvider.notifier).update(
        (stack) => stack.isEmpty ? stack : stack.sublist(0, stack.length - 1),
      );
}