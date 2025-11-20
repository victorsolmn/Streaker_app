import 'dart:convert';

class WorkoutTemplate {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String? workoutType;
  final int? estimatedDurationMinutes;
  final List<String> equipmentNeeded;
  final String? difficultyLevel;
  final List<TemplateExercise> exercises;
  final bool isFavorite;
  final int timesCompleted;
  final DateTime? lastCompletedAt;
  final String source; // 'user' or 'ai'
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutTemplate({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.workoutType,
    this.estimatedDurationMinutes,
    required this.equipmentNeeded,
    this.difficultyLevel,
    required this.exercises,
    this.isFavorite = false,
    this.timesCompleted = 0,
    this.lastCompletedAt,
    this.source = 'user',
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    // Parse exercises from JSONB
    List<TemplateExercise> exercisesList = [];
    if (json['exercises'] != null) {
      final exercisesJson = json['exercises'] is String
          ? jsonDecode(json['exercises'] as String)
          : json['exercises'];

      exercisesList = (exercisesJson as List)
          .map((e) => TemplateExercise.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return WorkoutTemplate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      workoutType: json['workout_type'] as String?,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      equipmentNeeded: json['equipment_needed'] != null
          ? List<String>.from(json['equipment_needed'] as List)
          : [],
      difficultyLevel: json['difficulty_level'] as String?,
      exercises: exercisesList,
      isFavorite: json['is_favorite'] as bool? ?? false,
      timesCompleted: json['times_completed'] as int? ?? 0,
      lastCompletedAt: json['last_completed_at'] != null
          ? DateTime.parse(json['last_completed_at'] as String)
          : null,
      source: json['source'] as String? ?? 'user',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'workout_type': workoutType,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'equipment_needed': equipmentNeeded,
      'difficulty_level': difficultyLevel,
      'exercises': jsonEncode(exercises.map((e) => e.toJson()).toList()),
      'is_favorite': isFavorite,
      'times_completed': timesCompleted,
      'last_completed_at': lastCompletedAt?.toIso8601String(),
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create insert JSON (without ID and metadata)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      'description': description,
      'workout_type': workoutType,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'equipment_needed': equipmentNeeded,
      'difficulty_level': difficultyLevel,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'is_favorite': isFavorite,
      'source': source,
    };
  }

  WorkoutTemplate copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? workoutType,
    int? estimatedDurationMinutes,
    List<String>? equipmentNeeded,
    String? difficultyLevel,
    List<TemplateExercise>? exercises,
    bool? isFavorite,
    int? timesCompleted,
    DateTime? lastCompletedAt,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      workoutType: workoutType ?? this.workoutType,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      equipmentNeeded: equipmentNeeded ?? this.equipmentNeeded,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      exercises: exercises ?? this.exercises,
      isFavorite: isFavorite ?? this.isFavorite,
      timesCompleted: timesCompleted ?? this.timesCompleted,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Computed properties
  int get totalSets => exercises.fold(0, (sum, ex) => sum + ex.sets);
  int get totalExercises => exercises.length;

  String get equipmentDisplay {
    if (equipmentNeeded.isEmpty) return 'No equipment';
    if (equipmentNeeded.length == 1) return equipmentNeeded.first;
    return '${equipmentNeeded.length} items';
  }

  String get durationDisplay {
    if (estimatedDurationMinutes == null) return 'Unknown';
    return '$estimatedDurationMinutes min';
  }

  @override
  String toString() {
    return 'WorkoutTemplate(name: $name, exercises: $totalExercises, duration: $durationDisplay)';
  }
}

class TemplateExercise {
  final String name;
  final int sets;
  final int reps;
  final int restSeconds;
  final double? weightKg;
  final String? notes;
  final List<String> muscleGroups;

  TemplateExercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.restSeconds = 60,
    this.weightKg,
    this.notes,
    this.muscleGroups = const [],
  });

  factory TemplateExercise.fromJson(Map<String, dynamic> json) {
    return TemplateExercise(
      name: json['name'] as String,
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      restSeconds: json['rest_seconds'] as int? ?? 60,
      weightKg: json['weight_kg'] != null ? (json['weight_kg'] as num).toDouble() : null,
      notes: json['notes'] as String?,
      muscleGroups: json['muscle_groups'] != null
          ? List<String>.from(json['muscle_groups'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'rest_seconds': restSeconds,
      'weight_kg': weightKg,
      'notes': notes,
      'muscle_groups': muscleGroups,
    };
  }

  TemplateExercise copyWith({
    String? name,
    int? sets,
    int? reps,
    int? restSeconds,
    double? weightKg,
    String? notes,
    List<String>? muscleGroups,
  }) {
    return TemplateExercise(
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
      weightKg: weightKg ?? this.weightKg,
      notes: notes ?? this.notes,
      muscleGroups: muscleGroups ?? this.muscleGroups,
    );
  }

  bool get isBodyweight => weightKg == null;

  String get weightDisplay {
    if (isBodyweight) return 'Bodyweight';
    return '${weightKg!.toStringAsFixed(1)} kg';
  }

  String get setsRepsDisplay => '$sets × $reps';

  String get muscleGroupsDisplay {
    if (muscleGroups.isEmpty) return '';
    if (muscleGroups.length == 1) return muscleGroups.first;
    return muscleGroups.join(', ');
  }

  @override
  String toString() {
    return 'TemplateExercise(name: $name, sets: $sets, reps: $reps, weight: $weightDisplay)';
  }
}
