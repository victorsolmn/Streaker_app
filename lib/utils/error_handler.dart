import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'error_messages.dart';
import '../widgets/error_dialog.dart';

/// Centralized error handling system that converts technical exceptions
/// to user-friendly messages and provides consistent error UI
class ErrorHandler {
  /// Converts technical exceptions to user-friendly messages
  static String getUserMessage(dynamic error) {
    if (error == null) return ErrorMessages.genericError;

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (error is SocketException) {
      return ErrorMessages.noInternetConnection;
    }

    if (error is TimeoutException) {
      return ErrorMessages.requestTimeout;
    }

    if (errorString.contains('failed host lookup') ||
        errorString.contains('network is unreachable')) {
      return ErrorMessages.serverUnreachable;
    }

    // Authentication errors
    if (errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('401')) {
      return ErrorMessages.authenticationExpired;
    }

    if (errorString.contains('jwt') || errorString.contains('token')) {
      return ErrorMessages.sessionExpired;
    }

    // Validation errors
    if (error is FormatException) {
      return ErrorMessages.invalidDataFormat;
    }

    // Database errors
    if (errorString.contains('duplicate key') ||
        errorString.contains('already exists')) {
      return ErrorMessages.duplicateEntry;
    }

    // Storage/Permission errors
    if (errorString.contains('storage') ||
        errorString.contains('permission denied')) {
      return ErrorMessages.storagePermissionDenied;
    }

    // Supabase specific errors
    if (errorString.contains('rate limit')) {
      return ErrorMessages.tooManyAttempts;
    }

    // Default fallback
    debugPrint('⚠️ Unhandled error: ${error.toString()}');
    return ErrorMessages.genericError;
  }

  /// Shows error dialog with retry option
  static Future<bool?> showErrorDialog({
    required BuildContext context,
    required String message,
    String title = 'Error',
    VoidCallback? onRetry,
    bool showContactSupport = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        onRetry: onRetry,
        showContactSupport: showContactSupport,
      ),
    );
  }

  /// Shows error snackbar (non-blocking feedback)
  static void showErrorSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Logs error for debugging and analytics
  /// TODO: Integrate with crash reporting service (Firebase Crashlytics, Sentry)
  static void logError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) {
    debugPrint('=== ERROR LOG ===');
    debugPrint('Context: ${context ?? 'Unknown'}');
    debugPrint('Error: ${error.toString()}');
    if (stackTrace != null) {
      debugPrint('StackTrace: ${stackTrace.toString()}');
    }
    if (metadata != null) {
      debugPrint('Metadata: $metadata');
    }
    debugPrint('=================');

    // TODO: Send to crash reporting service
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, context: context);
  }

  /// Handles errors with complete flow: log, convert, display
  static void handleError(
    BuildContext context,
    dynamic error,
    StackTrace? stackTrace, {
    String? errorContext,
    VoidCallback? onRetry,
    bool showDialog = false,
  }) {
    // Log for debugging
    logError(error, stackTrace, context: errorContext);

    // Convert to user-friendly message
    final userMessage = getUserMessage(error);

    // Display to user
    if (showDialog) {
      showErrorDialog(
        context: context,
        message: userMessage,
        onRetry: onRetry,
      );
    } else {
      showErrorSnackbar(context, userMessage);
    }
  }
}
