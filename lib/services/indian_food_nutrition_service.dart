import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_config.dart';

// ============================================================================
// ERROR HANDLING SYSTEM
// ============================================================================

enum NutritionErrorType {
  modelNotFound,      // Model doesn't exist on API
  apiKeyInvalid,      // Authentication failed
  rateLimitExceeded,  // Quota exceeded
  networkTimeout,     // Request took too long
  parseError,         // Response parsing failed
  apiError,           // Generic API error
  noModelAvailable,   // No initialized model
  unknown,            // Unexpected error
}

class NutritionError {
  final NutritionErrorType type;
  final String message;
  final String? originalError;
  final DateTime timestamp;

  NutritionError({
    required this.type,
    required this.message,
    this.originalError,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'message': message,
    'originalError': originalError,
    'timestamp': timestamp.toIso8601String(),
  };

  String get userMessage {
    switch (type) {
      case NutritionErrorType.rateLimitExceeded:
        return 'Too many requests. Please try again in a minute.';
      case NutritionErrorType.networkTimeout:
        return 'Network timeout. Check your connection and try again.';
      case NutritionErrorType.apiKeyInvalid:
        return 'Service configuration error. Please contact support.';
      case NutritionErrorType.noModelAvailable:
        return 'AI service temporarily unavailable. Using estimated values.';
      default:
        return 'Analysis failed. Using estimated values.';
    }
  }
}

// ============================================================================
// RESULT TYPES
// ============================================================================

enum NutritionSource {
  geminiAI,           // AI analysis successful
  localDatabase,      // Fallback to database
  smartEstimation,    // Intelligent estimation
}

class NutritionResult {
  final bool success;
  final List<String> foods;
  final Map<String, int> nutrition;
  final NutritionSource source;
  final double confidence;
  final String? modelUsed;
  final NutritionError? error;
  final Duration? processingTime;

  NutritionResult({
    required this.success,
    required this.foods,
    required this.nutrition,
    required this.source,
    required this.confidence,
    this.modelUsed,
    this.error,
    this.processingTime,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'foods': foods,
    'nutrition': nutrition,
    'source': source.toString().split('.').last,
    'confidence': confidence,
    'modelUsed': modelUsed,
    'isEstimated': source != NutritionSource.geminiAI,
    'error': error?.toJson(),
    'processingTimeMs': processingTime?.inMilliseconds,
    'reason': error?.userMessage,
  };
}

// ============================================================================
// RETRY & CIRCUIT BREAKER
// ============================================================================

class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
  });
}

class CircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;

  int _failureCount = 0;
  DateTime? _lastFailureTime;
  bool _isOpen = false;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(minutes: 5),
  });

  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_isOpen && _lastFailureTime != null) {
      final timeSinceFailure = DateTime.now().difference(_lastFailureTime!);
      if (timeSinceFailure > resetTimeout) {
        debugPrint('🔄 Circuit breaker: Attempting reset...');
        _isOpen = false;
        _failureCount = 0;
      }
    }

    if (_isOpen) {
      throw Exception('Circuit breaker is OPEN - too many failures');
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    if (_isOpen) {
      debugPrint('✅ Circuit breaker: Reset successful');
      _isOpen = false;
    }
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      debugPrint('⚠️ Circuit breaker: OPENED ($_failureCount failures)');
      _isOpen = true;
    }
  }

  bool get isOpen => _isOpen;
  int get failureCount => _failureCount;
}

// ============================================================================
// METRICS TRACKING
// ============================================================================

class NutritionMetrics {
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  int fallbackRequests = 0;

  final Map<String, int> errorCounts = {};
  final List<Duration> responseTimes = [];

  double get successRate =>
    totalRequests > 0 ? successfulRequests / totalRequests : 0;

  Duration get avgResponseTime {
    if (responseTimes.isEmpty) return Duration.zero;
    final totalMs = responseTimes.fold(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ responseTimes.length);
  }

  void recordSuccess(Duration responseTime) {
    totalRequests++;
    successfulRequests++;
    responseTimes.add(responseTime);

    if (responseTimes.length > 100) {
      responseTimes.removeAt(0);
    }
  }

