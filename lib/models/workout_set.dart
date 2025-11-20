class WorkoutSet {
  final String id;
  final String sessionId;
  final String exerciseName;
  final int exerciseOrder;
  final int setNumber;
  final int repsCompleted;
  final double? weightKg;
  final int? restSeconds;
  final String? notes;
  final bool skipped;
  final DateTime completedAt;

  WorkoutSet({
    required this.id,
    required this.sessionId,
    required this.exerciseName,
    required this.exerciseOrder,
    required this.setNumber,
    required this.repsCompleted,
    this.weightKg,
    this.restSeconds,
    this.notes,
    this.skipped = false,
    required this.completedAt,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      exerciseName: json['exercise_name'] as String,
      exerciseOrder: json['exercise_order'] as int,
      setNumber: json['set_number'] as int,
      repsCompleted: json['reps_completed'] as int,
      weightKg: json['weight_kg'] != null ? (json['weight_kg'] as num).toDouble() : null,
      restSeconds: json['rest_seconds'] as int?,
      notes: json['notes'] as String?,
      skipped: json['skipped'] as bool? ?? false,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'exercise_name': exerciseName,
      'exercise_order': exerciseOrder,
      'set_number': setNumber,
      'reps_completed': repsCompleted,
      'weight_kg': weightKg,
      'rest_seconds': restSeconds,
      'notes': notes,
      'skipped': skipped,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  // Create a new set for insertion (without ID)
  Map<String, dynamic> toInsertJson() {
    return {
      'session_id': sessionId,
      'exercise_name': exerciseName,
      'exercise_order': exerciseOrder,
      'set_number': setNumber,
      'reps_completed': repsCompleted,
      'weight_kg': weightKg,
      'rest_seconds': restSeconds,
      'notes': notes,
      'skipped': skipped,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  // Copy with method for updating fields
  WorkoutSet copyWith({
    String? id,
    String? sessionId,
    String? exerciseName,
    int? exerciseOrder,
    int? setNumber,
    int? repsCompleted,
    double? weightKg,
    int? restSeconds,
    String? notes,
    bool? skipped,
    DateTime? completedAt,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseName: exerciseName ?? this.exerciseName,
      exerciseOrder: exerciseOrder ?? this.exerciseOrder,
      setNumber: setNumber ?? this.setNumber,
      repsCompleted: repsCompleted ?? this.repsCompleted,
      weightKg: weightKg ?? this.weightKg,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      skipped: skipped ?? this.skipped,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // Calculate volume for this set (weight × reps)
  double get volume {
    if (weightKg == null) return 0.0;
    return weightKg! * repsCompleted;
  }

  // Check if this is a bodyweight exercise
  bool get isBodyweight => weightKg == null;

  // Format weight for display
  String get weightDisplay {
    if (isBodyweight) return 'Bodyweight';
    return '${weightKg!.toStringAsFixed(1)} kg';
  }

  @override
  String toString() {
    return 'WorkoutSet(exercise: $exerciseName, set: $setNumber, reps: $repsCompleted, weight: $weightDisplay)';
  }
}
