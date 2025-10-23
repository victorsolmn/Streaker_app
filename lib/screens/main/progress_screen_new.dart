import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/user_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/achievement_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/weight_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/circular_progress_widget.dart';
import '../../widgets/streak_display_widget.dart';
import '../../widgets/achievements/achievement_grid.dart';
import '../../widgets/streak_calendar_widget.dart';
import '../../widgets/milestone_progress_ring.dart';
import '../../widgets/modern_weight_chart.dart';
import '../../services/achievement_checker.dart';
import 'weight_details_screen.dart';

class ProgressScreenNew extends StatefulWidget {
  const ProgressScreenNew({Key? key}) : super(key: key);

  @override
  State<ProgressScreenNew> createState() => _ProgressScreenNewState();
}

class _ProgressScreenNewState extends State<ProgressScreenNew>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Data is loaded via provider initialization - no need for duplicate loads here
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Progress',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryAccent,
          labelColor: AppTheme.primaryAccent,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Progress'),
            Tab(text: 'Achievements'),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Consumer3<UserProvider, NutritionProvider, StreakProvider>(
          builder: (context, userProvider, nutritionProvider, streakProvider, child) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildProgressTab(userProvider, nutritionProvider, streakProvider),
                _buildAchievementsTab(userProvider, nutritionProvider, streakProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressTab(UserProvider userProvider, NutritionProvider nutritionProvider, StreakProvider streakProvider) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh nutrition and streak data only
        await Future.wait([
          streakProvider.refresh(),
          nutritionProvider.loadDataFromSupabase(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(20.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add StreakDisplayWidget at the top (contains grace period)
          const StreakDisplayWidget(isCompact: false),
          const SizedBox(height: 20),

          Text(
            'Today\'s Summary',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 20),

          // Today's Goals Checklist (Nutrition Only)
          _buildTodaysGoalsChecklist(nutritionProvider, streakProvider),
          const SizedBox(height: 24),

          // Centered Milestone Progress Ring - Main Feature (Moved to First)
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: const MilestoneProgressRing(size: 160, strokeWidth: 16),
            ),
          ),
          const SizedBox(height: 32),

          _buildWeeklyProgressChart(nutritionProvider, streakProvider),
          const SizedBox(height: 32),

          // Weight Progress Chart
          ModernWeightChart(
            isCompact: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WeightDetailsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAchievementsTab(UserProvider userProvider, NutritionProvider nutritionProvider, StreakProvider streakProvider) {
    // Check achievements when tab is viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AchievementChecker.checkAllAchievements(context);
    });

    return RefreshIndicator(
      onRefresh: () async {
        final achievementProvider = context.read<AchievementProvider>();
        await achievementProvider.loadAchievements();
        await AchievementChecker.checkAllAchievements(context);
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStreakStatsSection(streakProvider),
            const SizedBox(height: 32),
            _buildWeeklyPerformance(streakProvider, nutritionProvider),
            const SizedBox(height: 32),
            _buildMotivationalMessage(streakProvider),
            const SizedBox(height: 32),
            // Streak Calendar Widget
            const StreakCalendarWidget(),
            const SizedBox(height: 32),
            // Monthly Statistics Section (New)
            _buildMonthlyStats(streakProvider),
            const SizedBox(height: 32),
            // Replace old achievement badges with new AchievementGrid
            const AchievementGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysGoalsChecklist(NutritionProvider nutritionProvider, StreakProvider streakProvider) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Get nutrition goal achievement status from StreakProvider's todayMetrics
    final todayMetrics = streakProvider.todayMetrics;
    final nutritionAchieved = todayMetrics?.nutritionAchieved ?? false;

    // Get current nutrition stats
    final todayNutrition = nutritionProvider.todayNutrition;
    final caloriesConsumed = todayNutrition.totalCalories;
    final caloriesGoal = todayMetrics?.caloriesGoal ?? 2000;
    final proteinConsumed = todayNutrition.totalProtein;
    final proteinGoal = nutritionProvider.proteinGoal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Nutrition',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildGoalCheckItem(
            'Calorie Goal',
            caloriesConsumed >= caloriesGoal,
            Icons.local_fire_department,
            isDarkMode,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              '${caloriesConsumed.toInt()} / ${caloriesGoal.toInt()} cal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildGoalCheckItem(
            'Protein Goal',
            proteinConsumed >= proteinGoal,
            Icons.fitness_center,
            isDarkMode,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              '${proteinConsumed.toStringAsFixed(1)} / ${proteinGoal.toStringAsFixed(1)} g',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCheckItem(String label, bool achieved, IconData icon, bool isDarkMode) {
    return Row(
      children: [
        Icon(
          achieved ? Icons.check_circle : Icons.radio_button_unchecked,
          color: achieved ? AppTheme.successGreen : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          size: 24,
        ),
        const SizedBox(width: 12),
        Icon(
          icon,
          color: achieved ? AppTheme.primaryAccent : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: achieved
                ? Theme.of(context).colorScheme.onSurface
                : (isDarkMode ? Colors.grey[500] : Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyProgressChart(NutritionProvider nutritionProvider, StreakProvider streakProvider) {
    // Show only calories consumed (nutrition tracking)
    final consumedData = _generateWeeklyNutritionData(nutritionProvider);

    double maxValue = 0;
    for (final spot in consumedData) {
      if (spot.y > maxValue) maxValue = spot.y;
    }

    // Add padding to max value and round up to nearest 500
    maxValue = maxValue * 1.2; // Add 20% padding for better visibility
    final interval = maxValue > 3000 ? 500.0 : 250.0;
    final maxY = ((maxValue / interval).ceil() * interval).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Calorie Intake',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 200,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.borderColor,
                      strokeWidth: 1,
                    );
                  },
                ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      if (value.toInt() >= 0 && value.toInt() < days.length) {
                        return Text(
                          days[value.toInt()],
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: interval,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      // Show 0 and values at each interval
                      if (value == 0 || value % interval == 0) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                clipData: FlClipData.all(),
                lineBarsData: [
                  // Calories Consumed Line (Nutrition tracking)
                  LineChartBarData(
                    spots: consumedData,
                  isCurved: true,
                  color: AppTheme.primaryAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: AppTheme.primaryAccent,
                      strokeWidth: 2,
                      strokeColor: Theme.of(context).cardColor,
                    );
                  }),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primaryAccent.withOpacity(0.1),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Calories Consumed (from food intake)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _generateWeeklyNutritionData(NutritionProvider nutritionProvider) {
    final spots = <FlSpot>[];
    final now = DateTime.now();

    // Generate data for the last 7 days (nutrition consumption only)
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      double value = 0.0;

      // Get calories consumed data from nutrition provider
      final dayEntries = nutritionProvider.entries.where((entry) {
        return entry.timestamp.year == date.year &&
               entry.timestamp.month == date.month &&
               entry.timestamp.day == date.day;
      }).toList();

      // Sum up calories for that day
      for (final entry in dayEntries) {
        value += entry.calories.toDouble();
      }

      spots.add(FlSpot(i.toDouble(), value));
    }

    return spots;
  }



  Widget _buildStreakStatsSection(StreakProvider streakProvider) {
    final currentStreak = streakProvider.currentStreak;
    final bestStreak = streakProvider.longestStreak;
    final stats = streakProvider.getStreakStats();
    final goalsCompleted = stats['goalsCompleted'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Streak Statistics',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                value: currentStreak.toString(),
                label: 'Current\nstreak',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                value: bestStreak.toString(),
                label: 'Best\nstreak',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                value: goalsCompleted.toString(),
                label: 'Goals\ncompleted',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPerformance(StreakProvider streakProvider, NutritionProvider nutritionProvider) {
    final totalStreakDays = streakProvider.currentStreak;
    // Calculate weekly nutrition metrics
    final caloriesConsumedThisWeek = _calculateWeeklyCaloriesConsumed(nutritionProvider);
    final avgDailyProtein = _calculateAvgDailyProtein(nutritionProvider);
    // Calculate actual performance percentage
    final performancePercentage = _calculateWeeklyPerformance(streakProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress
          CircularProgressWidget(
            progress: performancePercentage / 100,
            size: 100,
            strokeWidth: 10,
            progressColor: AppTheme.primaryAccent,
            backgroundColor: AppTheme.borderColor,
            child: Text(
              '$performancePercentage%',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Performance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPerformanceItem('$totalStreakDays', 'Total streak days'),
                const SizedBox(height: 8),
                _buildPerformanceItem('${caloriesConsumedThisWeek.toStringAsFixed(0)}', 'Total calories consumed'),
                const SizedBox(height: 8),
                _buildPerformanceItem('${avgDailyProtein.toStringAsFixed(0)}g', 'Avg daily protein'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceItem(String value, String label) {
    return Row(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationalMessage(StreakProvider streakProvider) {
    final currentStreak = streakProvider.currentStreak;
    final daysToNextMilestone = _calculateDaysToNextMilestone(currentStreak);
    final message = streakProvider.getGracePeriodMessage();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryAccent.withOpacity(0.1),
            AppTheme.primaryAccent.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryAccent.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Text(
            '🔥',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message.isNotEmpty ? message :
              'You\'re on a $currentStreak-day streak! Just $daysToNextMilestone more days to the next milestone!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nutrition data calculation methods
  double _calculateWeeklyCaloriesConsumed(NutritionProvider nutritionProvider) {
    final now = DateTime.now();
    double totalCalories = 0.0;

    // Calculate calories consumed for the past 7 days
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dayEntries = nutritionProvider.entries.where((entry) {
        return entry.timestamp.year == date.year &&
               entry.timestamp.month == date.month &&
               entry.timestamp.day == date.day;
      }).toList();

      for (final entry in dayEntries) {
        totalCalories += entry.calories.toDouble();
      }
    }

    return totalCalories;
  }

  double _calculateAvgDailyProtein(NutritionProvider nutritionProvider) {
    final now = DateTime.now();
    double totalProtein = 0.0;
    int daysWithData = 0;

    // Calculate average protein for the past 7 days
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dayEntries = nutritionProvider.entries.where((entry) {
        return entry.timestamp.year == date.year &&
               entry.timestamp.month == date.month &&
               entry.timestamp.day == date.day;
      }).toList();

      if (dayEntries.isNotEmpty) {
        daysWithData++;
        for (final entry in dayEntries) {
          totalProtein += entry.protein;
        }
      }
    }

    return daysWithData > 0 ? totalProtein / daysWithData : 0.0;
  }

  int _calculateWeeklyPerformance(StreakProvider streakProvider) {
    // Calculate based on how many days goals were achieved this week
    final recentMetrics = streakProvider.recentMetrics;
    if (recentMetrics.isEmpty) return 0;

    int daysAchieved = 0;
    final now = DateTime.now();
    for (final metric in recentMetrics) {
      if (now.difference(metric.date).inDays < 7 && metric.allGoalsAchieved) {
        daysAchieved++;
      }
    }
    return ((daysAchieved / 7.0) * 100).round();
  }

  int _calculateDaysToNextMilestone(int currentStreak) {
    if (currentStreak < 7) return 7 - currentStreak;
    if (currentStreak < 30) return 30 - currentStreak;
    if (currentStreak < 100) return 100 - currentStreak;
    return (((currentStreak ~/ 100) + 1) * 100) - currentStreak;
  }

  Widget _buildGracePeriodWarning(StreakProvider streakProvider) {
    final remainingDays = streakProvider.remainingGraceDays;
    final isHighRisk = remainingDays <= 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighRisk
            ? AppTheme.errorRed.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighRisk
              ? AppTheme.errorRed.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHighRisk ? Icons.warning_rounded : Icons.info_outline_rounded,
            color: isHighRisk ? AppTheme.errorRed : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHighRisk ? 'Streak at Risk!' : 'Grace Period Active',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isHighRisk ? AppTheme.errorRed : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  streakProvider.getGracePeriodMessage(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          // Visual indicator of grace days
          Row(
            children: List.generate(2, (index) {
              final isUsed = index < streakProvider.graceDaysUsed;
              return Container(
                margin: const EdgeInsets.only(left: 4),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUsed
                      ? AppTheme.errorRed
                      : (isHighRisk && index == 1)
                          ? Colors.orange
                          : AppTheme.successGreen.withOpacity(0.5),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats(StreakProvider streakProvider) {
    return FutureBuilder<Map<String, dynamic>>(
      future: streakProvider.getMonthlyStats(),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Statistics',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildMonthlyStatsContent(snapshot),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyStatsContent(AsyncSnapshot<Map<String, dynamic>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading monthly statistics...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      );
    }

    if (snapshot.hasError) {
      return Column(
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.errorRed,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load monthly stats',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.errorRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() {}), // Trigger rebuild to retry
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return Column(
        children: [
          Icon(
            Icons.calendar_month,
            color: AppTheme.textSecondary,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No monthly data yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your daily goals to see monthly statistics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final stats = snapshot.data!;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMonthlyStatItem(
              'Days\nCompleted',
              '${stats['daysCompleted'] ?? 0}',
              Icons.calendar_month,
              AppTheme.primaryAccent,
            ),
            _buildMonthlyStatItem(
              'Perfect\nDays',
              '${stats['perfectDays'] ?? 0}',
              Icons.star,
              Colors.amber,
            ),
            _buildMonthlyStatItem(
              'Avg\nSleep',
              '${(stats['avgSleep'] ?? 0).toStringAsFixed(1)}h',
              Icons.bedtime,
              Colors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (stats['totalSteps'] != null && stats['totalSteps'] > 0) ...[
          Text(
            'Total Steps This Month',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(stats['totalSteps'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryAccent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMonthlyStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Removed old _buildAchievementBadges method as we're using AchievementGrid now

  // Removed old _buildAchievementCard method
  /*
  Widget _buildAchievementCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isUnlocked,
    bool isGold = false,
    bool isGrey = false,
  }) {
    Color bgColor;
    Color iconColor;
    
    if (isUnlocked) {
      if (isGold) {
        bgColor = Colors.orange.withOpacity(0.2);
        iconColor = Colors.orange;
      } else if (isGrey) {
        bgColor = Colors.grey.withOpacity(0.2);
        iconColor = Colors.grey[600]!;
      } else {
        bgColor = AppTheme.successGreen.withOpacity(0.2);
        iconColor = AppTheme.successGreen;
      }
    } else {
      bgColor = AppTheme.borderColor;
      iconColor = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? iconColor.withOpacity(0.3) : AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40, // Reduced icon container size
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20, // Reduced icon size
            ),
          ),
          const SizedBox(height: 8), // Reduced spacing
          Flexible( // Added Flexible to prevent text overflow
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith( // Changed to bodyMedium
                fontWeight: FontWeight.w600,
                fontSize: 13, // Explicit font size
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11, // Explicit smaller font size
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  */
}