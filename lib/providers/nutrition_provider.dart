import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/nutrition_ai_service.dart';
import '../services/indian_food_nutrition_service.dart';
import '../services/realtime_sync_service.dart';
import '../services/supabase_service.dart';
import '../services/database_sync_service.dart';
import '../services/offline_queue_service.dart';

class NutritionEntry {
  final String id;
  final String foodName;
  final String? quantity; // Added quantity/description field
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  // NOTE: fiber field REMOVED - database doesn't have this column
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // NEW: Metadata for source, confidence, etc.

  NutritionEntry({
    required this.id,
    required this.foodName,
    this.quantity,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    // NOTE: fiber parameter REMOVED
    required this.timestamp,
    this.metadata, // NEW: Optional metadata
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodName': foodName,
      'quantity': quantity,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      // NOTE: fiber field REMOVED - database doesn't have this column
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata, // Include metadata in JSON
    };
  }

  factory NutritionEntry.fromJson(Map<String, dynamic> json) {
    return NutritionEntry(
      id: json['id'],
      foodName: json['foodName'],
      quantity: json['quantity'],
      calories: json['calories'],
      protein: json['protein'].toDouble(),
      carbs: json['carbs'].toDouble(),
      fat: json['fat'].toDouble(),
      // NOTE: fiber field REMOVED - database doesn't have this column
      timestamp: DateTime.parse(json['timestamp']),
      metadata: json['metadata'] as Map<String, dynamic>?, // Parse metadata
    );
  }
}

class DailyNutrition {
  final DateTime date;
  final List<NutritionEntry> entries;

  DailyNutrition({required this.date, required this.entries});

  int get totalCalories => entries.fold(0, (sum, entry) => sum + entry.calories);
  double get totalProtein => entries.fold(0, (sum, entry) => sum + entry.protein);
  double get totalCarbs => entries.fold(0, (sum, entry) => sum + entry.carbs);
  double get totalFat => entries.fold(0, (sum, entry) => sum + entry.fat);
  // NOTE: totalFiber REMOVED - database doesn't track fiber
}

class NutritionProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  List<NutritionEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  final IndianFoodNutritionService _indianFoodService = IndianFoodNutritionService();
  final RealtimeSyncService _syncService = RealtimeSyncService();
  final SupabaseService _supabaseService = SupabaseService();
  late final OfflineQueueService _offlineQueue;

  // Connectivity and sync management
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  Timer? _syncTimer;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;

  // Date selection for viewing historical data
  DateTime _selectedDate = DateTime.now();

  // Daily goals
  int _calorieGoal = 2000;
  double _proteinGoal = 150.0;
  double _carbGoal = 250.0;
  double _fatGoal = 67.0;

  NutritionProvider(this._prefs) {
    _offlineQueue = OfflineQueueService(_prefs);
    _initializeData();
    _setupConnectivityMonitoring();
    _setupPeriodicSync();
  }

  Future<void> _initializeData() async {
    await _loadGoals();
    await loadDataFromSupabase();

    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = !connectivityResult.contains(ConnectivityResult.none);

    // Load pending sync count
    _pendingSyncCount = await _offlineQueue.getQueueCount();
    debugPrint('📦 Offline queue initialized: $_pendingSyncCount pending entries');
  }
  
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOffline = !_isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      if (wasOffline && _isOnline) {
        debugPrint('📡 NutritionProvider: Connection restored - syncing offline queue and data');
        _syncOfflineQueue(); // NEW: Sync offline queue first
        _syncToSupabase();
        loadDataFromSupabase();
      }

      notifyListeners(); // Notify UI of network status change
    });
  }
  
  void _setupPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (_isOnline && !_isSyncing) {
        debugPrint('NutritionProvider: Periodic sync triggered');
        _syncToSupabase();
      }
    });
  }
  
  Future<void> syncOnPause() async {
    if (_isOnline && !_isSyncing) {
      debugPrint('NutritionProvider: Syncing on app pause');
      await _syncToSupabase();
    }
  }

  List<NutritionEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _isOnline;
  int get pendingSyncCount => _pendingSyncCount;
  DateTime get selectedDate => _selectedDate;

  int get calorieGoal => _calorieGoal;
  double get proteinGoal => _proteinGoal;
  double get carbGoal => _carbGoal;
  double get fatGoal => _fatGoal;

  DailyNutrition get todayNutrition {
    final today = DateTime.now();
    final todayEntries = _entries.where((entry) {
      return entry.timestamp.year == today.year &&
             entry.timestamp.month == today.month &&
             entry.timestamp.day == today.day;
    }).toList();

    return DailyNutrition(date: today, entries: todayEntries);
  }

  // Helper getter for today's entries
  List<NutritionEntry> get todayEntries => todayNutrition.entries;

  // Getter for selected date nutrition (for date navigation feature)
  DailyNutrition get selectedDateNutrition {
    final selectedEntries = _entries.where((entry) {
      return entry.timestamp.year == _selectedDate.year &&
             entry.timestamp.month == _selectedDate.month &&
             entry.timestamp.day == _selectedDate.day;
    }).toList();

    return DailyNutrition(date: _selectedDate, entries: selectedEntries);
  }

  // Helper getter for selected date entries
  List<NutritionEntry> get selectedDateEntries => selectedDateNutrition.entries;

  // Select a specific date and load its nutrition data
  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day); // Normalize to start of day
    await loadNutritionForDate(date);
    notifyListeners();
  }

  // Reset to today's date
  Future<void> resetToToday() async {
    await selectDate(DateTime.now());
  }

  // Load today's nutrition data (loads ONLY today's entries for accurate home page display)
  Future<void> loadTodayNutrition() async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) {
      await _loadNutritionData();
      return;
    }

    _setLoading(true);
    try {
      // Load ONLY today's entries for home page accuracy
      final todayEntries = await _supabaseService.getTodayNutritionEntries(userId: userId);

      // Clear entries and load only today's data to prevent showing yesterday's data
      _entries.clear();

      for (final entry in todayEntries) {
        final timestamp = DateTime.parse(entry['created_at'] ?? entry['date'] ?? DateTime.now().toIso8601String());
        final foodName = entry['food_name'] ?? 'Unknown';

        _entries.add(NutritionEntry(
          id: entry['id'] ?? '${timestamp.millisecondsSinceEpoch}_$foodName',
          foodName: foodName,
          calories: entry['calories'] ?? 0,
          protein: (entry['protein'] ?? 0).toDouble(),
          carbs: (entry['carbs'] ?? 0).toDouble(),
          fat: (entry['fat'] ?? 0).toDouble(),
          timestamp: timestamp,
        ));
      }

      debugPrint('✅ Loaded ${_entries.length} entries for TODAY ONLY (home page)');

      // Save to local storage
      await _saveNutritionData();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading today\'s nutrition: $e');
      await _loadNutritionData();
      _setLoading(false);
    }
  }

  // Load nutrition data for a specific date
  Future<void> loadNutritionForDate(DateTime date) async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) {
      await _loadNutritionData();
      return;
    }

    _setLoading(true);
    try {
      debugPrint('📅 Loading nutrition for date: ${date.year}-${date.month}-${date.day}');

      // Get entries for the specific date
      final dateEntries = await _supabaseService.getNutritionEntriesForDate(
        userId: userId,
        date: date,
      );

      // Clear entries and load date-specific data
      _entries.clear();

      for (final entry in dateEntries) {
        final timestamp = entry['created_at'] != null
            ? DateTime.parse(entry['created_at'])
            : DateTime.parse(entry['date'] ?? DateTime.now().toIso8601String());

        final foodName = entry['food_name'] ?? 'Unknown';

        _entries.add(NutritionEntry(
          id: entry['id'] ?? '${timestamp.millisecondsSinceEpoch}_$foodName',
          foodName: foodName,
          calories: entry['calories'] ?? 0,
          protein: (entry['protein'] ?? 0).toDouble(),
          carbs: (entry['carbs'] ?? 0).toDouble(),
          fat: (entry['fat'] ?? 0).toDouble(),
          timestamp: timestamp,
        ));
      }

      debugPrint('✅ Loaded ${_entries.length} entries for ${date.year}-${date.month}-${date.day}');

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading nutrition for date: $e');
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      // Only notify if we're not in a build phase
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
        notifyListeners();
      }
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      // Only notify if we're not in a build phase
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
        notifyListeners();
      }
    }
  }

  Future<void> _loadNutritionData() async {
    try {
      final String? entriesJson = _prefs.getString('nutrition_entries');
      if (entriesJson != null) {
        final List<dynamic> decodedEntries = jsonDecode(entriesJson);
        _entries = decodedEntries.map((e) => NutritionEntry.fromJson(e)).toList();
      }
      notifyListeners();
    } catch (e) {
      _setError('Failed to load nutrition data');
    }
  }

  Future<void> loadDataFromSupabase() async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) {
      // If not logged in, load from local storage
      await _loadNutritionData();
      return;
    }

    _setLoading(true);
    try {
      // Note: clearAllNutritionEntries method available if needed for future cleanup
      // await _supabaseService.clearAllNutritionEntries(userId);

      // Load nutrition history from Supabase (last 7 days initially for performance)
      final history = await _supabaseService.getNutritionHistory(
        userId: userId,
        days: 7, // Start with 7 days for faster loading
      );

      _entries.clear();

      // Track unique entries to prevent duplicates
      final uniqueEntryKeys = <String>{};

      // Each entry from the database is a nutrition entry itself
      for (final entry in history) {
        final timestamp = DateTime.parse(entry['created_at'] ?? entry['date'] ?? DateTime.now().toIso8601String());
        final foodName = entry['food_name'] ?? 'Unknown';

        // Create a unique key for duplicate detection
        final entryKey = '${timestamp.millisecondsSinceEpoch}_$foodName';

        // Skip if we already have this entry (duplicate)
        if (uniqueEntryKeys.contains(entryKey)) {
          debugPrint('Skipping duplicate entry while loading: $foodName at $timestamp');
          continue;
        }

        uniqueEntryKeys.add(entryKey);

        _entries.add(NutritionEntry(
          id: entry['id'] ?? entryKey, // Use consistent ID
          foodName: foodName, // Database uses snake_case
          calories: entry['calories'] ?? 0,
          protein: (entry['protein'] ?? 0).toDouble(),
          carbs: (entry['carbs'] ?? 0).toDouble(),
          fat: (entry['fat'] ?? 0).toDouble(),
          timestamp: timestamp,
        ));
      }

      debugPrint('Loaded ${_entries.length} unique nutrition entries from Supabase');

      // Save to local storage as well
      await _saveNutritionData();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading from Supabase: $e');
      // Fallback to local data
      await _loadNutritionData();
      _setLoading(false);
    }
  }

  Future<void> _saveNutritionData() async {
    try {
      final String entriesJson = jsonEncode(_entries.map((e) => e.toJson()).toList());
      await _prefs.setString('nutrition_entries', entriesJson);
    } catch (e) {
      _setError('Failed to save nutrition data');
    }
  }

  Future<void> _loadGoals() async {
    _calorieGoal = _prefs.getInt('calorie_goal') ?? 2000;
    _proteinGoal = _prefs.getDouble('protein_goal') ?? 150.0;
    _carbGoal = _prefs.getDouble('carb_goal') ?? 250.0;
    _fatGoal = _prefs.getDouble('fat_goal') ?? 67.0;
    notifyListeners();
  }

  Future<void> updateGoals({
    int? calorieGoal,
    double? proteinGoal,
    double? carbGoal,
    double? fatGoal,
  }) async {
    if (calorieGoal != null) {
      _calorieGoal = calorieGoal;
      await _prefs.setInt('calorie_goal', calorieGoal);
    }
    if (proteinGoal != null) {
      _proteinGoal = proteinGoal;
      await _prefs.setDouble('protein_goal', proteinGoal);
    }
    if (carbGoal != null) {
      _carbGoal = carbGoal;
      await _prefs.setDouble('carb_goal', carbGoal);
    }
    if (fatGoal != null) {
      _fatGoal = fatGoal;
      await _prefs.setDouble('fat_goal', fatGoal);
    }
    notifyListeners();
  }

  Future<void> addNutritionEntry(NutritionEntry entry) async {
    _setLoading(true);
    _setError(null);

    try {
      _entries.add(entry);
      await _saveNutritionData();

      // Auto-sync to Supabase if user is logged in and online
      final userId = _supabaseService.currentUser?.id;
      if (userId != null && _isOnline) {
        debugPrint('NutritionProvider: Auto-syncing after adding entry');
        await _syncToSupabase(forceSync: true); // Force immediate sync for user-added entries

        // NEW: Trigger database-level sync to update health_metrics and streaks
        await _triggerDatabaseSync();
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add nutrition entry');
      _setLoading(false);
    }
  }

  /// Trigger database-level sync to aggregate nutrition and update goals/streaks
  /// Uses update_nutrition_streak function to calculate and update streaks
  Future<void> _triggerDatabaseSync() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      // Call update_nutrition_streak to recalculate streaks based on nutrition data
      await _supabaseService.client
          .rpc('update_nutrition_streak', params: {
        'p_user_id': userId,
        'p_date': DateTime.now().toIso8601String().split('T')[0], // Today's date in YYYY-MM-DD
      });

      debugPrint('✅ NutritionProvider: Nutrition streak updated successfully');
    } catch (e) {
      debugPrint('⚠️ NutritionProvider: Streak update failed (non-critical): $e');
      // Non-critical error - database triggers will handle it automatically
      // This is just for immediate feedback
    }
  }

  Future<void> _syncToSupabase({bool forceSync = false}) async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null || _isSyncing) return;

    // Throttle syncing - don't sync more than once per minute (unless forced)
    if (!forceSync && _lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync.inSeconds < 60) {
        debugPrint('NutritionProvider: Skipping sync, last sync was ${timeSinceLastSync.inSeconds} seconds ago');
        return;
      }
    }

    // If forceSync is true, log that we're bypassing throttle
    if (forceSync) {
      debugPrint('🚀 NutritionProvider: Force sync enabled - bypassing throttle');
    }

    _isSyncing = true;
    final syncedEntryIds = <String>{}; // Track already synced entries

    try {
      debugPrint('NutritionProvider: Starting sync to Supabase');

      // Get existing entries from Supabase for today to avoid duplicates
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // First, get existing entries from Supabase to check for duplicates
      final existingEntries = await _supabaseService.getNutritionHistory(
        userId: userId,
        days: 1, // Only check today's entries
      );

      // Create a set of existing entry identifiers to prevent duplicates
      // Using composite key: timestamp + food_name + calories for better duplicate detection
      final existingEntryKeys = <String>{};
      for (final existing in existingEntries) {
        final timestamp = DateTime.parse(existing['created_at'] ?? existing['date'] ?? '');
        final foodName = existing['food_name'] ?? '';
        final calories = existing['calories'] ?? 0;
        // Create composite key with timestamp (rounded to nearest minute), food name, and calories
        final roundedTimestamp = (timestamp.millisecondsSinceEpoch ~/ 60000) * 60000;
        final key = '${roundedTimestamp}_${foodName}_$calories';
        existingEntryKeys.add(key);
      }

      // Group local entries by date
      final Map<String, List<NutritionEntry>> entriesByDate = {};

      debugPrint('📋 Grouping ${_entries.length} local entries by date');
      for (final entry in _entries) {
        final dateStr = '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
        entriesByDate[dateStr] ??= [];
        entriesByDate[dateStr]!.add(entry);
        debugPrint('  Entry: ${entry.foodName} -> date: $dateStr');
      }

      debugPrint('📅 Today string: $todayStr');
      debugPrint('📅 Dates in entriesByDate: ${entriesByDate.keys.toList()}');

      // Only sync today's entries to avoid re-syncing old data
      if (entriesByDate.containsKey(todayStr)) {
        final todayEntries = entriesByDate[todayStr]!;
        debugPrint('✅ Found ${todayEntries.length} entries for today, will attempt to sync');

        // Only save entries that haven't been synced yet
        for (final entry in todayEntries) {
          // Use composite key: timestamp (rounded to minute) + food name + calories
          final roundedTimestamp = (entry.timestamp.millisecondsSinceEpoch ~/ 60000) * 60000;
          final entryKey = '${roundedTimestamp}_${entry.foodName}_${entry.calories}';

          // Check if entry already exists in database
          if (!existingEntryKeys.contains(entryKey) && !syncedEntryIds.contains(entryKey)) {
            try {
              await _supabaseService.saveNutritionEntry(
                userId: userId,
                foodName: entry.foodName,
                calories: entry.calories,
                protein: entry.protein,
                carbs: entry.carbs,
                fat: entry.fat,
                // Note: fiber parameter removed - field doesn't exist in database
                timestamp: entry.timestamp,
              );
              syncedEntryIds.add(entryKey);
              debugPrint('✅ Synced nutrition entry: ${entry.foodName}');
            } catch (e) {
              // NEW: Add to offline queue if sync fails
              debugPrint('❌ Failed to sync ${entry.foodName}, adding to offline queue: $e');
              await _addEntryToOfflineQueue(entry, userId);
            }
          } else {
            debugPrint('Skipping duplicate entry: ${entry.foodName}');
          }
        }
      } else {
        debugPrint('⚠️ No entries found for today ($todayStr) in local data');
      }

      _lastSyncTime = DateTime.now();
      debugPrint('✅ NutritionProvider: Sync to Supabase completed successfully');
    } catch (e) {
      debugPrint('❌ Error syncing to Supabase: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// NEW: Add entry to offline queue when sync fails
  Future<void> _addEntryToOfflineQueue(NutritionEntry entry, String userId) async {
    final entryData = {
      'user_id': userId,
      'food_name': entry.foodName,
      'calories': entry.calories,
      'protein': entry.protein,
      'carbs': entry.carbs,
      'fat': entry.fat,
      'created_at': entry.timestamp.toIso8601String(),
      'date': '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}',
    };

    await _offlineQueue.addToQueue(entryData);
    _pendingSyncCount = await _offlineQueue.getQueueCount();
    notifyListeners(); // Update UI with new pending count
  }

  /// NEW: Sync offline queue when network is restored
  Future<void> _syncOfflineQueue() async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null || !_isOnline) return;

    final queue = await _offlineQueue.getQueue();
    if (queue.isEmpty) {
      debugPrint('📦 Offline queue is empty, nothing to sync');
      return;
    }

    debugPrint('📦 Syncing offline queue: ${queue.length} pending entries');

    int successCount = 0;
    int failCount = 0;

    for (final entryData in queue) {
      try {
        await _supabaseService.saveNutritionEntry(
          userId: userId,
          foodName: entryData['food_name'],
          calories: entryData['calories'],
          protein: (entryData['protein'] ?? 0).toDouble(),
          carbs: (entryData['carbs'] ?? 0).toDouble(),
          fat: (entryData['fat'] ?? 0).toDouble(),
          timestamp: DateTime.parse(entryData['created_at']),
        );

        await _offlineQueue.removeFromQueue(entryData);
        successCount++;
        debugPrint('✅ Synced offline entry: ${entryData['food_name']}');
      } catch (e) {
        await _offlineQueue.incrementRetryCount(entryData);
        failCount++;
        debugPrint('❌ Failed to sync offline entry: ${entryData['food_name']} - $e');
      }
    }

    _pendingSyncCount = await _offlineQueue.getQueueCount();
    debugPrint('📦 Offline queue sync complete: $successCount succeeded, $failCount failed');

    if (successCount > 0) {
      // Trigger database sync to update metrics after syncing offline entries
      await _triggerDatabaseSync();
    }

    notifyListeners();
  }

  Future<void> removeNutritionEntry(String entryId) async {
    _setLoading(true);
    _setError(null);

    try {
      // Remove from local state
      _entries.removeWhere((entry) => entry.id == entryId);
      await _saveNutritionData();

      // CRITICAL FIX: Delete from Supabase database
      final userId = _supabaseService.currentUser?.id;
      if (userId != null && _isOnline) {
        debugPrint('NutritionProvider: Deleting entry from Supabase database');
        await _supabaseService.deleteNutritionEntry(entryId);

        debugPrint('NutritionProvider: Entry deleted, syncing to update metrics');

        // Trigger database-level sync to update health_metrics and streaks
        // This will recalculate totals after deletion via the DELETE trigger
        await _triggerDatabaseSync();
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing nutrition entry: $e');
      _setError('Failed to remove nutrition entry');
      _setLoading(false);
    }
  }

  Future<NutritionEntry?> scanFoodWithDescription(String imagePath, String mealDescription) async {
    _setLoading(true);
    _setError(null);

    try {
      final imageFile = File(imagePath);
      debugPrint('\n🍴 ===========================================');
      debugPrint('🍴 NUTRITION SCAN STARTED (Description Mode)');
      debugPrint('🍴 Description: $mealDescription');
      debugPrint('🍴 Image exists: ${imageFile.existsSync()}');
      debugPrint('🍴 ===========================================');

      // Call new description-based analysis
      debugPrint('📱 Calling Indian Food Service with description...');
      final result = await _indianFoodService.analyzeWithDescription(
        imageFile,
        mealDescription,
      );

      debugPrint('📱 Indian Food Service Result:');
      debugPrint('   Success: ${result['success']}');
      debugPrint('   Nutrition: ${result['nutrition']}');
      debugPrint('   Foods: ${result['foods']}');

      if (result['success'] == true && result['nutrition'] != null) {
        final nutrition = result['nutrition'];
        final foodName = result['foods']?.join(', ') ?? 'Mixed meal';

        // Extract metadata from result
        final metadata = {
          'source': result['source'] ?? 'Unknown',
          'isEstimated': result['isEstimated'] ?? false,
          'confidence': result['confidence'] ?? 0.5,
          'modelUsed': result['modelUsed'] ?? 'none',
          'reason': result['reason'],
          'error': result['error'],
        };

        // Create nutrition entry from result with metadata
        final entry = NutritionEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          foodName: foodName,
          quantity: mealDescription.length > 200 ? mealDescription.substring(0, 197) + '...' : mealDescription,
          calories: nutrition['calories'] ?? 0,
          protein: (nutrition['protein'] ?? 0).toDouble(),
          carbs: (nutrition['carbs'] ?? 0).toDouble(),
          fat: (nutrition['fat'] ?? 0).toDouble(),
          timestamp: DateTime.now(),
          metadata: metadata, // Include metadata
        );

        debugPrint('✅ Created nutrition entry:');
        debugPrint('   Food: ${entry.foodName}');
        debugPrint('   Description: ${entry.quantity}');
        debugPrint('   Calories: ${entry.calories}');
        debugPrint('   Protein: ${entry.protein}g');
        debugPrint('   Source: ${metadata['source']}');
        debugPrint('   Estimated: ${metadata['isEstimated']}');
        debugPrint('   Confidence: ${metadata['confidence']}');

        _setLoading(false);
        return entry;
      } else {
        throw Exception('Failed to analyze meal');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      _setError('Failed to analyze meal: ${e.toString()}');
      _setLoading(false);
      return null;
    }
  }

  Future<NutritionEntry?> scanFoodWithDetails(String imagePath, String foodName, String quantity) async {
    _setLoading(true);
    _setError(null);

    try {
      // First try Indian food recognition with user input for better accuracy
      final imageFile = File(imagePath);
      debugPrint('\n🍴 ===========================================');
      debugPrint('🍴 NUTRITION SCAN STARTED');
      debugPrint('🍴 Food: $foodName');
      debugPrint('🍴 Quantity: $quantity');
      debugPrint('🍴 Image exists: ${imageFile.existsSync()}');
      debugPrint('🍴 ===========================================');

      // Try Indian food service with user-provided details
      debugPrint('📱 Calling Indian Food Service...');
      final indianResult = await _indianFoodService.analyzeIndianFoodWithDetails(
        imageFile,
        foodName,
        quantity,
      );

      debugPrint('📱 Indian Food Service Result:');
      debugPrint('   Success: ${indianResult['success']}');
      debugPrint('   Nutrition: ${indianResult['nutrition']}');
      debugPrint('   Error: ${indianResult['error'] ?? 'None'}');

      if (indianResult['success'] == true && indianResult['nutrition'] != null) {
        final nutrition = indianResult['nutrition'];

        // Create nutrition entry from Indian food result with user-provided name
        final entry = NutritionEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          foodName: '$foodName ($quantity)',
          calories: nutrition['calories'] ?? 0,
          protein: (nutrition['protein'] ?? 0).toDouble(),
          carbs: (nutrition['carbs'] ?? 0).toDouble(),
          fat: (nutrition['fat'] ?? 0).toDouble(),
          timestamp: DateTime.now(),
        );

        debugPrint('✅ Created nutrition entry:');
        debugPrint('   Food: ${entry.foodName}');
        debugPrint('   Calories: ${entry.calories}');
        debugPrint('   Protein: ${entry.protein}g');
        debugPrint('   Carbs: ${entry.carbs}g');
        debugPrint('   Fat: ${entry.fat}g');

        _setLoading(false);
        return entry;
      }
      
      // Fallback to original AI service with user details
      debugPrint('Falling back to Edamam API with user input...');
      final entry = await NutritionAIService.analyzeFoodWithDetails(
        imagePath,
        foodName,
        quantity,
      );
      
      _setLoading(false);
      
      if (entry != null) {
        // Create new entry with updated name to include quantity
        return NutritionEntry(
          id: entry.id,
          foodName: '$foodName ($quantity)',
          calories: entry.calories,
          protein: entry.protein,
          carbs: entry.carbs,
          fat: entry.fat,
          timestamp: entry.timestamp,
        );
      } else {
        _setError('Could not analyze food. Please try again.');
        return null;
      }
    } catch (e) {
      _setError('Failed to analyze food: ${e.toString()}');
      _setLoading(false);
      return null;
    }
  }

  Future<NutritionEntry?> scanFood(String imagePath) async {
    _setLoading(true);
    _setError(null);

    try {
      // First try Indian food recognition for better accuracy
      final imageFile = File(imagePath);
      debugPrint('Analyzing with Indian Food Service first...');
      final indianResult = await _indianFoodService.analyzeIndianFood(imageFile);
      
      if (indianResult['success'] == true && indianResult['nutrition'] != null) {
        final nutrition = indianResult['nutrition'];
        final foods = indianResult['foods'] as List? ?? [];
        
        // Create nutrition entry from Indian food result
        final entry = NutritionEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          foodName: foods.isNotEmpty 
              ? foods.map((f) => f['name']).join(', ')
              : 'Indian Food',
          calories: nutrition['calories'] ?? 0,
          protein: (nutrition['protein'] ?? 0).toDouble(),
          carbs: (nutrition['carbs'] ?? 0).toDouble(),
          fat: (nutrition['fat'] ?? 0).toDouble(),
          timestamp: DateTime.now(),
        );
        
        _setLoading(false);
        return entry;
      }
      
      // Fallback to original AI service (Edamam)
      debugPrint('Falling back to Edamam API...');
      final entry = await NutritionAIService.analyzeFood(imagePath);
      
      _setLoading(false);
      
      if (entry != null) {
        return entry;
      } else {
        _setError('Could not identify food. Please try again or enter manually.');
        return null;
      }
    } catch (e) {
      _setError('Failed to analyze food: ${e.toString()}');
      _setLoading(false);
      return null;
    }
  }
  
  // New method for text-based Indian food search
  Future<NutritionEntry?> searchIndianFood(String query) async {
    try {
      final result = await _indianFoodService.searchIndianFood(query);
      
      if (result['success'] == true && result['nutrition'] != null) {
        final nutrition = result['nutrition'];
        final foods = result['foods'] as List? ?? [];
        
        final entry = NutritionEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          foodName: foods.isNotEmpty 
              ? foods.map((f) => f['name']).join(', ')
              : query,
          calories: nutrition['calories'] ?? 0,
          protein: (nutrition['protein'] ?? 0).toDouble(),
          carbs: (nutrition['carbs'] ?? 0).toDouble(),
          fat: (nutrition['fat'] ?? 0).toDouble(),
          timestamp: DateTime.now(),
        );
        
        return entry;
      }
    } catch (e) {
      debugPrint('Error searching Indian food: $e');
    }
    return null;
  }
  
  // Get list of all Indian foods for autocomplete
  List<String> getIndianFoodSuggestions() {
    return _indianFoodService.getAllIndianFoods();
  }

  List<DailyNutrition> getWeeklyNutrition() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final dayEntries = _entries.where((entry) {
        return entry.timestamp.year == date.year &&
               entry.timestamp.month == date.month &&
               entry.timestamp.day == date.day;
      }).toList();
      
      return DailyNutrition(date: date, entries: dayEntries);
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Load more nutrition history (for pagination)
  Future<void> loadMoreHistory({int days = 30}) async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      _setLoading(true);

      // Load extended history from Supabase
      final history = await _supabaseService.getNutritionHistory(
        userId: userId,
        days: days,
      );

      // Track existing entries to avoid duplicates
      final existingKeys = <String>{};
      for (final entry in _entries) {
        final roundedTimestamp = (entry.timestamp.millisecondsSinceEpoch ~/ 60000) * 60000;
        existingKeys.add('${roundedTimestamp}_${entry.foodName}_${entry.calories}');
      }

      // Add new entries that don't already exist
      for (final entry in history) {
        final timestamp = DateTime.parse(entry['created_at'] ?? entry['date'] ?? DateTime.now().toIso8601String());
        final foodName = entry['food_name'] ?? 'Unknown';
        final calories = entry['calories'] ?? 0;

        // Create composite key
        final roundedTimestamp = (timestamp.millisecondsSinceEpoch ~/ 60000) * 60000;
        final entryKey = '${roundedTimestamp}_${foodName}_$calories';

        // Skip if already exists
        if (!existingKeys.contains(entryKey)) {
          _entries.add(NutritionEntry(
            id: entry['id'] ?? entryKey,
            foodName: foodName,
            calories: calories,
            protein: (entry['protein'] ?? 0).toDouble(),
            carbs: (entry['carbs'] ?? 0).toDouble(),
            fat: (entry['fat'] ?? 0).toDouble(),
            timestamp: timestamp,
          ));
        }
      }

      // Sort entries by timestamp
      _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      debugPrint('Loaded ${_entries.length} total nutrition entries');
      await _saveNutritionData();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading more history: $e');
      _setLoading(false);
    }
  }

  Future<void> clearNutritionData() async {
    try {
      // Clear nutrition data from preferences
      await _prefs.remove('nutrition_entries');
      await _prefs.remove('calorie_goal');
      await _prefs.remove('protein_goal');
      await _prefs.remove('carb_goal');
      await _prefs.remove('fat_goal');
      
      // Reset state to defaults
      _entries.clear();
      _calorieGoal = 2000;
      _proteinGoal = 150.0;
      _carbGoal = 250.0;
      _fatGoal = 67.0;
      _error = null;
      _isLoading = false;
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear nutrition data';
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}