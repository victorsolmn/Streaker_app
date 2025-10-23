import 'package:intl/intl.dart';

class WeightMilestone {
  final String id;
  final double weight;
  final String title;
  final String description;
  final DateTime achievedAt;
  final String type; // 'loss', 'gain', 'target'

  WeightMilestone({
    required this.id,
    required this.weight,
    required this.title,
    required this.description,
    required this.achievedAt,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'weight': weight,
    'title': title,
    'description': description,
    'achievedAt': achievedAt.toIso8601String(),
    'type': type,
  };

  factory WeightMilestone.fromJson(Map<String, dynamic> json) {
    return WeightMilestone(
      id: json['id'],
      weight: json['weight'].toDouble(),
      title: json['title'],
      description: json['description'],
      achievedAt: DateTime.parse(json['achievedAt']),
      type: json['type'],
    );
  }
}

class WeightEntry {
  final String id;
  final String? userId;
  final double weight;
  final DateTime timestamp;
  final String? note;

  WeightEntry({
    required this.id,
    this.userId,
    required this.weight,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'weight': weight,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
  };

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'],
      userId: json['user_id'],
      weight: json['weight'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      note: json['note'],
    );
  }

  String get formattedDate => DateFormat('MMM dd, yyyy').format(timestamp);
  String get formattedTime => DateFormat('hh:mm a').format(timestamp);
  String get formattedDateTime => '$formattedDate at $formattedTime';
}

class WeightProgress {
  final double startWeight;
  final double currentWeight;
  final double targetWeight;
  final List<WeightEntry> entries;
  final String unit;
  final List<WeightMilestone> milestones;
  final int daysTracking;

  WeightProgress({
    required this.startWeight,
    required this.currentWeight,
    required this.targetWeight,
    required this.entries,
    this.unit = 'kg',
    this.milestones = const [],
    this.daysTracking = 0,
  });

  double get totalLoss => startWeight - currentWeight;
  double get targetLoss => startWeight - targetWeight;
  double get progress => targetLoss > 0 ? (totalLoss / targetLoss).clamp(0.0, 1.0) : 0.0;
  double get progressPercentage => progress * 100;
  double get remainingLoss => currentWeight - targetWeight;

  // Calculate days tracking from first entry to now
  int get actualDaysTracking {
    if (entries.isEmpty) return daysTracking;
    final sortedEntries = List<WeightEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final firstEntry = sortedEntries.first;
    return DateTime.now().difference(firstEntry.timestamp).inDays;
  }
  
  bool get isGoalAchieved => currentWeight <= targetWeight;
  
  String get progressText {
    if (isGoalAchieved) {
      return 'Goal Achieved! 🎉';
    } else if (totalLoss > 0) {
      return 'Lost ${totalLoss.toStringAsFixed(1)} $unit';
    } else if (totalLoss < 0) {
      return 'Gained ${(-totalLoss).toStringAsFixed(1)} $unit';
    } else {
      return 'No change';
    }
  }

  Map<String, dynamic> toJson() => {
    'startWeight': startWeight,
    'currentWeight': currentWeight,
    'targetWeight': targetWeight,
    'entries': entries.map((e) => e.toJson()).toList(),
    'unit': unit,
    'milestones': milestones.map((m) => m.toJson()).toList(),
    'daysTracking': daysTracking,
  };

  factory WeightProgress.fromJson(Map<String, dynamic> json) {
    return WeightProgress(
      startWeight: json['startWeight'].toDouble(),
      currentWeight: json['currentWeight'].toDouble(),
      targetWeight: json['targetWeight'].toDouble(),
      entries: (json['entries'] as List)
          .map((e) => WeightEntry.fromJson(e))
          .toList(),
      unit: json['unit'] ?? 'kg',
      milestones: json['milestones'] != null
          ? (json['milestones'] as List).map((m) => WeightMilestone.fromJson(m)).toList()
          : [],
      daysTracking: json['daysTracking'] ?? 0,
    );
  }

  WeightProgress copyWith({
    double? startWeight,
    double? currentWeight,
    double? targetWeight,
    List<WeightEntry>? entries,
    String? unit,
    List<WeightMilestone>? milestones,
    int? daysTracking,
  }) {
    return WeightProgress(
      startWeight: startWeight ?? this.startWeight,
      currentWeight: currentWeight ?? this.currentWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      entries: entries ?? this.entries,
      unit: unit ?? this.unit,
      milestones: milestones ?? this.milestones,
      daysTracking: daysTracking ?? this.daysTracking,
    );
  }
}

class UserProfile {
  final String name;
  final String? profileImagePath;
  final double height;
  final int age;
  final String heightUnit;
  final WeightProgress weightProgress;

  UserProfile({
    required this.name,
    this.profileImagePath,
    required this.height,
    required this.age,
    this.heightUnit = 'cm',
    required this.weightProgress,
  });

  String get formattedHeight {
    if (heightUnit == 'cm') {
      return '${height.toStringAsFixed(0)} cm';
    } else {
      final feet = (height / 30.48).floor();
      final inches = ((height % 30.48) / 2.54).round();
      return '$feet\'$inches"';
    }
  }

  double get bmi {
    final heightInMeters = height / 100;
    return weightProgress.currentWeight / (heightInMeters * heightInMeters);
  }

  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'profileImagePath': profileImagePath,
    'height': height,
    'age': age,
    'heightUnit': heightUnit,
    'weightProgress': weightProgress.toJson(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'],
      profileImagePath: json['profileImagePath'],
      height: json['height'].toDouble(),
      age: json['age'],
      heightUnit: json['heightUnit'] ?? 'cm',
      weightProgress: WeightProgress.fromJson(json['weightProgress']),
    );
  }
}