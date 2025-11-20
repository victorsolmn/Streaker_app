import 'workout_set.dart';

class WorkoutSession {
  final String id;
  final String userId;
  final String workoutName;
  final String? workoutType;
  final DateTime startedAt;
  final DateTime completedAt;
  final int totalExercises;
  final int totalSets;
  final int totalReps;
  final double totalVolumeKg;
  final String? notes;
  final bool aiGenerated;
  final String? templateId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WorkoutSet>? sets; // Optional - loaded separately

  WorkoutSession({
    required this.id,
    required this.userId,
    required this.workoutName,
    this.workoutType,
    required this.startedAt,
    required this.completedAt,
    this.totalExercises = 0,
    this.totalSets = 0,
    this.totalReps = 0,
    this.totalVolumeKg = 0.0,
    this.notes,
    this.aiGenerated = false,
    this.templateId,
    required this.createdAt,
    required this.updatedAt,
    this.sets,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      workoutName: json['workout_name'] as String,
      workoutType: json['workout_type'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: DateTime.parse(json['completed_at'] as String),
      totalExercises: json['total_exercises'] as int? ?? 0,
      totalSets: json['total_sets'] as int? ?? 0,
      totalReps: json['total_reps'] as int? ?? 0,
      totalVolumeKg: json['total_volume_kg'] != null
          ? (json['total_volume_kg'] as num).toDouble()
          : 0.0,
      notes: json['notes'] as String?,
      aiGenerated: json['ai_generated'] as bool? ?? false,
      templateId: json['template_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sets: null, // Sets loaded separately
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'workout_name': workoutName,
      'workout_type': workoutType,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt.toIso8601String(),
      'total_exercises': totalExercises,
      'total_sets': totalSets,
      'total_reps': totalReps,
      'total_volume_kg': totalVolumeKg,
      'notes': notes,
      'ai_generated': aiGenerated,
      'template_id': templateId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create insert JSON (without ID and computed fields)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'workout_name': workoutName,
      'workout_type': workoutType,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt.toIso8601String(),
      'total_exercises': totalExercises,
      'total_sets': totalSets,
      'total_reps': totalReps,
      'total_volume_kg': totalVolumeKg,
      'notes': notes,
      'ai_generated': aiGenerated,
      'template_id': templateId,
    };
  }

  WorkoutSession copyWith({
    String? id,
    String? userId,
    String? workoutName,
    String? workoutType,
    DateTime? startedAt,
    DateTime? completedAt,
    int? totalExercises,
    int? totalSets,
    int? totalReps,
    double? totalVolumeKg,
    String? notes,
    bool? aiGenerated,
    String? templateId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<WorkoutSet>? sets,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workoutName: workoutName ?? this.workoutName,
      workoutType: workoutType ?? this.workoutType,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      totalExercises: totalExercises ?? this.totalExercises,
      totalSets: totalSets ?? this.totalSets,
      totalReps: totalReps ?? this.totalReps,
      totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
      notes: notes ?? this.notes,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sets: sets ?? this.sets,
    );
  }

  // Computed properties
  int get durationMinutes => completedAt.difference(startedAt).inMinutes;

  String get durationDisplay {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return '${hours}h ${mins}m';
  }

  String get dateDisplay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(startedAt.year, startedAt.month, startedAt.day);

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      final diff = today.difference(sessionDate).inDays;
      if (diff < 7) {
        return '$diff days ago';
      } else {
        return '${startedAt.day}/${startedAt.month}/${startedAt.year}';
      }
    }
  }

  String get timeDisplay {
    final hour = startedAt.hour;
    final minute = startedAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String get volumeDisplay {
    if (totalVolumeKg < 1000) {
      return '${totalVolumeKg.toStringAsFixed(0)} kg';
    } else {
      final tons = totalVolumeKg / 1000;
      return '${tons.toStringAsFixed(1)}t';
    }
  }

  String get workoutTypeDisplay => workoutType ?? 'General';

  // Group sets by exercise
  Map<String, List<WorkoutSet>> get exerciseGroups {
    if (sets == null) return {};

    final groups = <String, List<WorkoutSet>>{};
    for (final set in sets!) {
      if (!groups.containsKey(set.exerciseName)) {
        groups[set.exerciseName] = [];
      }
      groups[set.exerciseName]!.add(set);
    }

    // Sort sets within each exercise by set number
    for (final exerciseSets in groups.values) {
      exerciseSets.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    }

    return groups;
  }

  // Get exercise names in order
  List<String> get orderedExercises {
    if (sets == null || sets!.isEmpty) return [];

    // Get unique exercises with their order
    final exerciseOrders = <String, int>{};
    for (final set in sets!) {
      if (!exerciseOrders.containsKey(set.exerciseName)) {
        exerciseOrders[set.exerciseName] = set.exerciseOrder;
      }
    }

    // Sort by order and return names
    final entries = exerciseOrders.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return entries.map((e) => e.key).toList();
  }

  // Calculate average rest time
  int get averageRestSeconds {
    if (sets == null || sets!.isEmpty) return 0;

    final setsWithRest = sets!.where((s) => s.restSeconds != null).toList();
    if (setsWithRest.isEmpty) return 0;

    final totalRest = setsWithRest.fold<int>(0, (sum, s) => sum + s.restSeconds!);
    return totalRest ~/ setsWithRest.length;
  }

  @override
  String toString() {
    return 'WorkoutSession(name: $workoutName, date: $dateDisplay, duration: $durationDisplay, exercises: $totalExercises, sets: $totalSets)';
  }
}
