import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workout_provider.dart';
import '../../models/workout_template.dart';
import '../../utils/app_theme.dart';
import 'workout_completion_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final WorkoutTemplate template;
  final String userId;

  const ActiveWorkoutScreen({
    Key? key,
    required this.template,
    required this.userId,
  }) : super(key: key);

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWorkout();
    });
  }

  Future<void> _initializeWorkout() async {
    if (_isInitialized) return;

    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    await provider.startWorkout(widget.template, widget.userId);

    setState(() {
      _isInitialized = true;
    });

    // Pre-fill form with suggested values
    _updateFormWithCurrentExercise();
  }

  void _updateFormWithCurrentExercise() {
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    final exercise = provider.currentExercise;

    if (exercise != null) {
      _repsController.text = exercise.reps.toString();
      _weightController.text = exercise.weightKg?.toString() ?? '';
      _notesController.clear();
    }
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, child) {
        // Show loading while initializing
        if (!_isInitialized) {
          return Scaffold(
            appBar: AppBar(title: const Text('Starting Workout...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Check if workout is complete
        if (provider.isWorkoutComplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleWorkoutComplete(provider);
          });
        }

        return WillPopScope(
          onWillPop: () => _confirmCancelWorkout(context, provider),
          child: Scaffold(
            appBar: _buildAppBar(context, provider),
            body: Column(
              children: [
                // Progress indicator
                _buildProgressBar(provider),

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Exercise header
                        _buildExerciseHeader(provider),

                        const SizedBox(height: 24),

                        // Set tracker
                        _buildSetTracker(provider),

                        const SizedBox(height: 24),

                        // Rest timer (if resting)
                        if (provider.isResting) _buildRestTimer(provider),

                        // Input form (if not resting)
                        if (!provider.isResting) _buildInputForm(provider),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                _buildActionButtons(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WorkoutProvider provider) {
    return AppBar(
      title: Text(widget.template.name),
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmCancelWorkout(context, provider),
        ),
      ],
    );
  }

  Widget _buildProgressBar(WorkoutProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryAccent.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryAccent.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Exercise ${provider.currentExerciseIndex + 1} of ${provider.totalExercises}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(provider.workoutProgress * 100).toInt()}% Complete',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: provider.workoutProgress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseHeader(WorkoutProvider provider) {
    final exercise = provider.currentExercise;
    if (exercise == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildInfoChip(
              icon: Icons.fitness_center,
              label: '${exercise.sets} sets',
            ),
            _buildInfoChip(
              icon: Icons.repeat,
              label: '${exercise.reps} reps',
            ),
            if (!exercise.isBodyweight)
              _buildInfoChip(
                icon: Icons.monitor_weight,
                label: exercise.weightDisplay,
              ),
            _buildInfoChip(
              icon: Icons.timer,
              label: '${exercise.restSeconds}s rest',
            ),
          ],
        ),
        if (exercise.notes != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exercise.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.primaryAccent,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetTracker(WorkoutProvider provider) {
    final exercise = provider.currentExercise;
    if (exercise == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sets Progress',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(exercise.sets, (index) {
            final setNumber = index + 1;
            final isCompleted = provider.currentExerciseCompletedSets >= setNumber;
            final isCurrent = provider.currentSetNumber == setNumber;

            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.primaryAccent
                    : (isCurrent ? Colors.orange : Colors.grey[200]),
                borderRadius: BorderRadius.circular(12),
                border: isCurrent && !isCompleted
                    ? Border.all(color: Colors.orange, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCompleted ? Icons.check : Icons.fitness_center,
                    color: isCompleted || isCurrent ? Colors.white : Colors.grey[600],
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set $setNumber',
                    style: TextStyle(
                      color: isCompleted || isCurrent ? Colors.white : Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRestTimer(WorkoutProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.timer,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Rest Time',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatRestTime(provider.remainingRestSeconds),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              provider.skipRest();
              _updateFormWithCurrentExercise();
            },
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip Rest'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm(WorkoutProvider provider) {
    final exercise = provider.currentExercise;
    if (exercise == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Log Set ${provider.currentSetNumber}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Reps input
        TextField(
          controller: _repsController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Reps Completed',
            hintText: 'Enter reps',
            prefixIcon: const Icon(Icons.repeat),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),

        const SizedBox(height: 16),

        // Weight input (if not bodyweight)
        if (!exercise.isBodyweight)
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Weight (kg)',
              hintText: 'Enter weight',
              prefixIcon: const Icon(Icons.monitor_weight),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),

        const SizedBox(height: 16),

        // Notes input
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'How did it feel?',
            prefixIcon: const Icon(Icons.note),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(WorkoutProvider provider) {
    if (provider.isResting) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Skip set button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  provider.skipSet();
                  _updateFormWithCurrentExercise();
                },
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip Set'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Complete set button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _completeSet(provider),
                icon: const Icon(Icons.check),
                label: const Text('Complete Set'),
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
            ),
          ],
        ),
      ),
    );
  }

  void _completeSet(WorkoutProvider provider) {
    // Validate inputs
    final repsText = _repsController.text.trim();
    if (repsText.isEmpty) {
      _showSnackBar('Please enter reps completed');
      return;
    }

    final reps = int.tryParse(repsText);
    if (reps == null || reps < 0) {
      _showSnackBar('Please enter a valid number of reps');
      return;
    }

    // Parse weight if provided
    double? weight;
    final weightText = _weightController.text.trim();
    if (weightText.isNotEmpty) {
      weight = double.tryParse(weightText);
      if (weight == null || weight < 0) {
        _showSnackBar('Please enter a valid weight');
        return;
      }
    }

    // Complete the set
    provider.completeSet(
      repsCompleted: reps,
      weightKg: weight,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    // Update form for next set
    _updateFormWithCurrentExercise();
  }

  Future<void> _handleWorkoutComplete(WorkoutProvider provider) async {
    // Save workout
    final session = await provider.completeWorkout(widget.userId);

    if (session != null && mounted) {
      // Navigate to completion screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => WorkoutCompletionScreen(session: session),
        ),
      );
    } else if (mounted) {
      _showSnackBar('Failed to save workout. Please try again.');
    }
  }

  Future<bool> _confirmCancelWorkout(BuildContext context, WorkoutProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Workout?'),
        content: const Text(
          'Are you sure you want to cancel this workout? Your progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Workout'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Workout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      provider.cancelWorkout();
      Navigator.of(context).pop();
      return true;
    }

    return false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatRestTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
