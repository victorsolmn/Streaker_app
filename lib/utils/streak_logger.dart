import 'package:flutter/foundation.dart';

/// Centralized logging for streak operations
/// Prevents duplicate/redundant log messages
///
/// Usage:
/// - StreakLogger.logLoaded() - When streak data is loaded from database
/// - StreakLogger.logUpdated() - When streak changes
/// - StreakLogger.logSyncComplete() - After sync operations
/// - StreakLogger.logGracePeriod() - Grace period status updates
class StreakLogger {
  static const bool _enableDebugLogs = true;

  /// Log when streak is loaded from database
  static void logLoaded({
    required int currentStreak,
    required int longestStreak,
    String? source,
  }) {
    if (!_enableDebugLogs) return;
    debugPrint('📊 Streak loaded: current=$currentStreak, longest=$longestStreak${source != null ? ' (from $source)' : ''}');
  }

  /// Log when streak is updated
  static void logUpdated({
    required int previousStreak,
    required int newStreak,
    required String reason,
  }) {
    if (!_enableDebugLogs) return;
    if (previousStreak == newStreak) {
      debugPrint('🔥 Streak maintained: $newStreak days ($reason)');
    } else {
      debugPrint('🔥 Streak updated: $previousStreak → $newStreak ($reason)');
    }
  }

  /// Log when streak update fails
  static void logUpdateFailed(String reason, [dynamic error]) {
    debugPrint('❌ Streak update failed: $reason${error != null ? ' - $error' : ''}');
  }

  /// Log when sync completes
  static void logSyncComplete({
    required int currentStreak,
    required int longestStreak,
    required Duration syncTime,
  }) {
    if (!_enableDebugLogs) return;
    debugPrint('✅ Streak sync complete: current=$currentStreak, longest=$longestStreak (${syncTime.inMilliseconds}ms)');
  }

  /// Log grace period usage
  static void logGracePeriod({
    required int graceDaysUsed,
    required int graceDaysAvailable,
    required int currentStreak,
  }) {
    if (!_enableDebugLogs) return;
    final remaining = graceDaysAvailable - graceDaysUsed;
    debugPrint('⚠️ Grace period: used $graceDaysUsed/$graceDaysAvailable (${remaining} remaining) - streak at $currentStreak');
  }

  /// Log when sync is skipped due to debouncing
  static void logSyncSkipped(Duration timeSinceLastSync) {
    if (!_enableDebugLogs) return;
    debugPrint('⏭️ Sync skipped - last sync was ${timeSinceLastSync.inSeconds}s ago (cooldown: 30s)');
  }

  /// Log when sync is already in progress
  static void logSyncInProgress() {
    if (!_enableDebugLogs) return;
    debugPrint('⏭️ Sync skipped - sync already in progress');
  }
}
