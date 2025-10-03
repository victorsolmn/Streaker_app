import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streak_provider.dart';
import '../providers/health_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/user_provider.dart';

class StreakChecklistWidget extends StatelessWidget {
  const StreakChecklistWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer4<StreakProvider, HealthProvider, NutritionProvider, UserProvider>(
      builder: (context, streakProvider, healthProvider, nutritionProvider, userProvider, child) {
        // Use provider data directly without waiting for todayMetrics
        final profile = userProvider.profile;

        // Build items directly from provider data
        final items = _buildChecklistItemsFromProviders(
          healthProvider,
          nutritionProvider,
          profile
        );
        final completedCount = items.where((item) => item.isCompleted).length;
        final mandatoryCompleted = items.where((item) => item.isCompleted && item.isMandatory).length;
        final isStreakSafe = mandatoryCompleted == 4; // All 4 mandatory goals

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              _buildHeader(completedCount, items.length, isStreakSafe),
              const SizedBox(height: 16),
              ...items.map((item) => _buildChecklistItem(context, item)),
              const SizedBox(height: 12),
              _buildStreakStatus(isStreakSafe, mandatoryCompleted),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildHeader(int completed, int total, bool isStreakSafe) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$completed of $total completed',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(BuildContext context, ChecklistItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: item.isCompleted
            ? const Color(0xFF00D68F).withOpacity(0.08)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isCompleted
              ? const Color(0xFF00D68F).withOpacity(0.3)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isCompleted
                  ? const Color(0xFF00D68F)
                  : Colors.white,
              border: Border.all(
                color: item.isCompleted
                    ? const Color(0xFF00D68F)
                    : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: item.isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          Icon(item.icon, size: 20, color: item.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.progress,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (!item.isCompleted)
            Text(
              item.remaining,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFFF6B1A),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStreakStatus(bool isStreakSafe, int mandatoryCompleted) {
    if (!isStreakSafe) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFAA00).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: const Color(0xFFFF6B1A),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Complete ${4 - mandatoryCompleted} more required goal${4 - mandatoryCompleted > 1 ? 's' : ''} to maintain your streak.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  List<ChecklistItem> _buildChecklistItemsFromProviders(
    HealthProvider healthProvider,
    NutritionProvider nutritionProvider,
    dynamic profile,
  ) {
    // Use default values if profile is null
    final stepsGoal = profile?.dailyStepsTarget ?? 10000;
    final caloriesGoal = profile?.dailyCaloriesTarget ?? 2000;
    final caloriesBurnedGoal = profile?.dailyActiveCaloriesTarget ?? 500;
    final sleepGoal = profile?.dailySleepTarget ?? 8.0;
    final waterGoal = profile?.dailyWaterTarget?.toInt() ?? 8;

    // Get data directly from providers
    final steps = healthProvider.todaySteps.toInt();
    final caloriesConsumed = nutritionProvider.todayNutrition.totalCalories;
    final caloriesBurned = healthProvider.todayCaloriesBurned.toInt();
    final sleep = healthProvider.todaySleep;
    final water = healthProvider.todayWater;

    return [
      ChecklistItem(
        title: 'Steps',
        icon: Icons.directions_walk,
        color: Colors.blue,
        progress: '$steps / $stepsGoal steps',
        remaining: '${(stepsGoal * 0.8 - steps).toInt()} left',
        isCompleted: steps >= (stepsGoal * 0.8),
        isMandatory: true,
      ),
      ChecklistItem(
        title: 'Calories In',
        icon: Icons.restaurant,
        color: Colors.orange,
        progress: '$caloriesConsumed / $caloriesGoal kcal',
        remaining: caloriesConsumed > caloriesGoal ? 'Over limit' : 'On track',
        isCompleted: caloriesConsumed <= (caloriesGoal * 1.2) && caloriesConsumed > 0,
        isMandatory: true,
      ),
      ChecklistItem(
        title: 'Calories Burned',
        icon: Icons.local_fire_department,
        color: Colors.red,
        progress: '$caloriesBurned / $caloriesBurnedGoal kcal',
        remaining: '${(caloriesBurnedGoal * 0.8 - caloriesBurned).toInt()} left',
        isCompleted: caloriesBurned >= (caloriesBurnedGoal * 0.8),
        isMandatory: true,
      ),
      ChecklistItem(
        title: 'Sleep',
        icon: Icons.bedtime,
        color: Colors.indigo,
        progress: '${sleep.toStringAsFixed(1)} / $sleepGoal hours',
        remaining: '${(sleepGoal * 0.7 - sleep).toStringAsFixed(1)}h left',
        isCompleted: sleep >= (sleepGoal * 0.7),
        isMandatory: true,
      ),
      ChecklistItem(
        title: 'Water',
        icon: Icons.water_drop,
        color: Colors.cyan,
        progress: '$water / $waterGoal glasses',
        remaining: '${waterGoal - water} left',
        isCompleted: water >= waterGoal,
        isMandatory: false,
      ),
    ];
  }
}

class ChecklistItem {
  final String title;
  final IconData icon;
  final Color color;
  final String progress;
  final String remaining;
  final bool isCompleted;
  final bool isMandatory;

  ChecklistItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.progress,
    required this.remaining,
    required this.isCompleted,
    required this.isMandatory,
  });
}