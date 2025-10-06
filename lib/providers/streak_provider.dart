import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/streak_model.dart';
import '../services/supabase_service.dart';
import '../services/database_sync_service.dart';
import 'health_provider.dart';
import 'nutrition_provider.dart';
import 'user_provider.dart';

class StreakProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  SharedPreferences? _prefs;
  
  // Current user metrics and streak
  UserDailyMetrics? _todayMetrics;
  UserStreak? _userStreak;
  List<UserDailyMetrics> _recentMetrics = [];
  int _currentMonthCompletedDays = 0;
  
  // Loading states
  bool _isLoading = false;
  String? _error;
  
  // Realtime subscription
  RealtimeChannel? _metricsSubscription;
  RealtimeChannel? _streakSubscription;
  
  // Getters
  UserDailyMetrics? get todayMetrics => _todayMetrics;
  UserStreak? get userStreak => _userStreak;
  List<UserDailyMetrics> get recentMetrics => _recentMetrics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  int get currentStreak => _userStreak?.currentStreak ?? 0;
  int get longestStreak => _userStreak?.longestStreak ?? 0;
  bool get allGoalsAchievedToday => _todayMetrics?.allGoalsAchieved ?? false;
  double get todayProgress => _todayMetrics?.goalsCompletionPercentage ?? 0.0;
  
  // Grace Period Getters
  bool get isStreakActive => _userStreak?.isStreakActive ?? false;
  bool get isInGracePeriod => _userStreak?.isInGracePeriod ?? false;
  int get graceDaysUsed => _userStreak?.graceDaysUsed ?? 0;
  int get graceDaysAvailable => _userStreak?.graceDaysAvailable ?? 2;
  int get remainingGraceDays => _userStreak?.remainingGraceDays ?? 2;
  int get consecutiveMissedDays => _userStreak?.consecutiveMissedDays ?? 0;
  
  StreakProvider() {
    _init();
  }
  
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadUserStreak();
    await loadTodayMetrics();
    await loadRecentMetrics();
    _setupRealtimeSubscriptions();
  }
  
  // Load user's streak data
  Future<void> loadUserStreak() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;
      
      final response = await _supabaseService.client
          .from('streaks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null) {
        _userStreak = UserStreak.fromJson(response);
      } else {
        // Create initial streak record
        _userStreak = UserStreak(userId: userId);
        await _createInitialStreak();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading streak: $e');
      _setError('Failed to load streak data');
    }
  }
  
  // Load today's metrics
  Future<void> loadTodayMetrics() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      // Use local timezone for date calculation
      final today = DateTime.now().toLocal();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await _supabaseService.client
          .from('health_metrics')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr)
          .maybeSingle();
      
      if (response != null) {
        _todayMetrics = UserDailyMetrics.fromJson(response);
      } else {
        // Create today's metrics with default values
        _todayMetrics = UserDailyMetrics(
          userId: userId,
          date: today,
          stepsGoal: await _getGoalValue('steps') ?? 10000,
          caloriesGoal: await _getGoalValue('calories') ?? 2000,
          sleepGoal: await _getGoalValue('sleep') ?? 8.0,
          waterGoal: await _getGoalValue('water') ?? 8,
          proteinGoal: await _getGoalValue('protein') ?? 50,
        );
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading today metrics: $e');
      _setError('Failed to load today\'s metrics');
    }
  }
  
  // Load recent metrics for history
  Future<void> loadRecentMetrics() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      final response = await _supabaseService.client
          .from('health_metrics')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(30);

      _recentMetrics = (response as List)
          .map((json) => UserDailyMetrics.fromJson(json))
          .toList();

      // Calculate current month's completed days
      _calculateMonthlyStats();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recent metrics: $e');
    }
  }
  
  // Update metrics from health and nutrition providers
  Future<void> syncMetricsFromProviders(
    HealthProvider healthProvider,
    NutritionProvider nutritionProvider,
    UserProvider userProvider,
  ) async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;
      
      final profile = userProvider.profile;
      if (profile == null) return;
      
      // Get current metrics or create new
      final today = DateTime.now();
      final metrics = _todayMetrics ?? UserDailyMetrics(
        userId: userId,
        date: today,
      );
      
      // Update with health data
      final updatedMetrics = metrics.copyWith(
        steps: healthProvider.todaySteps.toInt(),
        caloriesBurned: healthProvider.todayCaloriesBurned.toInt(),
        heartRate: healthProvider.todayHeartRate.toInt(),
        sleepHours: healthProvider.todaySleep,
        distance: healthProvider.todayDistance,
        waterGlasses: healthProvider.todayWater,
        workouts: healthProvider.todayWorkouts,
        
        // Update with nutrition data from today's entries
        caloriesConsumed: nutritionProvider.todayNutrition.totalCalories,
        protein: nutritionProvider.todayNutrition.totalProtein,
        carbs: nutritionProvider.todayNutrition.totalCarbs,
        fat: nutritionProvider.todayNutrition.totalFat,
        fiber: nutritionProvider.todayNutrition.totalFiber,
        
        // Update with user goals
        stepsGoal: profile.dailyStepsTarget ?? 10000,
        caloriesGoal: profile.dailyCaloriesTarget ?? 2000,
        sleepGoal: profile.dailySleepTarget ?? 8.0,
        waterGoal: profile.dailyWaterTarget?.toInt() ?? 8,
        proteinGoal: nutritionProvider.proteinGoal.toDouble(),
        
        // Update weight if available
        weight: profile.weight,
      );
      
      // Calculate achievements
      final finalMetrics = updatedMetrics.calculateAchievements();

      // Save to Supabase
      await saveMetrics(finalMetrics);

      // Trigger database sync to ensure everything is calculated correctly
      // This will aggregate nutrition, recalculate goals, and update streaks
      final dbSync = DatabaseSyncService();
      await dbSync.syncToday();

      // Reload updated data
      await loadUserStreak();
      await loadTodayMetrics();
      
    } catch (e) {
      debugPrint('Error syncing metrics: $e');
      _setError('Failed to sync metrics');
    }
  }
  
  // Save metrics to Supabase
  Future<void> saveMetrics(UserDailyMetrics metrics) async {
    try {
      _setLoading(true);
      
      final data = metrics.toJson();
      
      final response = await _supabaseService.client
          .from('health_metrics')
          .upsert(
            data,
            onConflict: 'user_id,date',
          )
          .select()
          .single();
      
      _todayMetrics = UserDailyMetrics.fromJson(response);
      
      // Save to local storage as well
      await _saveToLocal(metrics);
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving metrics: $e');
      _setError('Failed to save metrics');
      _setLoading(false);
    }
  }
  
  // Check and update streak
  Future<void> checkAndUpdateStreak() async {
    try {
      if (_todayMetrics == null || !_todayMetrics!.allGoalsAchieved) {
        debugPrint('⚠️ Streak not updated: goals not achieved');
        return;
      }

      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      debugPrint('🔥 All goals achieved! Triggering streak update...');

      // Use database function to ensure proper calculation
      final dbSync = DatabaseSyncService();
      final result = await dbSync.syncToday();

      if (result != null) {
        // Update local data from database result
        if (result['streak'] != null) {
          _userStreak = UserStreak.fromJson(result['streak']);
          debugPrint('✅ Streak updated via database: ${_userStreak?.currentStreak} days');
        }

        if (result['health_metrics'] != null) {
          _todayMetrics = UserDailyMetrics.fromJson(result['health_metrics']);
        }

        // Show achievement notification
        _showStreakNotification();

        notifyListeners();
      } else {
        // Fallback: reload from database
        debugPrint('⚠️ Database sync returned null, falling back to reload');
        await loadUserStreak();
      }

    } catch (e) {
      debugPrint('❌ Error updating streak: $e');
      // Try fallback reload
      try {
        await loadUserStreak();
      } catch (e2) {
        debugPrint('❌ Fallback reload also failed: $e2');
      }
    }
  }
  
  // Create initial streak record
  Future<void> _createInitialStreak() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;
      
      final response = await _supabaseService.client
          .from('streaks')
          .insert({
            'user_id': userId,
            'current_streak': 0,
            'longest_streak': 0,
            'total_days_completed': 0,
          })
          .select()
          .single();
      
      _userStreak = UserStreak.fromJson(response);
    } catch (e) {
      debugPrint('Error creating initial streak: $e');
    }
  }
  
  // Get goal value from user settings
  Future<dynamic> _getGoalValue(String goalType) async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return null;
      
      final response = await _supabaseService.client
          .from('user_goals')
          .select('daily_${goalType}_goal')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response?['daily_${goalType}_goal'];
    } catch (e) {
      return null;
    }
  }
  
  // Save to local storage
  Future<void> _saveToLocal(UserDailyMetrics metrics) async {
    if (_prefs == null) return;
    
    final today = DateTime.now();
    final key = 'metrics_${today.year}_${today.month}_${today.day}';
    
    await _prefs!.setInt('${key}_steps', metrics.steps);
    await _prefs!.setInt('${key}_calories', metrics.caloriesConsumed);
    await _prefs!.setDouble('${key}_sleep', metrics.sleepHours);
    await _prefs!.setInt('${key}_water', metrics.waterGlasses);
    await _prefs!.setBool('${key}_achieved', metrics.allGoalsAchieved);
    
    // Save current streak
    await _prefs!.setInt('current_streak', _userStreak?.currentStreak ?? 0);
    await _prefs!.setInt('longest_streak', _userStreak?.longestStreak ?? 0);
  }
  
  // Setup realtime subscriptions
  void _setupRealtimeSubscriptions() {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) return;
    
    // Subscribe to metrics changes
    _metricsSubscription = _supabaseService.client
        .channel('user_metrics_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'health_metrics',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('Metrics updated: ${payload.newRecord}');
            if (payload.newRecord != null) {
              final metrics = UserDailyMetrics.fromJson(payload.newRecord!);
              if (_isTodayMetrics(metrics)) {
                _todayMetrics = metrics;
                notifyListeners();
              }
            }
          },
        )
        .subscribe();
    
    // Subscribe to streak changes
    _streakSubscription = _supabaseService.client
        .channel('user_streak_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'streaks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('Streak updated: ${payload.newRecord}');
            if (payload.newRecord != null) {
              _userStreak = UserStreak.fromJson(payload.newRecord!);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }
  
  // Check if metrics are for today
  bool _isTodayMetrics(UserDailyMetrics metrics) {
    final today = DateTime.now();
    return metrics.date.year == today.year &&
           metrics.date.month == today.month &&
           metrics.date.day == today.day;
  }
  
  // Show streak notification
  void _showStreakNotification() {
    // This will be handled by the UI layer
    debugPrint('🔥 Streak updated: ${_userStreak?.currentStreak} days!');
  }
  
  // Update single metric
  Future<void> updateSingleMetric(String metricType, dynamic value) async {
    if (_todayMetrics == null) return;
    
    UserDailyMetrics updated;
    switch (metricType) {
      case 'water':
        updated = _todayMetrics!.copyWith(waterGlasses: value as int);
        break;
      case 'weight':
        updated = _todayMetrics!.copyWith(weight: value as double);
        break;
      case 'workouts':
        updated = _todayMetrics!.copyWith(workouts: value as int);
        break;
      default:
        return;
    }
    
    await saveMetrics(updated.calculateAchievements());
  }
  
  // Get streak statistics with grace period information
  Map<String, dynamic> getStreakStats() {
    return {
      'current': _userStreak?.currentStreak ?? 0,
      'longest': _userStreak?.longestStreak ?? 0,
      'total': _userStreak?.totalDaysCompleted ?? 0,
      'isActive': _userStreak?.isStreakActive ?? false,
      'isInGracePeriod': _userStreak?.isInGracePeriod ?? false,
      'graceDaysUsed': _userStreak?.graceDaysUsed ?? 0,
      'graceDaysAvailable': _userStreak?.graceDaysAvailable ?? 2,
      'remainingGraceDays': _userStreak?.remainingGraceDays ?? 2,
      'consecutiveMissedDays': _userStreak?.consecutiveMissedDays ?? 0,
      'message': _userStreak?.streakMessage ?? 'Start your streak!',
      'todayProgress': todayProgress,
      'goalsCompleted': _getGoalsCompletedCount(),
      'currentMonthDays': _currentMonthCompletedDays,
    };
  }
  
  // Get grace period status message
  String getGracePeriodMessage() {
    if (!isInGracePeriod || currentStreak == 0) {
      return '';
    }
    
    if (remainingGraceDays == 2) {
      return "Don't worry! You have 2 grace days to get back on track 💪";
    } else if (remainingGraceDays == 1) {
      return "Last chance! Complete your goals today to save your ${currentStreak}-day streak ⚠️";
    } else {
      return "Grace period used up. Complete goals today or lose your streak! ⚠️";
    }
  }
  
  // Check if user is at risk of losing streak
  bool get isStreakAtRisk {
    return isInGracePeriod && remainingGraceDays <= 1;
  }
  
  int _getGoalsCompletedCount() {
    if (_todayMetrics == null) return 0;
    int count = 0;
    if (_todayMetrics!.stepsAchieved) count++;
    if (_todayMetrics!.caloriesAchieved) count++;
    if (_todayMetrics!.sleepAchieved) count++;
    if (_todayMetrics!.waterAchieved) count++;
    if (_todayMetrics!.nutritionAchieved) count++;
    return count;
  }

  // Calculate monthly statistics from recent metrics
  void _calculateMonthlyStats() {
    final now = DateTime.now().toLocal();
    final currentMonth = now.month;
    final currentYear = now.year;

    _currentMonthCompletedDays = _recentMetrics.where((metric) {
      return metric.date.month == currentMonth &&
             metric.date.year == currentYear &&
             metric.allGoalsAchieved;
    }).length;
  }

  // Get detailed monthly statistics
  Future<Map<String, dynamic>> getMonthlyStats({int? month, int? year}) async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return {};

      final now = DateTime.now().toLocal();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;

      // Query monthly stats using the database function
      final response = await _supabaseService.client
          .rpc('get_user_monthly_stats', params: {
            'p_user_id': userId,
            'p_month': targetMonth,
            'p_year': targetYear,
          });

      if (response != null && (response as List).isNotEmpty) {
        final stats = response[0];
        return {
          'month': stats['month'] ?? targetMonth,
          'year': stats['year'] ?? targetYear,
          'daysCompleted': stats['days_completed'] ?? 0,
          'totalSteps': stats['total_steps'] ?? 0,
          'avgCalories': stats['avg_calories'] ?? 0.0,
          'avgSleep': stats['avg_sleep'] ?? 0.0,
          'perfectDays': stats['perfect_days'] ?? 0,
        };
      }

      return {
        'month': targetMonth,
        'year': targetYear,
        'daysCompleted': 0,
        'totalSteps': 0,
        'avgCalories': 0.0,
        'avgSleep': 0.0,
        'perfectDays': 0,
      };
    } catch (e) {
      debugPrint('Error getting monthly stats: $e');
      // Fallback to local calculation
      return {
        'month': month ?? DateTime.now().month,
        'year': year ?? DateTime.now().year,
        'daysCompleted': _currentMonthCompletedDays,
        'perfectDays': _currentMonthCompletedDays,
      };
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _metricsSubscription?.unsubscribe();
    _streakSubscription?.unsubscribe();
    super.dispose();
  }
}