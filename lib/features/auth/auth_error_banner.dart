import 'dart:async';

import 'package:flutter/material.dart';

/// FIX: previously a plain Text that stayed on screen forever and was
/// shared across every auth page via one global provider, so an error
/// from Sign Up would still be showing after navigating to Sign In.
/// This auto-dismisses after a few seconds AND can be dismissed
/// manually, and each page now clears it on entry (see initState in
/// each page) so errors never leak between screens.
class AuthErrorBanner extends StatefulWidget {
  final String? message;
  final VoidCallback onDismiss;

  const AuthErrorBanner({super.key, required this.message, required this.onDismiss});

  @override
  State<AuthErrorBanner> createState() => _AuthErrorBannerState();
}

class _AuthErrorBannerState extends State<AuthErrorBanner> {
  Timer? _timer;

  @override
  void didUpdateWidget(covariant AuthErrorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != null && widget.message != oldWidget.message) {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 6), widget.onDismiss);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: widget.message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, size: 18, color: theme.colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onDismiss,
                    child: Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),
    );
  }
}