import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';

class FitnessGoalsCard extends StatelessWidget {
  final UserProfile profile;

  const FitnessGoalsCard({
    Key? key,
    required this.profile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fitness Goals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),

          // Goals Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // First Row - Primary Goal & Activity
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactGoalItem(
                        context: context,
                        icon: Icons.flag_rounded,
                        label: 'Goal',
                        value: profile.fitnessGoal ?? 'Not set',
                        color: AppTheme.primaryAccent,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactGoalItem(
                        context: context,
                        icon: Icons.local_fire_department_rounded,
                        label: 'Activity',
                        value: _getShortActivityLevel(profile.activityLevel),
                        color: Colors.blue,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Second Row - Experience & Consistency
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactGoalItem(
                        context: context,
                        icon: Icons.star_rounded,
                        label: 'Experience',
                        value: _getShortExperienceLevel(profile.experienceLevel),
                        color: Colors.green,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactGoalItem(
                        context: context,
                        icon: Icons.calendar_today_rounded,
                        label: 'Consistency',
                        value: profile.workoutConsistency ?? 'Not set',
                        color: Colors.orange,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // BMI Section (if available)
          if (profile.height != null && profile.weight != null) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getBMIColor(profile.bmi).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.monitor_weight_outlined,
                      color: _getBMIColor(profile.bmi),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BMI',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              profile.bmi.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getBMIColor(profile.bmi),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getBMIColor(profile.bmi).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                profile.bmiCategory,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getBMIColor(profile.bmi),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactGoalItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? color.withOpacity(0.15)
            : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? color.withOpacity(0.3)
                  : color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getShortActivityLevel(String? level) {
    if (level == null) return 'Not set';
    if (level.toLowerCase().contains('sedentary')) return 'Sedentary';
    if (level.toLowerCase().contains('lightly')) return 'Light';
    if (level.toLowerCase().contains('moderately')) return 'Moderate';
    if (level.toLowerCase().contains('very')) return 'Very Active';
    if (level.toLowerCase().contains('extremely')) return 'Extreme';
    return level;
  }

  String _getShortExperienceLevel(String? level) {
    if (level == null) return 'Not set';
    if (level.toLowerCase().contains('beginner')) return 'Beginner';
    if (level.toLowerCase().contains('intermediate')) return 'Intermediate';
    if (level.toLowerCase().contains('advanced')) return 'Advanced';
    if (level.toLowerCase().contains('expert')) return 'Expert';
    return level;
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
}