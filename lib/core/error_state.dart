import 'package:flutter/material.dart';

/// Categories of errors for uniform handling across the app.
enum ErrorType { network, notFound, server, permission, unknown }

/// Standardized error object used throughout the application.
class AppError {
  final String message;
  final ErrorType type;
  final dynamic originalException;

  const AppError({
    required this.message,
    this.type = ErrorType.unknown,
    this.originalException,
  });

  /// Factory constructor to parse dynamic exceptions or strings into [AppError].
  factory AppError.fromException(dynamic error) {
    if (error is AppError) return error;

    final String errString = error.toString().toLowerCase();

    if (errString.contains('socketexception') ||
        errString.contains('connection failed') ||
        errString.contains('network')) {
      return AppError(
        message: 'Network connection error. Please check your connection.',
        type: ErrorType.network,
        originalException: error,
      );
    }

    if (errString.contains('permission') ||
        errString.contains('denied') ||
        errString.contains('403')) {
      return AppError(
        message: 'You do not have permission to perform this action.',
        type: ErrorType.permission,
        originalException: error,
      );
    }

    if (errString.contains('404') || errString.contains('not found')) {
      return AppError(
        message: 'The requested resource was not found.',
        type: ErrorType.notFound,
        originalException: error,
      );
    }

    return AppError(
      message: error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
      type: ErrorType.unknown,
      originalException: error,
    );
  }
}

/// Reusable UI widget for displaying errors with optional retry functionality.
class ErrorStateView extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const ErrorStateView({
    super.key,
    this.error,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appError = error is AppError
        ? error as AppError
        : error != null
            ? AppError.fromException(error)
            : const AppError(message: 'An unexpected error occurred.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _getIcon(appError.type),
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            _getTitle(appError.type),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            appError.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(retryLabel ?? 'Try Again'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off_rounded;
      case ErrorType.permission:
        return Icons.lock_outline_rounded;
      case ErrorType.notFound:
        return Icons.search_off_rounded;
      case ErrorType.server:
      case ErrorType.unknown:
        return Icons.error_outline_rounded;
    }
  }

  String _getTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Connection Failed';
      case ErrorType.permission:
        return 'Access Denied';
      case ErrorType.notFound:
        return 'Not Found';
      case ErrorType.server:
        return 'Server Error';
      case ErrorType.unknown:
        return 'Something Went Wrong';
    }
  }
}