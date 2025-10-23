import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/streak_model.dart';
import '../services/supabase_service.dart';
import '../services/database_sync_service.dart';
import '../utils/streak_logger.dart';
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

  // Debouncing for sync operations
  DateTime? _lastSyncTime;
  static const Duration _syncCooldown = Duration(seconds: 30);
  bool _isSyncing = false;

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
        StreakLogger.logLoaded(
          currentStreak: _userStreak!.currentStreak,
          longestStreak: _userStreak!.longestStreak,
          source: 'database',
        );
      } else {
        // Create initial streak record
        _userStreak = UserStreak(userId: userId);
        await _createInitialStreak();
      }

      notifyListeners();
    } catch (e) {
      StreakLogger.logUpdateFailed('Failed to load streak data', e);
      _setError('Failed to load streak data');
    }
  }
  
  // Load today's metrics (nutrition-based)
  Future<void> loadTodayMetrics() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      // Use local timezone for date calculation
      final today = DateTime.now().toLocal();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get user's calorie target from profile
      final profileResponse = await _supabaseService.client
          .from('profiles')
          .select('daily_calories_target')
          .eq('id', userId)
          .maybeSingle();

      final caloriesGoal = profileResponse?['daily_calories_target'] ?? 2000;

      // Get today's nutrition entries
      final nutritionResponse = await _supabaseService.client
          .from('nutrition_entries')
          .select('calories')
          .eq('user_id', userId)
          .eq('date', dateStr);

      // Calculate total calories consumed
      int totalCalories = 0;
      if (nutritionResponse != null && (nutritionResponse as List).isNotEmpty) {
        totalCalories = (nutritionResponse as List)
            .fold<int>(0, (sum, entry) => sum + ((entry['calories'] as num?)?.toInt() ?? 0));
      }

      // Calculate if goal is achieved (80% - 110% of target)
      final minCalories = (caloriesGoal * 0.8).toInt();
      final maxCalories = (caloriesGoal * 1.1).toInt();
      final goalAchieved = totalCalories >= minCalories && totalCalories <= maxCalories;

      // Create today's metrics
      _todayMetrics = UserDailyMetrics(
        userId: userId,
        date: today,
        caloriesConsumed: totalCalories,
        caloriesGoal: caloriesGoal,
      );

      // Update goal achievement status
      _todayMetrics = _todayMetrics!.copyWith(
        nutritionAchieved: goalAchieved,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading today metrics: $e');
      _setError('Failed to load today\'s metrics');
    }
  }
  
  // Load recent metrics for history (nutrition-based)
  // UPDATED: Now uses daily_nutrition_summary table for better performance
  Future<void> loadRecentMetrics() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      // Get daily nutrition summaries from last 30 days (includes goal_achieved field)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final dateStr = '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';

      final response = await _supabaseService.client
          .from('daily_nutrition_summary')
          .select('date, total_calories, calorie_target, goal_achieved')
          .eq('user_id', userId)
          .gte('date', dateStr)
          .order('date', ascending: false);

      // Create metrics from daily summaries
      _recentMetrics = [];
      if (response != null && (response as List).isNotEmpty) {
        for (var summary in response as List) {
          final date = DateTime.parse(summary['date'] as String);
          final totalCalories = (summary['total_calories'] as num?)?.toInt() ?? 0;
          final caloriesGoal = (summary['calorie_target'] as num?)?.toInt() ?? 2000;
          final goalAchieved = summary['goal_achieved'] as bool? ?? false;

          _recentMetrics.add(UserDailyMetrics(
            userId: userId,
            date: date,
            caloriesConsumed: totalCalories,
            caloriesGoal: caloriesGoal,
          ).copyWith(nutritionAchieved: goalAchieved));
        }
      }

      // Sort by date descending
      _recentMetrics.sort((a, b) => b.date.compareTo(a.date));

      // Calculate current month's completed days
      _calculateMonthlyStats();

      StreakLogger.logLoaded(
        currentStreak: _userStreak?.currentStreak ?? 0,
        longestStreak: _userStreak?.longestStreak ?? 0,
        source: 'daily_nutrition_summary (${_recentMetrics.length} days)',
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recent metrics: $e');
      // Fallback to empty list instead of failing completely
      _recentMetrics = [];
    }
  }
  
  // Update metrics from nutrition provider only
  Future<void> syncMetricsFromProviders(
    NutritionProvider nutritionProvider,
    UserProvider userProvider,
  ) async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      final profile = userProvider.profile;
      if (profile == null) return;

      // Get calorie target
      final caloriesGoal = profile.dailyCaloriesTarget ?? 2000;

      // Get today's total calories from nutrition provider
      final totalCalories = nutritionProvider.todayNutrition.totalCalories;

      // Calculate if goal is achieved (80% - 110% of target)
      final minCalories = (caloriesGoal * 0.8).toInt();
      final maxCalories = (caloriesGoal * 1.1).toInt();
      final goalAchieved = totalCalories >= minCalories && totalCalories <= maxCalories;

      // Update today's metrics
      _todayMetrics = UserDailyMetrics(
        userId: userId,
        date: DateTime.now(),
        caloriesConsumed: totalCalories,
        caloriesGoal: caloriesGoal,
      ).copyWith(nutritionAchieved: goalAchieved);

      notifyListeners();

      // Check and update streak if goal achieved
      if (goalAchieved) {
        await checkAndUpdateStreak();
      }

    } catch (e) {
      debugPrint('Error syncing metrics: $e');
      _setError('Failed to sync metrics');
    }
  }
  
  // Note: Metrics are no longer saved to a separate table.
  // Nutrition data is stored in nutrition_entries table.
  // Streak data is stored in streaks table.
  // This method is removed as it's no longer needed.
  
  // Check and update streak
  Future<void> checkAndUpdateStreak() async {
    try {
      if (_todayMetrics == null || !_todayMetrics!.allGoalsAchieved) {
        return;
      }

      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      // The database trigger will handle streak updates
      // We just need to reload the streak data
      await loadUserStreak();

      // Show achievement notification
      _showStreakNotification();

    } catch (e) {
      debugPrint('Error updating streak: $e');
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
  
  // Note: Goal values are now retrieved from profiles table only
  
  // Save to local storage (nutrition data only)
  Future<void> _saveToLocal(UserDailyMetrics metrics) async {
    if (_prefs == null) return;

    final today = DateTime.now();
    final key = 'metrics_${today.year}_${today.month}_${today.day}';

    // Only save nutrition-related metrics
    await _prefs!.setInt('${key}_calories', metrics.caloriesConsumed);
    await _prefs!.setDouble('${key}_protein', metrics.protein);
    await _prefs!.setDouble('${key}_carbs', metrics.carbs);
    await _prefs!.setDouble('${key}_fat', metrics.fat);
    await _prefs!.setBool('${key}_achieved', metrics.allGoalsAchieved);

    // REMOVED: SharedPreferences streak writes - database is single source of truth
    // This was causing stale data to overwrite correct database values
  }
  
  // Setup realtime subscriptions
  void _setupRealtimeSubscriptions() {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) return;

    // Subscribe to nutrition entries changes
    _metricsSubscription = _supabaseService.client
        .channel('user_nutrition_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'nutrition_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('Nutrition entry updated: ${payload.newRecord}');
            // Reload today's metrics when nutrition changes
            loadTodayMetrics();
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
  
  // Note: Single metric updates are no longer supported.
  // All nutrition data is managed through nutrition_entries table.
  // Weight updates go through weight_entries table.
  
  // Get streak statistics with grace period information
  Map<String, dynamic> getStreakStats() {
    return {
      'current': _userStreak?.currentStreak ?? 0,
      'longest': _userStreak?.longestStreak ?? 0,
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
  
  /// Public refresh method for pull-to-refresh
  Future<void> refresh() async {
    await Future.wait([
      loadTodayMetrics(),
      loadUserStreak(),
      loadRecentMetrics(),
    ]);
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
    // Only count nutrition-based goals now
    int count = 0;
    if (_todayMetrics!.nutritionAchieved) count++;
    // Can add more nutrition-specific goals here (e.g., protein goal, fiber goal)
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

  // Get detailed monthly statistics (nutrition-based)
  Future<Map<String, dynamic>> getMonthlyStats({int? month, int? year}) async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return {};

      final now = DateTime.now().toLocal();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;

      // Get user's calorie target
      final profileResponse = await _supabaseService.client
          .from('profiles')
          .select('daily_calories_target')
          .eq('id', userId)
          .maybeSingle();

      final caloriesGoal = profileResponse?['daily_calories_target'] ?? 2000;

      // Get nutrition entries for the target month
      final startDate = DateTime(targetYear, targetMonth, 1);
      final endDate = DateTime(targetYear, targetMonth + 1, 0); // Last day of month
      final startDateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endDateStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

      final response = await _supabaseService.client
          .from('nutrition_entries')
          .select('date, calories')
          .eq('user_id', userId)
          .gte('date', startDateStr)
          .lte('date', endDateStr);

      // Group by date and calculate daily totals
      final Map<String, int> dailyCalories = {};
      int totalCalories = 0;
      if (response != null && (response as List).isNotEmpty) {
        for (var entry in response as List) {
          final date = entry['date'] as String;
          final calories = (entry['calories'] as num?)?.toInt() ?? 0;
          dailyCalories[date] = (dailyCalories[date] ?? 0) + calories;
          totalCalories += calories;
        }
      }

      // Calculate perfect days (80%-110% of target)
      final minCalories = (caloriesGoal * 0.8).toInt();
      final maxCalories = (caloriesGoal * 1.1).toInt();
      int perfectDays = 0;
      for (var dayTotal in dailyCalories.values) {
        if (dayTotal >= minCalories && dayTotal <= maxCalories) {
          perfectDays++;
        }
      }

      return {
        'month': targetMonth,
        'year': targetYear,
        'daysCompleted': perfectDays,
        'avgCalories': dailyCalories.isEmpty ? 0.0 : totalCalories / dailyCalories.length,
        'perfectDays': perfectDays,
        'totalDays': dailyCalories.length,
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