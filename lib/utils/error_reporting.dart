import 'package:flutter/foundation.dart';

/// Writes diagnostic error details only in debug builds.
///
/// User-facing widgets should always provide their own friendly copy and must
/// not render [error] directly. Release builds intentionally omit these logs.
void logAppError(String operation, Object error, [StackTrace? stackTrace]) {
  if (!kDebugMode) return;

  debugPrint('[Groovefolio] $operation failed: $error');
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace);
  }
}
