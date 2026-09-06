import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../auth/auth_providers.dart';

/// Confirms, then performs sign-out with a minimum visible loading
/// duration - so a fast network response doesn't make the spinner
/// flash for 40ms and feel broken. Shared logic behind both button
/// variants below.
Future<void> _confirmAndSignOut({
  required BuildContext context,
  required WidgetRef ref,
  required AppStrings strings,
  required ValueChanged<bool> setSigningOut,
}) async {
  final theme = Theme.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(strings.signOutConfirmTitle),
      content: Text(strings.signOutConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          child: Text(strings.signOut),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  setSigningOut(true);
  final stopwatch = Stopwatch()..start();
  await ref.read(authControllerProvider.notifier).signOut();
  const minVisibleMs = 700;
  final remaining = minVisibleMs - stopwatch.elapsedMilliseconds;
  if (remaining > 0) await Future.delayed(Duration(milliseconds: remaining));

  if (context.mounted) context.go('/');
}

/// Compact icon-only variant for the sidebar (desktop/tablet) and the
/// mobile drawer.
class TeacherSignOutIconButton extends ConsumerStatefulWidget {
  final AppStrings strings;
  final Color color;
  const TeacherSignOutIconButton({super.key, required this.strings, required this.color});

  @override
  ConsumerState<TeacherSignOutIconButton> createState() => _TeacherSignOutIconButtonState();
}

class _TeacherSignOutIconButtonState extends ConsumerState<TeacherSignOutIconButton> {
  bool _signingOut = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.strings.signOut,
      child: IconButton(
        onPressed: _signingOut
            ? null
            : () => _confirmAndSignOut(
                  context: context,
                  ref: ref,
                  strings: widget.strings,
                  setSigningOut: (v) {
                    if (mounted) setState(() => _signingOut = v);
                  },
                ),
        icon: _signingOut
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: widget.color),
              )
            : Icon(Icons.logout_rounded, size: 20, color: widget.color),
      ),
    );
  }
}

/// Full-width labeled variant for the Profile tab.
class TeacherSignOutButton extends ConsumerStatefulWidget {
  final AppStrings strings;
  const TeacherSignOutButton({super.key, required this.strings});

  @override
  ConsumerState<TeacherSignOutButton> createState() => _TeacherSignOutButtonState();
}

class _TeacherSignOutButtonState extends ConsumerState<TeacherSignOutButton> {
  bool _signingOut = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
        onPressed: _signingOut
            ? null
            : () => _confirmAndSignOut(
                  context: context,
                  ref: ref,
                  strings: widget.strings,
                  setSigningOut: (v) {
                    if (mounted) setState(() => _signingOut = v);
                  },
                ),
        icon: _signingOut
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.error),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(_signingOut ? widget.strings.signingOut : widget.strings.signOut),
      ),
    );
  }
}