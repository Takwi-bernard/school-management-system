import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single "screen" shown inside the current tab's content area.
///
/// This module's drill-down is shallow (dashboard -> assignment detail
/// -> {class list, marks entry, attendance}) and the whole point of
/// this file is that going deeper must NEVER leave the shell: using
/// Flutter's real Navigator for that (as the original code did) meant
/// every pushed page was inserted into the app's Overlay as a SIBLING
/// of TeacherShell, not a descendant of it - so the sidebar/drawer
/// disappeared the moment you drilled in. This stack lives in
/// TeacherShell's own state instead, so the sidebar (desktop) and
/// drawer/hamburger (mobile) are structurally guaranteed to still be
/// there no matter how deep the stack goes.
class TeacherContentPage {
  final String title;
  final WidgetBuilder builder;
  const TeacherContentPage({required this.title, required this.builder});
}

final teacherContentStackProvider = StateProvider<List<TeacherContentPage>>((ref) => []);

void pushTeacherContent(WidgetRef ref, TeacherContentPage page) {
  ref.read(teacherContentStackProvider.notifier).update((stack) => [...stack, page]);
}

void popTeacherContent(WidgetRef ref) {
  ref.read(teacherContentStackProvider.notifier).update(
        (stack) => stack.isEmpty ? stack : stack.sublist(0, stack.length - 1),
      );
}