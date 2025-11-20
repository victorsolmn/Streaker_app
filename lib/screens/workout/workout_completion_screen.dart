import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../models/workout_session.dart';
import '../../utils/app_theme.dart';

class WorkoutCompletionScreen extends StatefulWidget {
  final WorkoutSession session;

  const WorkoutCompletionScreen({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<WorkoutCompletionScreen> createState() => _WorkoutCompletionScreenState();
}

class _WorkoutCompletionScreenState extends State<WorkoutCompletionScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Trigger confetti after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateToHome();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Main content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),

                    // Celebration header
                    _buildCelebrationHeader(),

                    const SizedBox(height: 40),

                    // Workout stats cards
                    _buildStatsGrid(),

                    const SizedBox(height: 24),

                    // Exercise breakdown
                    _buildExerciseBreakdown(),

                    const SizedBox(height: 32),

                    // Action buttons
                    _buildActionButtons(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Confetti overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: 3.14 / 2, // Down
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                gravity: 0.3,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationHeader() {
    return Column(
      children: [
        // Trophy icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.amber[300]!, Colors.amber[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.emoji_events,
            size: 60,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 20),

        // Congratulations text
        Text(
          'Workout Complete!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          'Great job! You crushed ${widget.session.workoutName}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          icon: Icons.timer,
          label: 'Duration',
          value: '${widget.session.durationMinutes} min',
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.fitness_center,
          label: 'Exercises',
          value: '${widget.session.totalExercises}',
          color: Colors.green,
        ),
        _buildStatCard(
          icon: Icons.format_list_numbered,
          label: 'Total Sets',
          value: '${widget.session.totalSets}',
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.repeat,
          label: 'Total Reps',
          value: '${widget.session.totalReps}',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseBreakdown() {
    final exerciseGroups = widget.session.exerciseGroups;
    if (exerciseGroups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercise Breakdown',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...exerciseGroups.entries.map((entry) {
          final exerciseName = entry.key;
          final sets = entry.value;

          // Calculate totals for this exercise
          final totalVolume = sets.fold<double>(
            0,
            (sum, set) => sum + set.volume,
          );
          final totalReps = sets.fold<int>(
            0,
            (sum, set) => sum + set.repsCompleted,
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise name
                  Text(
                    exerciseName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Exercise stats
                  Row(
                    children: [
                      _buildExerciseStat(
                        icon: Icons.format_list_numbered,
                        value: '${sets.length} sets',
                      ),
                      const SizedBox(width: 16),
                      _buildExerciseStat(
                        icon: Icons.repeat,
                        value: '$totalReps reps',
                      ),
                      if (totalVolume > 0) ...[
                        const SizedBox(width: 16),
                        _buildExerciseStat(
                          icon: Icons.monitor_weight,
                          value: '${totalVolume.toStringAsFixed(0)} kg',
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Individual sets
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sets.map((set) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: set.skipped
                              ? Colors.grey[200]
                              : AppTheme.primaryAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: set.skipped
                                ? Colors.grey[400]!
                                : AppTheme.primaryAccent.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          set.skipped
                              ? 'Set ${set.setNumber}: Skipped'
                              : set.isBodyweight
                                  ? 'Set ${set.setNumber}: ${set.repsCompleted} reps'
                                  : 'Set ${set.setNumber}: ${set.repsCompleted} × ${set.weightKg}kg',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: set.skipped ? Colors.grey[700] : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildExerciseStat({required IconData icon, required String value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Share button
        ElevatedButton.icon(
          onPressed: _shareWorkout,
          icon: const Icon(Icons.share),
          label: const Text('Share Workout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),

        const SizedBox(height: 12),

        // View details button
        OutlinedButton.icon(
          onPressed: _viewDetails,
          icon: const Icon(Icons.bar_chart),
          label: const Text('View Detailed Stats'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryAccent,
            side: BorderSide(color: AppTheme.primaryAccent, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Done button
        TextButton.icon(
          onPressed: _navigateToHome,
          icon: const Icon(Icons.home),
          label: const Text('Back to Home'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  void _shareWorkout() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _viewDetails() {
    // TODO: Navigate to detailed workout history view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Detailed stats view coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToHome() {
    // Pop all routes until we reach the home screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
