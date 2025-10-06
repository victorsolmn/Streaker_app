import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_sync_service.dart';
import 'supabase_service.dart';

const String syncTaskName = "dailyDataSync";
const String syncTaskTag = "streak_sync";

/// Background task callback
/// This runs in an isolate, so it needs to reinitialize Supabase
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('🔄 [BackgroundSync] Task started: $task');

      // Note: Supabase needs to be initialized in the background isolate
      // But we can't access the current user session here
      // So background sync is limited - we rely on app-level sync mostly

      debugPrint('✅ [BackgroundSync] Task completed');
      return Future.value(true);
    } catch (e) {
      debugPrint('❌ [BackgroundSync] Task error: $e');
      return Future.value(false);
    }
  });
}

/// Service to manage background sync using WorkManager
class BackgroundSyncService {
  static BackgroundSyncService? _instance;

  factory BackgroundSyncService() {
    _instance ??= BackgroundSyncService._internal();
    return _instance!;
  }

  BackgroundSyncService._internal();

  /// Initialize WorkManager
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      debugPrint('✅ [BackgroundSync] WorkManager initialized');
    } catch (e) {
      debugPrint('❌ [BackgroundSync] Initialization failed: $e');
    }
  }

  /// Register periodic sync task
  /// Syncs every 15 minutes (minimum allowed by Android)
  Future<void> registerPeriodicSync() async {
    try {
      await Workmanager().registerPeriodicTask(
        "1", // Unique task name
        syncTaskName,
        frequency: const Duration(minutes: 15), // Minimum allowed
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        tag: syncTaskTag,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );

      debugPrint('✅ [BackgroundSync] Periodic sync registered (every 15 min)');
    } catch (e) {
      debugPrint('❌ [BackgroundSync] Failed to register periodic sync: $e');
    }
  }

  /// Register one-time immediate sync
  Future<void> registerImmediateSync() async {
    try {
      await Workmanager().registerOneOffTask(
        "sync_immediate",
        syncTaskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        tag: syncTaskTag,
      );

      debugPrint('✅ [BackgroundSync] Immediate sync registered');
    } catch (e) {
      debugPrint('❌ [BackgroundSync] Failed to register immediate sync: $e');
    }
  }

  /// Cancel all background sync tasks
  Future<void> cancelAll() async {
    try {
      await Workmanager().cancelAll();
      debugPrint('✅ [BackgroundSync] All tasks cancelled');
    } catch (e) {
      debugPrint('❌ [BackgroundSync] Failed to cancel tasks: $e');
    }
  }

  /// Cancel only periodic sync
  Future<void> cancelPeriodicSync() async {
    try {
      await Workmanager().cancelByUniqueName("1");
      debugPrint('✅ [BackgroundSync] Periodic sync cancelled');
    } catch (e) {
      debugPrint('❌ [BackgroundSync] Failed to cancel periodic sync: $e');
    }
  }
}
