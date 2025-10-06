import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../models/health_metric_model.dart';
import '../services/unified_health_service.dart';
import '../services/realtime_sync_service.dart';
import '../services/supabase_service.dart';
import '../services/calorie_tracking_service.dart';
import '../services/database_sync_service.dart';
import '../models/daily_calorie_total.dart';

/// Data priority levels for health metrics
/// Determines which data source takes precedence when multiple sources provide data
enum DataPriority {
  /// Live data from HealthKit (iOS) or Health Connect (Android) - HIGHEST PRIORITY
  /// This is real-time data from the device's health platform
  liveHealthData,

  /// Cached data from Supabase database - MEDIUM PRIORITY
  /// This is synced data from previous sessions or other devices
  supabaseCache,

  /// Local SharedPreferences data - LOWEST PRIORITY
  /// This is locally stored data, used as last resort fallback
  localStorage,

  /// No data loaded yet - INITIAL STATE
  /// App just started, no data from any source yet
  noData,
}

class HealthProvider with ChangeNotifier {
  Map<MetricType, HealthMetric> _metrics = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  final UnifiedHealthService _healthService = UnifiedHealthService();
  final RealtimeSyncService _syncService = RealtimeSyncService();
  final SupabaseService _supabaseService = SupabaseService();
  final CalorieTrackingService _calorieService = CalorieTrackingService();
  SharedPreferences? _prefs;
  HealthDataSource _currentDataSource = HealthDataSource.unavailable;

  // Data priority tracking - determines which data source to trust
  DataPriority _currentDataPriority = DataPriority.noData;

  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  Timer? _syncTimer;
  Timer? _permissionMonitorTimer;
  DateTime? _lastSyncTime;
  DateTime? _lastPermissionCheck;
  
  // Expose health service for direct access
  UnifiedHealthService get healthService => _healthService;
  
  // Today's data - Initialize with -1 to indicate no data loaded yet
  double _todaySteps = -1;
  double _todayCaloriesBurned = -1;  // Active calories only (exercise + steps)
  double _todayTotalCalories = -1;   // Total daily energy (BMR + Active)
  double _todayHeartRate = -1;
  double _todaySleep = -1;
  double _todayDistance = -1;
  int _todayWater = -1;
  int _todayWorkouts = -1;
  double _todayWeight = -1;
  int _todayBloodOxygen = -1;
  Map<String, int> _todayBloodPressure = {'systolic': 0, 'diastolic': 0};
  int _todayExerciseMinutes = -1;
  
  Map<MetricType, HealthMetric> get metrics => _metrics;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // Check if we've synced recently (within last 5 minutes)
  bool get hasRecentSync {
    if (_lastSyncTime == null) return false;
    final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
    return timeSinceLastSync.inMinutes < 5;
  }

  // Check if currently syncing
  bool get isSyncing => _isLoading;
  
  // Getters for today's data
  // Return 0 instead of -1 for display purposes
  double get todaySteps => _todaySteps > 0 ? _todaySteps : 0;
  double get todayCaloriesBurned => _todayCaloriesBurned > 0 ? _todayCaloriesBurned : 0;
  double get todayTotalCalories => _todayTotalCalories > 0 ? _todayTotalCalories : 0;
  double get todayHeartRate => _todayHeartRate > 0 ? _todayHeartRate : 0;
  double get todaySleep => _todaySleep > 0 ? _todaySleep : 0;
  double get todayDistance => _todayDistance > 0 ? _todayDistance : 0;
  int get todayWater => _todayWater > 0 ? _todayWater : 0;
  int get todayWorkouts => _todayWorkouts > 0 ? _todayWorkouts : 0;
  double get todayWeight => _todayWeight > 0 ? _todayWeight : 0;
  int get todayBloodOxygen => _todayBloodOxygen > 0 ? _todayBloodOxygen : 0;
  Map<String, int> get todayBloodPressure => _todayBloodPressure;
  int get todayExerciseMinutes => _todayExerciseMinutes > 0 ? _todayExerciseMinutes : 0;
  HealthDataSource get dataSource => _currentDataSource;
  Map<String, String> get dataSourceInfo => _healthService.getDataSourceInfo();
  DataPriority get currentDataPriority => _currentDataPriority;
  
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    // Load saved data from SharedPreferences
    await _loadHealthData();

    // Setup connectivity monitoring
    _setupConnectivityMonitoring();

    // Setup background permission monitoring
    _startPermissionMonitoring();

