import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/nutrition_provider.dart';

class UserContextBuilder {
  static Map<String, dynamic> buildComprehensiveContext(BuildContext buildContext) {
    final userProvider = Provider.of<UserProvider>(buildContext, listen: false);
    final nutritionProvider = Provider.of<NutritionProvider>(buildContext, listen: false);
    
    final profile = userProvider.profile;
    final streakData = userProvider.streakData;
    final todayNutrition = nutritionProvider.todayNutrition;
    final weeklyNutrition = <DailyNutrition>[]; // Weekly nutrition to be implemented
    
    // Build comprehensive context
    final context = <String, dynamic>{};
    
    // User Profile Information
    if (profile != null) {
      context['name'] = profile.name;
      context['age'] = profile.age;
      context['height'] = profile.height;
      context['weight'] = profile.weight;
      context['bmi'] = _calculateBMI(profile.height, profile.weight);
      context['goal'] = _formatGoal(profile.goal.toString());
      context['activityLevel'] = _formatActivityLevel(profile.activityLevel.toString());
      context['experienceLevel'] = _determineExperienceLevel(profile.activityLevel.toString());
    }
    
    // Streak and Consistency Data
    if (streakData != null) {
      context['currentStreak'] = streakData.currentStreak;
      context['longestStreak'] = streakData.longestStreak;
      context['totalDaysLogged'] = streakData.activityDates.length;
      context['consistency'] = _calculateConsistency(streakData);
    }
    
    // Today's Nutrition
    context['todayCalories'] = todayNutrition.totalCalories.round();
    context['todayProtein'] = todayNutrition.totalProtein.round();
    context['todayCarbs'] = todayNutrition.totalCarbs.round();
    context['todayFat'] = todayNutrition.totalFat.round();
    context['todayWater'] = 0; // Water tracking to be implemented
    
    // Nutrition Goals
    context['calorieGoal'] = nutritionProvider.calorieGoal.round();
    context['proteinGoal'] = nutritionProvider.proteinGoal.round();
    context['carbGoal'] = nutritionProvider.carbGoal.round();
    context['fatGoal'] = nutritionProvider.fatGoal.round();
    context['waterGoal'] = 8; // Default 8 glasses
    
    // Nutrition Progress
    context['calorieProgress'] = ((todayNutrition.totalCalories / nutritionProvider.calorieGoal) * 100).round();
    context['proteinProgress'] = ((todayNutrition.totalProtein / nutritionProvider.proteinGoal) * 100).round();
    context['carbProgress'] = ((todayNutrition.totalCarbs / nutritionProvider.carbGoal) * 100).round();
    context['fatProgress'] = ((todayNutrition.totalFat / nutritionProvider.fatGoal) * 100).round();
    context['waterProgress'] = 0; // Water tracking to be implemented
    
    // Weekly Nutrition Averages
    if (weeklyNutrition.isNotEmpty) {
      double avgCalories = 0;
      double avgProtein = 0;
      double avgCarbs = 0;
      double avgFat = 0;
      
      for (var day in weeklyNutrition) {
        avgCalories += day.totalCalories;
        avgProtein += day.totalProtein;
        avgCarbs += day.totalCarbs;
        avgFat += day.totalFat;
      }
      
      int days = weeklyNutrition.length;
      context['weeklyAvgCalories'] = (avgCalories / days).round();
      context['weeklyAvgProtein'] = (avgProtein / days).round();
      context['weeklyAvgCarbs'] = (avgCarbs / days).round();
      context['weeklyAvgFat'] = (avgFat / days).round();
    }
    
    // Health tracking has been removed from the app
    // Only nutrition tracking remains
    context['todaySteps'] = 0;
    context['stepsGoal'] = 0;
    
    // Time-based Context
    final now = DateTime.now();
    context['currentHour'] = now.hour;
    context['dayOfWeek'] = _getDayOfWeek(now.weekday);
    context['timeOfDay'] = _getTimeOfDay(now.hour);
    context['isWeekend'] = now.weekday == 6 || now.weekday == 7;
    
    // Meal timing context
    context['mealTime'] = _getMealTime(now.hour);
    context['shouldHydrate'] = _shouldRemindHydration(0, now.hour); // Water tracking to be implemented
    
    // Performance Insights
    context['nutritionAdherence'] = _calculateNutritionAdherence(
      todayNutrition.totalCalories.toDouble(),
      nutritionProvider.calorieGoal.toDouble(),
    );
    
    // Motivational Context
    context['needsMotivation'] = _needsMotivation(streakData?.currentStreak ?? 0);
    context['recentMilestone'] = _getRecentMilestone(streakData);
    
    return context;
  }
  
