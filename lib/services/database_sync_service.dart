import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'supabase_service.dart';

/// Service to handle database-level sync operations
/// Uses Supabase RPC functions to trigger server-side calculations
class DatabaseSyncService {
  static final DatabaseSyncService _instance = DatabaseSyncService._internal();
  factory DatabaseSyncService() => _instance;
  DatabaseSyncService._internal();

  final SupabaseService _supabase = SupabaseService();

  /// Force sync all data for a specific date using database functions
  /// This triggers nutrition aggregation, goal calculation, and streak updates
  Future<Map<String, dynamic>?> syncDailyData({
    required String userId,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      debugPrint('🔄 [DatabaseSync] Syncing data for $dateStr...');

      final result = await _supabase.client.rpc(
        'sync_user_daily_data',
        params: {
          'p_user_id': userId,
          'p_date': dateStr,
        },
      );

      debugPrint('✅ [DatabaseSync] Sync completed successfully');
      debugPrint('   Result: $result');

      return result as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ [DatabaseSync] Sync failed: $e');
      return null;
    }
  }

  /// Sync current day's data
  Future<Map<String, dynamic>?> syncToday() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) {
      debugPrint('⚠️ [DatabaseSync] No user logged in, skipping sync');
      return null;
    }

    return await syncDailyData(userId: userId);
  }

  /// Sync yesterday's data (useful for late night corrections)
  Future<Map<String, dynamic>?> syncYesterday() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return null;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return await syncDailyData(userId: userId, date: yesterday);
  }

  /// Sync multiple days (for backfill or corrections)
  Future<List<Map<String, dynamic>>> syncDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = <Map<String, dynamic>>[];
    final days = endDate.difference(startDate).inDays;

    debugPrint('🔄 [DatabaseSync] Syncing date range: $startDate to $endDate ($days days)');

    for (int i = 0; i <= days; i++) {
      final date = startDate.add(Duration(days: i));
      final result = await syncDailyData(userId: userId, date: date);

      if (result != null) {
        results.add(result);
      }

      // Rate limiting to avoid overwhelming database
      if (i < days) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    debugPrint('✅ [DatabaseSync] Synced $days days successfully');
    return results;
  }

  /// Sync last N days (useful for ensuring recent data is accurate)
  Future<void> syncLastNDays(int days) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return;

    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));

    await syncDateRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get current sync status from audit log (if available)
  Future<List<Map<String, dynamic>>> getSyncAuditLog({
    int limit = 20,
  }) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase.client
          .from('sync_audit_log')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('⚠️ [DatabaseSync] Could not fetch audit log: $e');
      return [];
    }
  }

  /// Check if nutrition data needs syncing for a specific date
  Future<bool> needsNutritionSync(DateTime date) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return false;

      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // Check if there are nutrition entries but health_metrics.calories_consumed is 0
      final nutritionEntries = await _supabase.client
          .from('nutrition_entries')
          .select('calories')
          .eq('user_id', userId)
          .eq('date', dateStr);

      if (nutritionEntries.isEmpty) return false;

      final healthMetric = await _supabase.client
          .from('health_metrics')
          .select('calories_consumed')
          .eq('user_id', userId)
          .eq('date', dateStr)
          .maybeSingle();

      final totalNutrition = (nutritionEntries as List)
          .fold<double>(0, (sum, entry) => sum + (entry['calories'] ?? 0));

      final syncedCalories = healthMetric?['calories_consumed'] ?? 0;

      // Needs sync if there's a mismatch
      return totalNutrition > 0 && syncedCalories == 0;
    } catch (e) {
      debugPrint('⚠️ [DatabaseSync] Error checking sync status: $e');
      return false;
    }
  }

  /// Smart sync: Only sync if needed
  Future<void> smartSync() async {
    final today = DateTime.now();
    final needsSync = await needsNutritionSync(today);

    if (needsSync) {
      debugPrint('🔄 [DatabaseSync] Detected out-of-sync data, triggering sync...');
      await syncToday();
    } else {
      debugPrint('✅ [DatabaseSync] Data is already in sync');
    }
  }

  /// Force sync with retry logic
  Future<Map<String, dynamic>?> syncWithRetry({
    required String userId,
    DateTime? date,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      try {
        return await syncDailyData(userId: userId, date: date);
      } catch (e) {
        lastError = e as Exception;
        attempt++;

        if (attempt < maxRetries) {
          final delay = Duration(seconds: attempt * 2); // Exponential backoff
          debugPrint('⚠️ [DatabaseSync] Attempt $attempt failed, retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      }
    }

    debugPrint('❌ [DatabaseSync] All $maxRetries attempts failed: $lastError');
    return null;
  }
}
