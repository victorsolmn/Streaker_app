import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../models/health_metric_model.dart';
import 'native_health_connect_service.dart';

enum HealthDataSource {
  healthKit,        // iOS - Apple Health
  healthConnect,    // Android - Health Connect / Samsung Health
  unavailable       // No source available
}

enum HealthConnectionError {
  none,
  healthConnectNotInstalled,
  healthConnectNeedsUpdate,
  permissionsDenied,
  configurationFailed,
  dataFetchFailed,
  unknown
}

class HealthConnectionResult {
  final bool success;
  final HealthConnectionError error;
  final String? errorMessage;
  final String? debugInfo;
  
  HealthConnectionResult({
    required this.success,
    this.error = HealthConnectionError.none,
    this.errorMessage,
    this.debugInfo,
  });
}

class UnifiedHealthService {
  static final UnifiedHealthService _instance = UnifiedHealthService._internal();
  factory UnifiedHealthService() => _instance;
  UnifiedHealthService._internal();

  // Health package instance (works for both HealthKit and Health Connect)
  final Health _health = Health();

  // Native health connect service for Android
  final NativeHealthConnectService _nativeHealthConnectService = NativeHealthConnectService();

  // Current data source
  HealthDataSource _currentSource = HealthDataSource.unavailable;
  HealthDataSource get currentSource => _currentSource;
  
  // Track initialization
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // Data update callback
  Function(Map<String, dynamic>)? _onDataUpdate;
  
  // Sync timer
  Timer? _syncTimer;
  
  // Debug logs
  final List<String> _debugLogs = [];
  List<String> get debugLogs => _debugLogs;
  
