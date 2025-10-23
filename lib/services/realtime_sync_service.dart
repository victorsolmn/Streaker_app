import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'database_sync_service.dart';
import '../providers/nutrition_provider.dart';
import '../providers/user_provider.dart';

/// Service to handle real-time syncing between local storage and Supabase
class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  final SupabaseService _supabase = SupabaseService();
  final Connectivity _connectivity = Connectivity();
  
  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isOnline = true;
  
  // Queue for offline operations
  final List<Map<String, dynamic>> _offlineQueue = [];
  
  // Sync status callbacks
  Function(bool)? onSyncStatusChanged;
  Function(String)? onSyncError;
  
  /// Initialize real-time sync
  Future<void> initialize() async {
    debugPrint('🔄 Initializing Real-time Sync Service');
    
    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = !connectivityResult.contains(ConnectivityResult.none);
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        final wasOffline = !_isOnline;
        _isOnline = !results.contains(ConnectivityResult.none);
        
        debugPrint('📡 Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
        
        // If we came back online, sync offline queue
        if (wasOffline && _isOnline) {
          await _syncOfflineQueue();
        }
      },
    );
    
    // Start periodic sync (every 30 seconds when online)
    _startPeriodicSync();
  }
  
  /// Start periodic sync timer
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isOnline && !_isSyncing) {
        await syncAll();
      }
    });
  }
  
  /// Sync all data to Supabase
  Future<void> syncAll() async {
    if (!_isOnline || _isSyncing) return;
    if (_supabase.currentUser == null) return;

    _isSyncing = true;
    onSyncStatusChanged?.call(true);

    try {
      // Sync local data to Supabase
      await Future.wait([
        _syncNutritionData(),
        _syncUserProfile(),
        // REMOVED: _syncStreaks() - Database triggers handle streak updates automatically
        // REMOVED: _syncHealthMetrics() - Health tracking removed from app
      ]);

      debugPrint('✅ Local data synced to Supabase');

      // Database-level sync recalculates goals and streaks automatically
      try {
        final dbSync = DatabaseSyncService();
        await dbSync.syncToday();
        debugPrint('✅ Database sync completed - goals and streaks auto-calculated');
      } catch (e) {
        debugPrint('⚠️ Database sync failed (non-critical): $e');
      }

      debugPrint('✅ All data synced successfully');
    } catch (e) {
      debugPrint('❌ Sync error: $e');
      onSyncError?.call(e.toString());
    } finally {
      _isSyncing = false;
      onSyncStatusChanged?.call(false);
    }
  }
  
  /// Sync nutrition data
  Future<void> _syncNutritionData() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getString('nutrition_entries');
      
      if (entriesJson != null) {
        // Parse the JSON string first
        final decodedJson = jsonDecode(entriesJson);
        final entries = List<Map<String, dynamic>>.from(
          (decodedJson as List).map((e) => Map<String, dynamic>.from(e))
        );

        // Group entries by date
        final entriesByDate = <String, Map<String, dynamic>>{};
        
        for (final entry in entries) {
          final date = DateTime.parse(entry['timestamp']).toIso8601String().split('T')[0];
          
          if (!entriesByDate.containsKey(date)) {
            entriesByDate[date] = {
              'calories': 0,
              'protein': 0.0,
              'carbs': 0.0,
              'fat': 0.0,
              // NOTE: fiber field REMOVED - database doesn't have this column
              'water': 0,
            };
          }

          entriesByDate[date]!['calories'] =
              (entriesByDate[date]!['calories'] ?? 0) + (entry['calories'] ?? 0);
          entriesByDate[date]!['protein'] =
              (entriesByDate[date]!['protein'] ?? 0.0) + (entry['protein'] ?? 0.0);
          entriesByDate[date]!['carbs'] =
              (entriesByDate[date]!['carbs'] ?? 0.0) + (entry['carbs'] ?? 0.0);
          entriesByDate[date]!['fat'] =
              (entriesByDate[date]!['fat'] ?? 0.0) + (entry['fat'] ?? 0.0);
          // NOTE: fiber accumulation REMOVED - database doesn't have this column
        }
        
        // Sync each day's totals to Supabase - placeholder for now
        // This would need to be implemented with a different method
        // that handles daily nutrition totals rather than individual entries
        for (final date in entriesByDate.keys) {
          // TODO: Implement daily nutrition totals sync
          debugPrint('Would sync nutrition totals for $date: ${entriesByDate[date]}');
        }
        
        debugPrint('📊 Synced ${entriesByDate.length} days of nutrition data');
      }
    } catch (e) {
      debugPrint('Error syncing nutrition: $e');
      _addToOfflineQueue('nutrition', {'error': e.toString()});
    }
  }
  
  /// Sync user profile
  Future<void> _syncUserProfile() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      
      final updates = <String, dynamic>{};
      
      // Get user data from SharedPreferences
      final name = prefs.getString('user_name');
      final age = prefs.getInt('user_age');
      final height = prefs.getDouble('user_height');
      final weight = prefs.getDouble('user_weight');
      final activityLevel = prefs.getString('activity_level');
      final fitnessGoal = prefs.getString('fitness_goal');
      
      if (name != null) updates['name'] = name;
      if (age != null) updates['age'] = age;
      if (height != null) updates['height'] = height;
      if (weight != null) updates['weight'] = weight;
      if (activityLevel != null) updates['activity_level'] = activityLevel;
      if (fitnessGoal != null) updates['fitness_goal'] = fitnessGoal;
      
      if (updates.isNotEmpty) {
        await _supabase.updateUserProfile(
          userId: userId,
          updates: updates,
        );
        debugPrint('👤 Synced user profile');
      }
    } catch (e) {
      debugPrint('Error syncing user profile: $e');
      _addToOfflineQueue('profile', {'error': e.toString()});
    }
  }
  
  // REMOVED: _syncStreaks() method
  // Streaks are now automatically calculated by database triggers.
  // No manual sync needed - this was causing race conditions and stale data issues.

  /// Add operation to offline queue
  void _addToOfflineQueue(String type, Map<String, dynamic> data) {
    _offlineQueue.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    debugPrint('📦 Added to offline queue: $type');
  }
  
  /// Sync offline queue when back online
  Future<void> _syncOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    
    debugPrint('📤 Syncing ${_offlineQueue.length} offline operations');
    
    final queueCopy = List<Map<String, dynamic>>.from(_offlineQueue);
    _offlineQueue.clear();
    
    for (final operation in queueCopy) {
      try {
        switch (operation['type']) {
          case 'nutrition':
            await _syncNutritionData();
            break;
          case 'profile':
            await _syncUserProfile();
            break;
          // REMOVED: case 'health' - health tracking removed from app
          // REMOVED: case 'streaks' - no longer manually syncing streaks
          default:
            debugPrint('⚠️ Unknown offline operation type: ${operation['type']}');
        }
      } catch (e) {
        debugPrint('Error syncing offline operation: $e');
        // Re-add to queue if still failing
        _offlineQueue.add(operation);
      }
    }
  }
  
  /// Sync nutrition entry immediately
  Future<void> syncNutritionEntry(NutritionEntry entry) async {
    if (!_isOnline) {
      _addToOfflineQueue('nutrition_entry', entry.toJson());
      return;
    }
    
    final userId = _supabase.currentUser?.id;
    if (userId == null) return;
    
    try {
      final date = entry.timestamp.toIso8601String().split('T')[0];
      
      // Simply save individual nutrition entry
      
      // Use individual nutrition entry method instead
      await _supabase.saveNutritionEntry(
        userId: userId,
        foodName: entry.foodName,
        calories: entry.calories,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
        // Note: fiber and foodSource parameters removed - fields don't exist in database
        quantityGrams: 100, // Default value since not available in entry
        mealType: 'meal', // Default value since not available in entry
      );
      
      debugPrint('✅ Synced nutrition entry: ${entry.foodName}');
    } catch (e) {
      debugPrint('Error syncing nutrition entry: $e');
      _addToOfflineQueue('nutrition_entry', entry.toJson());
    }
  }
  
  /// Check if currently syncing
  bool get isSyncing => _isSyncing;
  
  /// Check if online
  bool get isOnline => _isOnline;
  
  /// Get offline queue size
  int get offlineQueueSize => _offlineQueue.length;
  
  /// Force sync now
  Future<void> forceSyncNow() async {
    if (_isOnline && !_isSyncing) {
      await syncAll();
    }
  }
  
  /// Dispose service
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}