  void recordFailure(String errorType) {
    totalRequests++;
    failedRequests++;
    errorCounts[errorType] = (errorCounts[errorType] ?? 0) + 1;
  }

  void recordFallback() {
    fallbackRequests++;
  }

  Map<String, dynamic> toJson() => {
    'totalRequests': totalRequests,
    'successfulRequests': successfulRequests,
    'failedRequests': failedRequests,
    'fallbackRequests': fallbackRequests,
    'successRate': successRate,
    'avgResponseTimeMs': avgResponseTime.inMilliseconds,
    'errorCounts': errorCounts,
  };

  void printReport() {
    debugPrint('\n📊 NUTRITION SERVICE METRICS');
    debugPrint('   Total Requests: $totalRequests');
    debugPrint('   Success Rate: ${(successRate * 100).toStringAsFixed(1)}%');
    debugPrint('   Avg Response: ${avgResponseTime.inMilliseconds}ms');
    debugPrint('   Fallback Usage: $fallbackRequests');
    if (errorCounts.isNotEmpty) {
      debugPrint('   Error Breakdown:');
      errorCounts.forEach((type, count) {
        debugPrint('     - $type: $count');
      });
    }
    debugPrint('');
  }
}

// ============================================================================
// MAIN SERVICE
// ============================================================================

class IndianFoodNutritionService {
  static IndianFoodNutritionService? _instance;
  factory IndianFoodNutritionService() {
    _instance ??= IndianFoodNutritionService._internal();
    return _instance!;
  }

  IndianFoodNutritionService._internal() {
    _initializeGeminiModel().catchError((error) {
      debugPrint('⚠️ Gemini initialization failed: $error');
      debugPrint('   Nutrition analysis will use fallback methods');
    });

    _startHealthCheckTimer();
    _startMetricsReporting();
  }

  // Core components
  GenerativeModel? _model;
  String? _activeModelName;
  DateTime? _lastSuccessfulCall;
  bool _isValidating = false;

  // Resilience components
  final _circuitBreaker = CircuitBreaker(
    failureThreshold: 5,
    resetTimeout: Duration(minutes: 5),
  );
  final _metrics = NutritionMetrics();

  // Timers
  Timer? _healthCheckTimer;
  Timer? _metricsTimer;

  static String get _geminiApiKey => ApiConfig.geminiApiKey;

  // ============================================================================
  // INITIALIZATION WITH REAL VALIDATION
  // ============================================================================

  Future<void> _initializeGeminiModel() async {
    if (!ApiConfig.enableGeminiVision || _geminiApiKey.isEmpty) {
      debugPrint('⚠️ Gemini Vision is disabled or API key is missing');
      return;
    }

    if (!_geminiApiKey.startsWith('AIza')) {
      debugPrint('❌ Invalid Gemini API key format');
      return;
    }

    debugPrint('\n🚀 GEMINI INITIALIZATION STARTING...');
    debugPrint('   Package: google_generative_ai v0.4.3');
    debugPrint('   API Endpoint: v1beta (Flutter package default)');
    debugPrint('   API Key: ${_geminiApiKey.substring(0, 10)}...');

    // CRITICAL: Use v1beta-compatible model names
    // The google_generative_ai Flutter package uses v1beta endpoint
    final modelVersions = [
      'gemini-flash-latest',       // Primary: Latest stable flash (v1beta compatible)
      'gemini-2.5-flash',          // Fallback 1: Stable 2.5 flash
      'gemini-2.0-flash',          // Fallback 2: Stable 2.0 flash
    ];

    for (var i = 0; i < modelVersions.length; i++) {
      final modelName = modelVersions[i];

      try {
        debugPrint('\n[${i + 1}/${modelVersions.length}] Testing model: $modelName');
        final startTime = DateTime.now();

        // Step 1: Create model instance
        final testModel = GenerativeModel(
          model: modelName,
          apiKey: _geminiApiKey,
        );
        debugPrint('   ✓ Model object created');

        // Step 2: ACTUALLY TEST with real API call
        _isValidating = true;
        debugPrint('   → Sending test request to Google API...');

        final response = await testModel.generateContent([
          Content.text('test')
        ]).timeout(
          Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('API request timeout after 10 seconds');
          },
        );

        _isValidating = false;
        final duration = DateTime.now().difference(startTime);

        // Step 3: Verify response is valid
        if (response.text == null || response.text!.isEmpty) {
          throw Exception('API returned empty response');
        }

        debugPrint('   ✓ API response received in ${duration.inMilliseconds}ms');
        debugPrint('   ✓ Response length: ${response.text!.length} chars');

        // SUCCESS
        _model = testModel;
        _activeModelName = modelName;
        _lastSuccessfulCall = DateTime.now();

        debugPrint('\n✅ INITIALIZATION SUCCESS');
        debugPrint('   Active Model: $modelName');
        debugPrint('   API Endpoint: v1beta');
        debugPrint('   Validation: PASSED with live API test');
        debugPrint('   Ready for production use\n');

        return;

      } catch (e, stackTrace) {
        _isValidating = false;

        debugPrint('   ❌ Model FAILED validation');
        debugPrint('   Error Type: ${e.runtimeType}');
        debugPrint('   Error: $e');

        if (e.toString().contains('not found') || e.toString().contains('404')) {
          debugPrint('   → Model does not exist on v1beta API');
        } else if (e.toString().contains('quota') || e.toString().contains('429')) {
          debugPrint('   → Rate limit or quota exceeded');
        } else if (e.toString().contains('timeout')) {
          debugPrint('   → Network timeout - possible connectivity issue');
        } else if (e.toString().contains('401') || e.toString().contains('403')) {
          debugPrint('   → API key invalid or unauthorized');
        }

        if (i < modelVersions.length - 1) {
          debugPrint('   → Trying next model...\n');
          await Future.delayed(Duration(seconds: 1));
        }
      }
    }

