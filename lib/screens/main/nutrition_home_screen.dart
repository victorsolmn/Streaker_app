import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../providers/nutrition_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/streak_provider.dart';
import '../../config/theme_config.dart';
import '../../utils/app_theme.dart';
import 'profile_screen.dart';

class NutritionHomeScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;

  const NutritionHomeScreen({Key? key, this.onProfileTap}) : super(key: key);

  @override
  State<NutritionHomeScreen> createState() => _NutritionHomeScreenState();
}

class _NutritionHomeScreenState extends State<NutritionHomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final nutritionProvider = context.read<NutritionProvider>();
    final streakProvider = context.read<StreakProvider>();

    await Future.wait([
      nutritionProvider.loadTodayNutrition(),
      streakProvider.loadTodayMetrics(),
      streakProvider.loadUserStreak(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: ThemeConfig.primaryColor,
          child: CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: widget.onProfileTap,
                        child: Hero(
                          tag: 'profile_avatar',
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: ThemeConfig.primaryColor.withOpacity(0.15),
                            child: Icon(Icons.person, color: ThemeConfig.primaryColor, size: 20),
                          ),
                        ),
                      ),
                      Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimary,
                        ),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

              // Weekly Calendar
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: EdgeInsets.only(bottom: 16),
                  child: _buildWeeklyCalendar(),
                ),
              ),

              // Hero Section
              SliverToBoxAdapter(
                child: _buildHeroSection(),
              ),

              // Macro Breakdown
              SliverToBoxAdapter(
                child: _buildMacroBreakdown(),
              ),

              // Daily Food Log Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'Daily',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.textPrimary,
                    ),
                  ),
                ),
              ),

              // Food Log List
              _buildFoodLogList(),

              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyCalendar() {
    return Consumer<StreakProvider>(
      builder: (context, streakProvider, child) {
        final today = DateTime.now();

        // Calculate days from Sunday to today
        final daysFromSunday = today.weekday % 7; // Sunday = 0, Monday = 1, ..., Saturday = 6
        final sunday = today.subtract(Duration(days: daysFromSunday));

        final weekDays = List.generate(7, (index) {
          return sunday.add(Duration(days: index));
        });

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: weekDays.map((date) {
              final isToday = date.day == today.day &&
                             date.month == today.month &&
                             date.year == today.year;

              final hasStreak = streakProvider.recentMetrics.any((metric) =>
                metric.date.day == date.day &&
                metric.date.month == date.month &&
                metric.date.year == date.year &&
                metric.allGoalsAchieved
              );

              return _buildCalendarDay(
                date.weekday == 7 ? 'S' :  // Sunday
                date.weekday == 1 ? 'M' :
                date.weekday == 2 ? 'T' :
                date.weekday == 3 ? 'W' :
                date.weekday == 4 ? 'T' :
                date.weekday == 5 ? 'F' : 'S',  // Saturday
                date.day.toString(),
                isToday: isToday,
                hasStreak: hasStreak,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCalendarDay(String day, String date, {bool isToday = false, bool hasStreak = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            color: isToday ? ThemeConfig.primaryColor : ThemeConfig.textSecondary,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isToday ? ThemeConfig.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: hasStreak && !isToday
                ? Border.all(color: ThemeConfig.primaryColor, width: 1.5)
                : null,
          ),
          child: Center(
            child: Text(
              date,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isToday ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
        if (hasStreak && !isToday)
          Container(
            margin: EdgeInsets.only(top: 3),
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: ThemeConfig.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Consumer3<NutritionProvider, UserProvider, StreakProvider>(
      builder: (context, nutritionProvider, userProvider, streakProvider, child) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final profile = userProvider.profile;
        final caloriesTarget = profile?.dailyCaloriesTarget ?? 2000;
        final caloriesConsumed = nutritionProvider.todayNutrition.totalCalories;
        final caloriesLeft = caloriesTarget - caloriesConsumed;
        final progress = (caloriesConsumed / caloriesTarget).clamp(0.0, 1.0);
        final currentStreak = streakProvider.currentStreak;

        return Container(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left stat - Eaten
              Expanded(
                child: _buildStatColumn(
                  icon: Icons.restaurant,
                  iconColor: ThemeConfig.accentColor,
                  value: caloriesConsumed.toInt().toString(),
                  label: 'EATEN',
                ),
              ),

              // Center - Circular Progress
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(150, 150),
                      painter: CircularProgressPainter(
                        progress: 1.0,
                        color: ThemeConfig.primaryColor.withOpacity(0.1),
                        strokeWidth: 14,
                      ),
                    ),
                    CustomPaint(
                      size: Size(150, 150),
                      painter: CircularProgressPainter(
                        progress: progress,
                        color: ThemeConfig.primaryColor,
                        strokeWidth: 14,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_fire_department,
                             color: ThemeConfig.primaryColor, size: 26),
                        SizedBox(height: 4),
                        Text(
                          caloriesLeft > 0 ? caloriesLeft.toInt().toString() : '0',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'KCAL LEFT',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right stat - Current Streak
              Expanded(
                child: _buildStatColumn(
                  icon: Icons.local_fire_department,
                  iconColor: ThemeConfig.primaryColor,
                  value: currentStreak.toString(),
                  label: 'STREAK',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroBreakdown() {
    return Consumer2<NutritionProvider, UserProvider>(
      builder: (context, nutritionProvider, userProvider, child) {
        final nutrition = nutritionProvider.todayNutrition;
        final proteinGoal = nutritionProvider.proteinGoal;
        final carbGoal = nutritionProvider.carbGoal;
        final fatGoal = nutritionProvider.fatGoal;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMacroItem(
                'CARB',
                nutrition.totalCarbs,
                carbGoal,
                Color(0xFF4A90E2),
              ),
              SizedBox(width: 16),
              _buildMacroItem(
                'PROTEIN',
                nutrition.totalProtein,
                proteinGoal,
                Color(0xFF9B59B6),
              ),
              SizedBox(width: 16),
              _buildMacroItem(
                'FAT',
                nutrition.totalFat,
                fatGoal,
                ThemeConfig.primaryColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroItem(String label, double consumed, double goal, Color color) {
    final left = (goal - consumed).clamp(0, double.infinity);
    final progress = (consumed / goal).clamp(0.0, 1.0);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Progress bar at top
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          // Value with "left" inline
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${left.toInt()}g',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' left',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodLogList() {
    return Consumer<NutritionProvider>(
      builder: (context, nutritionProvider, child) {
        final entries = nutritionProvider.todayEntries;

        if (entries.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu,
                       size: 64,
                       color: ThemeConfig.textSecondary.withOpacity(0.3)),
                  SizedBox(height: 16),
                  Text(
                    'No meals logged yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: ThemeConfig.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to add your first meal',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeConfig.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final entry = entries[index];
              return _buildFoodLogItem(entry);
            },
            childCount: entries.length,
          ),
        );
      },
    );
  }

  Widget _buildFoodLogItem(dynamic entry) {
    // Get meal type icon
    String mealTypeEmoji = '🍽️';
    if (entry.foodName.toLowerCase().contains('breakfast')) {
      mealTypeEmoji = '🌅';
    } else if (entry.foodName.toLowerCase().contains('lunch')) {
      mealTypeEmoji = '🌮';
    } else if (entry.foodName.toLowerCase().contains('dinner')) {
      mealTypeEmoji = '🍝';
    } else if (entry.foodName.toLowerCase().contains('snack')) {
      mealTypeEmoji = '🍪';
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Food emoji/icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: ThemeConfig.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                mealTypeEmoji,
                style: TextStyle(fontSize: 32),
              ),
            ),
          ),
          SizedBox(width: 16),
          // Food details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getMealType(entry.timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeConfig.accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  entry.foodName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ThemeConfig.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Calories
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.calories.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.primaryColor,
                ),
              ),
              Text(
                'KCAL',
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeConfig.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMealType(DateTime timestamp) {
    final hour = timestamp.hour;
    if (hour < 11) return 'Breakfast';
    if (hour < 15) return 'Lunch';
    if (hour < 19) return 'Snack';
    return 'Dinner';
  }
}

// Custom painter for circular progress
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
