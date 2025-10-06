import 'package:intl/intl.dart';

class UserDailyMetrics {
  final String? id;
  final String userId;
  final DateTime date;
  
  // Health Metrics
  final int steps;
  final int caloriesBurned;
  final int heartRate;
  final double sleepHours;
  final double distance;
  final int waterGlasses;
  final int workouts;
  
  // Nutrition Metrics
  final int caloriesConsumed;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  
  // Weight
  final double? weight;
  
  // Goals
  final int stepsGoal;
  final int caloriesGoal;
  final double sleepGoal;
  final int waterGoal;
  final double proteinGoal;
  
  // Achievement Flags
  final bool stepsAchieved;
  final bool caloriesAchieved;
  final bool sleepAchieved;
  final bool waterAchieved;
  final bool nutritionAchieved;
  final bool allGoalsAchieved;
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserDailyMetrics({
    this.id,
    required this.userId,
    required this.date,
    this.steps = 0,
    this.caloriesBurned = 0,
    this.heartRate = 0,
    this.sleepHours = 0,
    this.distance = 0,
    this.waterGlasses = 0,
    this.workouts = 0,
    this.caloriesConsumed = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.weight,
    this.stepsGoal = 10000,
    this.caloriesGoal = 2000,
    this.sleepGoal = 8.0,
    this.waterGoal = 8,
    this.proteinGoal = 50,
    this.stepsAchieved = false,
    this.caloriesAchieved = false,
    this.sleepAchieved = false,
    this.waterAchieved = false,
    this.nutritionAchieved = false,
    this.allGoalsAchieved = false,
    this.createdAt,
    this.updatedAt,
  });

