import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_session.dart';
import '../models/workout_set.dart';
import '../models/workout_template.dart';
import '../services/workout_service.dart';

class WorkoutProvider with ChangeNotifier {
  final WorkoutService _workoutService = WorkoutService();
  final Uuid _uuid = const Uuid();

  // Active workout state
  WorkoutTemplate? _activeTemplate;
  WorkoutSession? _activeSession;
  List<WorkoutSet> _completedSets = [];

  // Current exercise tracking
  int _currentExerciseIndex = 0;
  int _currentSetNumber = 1;

  // Rest timer state
  bool _isResting = false;
  int _remainingRestSeconds = 0;
  Timer? _restTimer;

  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  // Workout history
  List<WorkoutSession> _workoutHistory = [];
  List<WorkoutTemplate> _savedTemplates = [];

  // Getters
  WorkoutTemplate? get activeTemplate => _activeTemplate;
  WorkoutSession? get activeSession => _activeSession;
  List<WorkoutSet> get completedSets => _completedSets;
  int get currentExerciseIndex => _currentExerciseIndex;
  int get currentSetNumber => _currentSetNumber;
  bool get isResting => _isResting;
  int get remainingRestSeconds => _remainingRestSeconds;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<WorkoutSession> get workoutHistory => _workoutHistory;
  List<WorkoutTemplate> get savedTemplates => _savedTemplates;

  // Computed getters
  bool get hasActiveWorkout => _activeTemplate != null;

  TemplateExercise? get currentExercise {
    if (_activeTemplate == null) return null;
    if (_currentExerciseIndex >= _activeTemplate!.exercises.length) return null;
    return _activeTemplate!.exercises[_currentExerciseIndex];
  }

  int get totalExercises => _activeTemplate?.exercises.length ?? 0;

  int get totalSetsCompleted => _completedSets.length;

  int get totalSetsInWorkout {
    if (_activeTemplate == null) return 0;
    return _activeTemplate!.totalSets;
  }

  double get workoutProgress {
    if (totalSetsInWorkout == 0) return 0.0;
    return (totalSetsCompleted / totalSetsInWorkout).clamp(0.0, 1.0);
  }

  int get currentExerciseCompletedSets {
    if (currentExercise == null) return 0;
    return _completedSets
        .where((set) => set.exerciseOrder == _currentExerciseIndex + 1)
        .length;
  }

  bool get isCurrentExerciseComplete {
    if (currentExercise == null) return false;
    return currentExerciseCompletedSets >= currentExercise!.sets;
  }

  bool get isWorkoutComplete => workoutProgress >= 1.0;

  // ============================================================================
  // START WORKOUT
  // ============================================================================

  Future<void> startWorkout(WorkoutTemplate template, String userId) async {
    try {
      print('🏋️ Starting workout: ${template.name}');

      _activeTemplate = template;
      _currentExerciseIndex = 0;
      _currentSetNumber = 1;
      _completedSets = [];
      _isResting = false;
      _remainingRestSeconds = 0;
      _error = null;

      // Create session record (will be updated when workout completes)
      final now = DateTime.now();
      _activeSession = WorkoutSession(
        id: '', // Will be assigned by database
        userId: userId,
        workoutName: template.name,
        workoutType: template.workoutType,
        startedAt: now,
        completedAt: now, // Will be updated on completion
        createdAt: now,
        updatedAt: now,
        templateId: template.id.isNotEmpty ? template.id : null,
        aiGenerated: template.source == 'ai',
      );

      notifyListeners();
      print('✅ Workout started successfully');
    } catch (e) {
      _error = 'Failed to start workout: $e';
      print('❌ Error starting workout: $e');
      notifyListeners();
    }
  }

  // ============================================================================
  // SET COMPLETION
  // ============================================================================

