import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import '../../providers/user_provider.dart';
import '../../providers/supabase_user_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/fitness_goal_summary_dialog.dart';
import '../../widgets/streak_display_widget.dart';
import '../../widgets/sync_status_indicator.dart';
import '../../providers/streak_provider.dart';
import '../../widgets/loading/app_shimmer.dart';
import 'dart:math' as math;

class HomeScreenClean extends StatefulWidget {
  const HomeScreenClean({Key? key}) : super(key: key);

  @override
  State<HomeScreenClean> createState() => _HomeScreenCleanState();
}

class _HomeScreenCleanState extends State<HomeScreenClean>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<UserProvider>(context, listen: false).logActivity();

      // Force reload profile from Supabase to get correct values
      final supabaseUserProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
      await supabaseUserProvider.reloadUserProfile();
      if (kDebugMode) {
        debugPrint('🔄 Force reloaded profile from Supabase');
        debugPrint('   dailyActiveCaloriesTarget: ${supabaseUserProvider.userProfile?.dailyActiveCaloriesTarget}');
      }

      // Force reload nutrition data from Supabase
      final nutritionProv = Provider.of<NutritionProvider>(context, listen: false);
      await nutritionProv.loadDataFromSupabase();
      if (kDebugMode) {
        debugPrint('🔄 Nutrition entries loaded: ${nutritionProv.entries.length}');
        debugPrint('   Today calories: ${nutritionProv.todayNutrition.totalCalories}');
      }

      await _initializeHealthData();
      _checkAndShowFitnessGoalSummary();
    });
  }

  Future<void> _initializeHealthData() async {
    // Sync metrics to streak provider only once
    await _syncMetricsToStreak();

    // Note: Health initialization and syncing is already handled by MainScreen
    // We only need to ensure the provider is initialized
    final healthProvider = Provider.of<HealthProvider>(context, listen: false);
    if (!healthProvider.isInitialized) {
      await healthProvider.initialize();
    }

    // Don't sync here - MainScreen already handles this
    debugPrint('Home page: Health data ready - Steps: ${healthProvider.todaySteps}, Calories: ${healthProvider.todayCaloriesBurned}');
  }

  Future<void> _checkAndShowFitnessGoalSummary() async {
    await Future.delayed(Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final profile = userProvider.profile;
    
    // Only show dialog if user just completed onboarding and hasn't seen the summary yet
    if (profile != null && 
        userProvider.justCompletedOnboarding && 
        !profile.hasSeenFitnessGoalSummary) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => FitnessGoalSummaryDialog(
          onAgree: () async {
            await userProvider.updateProfile(
              hasSeenFitnessGoalSummary: true,
            );
            // Clear the temporary flag after showing the dialog
            userProvider.clearJustCompletedOnboardingFlag();
          },
        ),
      );
    }
  }


  Future<void> _syncMetricsToStreak() async {
    final streakProvider = Provider.of<StreakProvider>(context, listen: false);
    final healthProvider = Provider.of<HealthProvider>(context, listen: false);
    final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Sync all metrics to streak provider
    await streakProvider.syncMetricsFromProviders(
      healthProvider,
      nutritionProvider,
      userProvider,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Consumer4<UserProvider, HealthProvider, NutritionProvider, StreakProvider>(
            builder: (context, userProvider, healthProvider, nutritionProvider, streakProvider, child) {
              // Note: Do NOT call _syncMetricsToStreak() here - it causes infinite rebuilds
              // Sync is already handled in initState and _initializeHealthData
              final bool isLoadingHealth = !healthProvider.isInitialized;
              final bool hasNoData = healthProvider.isInitialized &&
                  healthProvider.todaySteps == 0 &&
                  healthProvider.todayCaloriesBurned == 0;

              return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personalized Greeting
                    _buildGreeting(userProvider, isDarkMode),

                    const SizedBox(height: 20),

                    // Steps Circle and Streak Icons Row — shimmer while loading
                    isLoadingHealth
                        ? const HomeTopSectionShimmer()
                        : _buildTopSection(healthProvider, nutritionProvider, streakProvider, isDarkMode),

                    const SizedBox(height: 16),

                    // Motivational message
                    Center(
                      child: Text(
                        'Every step counts towards your fitness journey!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Metrics Grid — shimmer while loading
                    isLoadingHealth
                        ? const HomeMetricsShimmer()
                        : _buildMetricsGrid(healthProvider, nutritionProvider, isDarkMode),

                    // Empty state — shown when health is initialized but no data
                    if (!isLoadingHealth && hasNoData) ...[
                      const SizedBox(height: 20),
                      _buildNoDataBanner(isDarkMode),
                    ],

                    const SizedBox(height: 32),

                    // Your Insights Section
                    _buildInsightsSection(healthProvider, nutritionProvider, userProvider, isDarkMode),
                  ],
                  ),
                );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(UserProvider userProvider, bool isDarkMode) {
    final profile = userProvider.profile;
    String userName = profile?.name ?? '';

    // If name is empty or just whitespace, fallback to 'User'
    if (userName.trim().isEmpty) {
      userName = 'User';
    }

    // Get first name from full name
    String displayName = userName.split(' ').first;

    // Handle long names - truncate if needed
    if (displayName.length > 15) {
      displayName = displayName.substring(0, 14) + '...';
    }

    // Get time-based greeting
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello $displayName 👋',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                greeting,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Sync status indicator removed - already shown in main_screen.dart
        // to avoid duplicate indicators
      ],
    );
  }

  Widget _buildTopSection(HealthProvider healthProvider, NutritionProvider nutritionProvider, StreakProvider streakProvider, bool isDarkMode) {
    final supabaseUserProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    final profile = supabaseUserProvider.userProfile;

    final steps = healthProvider.todaySteps.toInt();
    final stepsGoal = profile?.dailyStepsTarget ?? 10000;
    final progress = (steps / stepsGoal).clamp(0.0, 1.0);

    // Get streak data
    final currentStreak = streakProvider.currentStreak;
    final recordStreak = streakProvider.longestStreak;

    // Calculate progress for the streak circle (current/record or 1.0 if current equals record)
    final streakProgress = recordStreak > 0 ? (currentStreak / recordStreak).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Current Streak
          Flexible(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$currentStreak',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' days',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Text(
                  'Current Streak',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Record Streak Circle
          Container(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(140, 140),
                  painter: CircularProgressPainter(
                    progress: streakProgress,
                    backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                    progressColor: Colors.orange,
                    strokeWidth: 10,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recordStreak.toString(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Record Streak',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Steps counter
          Flexible(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedFlipCounter(
                      value: steps,
                      duration: const Duration(milliseconds: 800),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.directions_walk,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ],
                ),
                Text(
                  '/$stepsGoal',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(HealthProvider healthProvider, NutritionProvider nutritionProvider, bool isDarkMode) {
    final supabaseUserProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    final profile = supabaseUserProvider.userProfile;

    if (kDebugMode) {
      debugPrint('🔍 DEBUG: Calories Card - profile exists: ${profile != null}');
    }

    final caloriesGoal = profile?.dailyActiveCaloriesTarget ?? 2000;
    final sleepGoal = profile?.dailySleepTarget ?? 8.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Calories',
                icon: Icons.local_fire_department,
                iconColor: Colors.orange,
                value: '${healthProvider.todayTotalCalories.toInt()}',
                target: caloriesGoal.toString(),
                unit: 'kcal',
                showTarget: true,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                title: 'Avg Heart Rate',
                icon: Icons.favorite,
                iconColor: Colors.red,
                value: healthProvider.todayHeartRate.toInt().toString(),
                unit: 'bpm',
                statusText: _getHeartRateStatus(healthProvider.todayHeartRate.toInt()),
                statusColor: _getHeartRateStatusColor(healthProvider.todayHeartRate.toInt()),
                showTarget: false,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Sleep',
                icon: Icons.bedtime,
                iconColor: Colors.purple,
                value: healthProvider.todaySleep.toStringAsFixed(1),
                target: sleepGoal.toStringAsFixed(1),
                unit: 'hrs',
                showTarget: true,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                title: 'Calories Left',
                icon: Icons.restaurant,
                iconColor: Colors.green,
                value: _getCaloriesLeftDisplay(nutritionProvider),
                unit: 'kcal',
                showTarget: false,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String value,
    String? target,
    String? unit,
    String? statusText,
    Color? statusColor,
    required bool showTarget,
    required bool isDarkMode,
  }) {
    // Calculate progress for visual indicator
    double? progress;
    if (showTarget && target != null) {
      final currentVal = double.tryParse(value) ?? 0;
      final targetVal = double.tryParse(target) ?? 1;
      progress = targetVal > 0 ? (currentVal / targetVal).clamp(0.0, 1.0) : 0.0;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDarkMode ? [] : [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Icon(
                icon,
                color: iconColor.withOpacity(0.8),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                      if (showTarget && target != null) ...[
                        Text(
                          ' / ',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          target,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (unit != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (statusText != null) ...[
            const SizedBox(height: 4),
            Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: statusColor ?? (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                fontSize: 11,
              ),
            ),
          ] else if (showTarget && progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.green :
                  progress >= 0.7 ? iconColor :
                  progress >= 0.4 ? Colors.orange : Colors.red,
                ),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoDataBanner(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryAccent.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            color: AppTheme.primaryAccent,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No health data yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Connect your health app to see live metrics',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(HealthProvider healthProvider, NutritionProvider nutritionProvider, UserProvider userProvider, bool isDarkMode) {
    final insights = _generateInsights(healthProvider, nutritionProvider, userProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Insights',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...insights.map((insight) => _buildInsightItem(
          icon: insight['icon'] as IconData,
          iconColor: insight['iconColor'] as Color,
          text: insight['text'] as String,
          isDarkMode: isDarkMode,
        )).toList(),
      ],
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required Color iconColor,
    required String text,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateInsights(
    HealthProvider healthProvider, 
    NutritionProvider nutritionProvider,
    UserProvider userProvider,
  ) {
    final insights = <Map<String, dynamic>>[];
    final profile = userProvider.profile;
    final stepsGoal = profile?.dailyStepsTarget ?? 10000;
    final steps = healthProvider.todaySteps.toInt();
    final todayNutrition = nutritionProvider.todayNutrition;
    
    // Steps insight
    if (steps < 5000) {
      insights.add({
        'icon': Icons.directions_walk,
        'iconColor': Colors.orange,
        'text': 'Time to move! You\'re at $steps steps today →',
      });
    } else if (steps >= stepsGoal) {
      insights.add({
        'icon': Icons.celebration,
        'iconColor': Colors.green,
        'text': 'Great job! You\'ve hit your daily step goal!',
      });
    } else {
      insights.add({
        'icon': Icons.trending_up,
        'iconColor': Colors.blue,
        'text': 'Keep going! ${stepsGoal - steps} steps to reach your goal',
      });
    }
    
    // Protein insight
    if (todayNutrition != null && todayNutrition.totalProtein < 50) {
      insights.add({
        'icon': Icons.restaurant,
        'iconColor': Colors.red,
        'text': 'Protein intake is low (${todayNutrition.totalProtein.toStringAsFixed(0)}g). Aim for at least 50g',
      });
    }
    
    // Sleep insight
    final sleep = healthProvider.todaySleep;
    if (sleep > 0 && sleep < 7) {
      insights.add({
        'icon': Icons.bedtime,
        'iconColor': Colors.purple,
        'text': 'Only ${sleep.toStringAsFixed(1)} hours of sleep. Try to get 7-9 hours',
      });
    }
    
    // Heart rate insight
    final heartRate = healthProvider.todayHeartRate.toInt();
    if (heartRate > 0 && heartRate > 100) {
      insights.add({
        'icon': Icons.favorite,
        'iconColor': Colors.red,
        'text': 'Your resting heart rate is elevated at $heartRate bpm',
      });
    }
    
    return insights;
  }

  String _getHeartRateStatus(int heartRate) {
    if (heartRate == 0) return 'No data';
    if (heartRate < 60) return 'Below normal';
    if (heartRate <= 100) return 'Normal';
    return 'Above normal';
  }

  Color _getHeartRateStatusColor(int heartRate) {
    if (heartRate == 0) return Colors.grey;
    if (heartRate < 60) return Colors.blue;
    if (heartRate <= 100) return Colors.green;
    return Colors.orange;
  }

  int _calculateCaloriesLeft(NutritionProvider nutritionProvider) {
    final supabaseUserProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    final profile = supabaseUserProvider.userProfile;
    final todayNutrition = nutritionProvider.todayNutrition;
    final caloriesConsumed = todayNutrition?.totalCalories ?? 0;

    // Weight loss calorie deficit: active target - 400 = 2761 - 400 = 2350
    final activeCalorieTarget = profile?.dailyActiveCaloriesTarget ?? 2000;
    final weightLossIntakeTarget = activeCalorieTarget - 400;

    return (weightLossIntakeTarget - caloriesConsumed).clamp(0, weightLossIntakeTarget);
  }

  String _getCaloriesLeftDisplay(NutritionProvider nutritionProvider) {
    final supabaseUserProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    final profile = supabaseUserProvider.userProfile;
    final todayNutrition = nutritionProvider.todayNutrition;
    final caloriesConsumed = todayNutrition?.totalCalories ?? 0;

    // Weight loss calorie deficit: active target - 400 = 2761 - 400 = 2350
    final activeCalorieTarget = profile?.dailyActiveCaloriesTarget ?? 2000;
    final weightLossIntakeTarget = activeCalorieTarget - 400;

    final remaining = (weightLossIntakeTarget - caloriesConsumed).clamp(0, weightLossIntakeTarget);
    return '$remaining left';
  }


}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progressAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}