  static String generatePersonalizedSystemPrompt(Map<String, dynamic> context) {
    final name = context['name'] ?? 'User';
    final goal = context['goal'] ?? 'fitness';
    final currentStreak = context['currentStreak'] ?? 0;

    // Build CONCISE system prompt (optimized for speed)
    String systemPrompt = '''
Streaker AI Coach for $name. Keep responses under 200 words.

USER: $name, Goal: $goal, Streak: $currentStreak days
TODAY: ${context['todayCalories']}/${context['calorieGoal']}cal (${context['calorieProgress']}%), ${context['todayProtein']}g protein
STEPS: ${context['todaySteps'] ?? 0}/${context['stepsGoal'] ?? 10000}

RULES:
1. Answer the specific question only
2. Use their real data when relevant
3. Maximum 200 words
4. One clarifying question for vague queries
5. Be direct and actionable''';

    return systemPrompt;
  }
  
  // Helper Methods
  static double _calculateBMI(double height, double weight) {
    if (height <= 0 || weight <= 0) return 0;
    double heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }
  
  static String _formatGoal(String? goal) {
    if (goal == null) return 'general fitness';
    switch (goal) {
      case 'FitnessGoal.weightLoss':
        return 'weight loss';
      case 'FitnessGoal.muscleGain':
        return 'muscle gain';
      case 'FitnessGoal.maintenance':
        return 'fitness maintenance';
      case 'FitnessGoal.endurance':
        return 'endurance building';
      default:
        return 'general fitness';
    }
  }
  
  static String _formatActivityLevel(String? level) {
    if (level == null) return 'moderate';
    switch (level) {
      case 'ActivityLevel.sedentary':
        return 'sedentary';
      case 'ActivityLevel.lightlyActive':
        return 'lightly active';
      case 'ActivityLevel.moderatelyActive':
        return 'moderately active';
      case 'ActivityLevel.veryActive':
        return 'very active';
      case 'ActivityLevel.extremelyActive':
        return 'extremely active';
      default:
        return 'moderate';
    }
  }
  
  static String _determineExperienceLevel(String? activityLevel) {
    if (activityLevel == null) return 'intermediate';
    if (activityLevel.contains('sedentary') || activityLevel.contains('lightly')) {
      return 'beginner';
    } else if (activityLevel.contains('extremely') || activityLevel.contains('very')) {
      return 'advanced';
    }
    return 'intermediate';
  }
  
  static int _calculateConsistency(dynamic streakData) {
    if (streakData == null) return 0;
    int totalDays = streakData.activityDates?.length ?? 0;
    if (totalDays == 0) return 0;
    // Calculate based on current streak vs total activity days
    return ((streakData.currentStreak / (streakData.currentStreak + 7)) * 100).round().clamp(0, 100);
  }
  
  static String _getDayOfWeek(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }
  
  static String _getTimeOfDay(int hour) {
    if (hour < 6) return 'early morning';
    if (hour < 12) return 'morning';
    if (hour < 15) return 'afternoon';
    if (hour < 18) return 'late afternoon';
    if (hour < 21) return 'evening';
    return 'night';
  }
  
  static String _getMealTime(int hour) {
    if (hour >= 6 && hour < 10) return 'breakfast time';
    if (hour >= 10 && hour < 12) return 'mid-morning snack time';
    if (hour >= 12 && hour < 15) return 'lunch time';
    if (hour >= 15 && hour < 17) return 'afternoon snack time';
    if (hour >= 17 && hour < 20) return 'dinner time';
    if (hour >= 20 && hour < 22) return 'evening snack time';
    return 'outside typical meal times';
  }
  
  static bool _shouldRemindHydration(double currentWater, int hour) {
    // Remind if less than expected water intake for the time of day
    double expectedWater = (hour / 24.0) * 2.5; // Assuming 2.5L daily goal
    return currentWater < expectedWater * 0.8; // 80% of expected
  }
  
  static int _calculateNutritionAdherence(double actual, double goal) {
    if (goal <= 0) return 0;
    double ratio = actual / goal;
    // Perfect is 90-110% of goal
    if (ratio >= 0.9 && ratio <= 1.1) return 100;
    // Calculate adherence based on deviation
    double deviation = (ratio - 1.0).abs();
    return (100 - (deviation * 100)).round().clamp(0, 100);
  }
  
  static bool _needsMotivation(int currentStreak) {
    // Need motivation if streak is low or at risk
    return currentStreak < 3 || currentStreak % 7 == 6; // Day before weekly milestone
  }
  
  static String? _getRecentMilestone(dynamic streakData) {
    if (streakData == null) return null;
    int current = streakData.currentStreak ?? 0;
    
    if (current == 7) return '1 week streak!';
    if (current == 14) return '2 week streak!';
    if (current == 30) return '1 month streak!';
    if (current == 60) return '2 month streak!';
    if (current == 90) return '3 month streak!';
    if (current == 100) return '100 day streak!';
    if (current == 365) return '1 year streak!';
    
    return null;
  }
  
  // Removed unused methods _getGoalSpecificInstructions, _getExperienceLevelInstructions, and _getProgressFeedback
  // These were part of the verbose system prompt that has been optimized for speed
}