  void completeSet({
    required int repsCompleted,
    double? weightKg,
    String? notes,
  }) {
    if (_activeTemplate == null || currentExercise == null || _activeSession == null) {
      print('⚠️ Cannot complete set: No active workout');
      return;
    }

    try {
      print('✅ Completing set: ${currentExercise!.name} - Set $_currentSetNumber');

      // Create set record
      final set = WorkoutSet(
        id: _uuid.v4(),
        sessionId: '', // Will be updated when session is saved
        exerciseName: currentExercise!.name,
        exerciseOrder: _currentExerciseIndex + 1,
        setNumber: _currentSetNumber,
        repsCompleted: repsCompleted,
        weightKg: weightKg ?? currentExercise!.weightKg,
        restSeconds: currentExercise!.restSeconds,
        notes: notes,
        completedAt: DateTime.now(),
      );

      _completedSets.add(set);

      // Check if this exercise is complete
      if (isCurrentExerciseComplete) {
        print('🎯 Exercise complete: ${currentExercise!.name}');
        _moveToNextExercise();
      } else {
        // Move to next set and start rest timer
        _currentSetNumber++;
        _startRestTimer(currentExercise!.restSeconds);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to complete set: $e';
      print('❌ Error completing set: $e');
      notifyListeners();
    }
  }

  void skipSet() {
    if (currentExercise == null) return;

    print('⏭️ Skipping set: ${currentExercise!.name} - Set $_currentSetNumber');

    // Create skipped set record
    final set = WorkoutSet(
      id: _uuid.v4(),
      sessionId: '',
      exerciseName: currentExercise!.name,
      exerciseOrder: _currentExerciseIndex + 1,
      setNumber: _currentSetNumber,
      repsCompleted: 0,
      weightKg: currentExercise!.weightKg,
      restSeconds: currentExercise!.restSeconds,
      skipped: true,
      completedAt: DateTime.now(),
    );

    _completedSets.add(set);

    if (isCurrentExerciseComplete) {
      _moveToNextExercise();
    } else {
      _currentSetNumber++;
    }

    notifyListeners();
  }

  void _moveToNextExercise() {
    _currentExerciseIndex++;
    _currentSetNumber = 1;
    _stopRestTimer();

    if (_currentExerciseIndex >= totalExercises) {
      print('🎉 All exercises complete!');
    }
  }

  // ============================================================================
  // REST TIMER
  // ============================================================================

  void _startRestTimer(int seconds) {
    _stopRestTimer();

    _isResting = true;
    _remainingRestSeconds = seconds;
    notifyListeners();

    print('⏱️ Starting rest timer: $seconds seconds');

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingRestSeconds--;

      if (_remainingRestSeconds <= 0) {
        _stopRestTimer();
      }

      notifyListeners();
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
    _isResting = false;
    _remainingRestSeconds = 0;
  }

  void pauseRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
    print('⏸️ Rest timer paused at $_remainingRestSeconds seconds');
    notifyListeners();
  }

  void resumeRestTimer() {
    if (_remainingRestSeconds > 0) {
      _startRestTimer(_remainingRestSeconds);
      print('▶️ Rest timer resumed');
    }
  }

  void skipRest() {
    print('⏭️ Skipping rest period');
    _stopRestTimer();
    notifyListeners();
  }

  // ============================================================================
  // COMPLETE WORKOUT
  // ============================================================================