  // Calculate if goals are achieved
  UserDailyMetrics calculateAchievements() {
    // 80% completion threshold for more achievable streaks
    final stepsAchieved = steps >= (stepsGoal * 0.8); // 80% of steps goal

    // Calories: Between 80% and 150% (flexible range matching backend)
    final caloriesAchieved = caloriesConsumed >= (caloriesGoal * 0.8) &&
                             caloriesConsumed <= (caloriesGoal * 1.5) &&
                             caloriesConsumed > 0;

    final sleepAchieved = sleepHours >= (sleepGoal * 0.8); // 80% of sleep goal
    final waterAchieved = waterGlasses >= waterGoal; // 100% of water goal
    final nutritionAchieved = caloriesConsumed > 0; // Has logged food

    // Requires ANY 4 out of 5 goals (matches backend logic)
    final goalsCount = (stepsAchieved ? 1 : 0) +
                       (caloriesAchieved ? 1 : 0) +
                       (sleepAchieved ? 1 : 0) +
                       (waterAchieved ? 1 : 0) +
                       (nutritionAchieved ? 1 : 0);

    final allGoalsAchieved = goalsCount >= 4; // Need 4 out of 5
    
    return copyWith(
      stepsAchieved: stepsAchieved,
      caloriesAchieved: caloriesAchieved,
      sleepAchieved: sleepAchieved,
      waterAchieved: waterAchieved,
      nutritionAchieved: nutritionAchieved,
      allGoalsAchieved: allGoalsAchieved,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'date': DateFormat('yyyy-MM-dd').format(date),
    'steps': steps,
    'calories_burned': caloriesBurned,
    'heart_rate': heartRate,
    'sleep_hours': sleepHours,
    'distance': distance,
    'water_glasses': waterGlasses,
    'workouts': workouts,
    'calories_consumed': caloriesConsumed,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    if (weight != null) 'weight': weight,
    'steps_goal': stepsGoal,
    'calories_goal': caloriesGoal,
    'sleep_goal': sleepGoal,
    'water_goal': waterGoal,
    'protein_goal': proteinGoal,
    'steps_achieved': stepsAchieved,
    'calories_achieved': caloriesAchieved,
    'sleep_achieved': sleepAchieved,
    'water_achieved': waterAchieved,
    'nutrition_achieved': nutritionAchieved,
    'all_goals_achieved': allGoalsAchieved,
  };

  factory UserDailyMetrics.fromJson(Map<String, dynamic> json) {
    return UserDailyMetrics(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      steps: json['steps'] ?? 0,
      caloriesBurned: json['calories_burned'] ?? 0,
      heartRate: json['heart_rate'] ?? 0,
      sleepHours: (json['sleep_hours'] ?? 0).toDouble(),
      distance: (json['distance'] ?? 0).toDouble(),
      waterGlasses: json['water_glasses'] ?? 0,
      workouts: json['workouts'] ?? 0,
      caloriesConsumed: json['calories_consumed'] ?? 0,
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
      weight: json['weight']?.toDouble(),
      stepsGoal: json['steps_goal'] ?? 10000,
      caloriesGoal: json['calories_goal'] ?? 2000,
      sleepGoal: (json['sleep_goal'] ?? 8.0).toDouble(),
      waterGoal: json['water_goal'] ?? 8,
      proteinGoal: (json['protein_goal'] ?? 50).toDouble(),
      stepsAchieved: json['steps_achieved'] ?? false,
      caloriesAchieved: json['calories_achieved'] ?? false,
      sleepAchieved: json['sleep_achieved'] ?? false,
      waterAchieved: json['water_achieved'] ?? false,
      nutritionAchieved: json['nutrition_achieved'] ?? false,
      allGoalsAchieved: json['all_goals_achieved'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  UserDailyMetrics copyWith({
    String? id,
    String? userId,
    DateTime? date,
    int? steps,
    int? caloriesBurned,
    int? heartRate,
    double? sleepHours,
    double? distance,
    int? waterGlasses,
    int? workouts,
    int? caloriesConsumed,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? weight,
    int? stepsGoal,
    int? caloriesGoal,
    double? sleepGoal,
    int? waterGoal,
    double? proteinGoal,
    bool? stepsAchieved,
    bool? caloriesAchieved,
    bool? sleepAchieved,
    bool? waterAchieved,
    bool? nutritionAchieved,
    bool? allGoalsAchieved,
  }) {
    return UserDailyMetrics(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      heartRate: heartRate ?? this.heartRate,
      sleepHours: sleepHours ?? this.sleepHours,
      distance: distance ?? this.distance,
      waterGlasses: waterGlasses ?? this.waterGlasses,
      workouts: workouts ?? this.workouts,
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      weight: weight ?? this.weight,
      stepsGoal: stepsGoal ?? this.stepsGoal,
      caloriesGoal: caloriesGoal ?? this.caloriesGoal,
      sleepGoal: sleepGoal ?? this.sleepGoal,
      waterGoal: waterGoal ?? this.waterGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      stepsAchieved: stepsAchieved ?? this.stepsAchieved,
      caloriesAchieved: caloriesAchieved ?? this.caloriesAchieved,
      sleepAchieved: sleepAchieved ?? this.sleepAchieved,
      waterAchieved: waterAchieved ?? this.waterAchieved,
      nutritionAchieved: nutritionAchieved ?? this.nutritionAchieved,
      allGoalsAchieved: allGoalsAchieved ?? this.allGoalsAchieved,
    );
  }

  double get goalsCompletionPercentage {
    int goalsCompleted = 0;
    if (stepsAchieved) goalsCompleted++;
    if (caloriesAchieved) goalsCompleted++;
    if (sleepAchieved) goalsCompleted++;
    if (waterAchieved) goalsCompleted++;
    if (nutritionAchieved) goalsCompleted++;
    return (goalsCompleted / 5.0) * 100;
  }
}

class UserStreak {
  final String? id;
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final int totalDaysCompleted;
  
  // Grace Period System (NEW)
  final int consecutiveMissedDays;
  final int graceDaysUsed;
  final int graceDaysAvailable;
  final DateTime? lastGraceResetDate;
  
  final DateTime? streakStartDate;
  final DateTime? lastCompletedDate;
  final DateTime? lastCheckedDate;
  final DateTime? lastAttemptedDate; // NEW: Last day user tried
  final int totalSteps;
  final int totalCaloriesBurned;
  final int totalWorkouts;
  final double averageSleep;
  final int perfectWeeks;
  final int perfectMonths;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserStreak({
    this.id,
    required this.userId,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalDaysCompleted = 0,
    
    // Grace Period fields
    this.consecutiveMissedDays = 0,
    this.graceDaysUsed = 0,
    this.graceDaysAvailable = 2,
    this.lastGraceResetDate,
    
    this.streakStartDate,
    this.lastCompletedDate,
    this.lastCheckedDate,
    this.lastAttemptedDate,
    this.totalSteps = 0,
    this.totalCaloriesBurned = 0,
    this.totalWorkouts = 0,
    this.averageSleep = 0,
    this.perfectWeeks = 0,
    this.perfectMonths = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isStreakActive {
    if (currentStreak == 0) return false;
    if (lastCompletedDate == null) return false;
    
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(
      lastCompletedDate!.year,
      lastCompletedDate!.month,
      lastCompletedDate!.day,
    );
    
    final daysSinceCompletion = todayDate.difference(lastDate).inDays;
    
    // Streak is active if:
    // 1. Completed today (daysSinceCompletion = 0)
    // 2. Within grace period and hasn't exceeded grace days available
    return daysSinceCompletion <= graceDaysAvailable;
  }
  
  // New getter for grace period status
  bool get isInGracePeriod {
    if (currentStreak == 0) return false;
    if (lastCompletedDate == null) return false;
    
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(
      lastCompletedDate!.year,
      lastCompletedDate!.month,
      lastCompletedDate!.day,
    );
    
    final daysSinceCompletion = todayDate.difference(lastDate).inDays;
    
    return daysSinceCompletion > 0 && daysSinceCompletion <= graceDaysAvailable;
  }
  
  // Get remaining grace days
  int get remainingGraceDays {
    return graceDaysAvailable - graceDaysUsed;
  }

  String get streakMessage {
    if (currentStreak == 0) {
      return "Start your streak today!";
    }
    
    // Check if in grace period
    if (isInGracePeriod) {
      return "$currentStreak days streak protected! ${remainingGraceDays} grace days left ⏳";
    }
    
    // Normal streak messages
    if (currentStreak == 1) {
      return "Great start! Keep it up!";
    } else if (currentStreak < 7) {
      return "$currentStreak days! Building momentum!";
    } else if (currentStreak < 30) {
      return "$currentStreak days! You're on fire! 🔥";
    } else if (currentStreak < 100) {
      return "$currentStreak days! Incredible dedication! 💪";
    } else {
      return "$currentStreak days! Legendary streak! 🏆";
    }
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'current_streak': currentStreak,
    'longest_streak': longestStreak,
    'total_days_completed': totalDaysCompleted,
    
    // Grace Period fields
    'consecutive_missed_days': consecutiveMissedDays,
    'grace_days_used': graceDaysUsed,
    'grace_days_available': graceDaysAvailable,
    if (lastGraceResetDate != null) 'last_grace_reset_date': DateFormat('yyyy-MM-dd').format(lastGraceResetDate!),
    
    if (streakStartDate != null) 'streak_start_date': DateFormat('yyyy-MM-dd').format(streakStartDate!),
    if (lastCompletedDate != null) 'last_completed_date': DateFormat('yyyy-MM-dd').format(lastCompletedDate!),
    if (lastCheckedDate != null) 'last_checked_date': DateFormat('yyyy-MM-dd').format(lastCheckedDate!),
    if (lastAttemptedDate != null) 'last_attempted_date': DateFormat('yyyy-MM-dd').format(lastAttemptedDate!),
    'total_steps': totalSteps,
    'total_calories_burned': totalCaloriesBurned,
    'total_workouts': totalWorkouts,
    'average_sleep': averageSleep,
    'perfect_weeks': perfectWeeks,
    'perfect_months': perfectMonths,
  };

  factory UserStreak.fromJson(Map<String, dynamic> json) {
    return UserStreak(
      id: json['id'],
      userId: json['user_id'],
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      totalDaysCompleted: json['total_days_completed'] ?? 0,
      
      // Grace Period fields
      consecutiveMissedDays: json['consecutive_missed_days'] ?? 0,
      graceDaysUsed: json['grace_days_used'] ?? 0,
      graceDaysAvailable: json['grace_days_available'] ?? 2,
      lastGraceResetDate: json['last_grace_reset_date'] != null ? DateTime.parse(json['last_grace_reset_date']) : null,
      
      streakStartDate: json['streak_start_date'] != null ? DateTime.parse(json['streak_start_date']) : null,
      lastCompletedDate: json['last_completed_date'] != null ? DateTime.parse(json['last_completed_date']) : null,
      lastCheckedDate: json['last_checked_date'] != null ? DateTime.parse(json['last_checked_date']) : null,
      lastAttemptedDate: json['last_attempted_date'] != null ? DateTime.parse(json['last_attempted_date']) : null,
      totalSteps: json['total_steps'] ?? 0,
      totalCaloriesBurned: json['total_calories_burned'] ?? 0,
      totalWorkouts: json['total_workouts'] ?? 0,
      averageSleep: (json['average_sleep'] ?? 0).toDouble(),
      perfectWeeks: json['perfect_weeks'] ?? 0,
      perfectMonths: json['perfect_months'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
}