    // Initialize unified health service
    await _healthService.initialize();

    // Initialize calorie tracking service
    await _calorieService.initialize();

    // Set up callback for data updates
    _healthService.setDataUpdateCallback((data) {
      updateMetricsFromHealth(data);
    });

    // Get current data source (prefer saved one over detected)
    if (_currentDataSource == HealthDataSource.unavailable) {
      _currentDataSource = _healthService.currentSource;
    }

    // Only initialize metrics if they haven't been loaded yet (e.g., from Supabase)
    if (_metrics.isEmpty) {
      // Initialize with saved values - will be updated from health service if available
      _metrics = {
        MetricType.steps: HealthMetric(value: _todaySteps, timestamp: DateTime.now(), type: MetricType.steps, currentValue: _todaySteps, goalValue: 10000),
        MetricType.caloriesIntake: HealthMetric(value: _todayCaloriesBurned, timestamp: DateTime.now(), type: MetricType.caloriesIntake, currentValue: _todayCaloriesBurned, goalValue: 2200),
        MetricType.sleep: HealthMetric(value: _todaySleep, timestamp: DateTime.now(), type: MetricType.sleep, currentValue: _todaySleep, goalValue: 8.0),
        MetricType.restingHeartRate: HealthMetric(value: _todayHeartRate, timestamp: DateTime.now(), type: MetricType.restingHeartRate, currentValue: _todayHeartRate, goalValue: 60),
      };
    }
    
    // If we have a saved connection, try to reconnect
    if (_currentDataSource != HealthDataSource.unavailable) {
      await connectToHealthSource(_currentDataSource);
    }
    
    // Fetch initial data if source available
    if (_healthService.isDataSourceAvailable) {
      await fetchMetrics();
    } else if (_currentDataSource == HealthDataSource.unavailable) {
      // Don't auto-request permissions - let user initiate via dialog
      debugPrint('HealthProvider: No health data source available. User can connect via settings.');
    }
    
    // Start automatic sync
    await _healthService.startDataSync();
    