  Future<WorkoutSession?> completeWorkout(String userId) async {
    if (_activeTemplate == null || _activeSession == null) {
      _error = 'No active workout to complete';
      return null;
    }

    try {
      _isSaving = true;
      notifyListeners();

      print('💾 Saving workout session...');

      final completedAt = DateTime.now();
      final duration = completedAt.difference(_activeSession!.startedAt).inMinutes;

      // Calculate stats from completed sets
      final nonSkippedSets = _completedSets.where((s) => !s.skipped).toList();
      final totalReps = nonSkippedSets.fold<int>(0, (sum, set) => sum + set.repsCompleted);
      final totalVolume = nonSkippedSets.fold<double>(0, (sum, set) => sum + set.volume);

      final uniqueExercises = nonSkippedSets
          .map((s) => s.exerciseName)
          .toSet()
          .length;

      // Create final session with stats
      final session = WorkoutSession(
        id: '',
        userId: userId,
        workoutName: _activeTemplate!.name,
        workoutType: _activeTemplate!.workoutType,
        startedAt: _activeSession!.startedAt,
        completedAt: completedAt,
        totalExercises: uniqueExercises,
        totalSets: nonSkippedSets.length,
        totalReps: totalReps,
        totalVolumeKg: totalVolume,
        templateId: _activeTemplate!.id.isNotEmpty ? _activeTemplate!.id : null,
        aiGenerated: _activeTemplate!.source == 'ai',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save session to database
      final savedSession = await _workoutService.createSession(session);

      // Save all sets with correct session ID
      final setsToSave = _completedSets.map((set) {
        return set.copyWith(sessionId: savedSession.id);
      }).toList();

      await _workoutService.saveSets(setsToSave);

      print('✅ Workout saved successfully!');
      print('   Duration: $duration min');
      print('   Exercises: $uniqueExercises');
      print('   Sets: ${nonSkippedSets.length}');
      print('   Reps: $totalReps');
      print('   Volume: ${totalVolume.toStringAsFixed(1)} kg');

      // Add to history
      _workoutHistory.insert(0, savedSession);

      // Clear active workout
      _clearActiveWorkout();

      _isSaving = false;
      notifyListeners();

      return savedSession;
    } catch (e) {
      _error = 'Failed to save workout: $e';
      _isSaving = false;
      print('❌ Error saving workout: $e');
      notifyListeners();
      return null;
    }
  }

  void _clearActiveWorkout() {
    _activeTemplate = null;
    _activeSession = null;
    _completedSets = [];
    _currentExerciseIndex = 0;
    _currentSetNumber = 1;
    _stopRestTimer();
  }

  void cancelWorkout() {
    print('❌ Workout cancelled');
    _clearActiveWorkout();
    notifyListeners();
  }

  // ============================================================================
  // TEMPLATES
  // ============================================================================

  Future<void> saveTemplate(WorkoutTemplate template) async {
    try {
      _isSaving = true;
      notifyListeners();

      final savedTemplate = await _workoutService.saveTemplate(template);
      _savedTemplates.insert(0, savedTemplate);

      _isSaving = false;
      notifyListeners();

      print('✅ Template saved: ${savedTemplate.name}');
    } catch (e) {
      _error = 'Failed to save template: $e';
      _isSaving = false;
      print('❌ Error saving template: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadTemplates(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _savedTemplates = await _workoutService.getUserTemplates(userId);

      _isLoading = false;
      notifyListeners();

      print('✅ Loaded ${_savedTemplates.length} templates');
    } catch (e) {
      _error = 'Failed to load templates: $e';
      _isLoading = false;
      print('❌ Error loading templates: $e');
      notifyListeners();
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      await _workoutService.deleteTemplate(templateId);
      _savedTemplates.removeWhere((t) => t.id == templateId);
      notifyListeners();
      print('✅ Template deleted');
    } catch (e) {
      _error = 'Failed to delete template: $e';
      print('❌ Error deleting template: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleTemplateFavorite(WorkoutTemplate template) async {
    try {
      await _workoutService.toggleFavorite(template.id, template.isFavorite);

      // Update local state
      final index = _savedTemplates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        _savedTemplates[index] = template.copyWith(isFavorite: !template.isFavorite);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update favorite: $e';
      print('❌ Error updating favorite: $e');
      notifyListeners();
    }
  }

  // ============================================================================
  // WORKOUT HISTORY
  // ============================================================================

  Future<void> loadWorkoutHistory(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _workoutHistory = await _workoutService.getUserSessions(userId);

      _isLoading = false;
      notifyListeners();

      print('✅ Loaded ${_workoutHistory.length} workout sessions');
    } catch (e) {
      _error = 'Failed to load history: $e';
      _isLoading = false;
      print('❌ Error loading history: $e');
      notifyListeners();
    }
  }

  Future<void> deleteWorkoutSession(String sessionId) async {
    try {
      await _workoutService.deleteSession(sessionId);
      _workoutHistory.removeWhere((s) => s.id == sessionId);
      notifyListeners();
      print('✅ Workout session deleted');
    } catch (e) {
      _error = 'Failed to delete session: $e';
      print('❌ Error deleting session: $e');
      notifyListeners();
      rethrow;
    }
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  @override
  void dispose() {
    _stopRestTimer();
    super.dispose();
  }
}