  // Health data types we want to read - using only basic types for better compatibility
  final List<HealthDataType> _healthTypes = Platform.isAndroid ? [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WATER,
    HealthDataType.WEIGHT,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WORKOUT,
  ] : [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,  // Added for iOS to get resting heart rate
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,  // Added for iOS to get complete sleep data
    HealthDataType.SLEEP_IN_BED,  // Added for iOS to get complete sleep data
    HealthDataType.WATER,
    HealthDataType.WEIGHT,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WORKOUT,
  ];
  
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    debugPrint('HealthService: $message');
    _debugLogs.add(logMessage);
    if (_debugLogs.length > 100) {
      _debugLogs.removeAt(0);
    }
  }
  
  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) {
      _log('Already initialized');
      return;
    }

    _log('Starting initialization...');

    try {

      // Configure health services based on platform
      if (Platform.isAndroid) {
        _log('Android detected - configuring Health Connect...');
        try {
          await _health.configure();
          _log('Health Connect configured successfully');
        } catch (e) {
          _log('ERROR: Health Connect configuration failed: $e');
        }
      } else if (Platform.isIOS) {
        _log('iOS detected - HealthKit ready');
      }


      _isInitialized = true;
      _log('Initialization complete');

      // Determine best available data source
      await _determineBestDataSource();
    } catch (e) {
      _log('ERROR: Initialization failed: $e');
      _isInitialized = false;
    }
  }
  
  // Determine the best available data source
  Future<void> _determineBestDataSource() async {
    _log('Determining best data source...');
    
    // Try platform-specific health APIs first
    if (Platform.isIOS) {
      bool available = await _checkHealthKitAvailability();
      if (available) {
        _currentSource = HealthDataSource.healthKit;
        _log('Using HealthKit as data source');
        return;
      }
    } else if (Platform.isAndroid) {
      bool available = await _checkHealthConnectAvailability();
      if (available) {
        _currentSource = HealthDataSource.healthConnect;
        _log('Using Health Connect as data source');
        return;
      }
    }
    
    
    // No source available yet
    _currentSource = HealthDataSource.unavailable;
    _log('No data source available');
  }
  
  // Check HealthKit availability (iOS)
  Future<bool> _checkHealthKitAvailability() async {
    try {
      _log('Checking HealthKit availability...');

      // Create permissions array matching health types length
      final permissions = List<HealthDataAccess>.filled(
        _healthTypes.length,
        HealthDataAccess.READ,
      );

      // Check if we have permissions
      bool? hasPermissions = await _health.hasPermissions(
        _healthTypes,
        permissions: permissions,
      );

      _log('HealthKit permissions status: $hasPermissions');

      return hasPermissions == true;
    } catch (e) {
      _log('ERROR: HealthKit check failed: $e');
      return false;
    }
  }

  /// iOS-specific diagnostic method to identify HealthKit data sync issues
  /// Returns detailed report of HealthKit status and data availability
  Future<Map<String, dynamic>> runIOSHealthKitDiagnostics() async {
    if (!Platform.isIOS) {
      return {
        'error': 'This diagnostic is only for iOS',
        'platform': Platform.operatingSystem,
      };
    }

    Map<String, dynamic> diagnosticReport = {
      'timestamp': DateTime.now().toIso8601String(),
      'platform': 'iOS',
      'permissions': {},
      'dataAvailability': {},
      'sampleData': {},
      'errors': [],
    };

    try {
      // 1. Check overall HealthKit availability
      _log('🔍 iOS DIAGNOSTIC: Starting HealthKit diagnostics...');

      final permissions = List<HealthDataAccess>.filled(
        _healthTypes.length,
        HealthDataAccess.READ,
      );

      bool? hasPermissions = await _health.hasPermissions(
        _healthTypes,
        permissions: permissions,
      );

      diagnosticReport['permissions']['overall'] = hasPermissions ?? false;
      _log('📋 Overall permissions: ${hasPermissions ?? false}');

      // 2. Check individual permission status for each health type
      for (var healthType in _healthTypes) {
        try {
          bool? typePermission = await _health.hasPermissions(
            [healthType],
            permissions: [HealthDataAccess.READ],
          );
          diagnosticReport['permissions'][healthType.name] = typePermission ?? false;
          _log('  ${healthType.name}: ${typePermission ?? false}');
        } catch (e) {
          diagnosticReport['errors'].add('Permission check failed for ${healthType.name}: $e');
        }
      }

      // 3. Test actual data fetching for today
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      _log('📊 Testing data fetching for today (${startOfDay.toString()})...');

      // Test Steps
      try {
        List<HealthDataPoint> stepsData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: startOfDay,
          endTime: now,
        );
        diagnosticReport['dataAvailability']['STEPS'] = stepsData.length;
        if (stepsData.isNotEmpty) {
          int totalSteps = 0;
          for (var point in stepsData) {
            if (point.value is NumericHealthValue) {
              totalSteps += (point.value as NumericHealthValue).numericValue.toInt();
            }
          }
          diagnosticReport['sampleData']['STEPS'] = totalSteps;
          _log('  Steps: $totalSteps (${stepsData.length} data points)');
        } else {
          _log('  ⚠️ Steps: No data available');
        }
      } catch (e) {
        diagnosticReport['errors'].add('Steps fetch failed: $e');
        _log('  ❌ Steps fetch error: $e');
      }

      // Test Active Calories
      try {
        List<HealthDataPoint> caloriesData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: startOfDay,
          endTime: now,
        );
        diagnosticReport['dataAvailability']['ACTIVE_ENERGY_BURNED'] = caloriesData.length;
        if (caloriesData.isNotEmpty) {
          double totalCalories = 0;
          for (var point in caloriesData) {
            if (point.value is NumericHealthValue) {
              totalCalories += (point.value as NumericHealthValue).numericValue;
            }
          }
          diagnosticReport['sampleData']['ACTIVE_ENERGY_BURNED'] = totalCalories.toStringAsFixed(1);
          _log('  Calories: ${totalCalories.toStringAsFixed(1)} (${caloriesData.length} data points)');
        } else {
          _log('  ⚠️ Calories: No data available');
        }
      } catch (e) {
        diagnosticReport['errors'].add('Calories fetch failed: $e');
        _log('  ❌ Calories fetch error: $e');
      }

      // Test Heart Rate
      try {
        List<HealthDataPoint> heartRateData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE, HealthDataType.RESTING_HEART_RATE],
          startTime: startOfDay,
          endTime: now,
        );
        diagnosticReport['dataAvailability']['HEART_RATE'] = heartRateData.length;
        if (heartRateData.isNotEmpty) {
          var latestHR = heartRateData.last;
          if (latestHR.value is NumericHealthValue) {
            int hr = (latestHR.value as NumericHealthValue).numericValue.toInt();
            diagnosticReport['sampleData']['HEART_RATE'] = hr;
            _log('  Heart Rate: $hr bpm (${heartRateData.length} data points)');
          }
        } else {
          _log('  ⚠️ Heart Rate: No data available');
        }
      } catch (e) {
        diagnosticReport['errors'].add('Heart Rate fetch failed: $e');
        _log('  ❌ Heart Rate fetch error: $e');
      }

      // Test Sleep (yesterday to today to ensure we get last night's sleep)
      try {
        final yesterday = startOfDay.subtract(Duration(days: 1));
        List<HealthDataPoint> sleepData = await _health.getHealthDataFromTypes(
          types: [
            HealthDataType.SLEEP_ASLEEP,
            HealthDataType.SLEEP_AWAKE,
            HealthDataType.SLEEP_IN_BED,
          ],
          startTime: yesterday,
          endTime: now,
        );
        diagnosticReport['dataAvailability']['SLEEP'] = sleepData.length;
        if (sleepData.isNotEmpty) {
          double asleepMinutes = 0;
          for (var point in sleepData) {
            if (point.type == HealthDataType.SLEEP_ASLEEP) {
              asleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
            }
          }
          double sleepHours = asleepMinutes / 60;
          diagnosticReport['sampleData']['SLEEP'] = sleepHours.toStringAsFixed(2);
          _log('  Sleep: ${sleepHours.toStringAsFixed(2)} hours (${sleepData.length} data points)');
        } else {
          _log('  ⚠️ Sleep: No data available');
        }
      } catch (e) {
        diagnosticReport['errors'].add('Sleep fetch failed: $e');
        _log('  ❌ Sleep fetch error: $e');
      }

      _log('✅ iOS DIAGNOSTIC: Completed');
      _log('📊 Summary:');
      _log('  Permissions granted: ${diagnosticReport['permissions']['overall']}');
      _log('  Data points found: ${diagnosticReport['dataAvailability']}');
      _log('  Errors encountered: ${diagnosticReport['errors'].length}');

    } catch (e) {
      diagnosticReport['errors'].add('Diagnostic failed: $e');
      _log('❌ iOS DIAGNOSTIC: Failed with error: $e');
    }

    return diagnosticReport;
  }

  // Check Health Connect availability (Android)
  Future<bool> _checkHealthConnectAvailability() async {
    try {
      _log('Checking Health Connect availability...');
      
      // Try to get Health Connect SDK status
      try {
        final status = await _health.getHealthConnectSdkStatus();
        _log('Health Connect SDK status: $status');
        
        if (status == HealthConnectSdkStatus.sdkAvailable) {
          // Create permissions array matching health types length
          final permissions = List<HealthDataAccess>.filled(
            _healthTypes.length, 
            HealthDataAccess.READ,
          );
          
          // Check if we have permissions
          bool? hasPermissions = await _health.hasPermissions(
            _healthTypes,
            permissions: permissions,
          );
          _log('Health Connect permissions status: $hasPermissions');
          
          return hasPermissions == true;
        } else {
          _log('Health Connect not available: $status');
          return false;
        }
      } catch (e) {
        _log('ERROR: SDK status check failed: $e');
        return false;
      }
    } catch (e) {
      _log('ERROR: Health Connect check failed: $e');
      return false;
    }
  }
  
  // Get Android device information
  Future<Map<String, dynamic>> getAndroidDeviceInfo() async {
    if (!Platform.isAndroid) {
      return {};
    }

    try {
      const platform = MethodChannel('com.streaker/health_connect');
      // Just get device info without actually opening settings
      final result = await platform.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      _log('Error getting Android device info: $e');
      return {
        'isSamsung': false,
        'androidVersion': 33,
        'manufacturer': 'unknown',
      };
    }
  }

  // Open health settings directly
  Future<void> openHealthSettings() async {
    try {
      if (Platform.isIOS) {
        // On iOS, we can open the Health app settings
        // The health package's requestAuthorization already opens the Health permission dialog
        // If user wants to manually change settings, they need to go through Settings app
        await _health.requestAuthorization(
          _healthTypes,
          permissions: List<HealthDataAccess>.filled(
            _healthTypes.length,
            HealthDataAccess.READ,
          ),
        );
      } else if (Platform.isAndroid) {
        // On Android, request permissions which will open Health Connect if needed
        try {
          // This will open Health Connect permission dialog
          await _health.requestAuthorization(
            _healthTypes,
            permissions: List<HealthDataAccess>.filled(
              _healthTypes.length,
              HealthDataAccess.READ,
            ),
          );
        } catch (e) {
          _log('Could not open Health Connect: $e');
          // Fallback to general app settings
          await AppSettings.openAppSettings();
        }
      }
    } catch (e) {
      _log('Error opening health settings: $e');
      // Fallback to general app settings
      await AppSettings.openAppSettings();
    }
  }

  // Public method to check if health permissions are granted
  Future<bool> hasHealthPermissions() async {
    _log('Checking if health permissions are granted...');

    try {
      if (Platform.isIOS) {
        // Check HealthKit permissions
        final hasPermissions = await _health.hasPermissions(
          _healthTypes,
          permissions: List<HealthDataAccess>.filled(
            _healthTypes.length,
            HealthDataAccess.READ,
          ),
        ) ?? false;
        _log('HealthKit permissions check: $hasPermissions');
        return hasPermissions;
      } else if (Platform.isAndroid) {
        // Check Health Connect permissions
        try {
          final status = await _health.getHealthConnectSdkStatus();
          if (status == HealthConnectSdkStatus.sdkAvailable) {
            // Try to read some data to verify permissions
            final now = DateTime.now();
            final midnight = DateTime(now.year, now.month, now.day);
            final steps = await _health.getTotalStepsInInterval(midnight, now);
            // If we can read data, we have permissions
            _log('Health Connect permissions check: ${steps != null}');
            return steps != null;
          }
        } catch (e) {
          _log('Error checking Health Connect permissions: $e');
        }
      }
    } catch (e) {
      _log('Error checking health permissions: $e');
    }

    return false;
  }

  // Force re-request all permissions (including new data types)
  Future<bool> forceRequestAllPermissions() async {
    _log('Force re-requesting all health permissions including new data types...');

    try {
      // Create permissions for all data types including new ones
      final permissions = List<HealthDataAccess>.filled(
        _healthTypes.length,
        HealthDataAccess.READ,
      );

      // Always request authorization even if we think we have it
      bool authorized = await _health.requestAuthorization(
        _healthTypes,
        permissions: permissions,
      );

      _log('Force permission request result: $authorized');

      if (authorized && Platform.isIOS) {
        // For iOS, set the data source after successful authorization
        _currentSource = HealthDataSource.healthKit;
        _log('HealthKit permissions updated successfully');
      }

      return authorized;
    } catch (e) {
      _log('ERROR force requesting permissions: $e');
      return false;
    }
  }

  // Request health permissions with detailed error handling
  Future<HealthConnectionResult> requestHealthPermissions() async {
    _log('Starting health permission request...');

    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        _log('Service not initialized, initializing now...');
        await initialize();
      }

      if (Platform.isIOS) {
        _log('Requesting HealthKit permissions...');

        // Create a permissions list that matches the length of health types
        final permissions = List<HealthDataAccess>.filled(
          _healthTypes.length,
          HealthDataAccess.READ,
        );

        // Request HealthKit permissions - this will open the Health app permission dialog
        bool authorized = await _health.requestAuthorization(
          _healthTypes,
          permissions: permissions,
        );

        _log('HealthKit authorization result: $authorized');

        if (authorized) {
          _currentSource = HealthDataSource.healthKit;
          return HealthConnectionResult(
            success: true,
            debugInfo: 'HealthKit connected successfully',
          );
        } else {
          return HealthConnectionResult(
            success: false,
            error: HealthConnectionError.permissionsDenied,
            errorMessage: 'HealthKit permissions were denied. Please go to Settings > Privacy & Security > Health to grant permissions.',
            debugInfo: _debugLogs.join('\n'),
          );
        }
      } else if (Platform.isAndroid) {
        _log('Android platform - checking Health Connect...');
        
        // First check if Health Connect is installed
        try {
          final status = await _health.getHealthConnectSdkStatus();
          _log('Health Connect SDK status: $status');
          
          if (status == HealthConnectSdkStatus.sdkUnavailable) {
            return HealthConnectionResult(
              success: false,
              error: HealthConnectionError.healthConnectNotInstalled,
              errorMessage: 'Health Connect is not installed. Please install it from the Play Store.',
              debugInfo: _debugLogs.join('\n'),
            );
          } else if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
            return HealthConnectionResult(
              success: false,
              error: HealthConnectionError.healthConnectNeedsUpdate,
              errorMessage: 'Health Connect needs to be updated. Please update it from the Play Store.',
              debugInfo: _debugLogs.join('\n'),
            );
          }
        } catch (e) {
          _log('WARNING: Could not check SDK status: $e');
        }
        
        // Activity recognition permission is not needed with Health Connect
        // Health Connect handles step tracking internally
        _log('Skipping activity recognition permission - using Health Connect directly');
        
        // Configure Health Connect if not already done
        _log('Configuring Health Connect...');
        try {
          await _health.configure();
          _log('Health Connect configured');
        } catch (e) {
          _log('ERROR: Health Connect configuration failed: $e');
          return HealthConnectionResult(
            success: false,
            error: HealthConnectionError.configurationFailed,
            errorMessage: 'Failed to configure Health Connect. Please check if the app is installed.',
            debugInfo: _debugLogs.join('\n'),
          );
        }
        
        // Request Health Connect permissions
        _log('Requesting Health Connect authorization for ${_healthTypes.length} data types...');
        
        bool authorized = false;
        try {
          // Create a permissions list that matches the length of health types
          final permissions = List<HealthDataAccess>.filled(
            _healthTypes.length, 
            HealthDataAccess.READ,
          );
          _log('Created ${permissions.length} permission entries for ${_healthTypes.length} data types');
          
          authorized = await _health.requestAuthorization(
            _healthTypes,
            permissions: permissions,
          );
          _log('Health Connect authorization result: $authorized');
        } catch (e) {
          _log('ERROR: Authorization request failed: $e');
          
          // Try with reduced permissions
          _log('Trying with basic permissions only...');
          try {
            final basicTypes = [HealthDataType.STEPS];
            final basicPermissions = [HealthDataAccess.READ];
            authorized = await _health.requestAuthorization(
              basicTypes,
              permissions: basicPermissions,
            );
            _log('Basic authorization result: $authorized');
          } catch (e2) {
            _log('ERROR: Basic authorization also failed: $e2');
          }
        }
        
        if (authorized) {
          _currentSource = HealthDataSource.healthConnect;
          _log('Successfully connected to Health Connect');
          return HealthConnectionResult(
            success: true,
            debugInfo: 'Health Connect connected successfully',
          );
        } else {
          _log('Health Connect authorization failed or was denied');

          // On Android, when permissions are denied, automatically open Health Connect settings
          _log('Opening Health Connect settings for manual permission grant...');

          // Call native Android method to open Health Connect settings
          try {
            const platform = MethodChannel('com.streaker/health_connect');
            final settingsResult = await platform.invokeMethod('openHealthConnectSettings');
            _log('Health Connect settings navigation result: $settingsResult');

            // Check if settings were successfully opened
            if (settingsResult != null && settingsResult['settingsOpened'] == true) {
              // Settings were opened, return a special status indicating pending permission
              return HealthConnectionResult(
                success: false,
                error: HealthConnectionError.permissionsDenied,
                errorMessage: settingsResult['message'] ?? 'Please grant all permissions in Health Connect and return to the app.',
                debugInfo: 'settings_opened:${settingsResult['openMethod']}',
              );
            } else {
              // Failed to open settings
              return HealthConnectionResult(
                success: false,
                error: HealthConnectionError.permissionsDenied,
                errorMessage: 'Could not open Health Connect settings. Please grant permissions manually in Settings > Apps > Streaker.',
                debugInfo: _debugLogs.join('\n'),
              );
            }
          } catch (e) {
            _log('Error opening Health Connect settings: $e');

            return HealthConnectionResult(
              success: false,
              error: HealthConnectionError.permissionsDenied,
              errorMessage: 'Health Connect permissions were denied. Please grant permissions manually in Settings > Apps > Streaker > Permissions.',
              debugInfo: _debugLogs.join('\n'),
            );
          }
        }
      }
      
      return HealthConnectionResult(
        success: false,
        error: HealthConnectionError.unknown,
        errorMessage: 'Unsupported platform',
        debugInfo: _debugLogs.join('\n'),
      );
    } catch (e) {
      _log('ERROR: Permission request failed with exception: $e');
      return HealthConnectionResult(
        success: false,
        error: HealthConnectionError.unknown,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
        debugInfo: _debugLogs.join('\n'),
      );
    }
  }
  
  // Test health data fetching
  Future<bool> testHealthDataFetch() async {
    _log('Testing health data fetch...');
    
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      // Try to fetch just steps as a test
      _log('Attempting to fetch steps data...');
      List<HealthDataPoint> stepsData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: midnight,
        endTime: now,
      );
      
      _log('Successfully fetched ${stepsData.length} step data points');
      
      int totalSteps = 0;
      for (var point in stepsData) {
        if (point.value is NumericHealthValue) {
          totalSteps += (point.value as NumericHealthValue).numericValue.toInt();
        }
      }
      
      _log('Total steps today: $totalSteps');
      return true;
    } catch (e) {
      _log('ERROR: Test fetch failed: $e');
      return false;
    }
  }
  
  // Fetch health data based on current source
  Future<Map<String, dynamic>> fetchHealthData() async {
    _log('Fetching health data from source: $_currentSource');

    switch (_currentSource) {
      case HealthDataSource.healthKit:
        return await _fetchFromHealthAPI();
      case HealthDataSource.healthConnect:
        // On Android, use native method for proper deduplication
        if (Platform.isAndroid) {
          return await _fetchFromNativeAndroid();
        }
        return await _fetchFromHealthAPI();
      case HealthDataSource.unavailable:
        // Try to determine source again
        await _determineBestDataSource();
        if (_currentSource != HealthDataSource.unavailable) {
          return await fetchHealthData();
        }
        _log('No data source available for fetching');
        return _getEmptyHealthData();
    }
  }
  
  // Fetch from native Android Health Connect with proper deduplication
  Future<Map<String, dynamic>> _fetchFromNativeAndroid() async {
    try {
      _log('Using native Android Health Connect with deduplication...');

      final healthData = await _nativeHealthConnectService.readAllHealthData();

      _log('Native Android data received:');
      _log('  Steps: ${healthData['steps']} (deduplicated)');
      _log('  Heart Rate: ${healthData['heartRate']} bpm');
      _log('  Calories: ${healthData['calories']} kcal');
      _log('  Distance: ${healthData['distance']} km');
      _log('  Sleep: ${healthData['sleep']} hours');
      _log('  Water: ${healthData['water']} ml');

      // Handle steps by source information
      if (healthData.containsKey('stepsBySource')) {
        final stepsBySource = healthData['stepsBySource'];
        _log('Steps by source breakdown:');
        _log('  Samsung Health: ${stepsBySource['samsung']} steps');
        _log('  Google Fit: ${stepsBySource['googleFit']} steps');
        _log('  Data Source Used: ${stepsBySource['dataSource']}');
      }

      return healthData;
    } catch (e) {
      _log('ERROR fetching from native Android: $e');
      _log('Falling back to health API...');
      return await _fetchFromHealthAPI();
    }
  }

  // Fetch data from Health API (HealthKit or Health Connect)
  Future<Map<String, dynamic>> _fetchFromHealthAPI() async {
    Map<String, dynamic> healthData = _getEmptyHealthData();
    
    try {
      // Get data from the last 24 hours
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      _log('Fetching health data from $midnight to $now');
      
      // Fetch different health data types
      
      // Steps
      try {
        _log('Fetching steps...');
        List<HealthDataPoint> stepsData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: midnight,
          endTime: now,
        );

        _log('Steps data points found: ${stepsData.length}');
        int totalSteps = 0;
        for (var point in stepsData) {
          if (point.value is NumericHealthValue) {
            int stepValue = (point.value as NumericHealthValue).numericValue.toInt();
            totalSteps += stepValue;
            _log('Step entry: $stepValue steps at ${point.dateFrom}');
          }
        }
        healthData['steps'] = totalSteps;
        _log('Steps today: $totalSteps');
      } catch (e) {
        _log('ERROR fetching steps: $e');
      }
      
      // Heart Rate (latest reading) and Resting Heart Rate for iOS
      try {
        _log('Fetching heart rate...');

        // For iOS, fetch both regular and resting heart rate
        List<HealthDataType> heartRateTypes = Platform.isIOS
          ? [HealthDataType.HEART_RATE, HealthDataType.RESTING_HEART_RATE]
          : [HealthDataType.HEART_RATE];

        List<HealthDataPoint> heartRateData = await _health.getHealthDataFromTypes(
          types: heartRateTypes,
          startTime: now.subtract(Duration(hours: 24)),  // Extended time range for resting heart rate
          endTime: now,
        );

        _log('Heart rate data points found: ${heartRateData.length}');

        // Process regular heart rate
        var regularHeartRateData = heartRateData.where((point) => point.type == HealthDataType.HEART_RATE).toList();
        if (regularHeartRateData.isNotEmpty) {
          regularHeartRateData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

          if (Platform.isIOS) {
            // For iOS, calculate average heart rate from today's readings
            var todayHeartRateData = regularHeartRateData.where((point) =>
              point.dateFrom.isAfter(midnight) && point.dateFrom.isBefore(now)
            ).toList();

            if (todayHeartRateData.isNotEmpty) {
              double totalHR = 0;
              int count = 0;
              for (var point in todayHeartRateData) {
                if (point.value is NumericHealthValue) {
                  totalHR += (point.value as NumericHealthValue).numericValue;
                  count++;
                }
              }
              if (count > 0) {
                healthData['heartRate'] = (totalHR / count).round();
                _log('iOS Average heart rate: ${healthData['heartRate']} bpm (from $count readings)');
              }
            } else if (regularHeartRateData.first.value is NumericHealthValue) {
              // Fallback to latest if no data from today
              healthData['heartRate'] = (regularHeartRateData.first.value as NumericHealthValue).numericValue.toInt();
              _log('Using latest heart rate (no data from today): ${healthData['heartRate']} bpm');
            }
          } else {
            // For Android, use latest reading
            for (var point in regularHeartRateData.take(3)) {
              _log('Heart rate entry: ${(point.value as NumericHealthValue).numericValue} bpm at ${point.dateFrom}');
            }
            if (regularHeartRateData.first.value is NumericHealthValue) {
              healthData['heartRate'] = (regularHeartRateData.first.value as NumericHealthValue).numericValue.toInt();
              _log('Latest heart rate: ${healthData['heartRate']} bpm');
            }
          }
        } else {
          _log('No heart rate data found');
        }

        // Process resting heart rate for iOS
        if (Platform.isIOS) {
          var restingHeartRateData = heartRateData.where((point) => point.type == HealthDataType.RESTING_HEART_RATE).toList();
          if (restingHeartRateData.isNotEmpty) {
            restingHeartRateData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
            if (restingHeartRateData.first.value is NumericHealthValue) {
              int restingHR = (restingHeartRateData.first.value as NumericHealthValue).numericValue.toInt();
              // If no regular heart rate but we have resting, use resting as the main heart rate
              if (healthData['heartRate'] == 0 && restingHR > 0) {
                healthData['heartRate'] = restingHR;
                _log('Using resting heart rate as main heart rate: $restingHR bpm');
              }
              _log('Resting heart rate: $restingHR bpm');
            }
          } else {
            _log('No resting heart rate data found');
          }
        }
      } catch (e) {
        _log('ERROR fetching heart rate: $e');
      }
      
      // Calories burned - Both iOS and Android use active energy burned
      try {
        _log('Fetching calories...');

        // Both platforms use ACTIVE_ENERGY_BURNED as TOTAL_CALORIES_BURNED is not supported on iOS
        List<HealthDataType> calorieTypes = [HealthDataType.ACTIVE_ENERGY_BURNED];

        List<HealthDataPoint> caloriesData = await _health.getHealthDataFromTypes(
          types: calorieTypes,
          startTime: midnight,
          endTime: now,
        );

        _log('Calories data points found: ${caloriesData.length}');

        // Process active energy burned for both platforms
        double totalCalories = 0;
        for (var point in caloriesData) {
          if (point.value is NumericHealthValue) {
            double calorieValue = (point.value as NumericHealthValue).numericValue.toDouble();
            totalCalories += calorieValue;
            _log('Active calorie entry: ${calorieValue.toStringAsFixed(1)} cal at ${point.dateFrom}');
          }
        }

        healthData['calories'] = totalCalories.toInt();
        _log('Calories burned total: ${healthData['calories']}');
      } catch (e) {
        _log('ERROR fetching calories: $e');
      }
      
      // Distance
      try {
        _log('Fetching distance...');
        List<HealthDataPoint> distanceData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.DISTANCE_WALKING_RUNNING],
          startTime: midnight,
          endTime: now,
        );

        _log('Distance data points found: ${distanceData.length}');
        double totalDistance = 0;
        for (var point in distanceData) {
          if (point.value is NumericHealthValue) {
            // Convert meters to kilometers
            double distanceValue = (point.value as NumericHealthValue).numericValue.toDouble() / 1000;
            totalDistance += distanceValue;
            _log('Distance entry: ${distanceValue.toStringAsFixed(2)} km at ${point.dateFrom}');
          }
        }
        healthData['distance'] = totalDistance;
        _log('Distance total: ${totalDistance.toStringAsFixed(2)} km');
      } catch (e) {
        _log('ERROR fetching distance: $e');
      }

      // Sleep - iOS gets comprehensive sleep data, Android gets basic
      try {
        _log('Fetching sleep...');

        // For iOS, fetch all sleep types; for Android, just SLEEP_ASLEEP
        List<HealthDataType> sleepTypes = Platform.isIOS
          ? [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_AWAKE, HealthDataType.SLEEP_IN_BED]
          : [HealthDataType.SLEEP_ASLEEP];

        // Fetch sleep data from yesterday to now to get last night's sleep
        final yesterday = now.subtract(Duration(days: 1));
        List<HealthDataPoint> sleepData = await _health.getHealthDataFromTypes(
          types: sleepTypes,
          startTime: yesterday,
          endTime: now,
        );

        _log('Sleep data points found: ${sleepData.length}');

        if (Platform.isIOS) {
          // For iOS, calculate actual sleep time more accurately
          // Only consider sleep sessions that ended on the current day (last night's sleep)
          double asleepMinutes = 0;
          double awakeMinutes = 0;
          double inBedMinutes = 0;

          // Group sleep sessions by their end time to identify last night's sleep
          var lastNightSleepData = sleepData.where((point) {
            // Consider sleep that ended after midnight of today
            return point.dateTo.isAfter(midnight);
          }).toList();

          _log('Last night sleep data points: ${lastNightSleepData.length}');

          for (var point in lastNightSleepData) {
            // For iOS, sleep data points represent time periods (from dateFrom to dateTo)
            double durationMinutes = point.dateTo.difference(point.dateFrom).inMinutes.toDouble();

            if (point.type == HealthDataType.SLEEP_ASLEEP) {
              asleepMinutes += durationMinutes;
              _log('Sleep asleep: ${durationMinutes.toStringAsFixed(1)} minutes from ${point.dateFrom} to ${point.dateTo}');
            } else if (point.type == HealthDataType.SLEEP_AWAKE) {
              awakeMinutes += durationMinutes;
              _log('Sleep awake: ${durationMinutes.toStringAsFixed(1)} minutes from ${point.dateFrom} to ${point.dateTo}');
            } else if (point.type == HealthDataType.SLEEP_IN_BED) {
              inBedMinutes += durationMinutes;
              _log('Sleep in bed: ${durationMinutes.toStringAsFixed(1)} minutes from ${point.dateFrom} to ${point.dateTo}');
            }
          }

          // Use actual sleep time (asleep) if available, otherwise use in bed time
          double totalSleepMinutes = asleepMinutes > 0 ? asleepMinutes : inBedMinutes;
          healthData['sleep'] = totalSleepMinutes / 60; // Convert to hours

          _log('iOS Sleep - Asleep: ${(asleepMinutes/60).toStringAsFixed(1)}h, Awake: ${(awakeMinutes/60).toStringAsFixed(1)}h, In Bed: ${(inBedMinutes/60).toStringAsFixed(1)}h');
          _log('Total sleep hours: ${healthData['sleep'].toStringAsFixed(1)}');
        } else {
          // For Android, use the existing logic
          double totalSleepMinutes = 0;
          for (var point in sleepData) {
            if (point.value is NumericHealthValue) {
              double sleepValue = (point.value as NumericHealthValue).numericValue.toDouble();
              totalSleepMinutes += sleepValue;
              _log('Sleep entry: ${sleepValue.toStringAsFixed(1)} minutes at ${point.dateFrom}');
            }
          }
          healthData['sleep'] = totalSleepMinutes / 60; // Convert to hours
          _log('Android sleep total: ${(totalSleepMinutes / 60).toStringAsFixed(1)} hours');
        }
      } catch (e) {
        _log('ERROR fetching sleep: $e');
      }

      // Water intake
      try {
        _log('Fetching water intake...');
        List<HealthDataPoint> waterData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.WATER],
          startTime: midnight,
          endTime: now,
        );

        _log('Water data points found: ${waterData.length}');
        double totalWater = 0;
        for (var point in waterData) {
          if (point.value is NumericHealthValue) {
            double waterValue = (point.value as NumericHealthValue).numericValue.toDouble();
            totalWater += waterValue;
            _log('Water entry: ${waterValue.toStringAsFixed(1)} ml at ${point.dateFrom}');
          }
        }
        healthData['water'] = totalWater.toInt();
        _log('Water total: ${totalWater.toStringAsFixed(0)} ml');
      } catch (e) {
        _log('ERROR fetching water: $e');
      }

      _log('Health data fetch complete');
      return healthData;
    } catch (e) {
      _log('ERROR: Failed to fetch health data: $e');
      return healthData;
    }
  }
  
  // Get empty health data structure
  Map<String, dynamic> _getEmptyHealthData() {
    return {
      'steps': 0,
      'heartRate': 0,
      'calories': 0,
      'sleep': 0.0,
      'distance': 0.0,
      'water': 0,
      'weight': 0.0,
      'bloodOxygen': 0,
      'bloodPressure': {'systolic': 0, 'diastolic': 0},
      'workouts': 0,
      'exerciseMinutes': 0,
      'latestHeartRate': 0,
      'heartRateType': 'none',
      'sleepMinutes': 0,
      'workoutDetails': [],
      'stepDetails': [],
      'sleepDetails': [],
    };
  }
  
  // Check if data source is available
  bool get isDataSourceAvailable => _currentSource != HealthDataSource.unavailable;

  // Smart check to auto-connect if permissions exist
  Future<bool> checkAndAutoConnect() async {
    _log('Smart check: Checking for existing permissions...');

    if (Platform.isAndroid) {
      try {
        // First check if Health Connect is available
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          _log('Health Connect not available: $status');
          return false;
        }

        // Check if we have permissions using native service
        final nativeHealthService = NativeHealthConnectService();
        final permissionStatus = await nativeHealthService.checkPermissions();

        if (permissionStatus['granted'] == true) {
          _log('✅ Permissions already granted! Auto-connecting...');

          // Configure health service if not already configured
          if (!_isInitialized) {
            try {
              await _health.configure();
              _log('Health Connect configured successfully');
            } catch (e) {
              _log('Health Connect configuration warning: $e');
            }
          }

          // Since native permissions are granted, trust that and connect
          // The health package's hasPermissions can be unreliable on some Android versions
          _currentSource = HealthDataSource.healthConnect;
          _log('✅ Successfully connected to Health Connect!');
          return true;
        } else {
          _log('No permissions granted yet');
          return false;
        }
      } catch (e) {
        _log('Error checking permissions: $e');
        return false;
      }
    } else if (Platform.isIOS) {
      // Check iOS permissions
      bool hasPerms = await _checkHealthKitAvailability();
      if (hasPerms) {
        _currentSource = HealthDataSource.healthKit;
        _log('✅ Successfully connected to HealthKit!');
        return true;
      }
    }

    return false;
  }

  // Get data source info
  Map<String, String> getDataSourceInfo() {
    switch (_currentSource) {
      case HealthDataSource.healthKit:
        return {
          'source': 'Apple Health',
          'status': 'Connected',
          'icon': '🍎',
        };
      case HealthDataSource.healthConnect:
        return {
          'source': 'Health Connect',
          'status': 'Connected',
          'icon': '🤖',
        };
      case HealthDataSource.unavailable:
        return {
          'source': 'Not Connected',
          'status': 'No data source',
          'icon': '❌',
        };
    }
  }

  // Get connected device info
  Map<String, dynamic>? getConnectedDeviceInfo() {
    return null;
  }

  // Set data update callback
  void setDataUpdateCallback(Function(Map<String, dynamic>) callback) {
    _onDataUpdate = callback;
  }
  
  // Start automatic data sync
  Future<void> startDataSync() async {
    _log('Starting automatic data sync...');
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      if (isDataSourceAvailable) {
        final data = await fetchHealthData();
        _onDataUpdate?.call(data);
      }
    });
  }
  
  // Stop automatic data sync
  void stopDataSync() {
    _log('Stopping automatic data sync...');
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  // Sync now
  Future<void> syncNow() async {
    _log('Manual sync triggered...');
    if (isDataSourceAvailable) {
      final data = await fetchHealthData();
      _onDataUpdate?.call(data);
    }
  }
  
  // Clear debug logs
  void clearDebugLogs() {
    _debugLogs.clear();
  }
  
  // Dispose
  void dispose() {
    stopDataSync();
  }
}