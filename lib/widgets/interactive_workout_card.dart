import 'package:flutter/material.dart';
import '../models/workout_template.dart';
import '../utils/app_theme.dart';

class InteractiveWorkoutCard extends StatelessWidget {
  final WorkoutTemplate workout;
  final VoidCallback onStartWorkout;
  final VoidCallback? onSaveTemplate;  // Made optional
  final bool isSaving;

  const InteractiveWorkoutCard({
    Key? key,
    required this.workout,
    required this.onStartWorkout,
    this.onSaveTemplate,  // No longer required
    this.isSaving = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryAccent.withOpacity(0.1),
              AppTheme.primaryAccent.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with workout type icon
              _buildHeader(context),

              const SizedBox(height: 16),

              // Workout stats row
              _buildStatsRow(context),

              const SizedBox(height: 16),

              // Exercise preview list
              _buildExercisePreview(context),

              const SizedBox(height: 20),

              // Action buttons
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Workout type icon
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getWorkoutIcon(),
            color: Colors.white,
            size: 24,
          ),
        ),

        const SizedBox(width: 12),

        // Workout name and description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workout.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (workout.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  workout.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Difficulty badge
        if (workout.difficultyLevel != null)
          _buildDifficultyBadge(context),
      ],
    );
  }

  Widget _buildDifficultyBadge(BuildContext context) {
    final colors = {
      'Beginner': Colors.green,
      'Intermediate': Colors.orange,
      'Advanced': Colors.red,
    };

    final color = colors[workout.difficultyLevel] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        workout.difficultyLevel!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        _buildStatItem(
          context,
          icon: Icons.timer_outlined,
          label: 'Duration',
          value: workout.durationDisplay,
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          context,
          icon: Icons.fitness_center,
          label: 'Exercises',
          value: '${workout.exercises.length}',
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          context,
          icon: Icons.format_list_numbered,
          label: 'Total Sets',
          value: '${workout.totalSets}',
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.primaryAccent,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExercisePreview(BuildContext context) {
    // Show first 3 exercises
    final previewExercises = workout.exercises.take(3).toList();
    final hasMore = workout.exercises.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercises',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...previewExercises.map((exercise) => _buildExerciseItem(context, exercise)),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 32),
            child: Text(
              '+ ${workout.exercises.length - 3} more exercises',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.primaryAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExerciseItem(BuildContext context, TemplateExercise exercise) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Bullet point
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryAccent.withOpacity(0.1),
            ),
            child: Center(
              child: Icon(
                Icons.check,
                size: 14,
                color: AppTheme.primaryAccent,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Exercise name and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${exercise.sets} sets × ${exercise.reps} reps${exercise.isBodyweight ? "" : " @ ${exercise.weightDisplay}"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Start Workout button (primary)
        Expanded(
          flex: onSaveTemplate != null ? 2 : 1,  // Take full width if no Save button
          child: ElevatedButton.icon(
            onPressed: onStartWorkout,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('Start Workout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),

        // Only show Save button if onSaveTemplate is provided
        if (onSaveTemplate != null) ...[
          const SizedBox(width: 12),

          // Save Template button (secondary)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isSaving ? null : onSaveTemplate,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
                      ),
                    )
                  : const Icon(Icons.bookmark_border, size: 20),
              label: Text(isSaving ? 'Saving...' : 'Save'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryAccent,
                side: BorderSide(color: AppTheme.primaryAccent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getWorkoutIcon() {
    final type = workout.workoutType?.toLowerCase() ?? '';

    if (type.contains('strength')) return Icons.fitness_center;
    if (type.contains('cardio')) return Icons.directions_run;
    if (type.contains('hiit')) return Icons.local_fire_department;
    if (type.contains('upper')) return Icons.accessibility_new;
    if (type.contains('lower') || type.contains('leg')) return Icons.directions_walk;
    if (type.contains('core') || type.contains('ab')) return Icons.self_improvement;
    if (type.contains('full')) return Icons.settings_accessibility;

    return Icons.fitness_center; // Default
  }
}