    _isInitialized = true;
    notifyListeners();
  }
  
  Future<void> fetchMetrics() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('HealthProvider: Fetching metrics from health service...');

      // Fetch data from unified health service
      final data = await _healthService.fetchHealthData();
      _currentDataSource = _healthService.currentSource;

      debugPrint('HealthProvider: Fetched data - Steps: ${data['steps']}, Source: $_currentDataSource');

      updateMetricsFromHealth(data);

      debugPrint('HealthProvider: Accurate calorie calculation complete');
      debugPrint('  - Active calories: $_todayCaloriesBurned kcal (steps + exercise)');
      debugPrint('  - Total daily energy: $_todayTotalCalories kcal (BMR + active)');

      _lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('Error fetching metrics: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
  
  void updateMetricsFromHealth(Map<String, dynamic> data) {
    // 🔥 DATA PRIORITY ENFORCEMENT
    // Live health data from HealthKit/Health Connect should ALWAYS take priority
    // over cached Supabase data, even if values are 0 (could be early morning, no activity yet)
    debugPrint('📊 [DataPriority] Updating metrics from live health source');
    debugPrint('📊 [DataPriority] Current priority: $_currentDataPriority');
    debugPrint('📊 [DataPriority] New priority: ${DataPriority.liveHealthData}');

    // Check if we have Samsung Health data source info
    final stepsBySource = data['stepsBySource'] as Map<String, dynamic>?;
    final dataSource = stepsBySource?['dataSource'] ?? 'Unknown';
    debugPrint('Samsung Health Integration: Data from $dataSource');

    // Check if data is valid (not all zeros which indicates no real data)
    bool hasValidData = (data['steps'] ?? 0) > 0 ||
                       (data['calories'] ?? 0) > 0 ||
                       (data['heartRate'] ?? 0) > 0 ||
                       (data['sleep'] ?? 0) > 0 ||
                       (data['water'] ?? 0) > 0 ||
                       (data['workouts'] ?? 0) > 0;
    
    // Log Samsung Health prioritization for key metrics
    if (stepsBySource != null) {
      debugPrint('Samsung Health Steps: ${stepsBySource['samsung']} (priority)');
      debugPrint('Google Fit Steps: ${stepsBySource['googleFit']} (fallback)');
      debugPrint('Using: ${stepsBySource['dataSource']}');
    }
    
    // 🔥 CRITICAL CHANGE FOR iOS FIX:
    // Always update with live health data, even if values are 0
    // Zero could be legitimate (early morning, no activity yet)
    // This fixes the issue where Supabase cached data overrides real HealthKit/Health Connect data

    // Set data priority to liveHealthData (highest priority)
    _currentDataPriority = DataPriority.liveHealthData;
    debugPrint('📊 [DataPriority] Priority elevated to: $_currentDataPriority');

    // Only update if we have valid data, otherwise keep existing values
    if (hasValidData) {
      debugPrint('📊 [DataPriority] Updating with VALID live health data');
      // Update today's data with accurate calorie calculation
      _todaySteps = (data['steps'] != null && data['steps'] > 0) ? data['steps'].toDouble() : _todaySteps;

      // Use the accurate active calories (steps + exercise) - NEW field from Android
      _todayCaloriesBurned = (data['activeCalories'] != null && data['activeCalories'] > 0)
        ? data['activeCalories'].toDouble()
        : ((data['calories'] != null && data['calories'] > 0) ? data['calories'].toDouble() : _todayCaloriesBurned);

      // Use the accurate total calories (BMR + active) from our calculation
      _todayTotalCalories = (data['totalCalories'] != null && data['totalCalories'] > 0)
        ? data['totalCalories'].toDouble()
        : _todayTotalCalories;
      _todayHeartRate = (data['heartRate'] != null && data['heartRate'] > 0) ? data['heartRate'].toDouble() : _todayHeartRate;
      _todaySleep = (data['sleep'] != null && data['sleep'] > 0) ? data['sleep'].toDouble() : _todaySleep;
      _todayDistance = (data['distance'] != null && data['distance'] > 0) ? data['distance'].toDouble() : _todayDistance;
      _todayWater = (data['water'] != null && data['water'] > 0) ? data['water'] : _todayWater;
      _todayWorkouts = (data['workouts'] != null && data['workouts'] > 0) ? data['workouts'] : _todayWorkouts;
      
      // New Samsung Health metrics
      _todayWeight = (data['weight'] != null && data['weight'] > 0) ? data['weight'].toDouble() : _todayWeight;
      _todayBloodOxygen = (data['bloodOxygen'] != null && data['bloodOxygen'] > 0) ? data['bloodOxygen'] : _todayBloodOxygen;
      _todayExerciseMinutes = (data['exerciseMinutes'] != null && data['exerciseMinutes'] > 0) ? data['exerciseMinutes'] : _todayExerciseMinutes;
      
      // Blood pressure handling
      if (data['bloodPressure'] is Map) {
        final bp = data['bloodPressure'] as Map<String, dynamic>;
        _todayBloodPressure = {
          'systolic': (bp['systolic'] != null && bp['systolic'] > 0) ? bp['systolic'] : _todayBloodPressure['systolic']!,
          'diastolic': (bp['diastolic'] != null && bp['diastolic'] > 0) ? bp['diastolic'] : _todayBloodPressure['diastolic']!,
        };
      }
      
      // Log the accurate calorie breakdown if available
      final exerciseCalories = data['exerciseCalories'] as int? ?? 0;
      final stepCalories = data['stepCalories'] as int? ?? 0;
      final bmrCalories = data['bmrCalories'] as int? ?? 0;

      debugPrint('Metrics Updated:');
      debugPrint('  Steps: $_todaySteps (from $dataSource)');
      debugPrint('  Heart Rate: $_todayHeartRate bpm');
      debugPrint('  === ACCURATE CALORIE BREAKDOWN ===');
      debugPrint('  Step Calories: $stepCalories kcal');
      debugPrint('  Exercise Calories: $exerciseCalories kcal');
      debugPrint('  Active Total: $_todayCaloriesBurned kcal');
      debugPrint('  BMR So Far: $bmrCalories kcal');
      debugPrint('  TOTAL DAILY: $_todayTotalCalories kcal');
      debugPrint('  ===================================');
      debugPrint('  Sleep: $_todaySleep hours');
      debugPrint('  Distance: $_todayDistance km');
      debugPrint('  Water: $_todayWater ml');
      debugPrint('  Weight: $_todayWeight kg');
      debugPrint('  Blood Oxygen: $_todayBloodOxygen%');
      debugPrint('  Blood Pressure: ${_todayBloodPressure['systolic']}/${_todayBloodPressure['diastolic']}');
      debugPrint('  Workouts: $_todayWorkouts ($_todayExerciseMinutes min)');
    } else {
      // No valid data from health source, keep existing values
      debugPrint('No valid health data received, keeping existing values');
      debugPrint('Current values - Steps: $_todaySteps, Calories: $_todayCaloriesBurned, HR: $_todayHeartRate, Sleep: $_todaySleep');
    }
    
    // Update metrics
    _metrics[MetricType.steps] = HealthMetric(
      value: _todaySteps,
      timestamp: DateTime.now(),
      type: MetricType.steps,
      currentValue: _todaySteps,
      goalValue: 10000,
    );
    
    _metrics[MetricType.caloriesIntake] = HealthMetric(
      value: _todayCaloriesBurned,
      timestamp: DateTime.now(),
      type: MetricType.caloriesIntake,
      currentValue: _todayCaloriesBurned,
      goalValue: 2200,
    );
    
    _metrics[MetricType.sleep] = HealthMetric(
      value: _todaySleep,
      timestamp: DateTime.now(),
      type: MetricType.sleep,
      currentValue: _todaySleep,
      goalValue: 8.0,
    );
    
    _metrics[MetricType.restingHeartRate] = HealthMetric(
      value: _todayHeartRate,
      timestamp: DateTime.now(),
      type: MetricType.restingHeartRate,
      currentValue: _todayHeartRate,
      goalValue: 60,
    );
    
    // Save to SharedPreferences and sync to Supabase
    _saveHealthData();
    
    // Automatically sync with Supabase
    saveHealthDataToSupabase();
    
    notifyListeners();
  }
  
  // Method to manually sync data
  Future<void> connectToHealthSource(HealthDataSource source) async {
    _currentDataSource = source;
    
    // Save the connection state
    if (_prefs != null) {
      String sourceString = '';
      switch (source) {
        case HealthDataSource.healthConnect:
          sourceString = 'healthConnect';
          break;
        case HealthDataSource.healthKit:
          sourceString = 'healthKit';
          break;
        default:
          sourceString = '';
      }
      if (sourceString.isNotEmpty) {
        await _prefs!.setString('connected_health_source', sourceString);
      }
    }
    
    notifyListeners();
  }
  
  Future<void> syncWithHealth() async {
    debugPrint('HealthProvider: Starting health sync...');

    // Ensure we're connected before syncing
    if (!_healthService.isDataSourceAvailable) {
      debugPrint('HealthProvider: Data source not available, cannot sync');
      return;
    }

    await _healthService.syncNow();
    await fetchMetrics();
    _lastSyncTime = DateTime.now();

    debugPrint('HealthProvider: Health sync complete - Steps: $_todaySteps');
  }
  
  // Check if health source is connected
  bool get isHealthSourceConnected => _healthService.isDataSourceAvailable;
  String? get connectedDevice {
    return _healthService.getDataSourceInfo()['source'];
  }
  
  // Request health permissions
  Future<bool> requestHealthPermissions() async {
    final result = await _healthService.requestHealthPermissions();
    if (result.success) {
      _currentDataSource = _healthService.currentSource;
      await fetchMetrics();
    }
    return result.success;
  }

  // Initialize health service connection (for UI calls)
  Future<bool> initializeHealth() async {
    try {
      // Initialize the health service
      await _healthService.initialize();
      
      // Update current data source
      _currentDataSource = _healthService.currentSource;
      
      // If source is available, fetch initial data
      if (_healthService.isDataSourceAvailable) {
        await fetchMetrics();
        return true;
      } else {
        // Don't auto-request - return false to let UI handle permission request
        debugPrint('HealthProvider: No health source available, user needs to connect manually');
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('HealthProvider: Error initializing health service: $e');
      return false;
    }
  }
  
  // Load health data from SharedPreferences
  Future<void> _loadHealthData() async {
    if (_prefs == null) return;

    debugPrint('📊 [DataPriority] Loading from SharedPreferences (localStorage)');

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    // Load today's data with 0 as fallback (no more hardcoded demo values)
    _todaySteps = _prefs!.getDouble('steps_$todayKey') ?? 0.0;
    _todayCaloriesBurned = _prefs!.getDouble('calories_burned_$todayKey') ?? 0.0;
    _todayHeartRate = _prefs!.getDouble('heart_rate_$todayKey') ?? 0.0;
    _todaySleep = _prefs!.getDouble('sleep_$todayKey') ?? 0.0;
    _todayDistance = _prefs!.getDouble('distance_$todayKey') ?? 0.0;
    _todayWater = _prefs!.getInt('water_$todayKey') ?? 0;
    _todayWorkouts = _prefs!.getInt('workouts_$todayKey') ?? 0;
    _todayWeight = _prefs!.getDouble('weight_$todayKey') ?? 0.0;
    _todayBloodOxygen = _prefs!.getInt('blood_oxygen_$todayKey') ?? 0;
    _todayExerciseMinutes = _prefs!.getInt('exercise_minutes_$todayKey') ?? 0;
    _todayBloodPressure = {
      'systolic': _prefs!.getInt('bp_systolic_$todayKey') ?? 120,
      'diastolic': _prefs!.getInt('bp_diastolic_$todayKey') ?? 80,
    };
    
    // Check for saved health source connection
    final connectedSource = _prefs!.getString('connected_health_source');
    if (connectedSource != null) {
      // Restore the connection state
      if (connectedSource == 'healthConnect') {
        _currentDataSource = HealthDataSource.healthConnect;
      } else if (connectedSource == 'healthKit') {
        _currentDataSource = HealthDataSource.healthKit;
      }
      debugPrint('Restored health source connection: $connectedSource');
    }

    // Set priority to localStorage (lowest)
    if (_currentDataPriority == DataPriority.noData) {
      _currentDataPriority = DataPriority.localStorage;
      debugPrint('📊 [DataPriority] Priority set to: $_currentDataPriority');
    }
  }
  
  // Save health data to SharedPreferences and sync to Supabase
  Future<void> _saveHealthData() async {
    if (_prefs == null) return;
    
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    // Save to SharedPreferences - All Samsung Health metrics
    await _prefs!.setDouble('steps_$todayKey', _todaySteps);
    await _prefs!.setDouble('calories_burned_$todayKey', _todayCaloriesBurned);
    await _prefs!.setDouble('heart_rate_$todayKey', _todayHeartRate);
    await _prefs!.setDouble('sleep_$todayKey', _todaySleep);
    await _prefs!.setDouble('distance_$todayKey', _todayDistance);
    await _prefs!.setInt('water_$todayKey', _todayWater);
    await _prefs!.setInt('workouts_$todayKey', _todayWorkouts);
    await _prefs!.setDouble('weight_$todayKey', _todayWeight);
    await _prefs!.setInt('blood_oxygen_$todayKey', _todayBloodOxygen);
    await _prefs!.setInt('exercise_minutes_$todayKey', _todayExerciseMinutes);
    await _prefs!.setInt('bp_systolic_$todayKey', _todayBloodPressure['systolic']!);
    await _prefs!.setInt('bp_diastolic_$todayKey', _todayBloodPressure['diastolic']!);
    
    // Also save for RealtimeSyncService to pick up
    await _prefs!.setInt('today_steps', _todaySteps.toInt());
    await _prefs!.setInt('today_heart_rate', _todayHeartRate.toInt());
    await _prefs!.setDouble('today_sleep', _todaySleep);
    await _prefs!.setInt('today_calories_burned', _todayCaloriesBurned.toInt());
    await _prefs!.setDouble('today_distance', _todayDistance);
    await _prefs!.setInt('today_water', _todayWater);
    await _prefs!.setDouble('today_weight', _todayWeight);
    await _prefs!.setInt('today_blood_oxygen', _todayBloodOxygen);
    await _prefs!.setInt('today_exercise_minutes', _todayExerciseMinutes);
    
    // Save to Supabase directly
    await saveHealthDataToSupabase();
    
    // Trigger immediate sync to Supabase
    await _syncService.syncAll();
  }
  
  // Method to update water intake
  Future<void> updateWaterIntake(int glasses) async {
    _todayWater = glasses;
    await _saveHealthData();
    notifyListeners();
  }
  
  // Method to log a workout
  Future<void> logWorkout() async {
    _todayWorkouts++;
    await _saveHealthData();
    notifyListeners();
  }
  
  // Update health connection status
  Future<void> updateHealthConnectionStatus(bool connected) async {
    if (connected) {
      _currentDataSource = _healthService.currentSource;
      await fetchMetrics();
    } else {
      _currentDataSource = HealthDataSource.unavailable;
    }
    notifyListeners();
  }

  // Load health data from Supabase
  Future<void> loadHealthDataFromSupabase() async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) {
      // If not logged in, just load from local storage
      await _loadHealthData();
      return;
    }

    // 🔥 DATA PRIORITY CHECK - CRITICAL FOR iOS FIX
    // Do NOT overwrite live health data with Supabase cache
    if (_currentDataPriority == DataPriority.liveHealthData) {
      debugPrint('📊 [DataPriority] BLOCKING Supabase load - already have live health data');
      debugPrint('📊 [DataPriority] Current priority: $_currentDataPriority (higher than Supabase cache)');
      debugPrint('📊 [DataPriority] Live data takes precedence - keeping current values');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('📊 [DataPriority] Loading data from Supabase (priority: ${DataPriority.supabaseCache})');
      debugPrint('📊 [DataPriority] Current priority: $_currentDataPriority');

      // Get today's date
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Load today's health metrics from Supabase
      final healthData = await _supabaseService.getHealthMetrics(
        userId: userId,
        date: todayStr,
      );

      if (healthData != null) {
        debugPrint('📊 [DataPriority] Supabase data found for $todayStr');
        debugPrint('📊 [DataPriority] Supabase Steps: ${healthData['steps']}');
        debugPrint('📊 [DataPriority] Supabase HR: ${healthData['heart_rate']}');
        debugPrint('📊 [DataPriority] Supabase Sleep: ${healthData['sleep_hours']}');

        // Update local data with Supabase data
        _todaySteps = (healthData['steps'] ?? 0).toDouble();
        _todayCaloriesBurned = (healthData['calories_burned'] ?? 0).toDouble();
        _todayHeartRate = (healthData['heart_rate'] ?? 0).toDouble();
        _todaySleep = (healthData['sleep_hours'] ?? 0).toDouble();
        _todayDistance = (healthData['distance'] ?? 0).toDouble();

        // Set priority to Supabase cache
        _currentDataPriority = DataPriority.supabaseCache;
        debugPrint('📊 [DataPriority] Priority set to: $_currentDataPriority');
        
        // Update metrics
        _metrics[MetricType.steps] = HealthMetric(
          value: _todaySteps,
          timestamp: DateTime.now(),
          type: MetricType.steps,
          currentValue: _todaySteps,
          goalValue: 10000,
        );
        
        _metrics[MetricType.caloriesIntake] = HealthMetric(
          value: _todayCaloriesBurned,
          timestamp: DateTime.now(),
          type: MetricType.caloriesIntake,
          currentValue: _todayCaloriesBurned,
          goalValue: 2200,
        );
        
        _metrics[MetricType.sleep] = HealthMetric(
          value: _todaySleep,
          timestamp: DateTime.now(),
          type: MetricType.sleep,
          currentValue: _todaySleep,
          goalValue: 8.0,
        );
        
        _metrics[MetricType.restingHeartRate] = HealthMetric(
          value: _todayHeartRate,
          timestamp: DateTime.now(),
          type: MetricType.restingHeartRate,
          currentValue: _todayHeartRate,
          goalValue: 60,
        );
        
        // Save to local storage
        await _saveHealthData();
      } else {
        // No data in Supabase for today yet
        // Load default values if we haven't loaded anything yet (values are -1)
        if (_todaySteps < 0) {
          debugPrint('No Supabase data for today, initializing with zeros');
          // Initialize with zeros for today (not demo data)
          _todaySteps = 0;
          _todayCaloriesBurned = 0;
          _todayHeartRate = 0;
          _todaySleep = 0;
          _todayDistance = 0;
          _todayWater = 0;
          _todayWorkouts = 0;
          _todayWeight = 0;
          _todayBloodOxygen = 0;
          _todayExerciseMinutes = 0;
          _todayBloodPressure = {'systolic': 0, 'diastolic': 0};
        } else {
          debugPrint('No Supabase data for today yet, keeping current synced values');
          debugPrint('Current values - Steps: $_todaySteps, Calories: $_todayCaloriesBurned');
        }
      }
    } catch (e) {
      debugPrint('Error loading health data from Supabase: $e');
      // Fallback to local data
      await _loadHealthData();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Save health data to Supabase
  Future<void> saveHealthDataToSupabase() async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) return;

    // Check if online
    if (!_isOnline) {
      debugPrint('Offline - data will sync when connection restored');
      return;
    }

    // CRITICAL: Don't save uninitialized or zero data to Supabase
    // Check if we have real data (not initial -1 values or all zeros)
    bool hasRealData = _todaySteps > 0 ||
                      _todayCaloriesBurned > 0 ||
                      _todayHeartRate > 0 ||
                      _todaySleep > 0 ||
                      _todayDistance > 0;

    if (!hasRealData) {
      debugPrint('⚠️ Skipping Supabase save - no valid health data to save');
      debugPrint('Current values - Steps: $_todaySteps, Calories: $_todayCaloriesBurned, HR: $_todayHeartRate');
      return;
    }

    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      debugPrint('📤 Saving to Supabase - Steps: $_todaySteps, Calories: $_todayCaloriesBurned, HR: $_todayHeartRate');

      await _supabaseService.saveHealthMetrics(
        userId: userId,
        date: todayStr,
        metrics: {
          'steps': _todaySteps > 0 ? _todaySteps.toInt() : 0,
          'heart_rate': _todayHeartRate > 0 ? _todayHeartRate.toInt() : 0,
          'sleep_hours': _todaySleep > 0 ? _todaySleep : 0,
          'calories_burned': _todayCaloriesBurned > 0 ? _todayCaloriesBurned.toInt() : 0,
          'distance': _todayDistance > 0 ? _todayDistance : 0,
          'active_minutes': _todayWorkouts > 0 ? _todayWorkouts * 30 : 0, // Approximate
        },
      );

      debugPrint('✅ Health data synced to Supabase successfully');

      // NEW: Trigger database sync to recalculate goals and streaks
      try {
        final dbSync = DatabaseSyncService();
        await dbSync.syncToday();
        debugPrint('✅ Database sync triggered after health save');
      } catch (e) {
        debugPrint('⚠️ Database sync failed (non-critical): $e');
      }
    } catch (e) {
      debugPrint('❌ Error saving health data to Supabase: $e');
    }
  }
  
  // Setup connectivity monitoring
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOffline = !_isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      
      if (wasOffline && _isOnline) {
        debugPrint('Connection restored - syncing data with Supabase');
        // Sync data when coming back online
        saveHealthDataToSupabase();
        loadHealthDataFromSupabase();
      }
    });
    
    // Check initial connectivity
    _connectivity.checkConnectivity().then((results) {
      _isOnline = !results.contains(ConnectivityResult.none);
    });
  }
  
  // Sync health data on app open - called when user opens the app
  Future<void> syncOnAppOpen() async {
    if (_isOnline && _isInitialized) {
      debugPrint('Syncing health data on app open...');
      await syncWithHealth();
      // Only save if we have real data after sync
      if (_todaySteps > 0 || _todayCaloriesBurned > 0 || _todayHeartRate > 0) {
        await saveHealthDataToSupabase();
        debugPrint('Health data sync completed on app open');
      } else {
        debugPrint('No real health data to save after sync');
      }
    } else {
      debugPrint('Skipping sync: online=$_isOnline, initialized=$_isInitialized');
    }
  }
  
  // Ensure data is synced when app is paused
  Future<void> syncOnPause() async {
    if (_isOnline) {
      await saveHealthDataToSupabase();
    }
  }

  // Start background permission monitoring
  void _startPermissionMonitoring() {
    debugPrint('Starting background permission monitoring...');

    // Cancel existing timer if any
    _permissionMonitorTimer?.cancel();

    // Check for permissions every 30 seconds
    _permissionMonitorTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      // Throttle permission checks to avoid excessive checking
      if (_lastPermissionCheck != null) {
        final timeSinceLastCheck = DateTime.now().difference(_lastPermissionCheck!);
        if (timeSinceLastCheck.inSeconds < 25) {
          return; // Skip if checked too recently
        }
      }

      // Only check if not already connected
      if (!_healthService.isDataSourceAvailable) {
        debugPrint('Background permission check: Checking for newly granted permissions...');
        _lastPermissionCheck = DateTime.now();

        final autoConnected = await _healthService.checkAndAutoConnect();
        if (autoConnected) {
          debugPrint('✅ Background check: Auto-connected to health source!');
          _currentDataSource = _healthService.currentSource;

          // Sync data immediately after auto-connect
          await syncWithHealth();

          // Notify listeners about the connection
          notifyListeners();
        }
      }
    });
  }

  // Stop background permission monitoring
  void _stopPermissionMonitoring() {
    debugPrint('Stopping background permission monitoring');
    _permissionMonitorTimer?.cancel();
    _permissionMonitorTimer = null;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _permissionMonitorTimer?.cancel();
    super.dispose();
  }
}