    debugPrint('\n❌ INITIALIZATION FAILED');
    debugPrint('   All ${modelVersions.length} models failed validation');
    debugPrint('   AI nutrition analysis unavailable');
    debugPrint('   Will use local database fallback\n');

    _model = null;
    _activeModelName = null;
  }

  // ============================================================================
  // ERROR CLASSIFICATION
  // ============================================================================

  NutritionError _classifyError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return NutritionError(
        type: NutritionErrorType.modelNotFound,
        message: 'Model does not exist on API endpoint',
        originalError: error.toString(),
      );
    }

    if (errorStr.contains('quota') || errorStr.contains('rate limit') ||
        errorStr.contains('429')) {
      return NutritionError(
        type: NutritionErrorType.rateLimitExceeded,
        message: 'API rate limit exceeded',
        originalError: error.toString(),
      );
    }

    if (errorStr.contains('timeout')) {
      return NutritionError(
        type: NutritionErrorType.networkTimeout,
        message: 'Request timed out',
        originalError: error.toString(),
      );
    }

    if (errorStr.contains('401') || errorStr.contains('403') ||
        errorStr.contains('unauthorized')) {
      return NutritionError(
        type: NutritionErrorType.apiKeyInvalid,
        message: 'API authentication failed',
        originalError: error.toString(),
      );
    }

    if (error is FormatException || errorStr.contains('json')) {
      return NutritionError(
        type: NutritionErrorType.parseError,
        message: 'Failed to parse API response',
        originalError: error.toString(),
      );
    }

    return NutritionError(
      type: NutritionErrorType.unknown,
      message: 'Unexpected error',
      originalError: error.toString(),
    );
  }

  // ============================================================================
  // RETRY LOGIC
  // ============================================================================

  Future<T> _retryWithBackoff<T>({
    required Future<T> Function() operation,
    required RetryConfig config,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = config.initialDelay;

    while (true) {
      attempt++;

      try {
        if (attempt > 1) {
          debugPrint('   Retry attempt $attempt/${config.maxAttempts}...');
        }
        return await operation();

      } catch (e) {
        final canRetry = shouldRetry?.call(e) ?? true;

        if (!canRetry || attempt >= config.maxAttempts) {
          if (attempt > 1) {
            debugPrint('   ❌ Failed after $attempt attempts');
          }
          rethrow;
        }

        debugPrint('   ⚠️ Attempt $attempt failed: ${e.toString().substring(0, 100)}');
        debugPrint('   ⏳ Retrying in ${delay.inSeconds}s...');

        await Future.delayed(delay);

        delay = Duration(
          milliseconds: (delay.inMilliseconds * config.backoffMultiplier).toInt(),
        );

        if (delay > config.maxDelay) {
          delay = config.maxDelay;
        }
      }
    }
  }

  // ============================================================================
  // MAIN ANALYSIS METHOD WITH FALLBACK CHAIN
  // ============================================================================

  Future<Map<String, dynamic>> analyzeWithDescription(
    File imageFile,
    String mealDescription,
  ) async {
    final startTime = DateTime.now();
    debugPrint('\n🍴 NUTRITION SCAN STARTED (Description Mode)');
    debugPrint('   Description: $mealDescription');
    debugPrint('   Image: ${imageFile.path}');

    try {
      // Try 1: AI Analysis with circuit breaker and retry
      if (_model != null && !_circuitBreaker.isOpen) {
        try {
          debugPrint('🤖 Attempting Gemini AI analysis...');
          debugPrint('   Model: $_activeModelName');
          debugPrint('   Circuit Breaker: Closed (healthy)');

          final result = await _circuitBreaker.execute(() =>
            _retryWithBackoff(
              operation: () => _callGeminiAPI(imageFile, mealDescription),
              config: RetryConfig(
                maxAttempts: 2,
                initialDelay: Duration(seconds: 1),
              ),
              shouldRetry: (error) {
                final errorStr = error.toString().toLowerCase();
                return errorStr.contains('timeout') ||
                       errorStr.contains('network') ||
                       errorStr.contains('connection');
              },
            ),
          );

          if (result['success'] == true) {
            final processingTime = DateTime.now().difference(startTime);
            _metrics.recordSuccess(processingTime);
            _lastSuccessfulCall = DateTime.now();

            debugPrint('✅ AI Analysis successful in ${processingTime.inMilliseconds}ms');
            debugPrint('   📦 Creating success result with:');
            debugPrint('      foods: ${result['foods']}');
            debugPrint('      foods type: ${result['foods'].runtimeType}');
            debugPrint('      nutrition: ${result['nutrition']}');
            debugPrint('      nutrition type: ${result['nutrition'].runtimeType}');
            debugPrint('      source: NutritionSource.geminiAI');
            debugPrint('      confidence: 0.95');
            debugPrint('      modelUsed: $_activeModelName');

            return _createSuccessResult(
              foods: List<String>.from(result['foods']),
              nutrition: result['nutrition'],
              source: NutritionSource.geminiAI,
              confidence: 0.95,
              modelUsed: _activeModelName,
              processingTime: processingTime,
            );
          }
        } catch (e, stackTrace) {
          final error = _classifyError(e);
          debugPrint('⚠️ AI Analysis failed: ${error.message}');
          debugPrint('   Error Type: ${error.type}');
          debugPrint('   Original Error: ${error.originalError}');
          debugPrint('   Exception Object: $e');
          debugPrint('   Exception Runtime Type: ${e.runtimeType}');
          debugPrint('   Stack Trace (first 5 lines):');
          final stackLines = stackTrace.toString().split('\n');
          for (var i = 0; i < (stackLines.length < 5 ? stackLines.length : 5); i++) {
            debugPrint('   ${stackLines[i]}');
          }
          _metrics.recordFailure(error.type.toString());
        }
      } else {
        debugPrint('⚠️ Skipping AI - Circuit breaker: ${_circuitBreaker.isOpen ? "OPEN" : "Model not initialized"}');
      }

      // Try 2: Local Database Matching
      debugPrint('📚 Attempting local database lookup...');
      _metrics.recordFallback();

      final dbResult = await _analyzeWithLocalDatabase(mealDescription);
      if (dbResult['success'] == true && dbResult['nutrition']['calories'] > 0) {
        final processingTime = DateTime.now().difference(startTime);

        debugPrint('✅ Local database match found in ${processingTime.inMilliseconds}ms');

        return _createSuccessResult(
          foods: dbResult['foods'],
          nutrition: dbResult['nutrition'],
          source: NutritionSource.localDatabase,
          confidence: 0.7,
          processingTime: processingTime,
        );
      }

      // Try 3: Smart Estimation (always succeeds)
      debugPrint('🧮 Using smart estimation...');

      final estimateResult = _getEstimatedNutrition(mealDescription);
      final processingTime = DateTime.now().difference(startTime);

      debugPrint('✅ Smart estimation complete in ${processingTime.inMilliseconds}ms');

      return _createSuccessResult(
        foods: estimateResult['foods'],
        nutrition: estimateResult['nutrition'],
        source: NutritionSource.smartEstimation,
        confidence: 0.6,
        processingTime: processingTime,
      );

    } catch (e) {
      debugPrint('❌ Critical error in nutrition analysis: $e');
      final processingTime = DateTime.now().difference(startTime);

      return _createSuccessResult(
        foods: ['Unknown meal'],
        nutrition: {'calories': 350, 'protein': 15, 'carbs': 45, 'fat': 12, 'fiber': 5},
        source: NutritionSource.smartEstimation,
        confidence: 0.5,
        processingTime: processingTime,
      );
    }
  }

  Map<String, dynamic> _createSuccessResult({
    required List<String> foods,
    required Map<String, dynamic> nutrition,
    required NutritionSource source,
    required double confidence,
    String? modelUsed,
    Duration? processingTime,
  }) {
    return {
      'success': true,
      'foods': foods,
      'nutrition': nutrition,
      'source': source.toString().split('.').last,
      'isEstimated': source != NutritionSource.geminiAI,
      'confidence': confidence,
      'modelUsed': modelUsed ?? 'none',
      'processingTimeMs': processingTime?.inMilliseconds,
      'reason': source == NutritionSource.geminiAI
        ? null
        : 'AI analysis unavailable. Values ${source == NutritionSource.localDatabase ? "from database" : "estimated"}.',
    };
  }

  // ============================================================================
  // GEMINI API CALL
  // ============================================================================

  Future<Map<String, dynamic>> _callGeminiAPI(
    File imageFile,
    String description,
  ) async {
    debugPrint('   📡 Calling Gemini API...');
    final startTime = DateTime.now();

    final imageBytes = await imageFile.readAsBytes();
    debugPrint('   Image size: ${(imageBytes.length / 1024).toStringAsFixed(1)} KB');

    final prompt = '''
Analyze this food image and the provided description to calculate total nutrition.

Meal Description: $description

Important:
1. Look at the image to understand portion sizes and actual foods present
2. Use the description to identify specific items and quantities mentioned
3. Calculate total nutrition for the ENTIRE meal shown/described
4. Be accurate with Indian food nutritional values if applicable

Return ONLY a JSON object in this exact format (no markdown, no explanation):
{
  "foods": ["item1", "item2", "item3"],
  "total_calories": number,
  "total_protein": number (in grams),
  "total_carbs": number (in grams),
  "total_fat": number (in grams),
}
''';

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ]),
    ];

    final response = await _model!.generateContent(content).timeout(
      Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Gemini API request timed out after 30 seconds'),
    );

    final duration = DateTime.now().difference(startTime);
    final responseText = response.text?.trim() ?? '';

    debugPrint('   ✓ Response received in ${duration.inMilliseconds}ms');
    debugPrint('   Response length: ${responseText.length} chars');

    if (responseText.isEmpty) {
      throw Exception('Empty response from Gemini API');
    }

    // Parse JSON response
    String cleanJson = responseText;
    if (cleanJson.contains('```')) {
      cleanJson = cleanJson.replaceAll(RegExp(r'```[\w]*\n?'), '').trim();
    }

    final nutritionData = json.decode(cleanJson);

    debugPrint('   ✓ Parsed successfully');
    debugPrint('   Foods: ${nutritionData['foods']}');
    debugPrint('   Calories: ${nutritionData['total_calories']}');

    return {
      'success': true,
      'foods': nutritionData['foods'] ?? [description],
      'nutrition': {
        'calories': (nutritionData['total_calories'] ?? 0).round(),
        'protein': (nutritionData['total_protein'] ?? 0).round(),
        'carbs': (nutritionData['total_carbs'] ?? 0).round(),
        'fat': (nutritionData['total_fat'] ?? 0).round(),
      },
    };
  }

  // ============================================================================
  // HEALTH CHECKS & MONITORING
  // ============================================================================

  void _startHealthCheckTimer() {
    _healthCheckTimer = Timer.periodic(Duration(minutes: 15), (timer) async {
      await _performHealthCheck();
    });
    debugPrint('✅ Health check timer started (15min intervals)');
  }

  void _startMetricsReporting() {
    _metricsTimer = Timer.periodic(Duration(hours: 1), (timer) {
      _metrics.printReport();
    });
  }

  Future<void> _performHealthCheck() async {
    if (_isValidating) {
      debugPrint('⏭️ Health check skipped - validation in progress');
      return;
    }

    if (_lastSuccessfulCall != null) {
      final timeSinceSuccess = DateTime.now().difference(_lastSuccessfulCall!);
      final successRate = _metrics.successRate;

      if (timeSinceSuccess.inMinutes < 30 && successRate > 0.8) {
        debugPrint('✅ Health check skipped - system healthy (${(successRate * 100).toStringAsFixed(1)}% success rate)');
        return;
      }
    }

    if (_model != null) {
      try {
        debugPrint('🏥 Running health check on $_activeModelName...');
        final startTime = DateTime.now();

        await _model!.generateContent([
          Content.text('health check')
        ]).timeout(Duration(seconds: 5));

        final duration = DateTime.now().difference(startTime);
        _lastSuccessfulCall = DateTime.now();

        debugPrint('✅ Health check passed (${duration.inMilliseconds}ms)');

      } catch (e) {
        debugPrint('⚠️ Health check failed: $e');
        debugPrint('   Attempting model reinitialization...');

        _model = null;
        _activeModelName = null;

        await _initializeGeminiModel();

        if (_model != null) {
          debugPrint('✅ Auto-recovery successful');
        } else {
          debugPrint('❌ Auto-recovery failed');
        }
      }
    } else {
      debugPrint('🏥 No model initialized - attempting init...');
      await _initializeGeminiModel();
    }
  }

  void dispose() {
    _healthCheckTimer?.cancel();
    _metricsTimer?.cancel();
    debugPrint('🧹 IndianFoodNutritionService disposed');
  }

  // ============================================================================
  // DIAGNOSTIC TOOLS
  // ============================================================================

  Future<void> runDiagnostics() async {
    debugPrint('\n🔧 RUNNING NUTRITION SERVICE DIAGNOSTICS\n');

    debugPrint('TEST 1: API Key Validation');
    debugPrint('  API Key Present: ${_geminiApiKey.isNotEmpty}');
    debugPrint('  API Key Format: ${_geminiApiKey.startsWith("AIza") ? "Valid" : "Invalid"}');
    debugPrint('  API Key Length: ${_geminiApiKey.length} chars');

    debugPrint('\nTEST 2: Model Initialization');
    await _initializeGeminiModel();
    debugPrint('  Active Model: ${_activeModelName ?? "NONE"}');
    debugPrint('  Model Initialized: ${_model != null}');

    if (_model != null) {
      debugPrint('\nTEST 3: Simple API Call');
      try {
        final start = DateTime.now();
        final response = await _model!.generateContent([
          Content.text('What is 2+2?')
        ]).timeout(Duration(seconds: 10));

        final duration = DateTime.now().difference(start);
        debugPrint('  ✅ API Call Successful');
        debugPrint('  Response Time: ${duration.inMilliseconds}ms');
        debugPrint('  Response: ${response.text?.substring(0, 50)}...');

      } catch (e) {
        debugPrint('  ❌ API Call Failed: $e');
      }
    }

    debugPrint('\nTEST 4: Circuit Breaker Status');
    debugPrint('  Is Open: ${_circuitBreaker.isOpen}');
    debugPrint('  Failure Count: ${_circuitBreaker.failureCount}');

    debugPrint('\nTEST 5: Service Metrics');
    _metrics.printReport();

    debugPrint('🔧 DIAGNOSTICS COMPLETE\n');
  }

  // ============================================================================
  // LOCAL DATABASE & ESTIMATION (keeping existing implementation)
  // ============================================================================

  static final Map<String, Map<String, dynamic>> _indianFoodDatabase = {
    'mixed meal': {'calories': 350, 'protein': 15.0, 'carbs': 45.0, 'fat': 12.0, 'fiber': 5.0},
    'thali': {'calories': 400, 'protein': 18.0, 'carbs': 55.0, 'fat': 14.0, 'fiber': 6.0},
    'roti': {'calories': 71, 'protein': 2.7, 'carbs': 15.7, 'fat': 0.4, 'fiber': 2.0},
    'chapati': {'calories': 71, 'protein': 2.7, 'carbs': 15.7, 'fat': 0.4, 'fiber': 2.0},
    'naan': {'calories': 262, 'protein': 8.7, 'carbs': 45.6, 'fat': 5.1, 'fiber': 2.2},
    'paratha': {'calories': 326, 'protein': 5.8, 'carbs': 37.6, 'fat': 17.8, 'fiber': 2.7},
    'dal': {'calories': 104, 'protein': 6.8, 'carbs': 16.3, 'fat': 0.9, 'fiber': 4.8},
    'dal tadka': {'calories': 120, 'protein': 6.8, 'carbs': 16.3, 'fat': 3.2, 'fiber': 4.8},
    'dal makhani': {'calories': 233, 'protein': 7.8, 'carbs': 21.2, 'fat': 13.2, 'fiber': 5.1},
    'rajma': {'calories': 140, 'protein': 7.6, 'carbs': 22.8, 'fat': 1.5, 'fiber': 6.3},
    'chole': {'calories': 210, 'protein': 8.4, 'carbs': 27.4, 'fat': 6.7, 'fiber': 7.2},
    'paneer butter masala': {'calories': 342, 'protein': 14.3, 'carbs': 9.8, 'fat': 28.1, 'fiber': 1.2},
    'palak paneer': {'calories': 284, 'protein': 12.4, 'carbs': 8.2, 'fat': 22.8, 'fiber': 3.4},
    'butter chicken': {'calories': 438, 'protein': 30.8, 'carbs': 14.0, 'fat': 28.1, 'fiber': 2.1},
    'chicken curry': {'calories': 243, 'protein': 25.9, 'carbs': 8.2, 'fat': 12.3, 'fiber': 1.8},
    'biryani': {'calories': 290, 'protein': 12.2, 'carbs': 38.3, 'fat': 9.5, 'fiber': 2.9},
    'pulao': {'calories': 205, 'protein': 4.3, 'carbs': 35.1, 'fat': 5.2, 'fiber': 1.8},
    'dosa': {'calories': 133, 'protein': 3.9, 'carbs': 28.3, 'fat': 0.7, 'fiber': 1.5},
    'masala dosa': {'calories': 165, 'protein': 4.5, 'carbs': 32.3, 'fat': 1.8, 'fiber': 2.5},
    'idli': {'calories': 58, 'protein': 2.1, 'carbs': 12.3, 'fat': 0.2, 'fiber': 0.8},
    'vada': {'calories': 97, 'protein': 3.1, 'carbs': 10.9, 'fat': 4.5, 'fiber': 1.3},
    'sambar': {'calories': 65, 'protein': 3.4, 'carbs': 11.5, 'fat': 0.6, 'fiber': 3.2},
    'rice': {'calories': 130, 'protein': 2.4, 'carbs': 28.7, 'fat': 0.3, 'fiber': 0.4},
    'samosa': {'calories': 262, 'protein': 3.5, 'carbs': 23.8, 'fat': 17.5, 'fiber': 2.1},
  };

  Future<Map<String, dynamic>> _analyzeWithLocalDatabase(String description) async {
    final lowerDesc = description.toLowerCase();
    final foods = <String>[];
    final quantities = <String, int>{};

    final sortedFoodNames = _indianFoodDatabase.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final foodName in sortedFoodNames) {
      if (lowerDesc.contains(foodName) && !foods.contains(foodName)) {
        foods.add(foodName);
        quantities[foodName] = 1;
      }
    }

    if (foods.isEmpty) {
      return {'success': false, 'foods': [], 'nutrition': {}};
    }

    int totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final food in foods) {
      final nutrition = _indianFoodDatabase[food]!;
      final quantity = quantities[food] ?? 1;

      totalCalories += (nutrition['calories'] as int) * quantity;
      totalProtein += (nutrition['protein'] as double) * quantity;
      totalCarbs += (nutrition['carbs'] as double) * quantity;
      totalFat += (nutrition['fat'] as double) * quantity;
    }

    return {
      'success': true,
      'foods': foods,
      'nutrition': {
        'calories': totalCalories,
        'protein': totalProtein.round(),
        'carbs': totalCarbs.round(),
        'fat': totalFat.round(),
      },
    };
  }

  Map<String, dynamic> _getEstimatedNutrition(String description) {
    final lowerDesc = description.toLowerCase();
    int baseCalories = 350;
    String foodCategory = 'Mixed meal';

    if (lowerDesc.contains('breakfast')) {
      baseCalories = 250;
      foodCategory = 'Breakfast';
    } else if (lowerDesc.contains('lunch') || lowerDesc.contains('dinner')) {
      baseCalories = 450;
      foodCategory = 'Main meal';
    } else if (lowerDesc.contains('snack')) {
      baseCalories = 150;
      foodCategory = 'Snack';
    }

    if (lowerDesc.contains('large') || lowerDesc.contains('full') || lowerDesc.contains('plate')) {
      baseCalories = (baseCalories * 1.5).round();
    } else if (lowerDesc.contains('small') || lowerDesc.contains('light')) {
      baseCalories = (baseCalories * 0.6).round();
    }

    final protein = (baseCalories * 0.20 / 4).round();
    final carbs = (baseCalories * 0.50 / 4).round();
    final fat = (baseCalories * 0.30 / 9).round();

    return {
      'success': true,
      'foods': [foodCategory],
      'nutrition': {
        'calories': baseCalories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      },
    };
  }

  // ============================================================================
  // HELPER METHODS FOR BACKWARD COMPATIBILITY
  // ============================================================================

  Future<Map<String, dynamic>> analyzeIndianFoodWithDetails(
    File imageFile,
    String foodName,
    String quantity,
  ) async {
    final description = '$quantity $foodName';
    return analyzeWithDescription(imageFile, description);
  }

  Future<Map<String, dynamic>> analyzeIndianFood(File imageFile) async {
    return analyzeWithDescription(imageFile, 'food item');
  }

  // Search for food by text query
  Future<Map<String, dynamic>> searchIndianFood(String query) async {
    final normalizedQuery = query.toLowerCase().trim();

    // Try exact match first
    if (_indianFoodDatabase.containsKey(normalizedQuery)) {
      final nutrition = _indianFoodDatabase[normalizedQuery]!;
      return {
        'success': true,
        'foods': [
          {'name': normalizedQuery, 'confidence': 0.9}
        ],
        'nutrition': {
          'calories': nutrition['calories'],
          'protein': (nutrition['protein'] as double).round(),
          'carbs': (nutrition['carbs'] as double).round(),
          'fat': (nutrition['fat'] as double).round(),
        },
        'source': 'Local Database',
      };
    }

    // Try partial matches
    final matches = <String>[];
    final words = normalizedQuery.split(' ');

    for (final foodName in _indianFoodDatabase.keys) {
      for (final word in words) {
        if (foodName.contains(word) && word.length > 2) {
          matches.add(foodName);
          break;
        }
      }
    }

    if (matches.isNotEmpty) {
      // Return first match
      final foodName = matches.first;
      final nutrition = _indianFoodDatabase[foodName]!;
      return {
        'success': true,
        'foods': [
          {'name': foodName, 'confidence': 0.7}
        ],
        'nutrition': {
          'calories': nutrition['calories'],
          'protein': (nutrition['protein'] as double).round(),
          'carbs': (nutrition['carbs'] as double).round(),
          'fat': (nutrition['fat'] as double).round(),
        },
        'source': 'Local Database (Partial Match)',
      };
    }

    // No match found - use estimation
    return _getEstimatedNutrition(query);
  }

  // Get all available food names for autocomplete
  List<String> getAllIndianFoods() {
    return _indianFoodDatabase.keys.toList()..sort();
  }

  // Get nutrition for specific food
  Map<String, dynamic>? getNutritionForFood(String foodName) {
    final normalized = foodName.toLowerCase().trim();
    return _indianFoodDatabase[normalized];
  }
}
