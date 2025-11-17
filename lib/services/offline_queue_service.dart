import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Offline Queue Service - Manages pending operations when network is unavailable
///
/// This service stores nutrition entries that failed to sync due to network issues
/// and automatically retries when network becomes available.
class OfflineQueueService {
  static const String _queueKey = 'offline_nutrition_queue';
  static const String _lastSyncKey = 'last_sync_timestamp';

  final SharedPreferences _prefs;

  OfflineQueueService(this._prefs);

  /// Add a nutrition entry to the offline queue
  Future<bool> addToQueue(Map<String, dynamic> entry) async {
    try {
      final queue = await getQueue();

      // Add timestamp to track when it was queued
      entry['queued_at'] = DateTime.now().toIso8601String();
      entry['retry_count'] = 0;

      queue.add(entry);

      final success = await _prefs.setString(_queueKey, jsonEncode(queue));

      if (success) {
        debugPrint('📦 Added entry to offline queue: ${entry['food_name']} (${queue.length} total)');
      } else {
        debugPrint('❌ Failed to save entry to offline queue');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error adding to offline queue: $e');
      return false;
    }
  }

  /// Get all pending entries from the queue
  Future<List<Map<String, dynamic>>> getQueue() async {
    try {
      final queueJson = _prefs.getString(_queueKey);
      if (queueJson == null || queueJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(queueJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Error reading offline queue: $e');
      return [];
    }
  }

  /// Get count of pending entries
  Future<int> getQueueCount() async {
    final queue = await getQueue();
    return queue.length;
  }

  /// Remove an entry from the queue after successful sync
  Future<bool> removeFromQueue(Map<String, dynamic> entry) async {
    try {
      final queue = await getQueue();

      // Find and remove the entry by matching food_name and created_at
      queue.removeWhere((item) =>
        item['food_name'] == entry['food_name'] &&
        item['created_at'] == entry['created_at']
      );

      final success = await _prefs.setString(_queueKey, jsonEncode(queue));

      if (success) {
        debugPrint('✅ Removed entry from offline queue: ${entry['food_name']} (${queue.length} remaining)');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error removing from offline queue: $e');
      return false;
    }
  }

  /// Clear entire queue (use after successful full sync)
  Future<bool> clearQueue() async {
    try {
      final success = await _prefs.setString(_queueKey, jsonEncode([]));
      if (success) {
        debugPrint('🧹 Cleared offline queue');
      }
      return success;
    } catch (e) {
      debugPrint('❌ Error clearing offline queue: $e');
      return false;
    }
  }

  /// Increment retry count for an entry
  Future<bool> incrementRetryCount(Map<String, dynamic> entry) async {
    try {
      final queue = await getQueue();

      // Find the entry and increment retry count
      for (var i = 0; i < queue.length; i++) {
        if (queue[i]['food_name'] == entry['food_name'] &&
            queue[i]['created_at'] == entry['created_at']) {
          queue[i]['retry_count'] = (queue[i]['retry_count'] ?? 0) + 1;
          queue[i]['last_retry_at'] = DateTime.now().toIso8601String();
          break;
        }
      }

      return await _prefs.setString(_queueKey, jsonEncode(queue));
    } catch (e) {
      debugPrint('❌ Error incrementing retry count: $e');
      return false;
    }
  }

  /// Update last successful sync timestamp
  Future<void> updateLastSyncTime() async {
    await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Get last successful sync timestamp
  DateTime? getLastSyncTime() {
    final timestamp = _prefs.getString(_lastSyncKey);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  /// Check if entry already exists in queue
  Future<bool> isInQueue(String foodName, DateTime createdAt) async {
    final queue = await getQueue();
    return queue.any((item) =>
      item['food_name'] == foodName &&
      item['created_at'] == createdAt.toIso8601String()
    );
  }

  /// Get entries that failed after multiple retries (for manual review)
  Future<List<Map<String, dynamic>>> getFailedEntries({int maxRetries = 5}) async {
    final queue = await getQueue();
    return queue.where((entry) =>
      (entry['retry_count'] ?? 0) >= maxRetries
    ).toList();
  }

  /// Get statistics about the queue
  Future<Map<String, dynamic>> getQueueStats() async {
    final queue = await getQueue();
    final lastSync = getLastSyncTime();

    if (queue.isEmpty) {
      return {
        'total': 0,
        'oldest': null,
        'newest': null,
        'failed_count': 0,
        'last_sync': lastSync?.toIso8601String(),
      };
    }

    final timestamps = queue
      .map((e) => DateTime.tryParse(e['queued_at'] ?? ''))
      .where((d) => d != null)
      .cast<DateTime>()
      .toList();

    timestamps.sort();

    final failedCount = queue.where((e) => (e['retry_count'] ?? 0) >= 3).length;

    return {
      'total': queue.length,
      'oldest': timestamps.isNotEmpty ? timestamps.first.toIso8601String() : null,
      'newest': timestamps.isNotEmpty ? timestamps.last.toIso8601String() : null,
      'failed_count': failedCount,
      'last_sync': lastSync?.toIso8601String(),
    };
  }
}
