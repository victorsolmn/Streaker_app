import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/nutrition_provider.dart';
import '../providers/streak_provider.dart';

class DailyResetService {
  static final DailyResetService _instance = DailyResetService._internal();
  factory DailyResetService() => _instance;
  DailyResetService._internal();

  SharedPreferences? _prefs;
  Timer? _midnightTimer;
  String? _lastResetDate;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _lastResetDate = _prefs?.getString('last_reset_date');
    
    // Check if we need to reset today
    await _checkAndPerformDailyReset();
    
    // Set up automatic midnight reset
    _setupMidnightTimer();
    
    debugPrint('DailyResetService initialized. Last reset: $_lastResetDate');
  }

  Future<void> _checkAndPerformDailyReset() async {
    final today = _getTodayString();
    
    if (_lastResetDate != today) {
      debugPrint('Daily reset needed for $today (last reset: $_lastResetDate)');
      await _performDailyReset();
      
      // Update last reset date
      _lastResetDate = today;
      await _prefs?.setString('last_reset_date', today);
    }
  }

  Future<void> _performDailyReset() async {
    debugPrint('🔄 Performing daily reset...');
    
    try {
      // Reset SharedPreferences daily keys
      await _resetSharedPreferencesDaily();
      
      // The database doesn't need reset as it uses date-based queries
      // New day automatically shows fresh data
      
      debugPrint('✅ Daily reset completed successfully');
    } catch (e) {
      debugPrint('❌ Daily reset failed: $e');
    }
  }

  Future<void> _resetSharedPreferencesDaily() async {
    if (_prefs == null) return;

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    // Note: Health tracking has been removed from the app
    // Only nutrition tracking remains, which uses date-based queries
    // No daily reset needed for nutrition data

    debugPrint('SharedPreferences daily reset completed for $todayKey');
  }

  void _setupMidnightTimer() {
    _midnightTimer?.cancel();
    
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);
    
    debugPrint('⏰ Next daily reset scheduled in ${timeUntilMidnight.inHours}h ${timeUntilMidnight.inMinutes % 60}m');
    
    _midnightTimer = Timer(timeUntilMidnight, () {
      _performDailyReset();
      // Set up timer for next day
      _setupMidnightTimer();
    });
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // Manual reset for testing or force reset
  Future<void> forceReset() async {
    debugPrint('🔧 Force daily reset triggered');
    await _performDailyReset();
    await _prefs?.setString('last_reset_date', _getTodayString());
  }

  // Check if reset happened today
  bool get didResetToday {
    return _lastResetDate == _getTodayString();
  }

  // Get last reset date
  String? get lastResetDate => _lastResetDate;

  void dispose() {
    _midnightTimer?.cancel();
  }
}