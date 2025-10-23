import 'package:flutter/material.dart';

enum AchievementType {
  streak,
  special,
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementType requirementType;
  final int requirementValue;
  final String iconName;
  final String colorPrimary;
  final String colorSecondary;
  final int sortOrder;

  // User-specific fields
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int currentProgress;
  final int targetProgress;
  final bool notified;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.requirementType,
    required this.requirementValue,
    required this.iconName,
    required this.colorPrimary,
    required this.colorSecondary,
    required this.sortOrder,
    this.isUnlocked = false,
    this.unlockedAt,
    this.currentProgress = 0,
    this.targetProgress = 0,
    this.notified = false,
  });

  double get progressPercentage {
    if (targetProgress == 0) return 0.0;
    return (currentProgress / targetProgress).clamp(0.0, 1.0);
  }

  bool get isCloseToUnlock {
    return progressPercentage >= 0.8 && !isUnlocked;
  }

  Color get primaryColor => Color(int.parse(colorPrimary.replaceFirst('#', '0xFF')));
  Color get secondaryColor => Color(int.parse(colorSecondary.replaceFirst('#', '0xFF')));

  IconData get icon {
    // Map icon names to actual Flutter icons
    final iconMap = {
      'fitness_center': Icons.fitness_center,
      'event_available': Icons.event_available,
      'local_fire_department': Icons.local_fire_department,
      'trending_up': Icons.trending_up,
      'flash_on': Icons.flash_on,
      'shield': Icons.shield,
      'emoji_events': Icons.emoji_events,
      'military_tech': Icons.military_tech,
      'restart_alt': Icons.restart_alt,
      'workspace_premium': Icons.workspace_premium,
      'whatshot': Icons.whatshot,
      'all_inclusive': Icons.all_inclusive,
      'weekend': Icons.weekend,
      'nightlight': Icons.nightlight,
      'repeat': Icons.repeat,
    };
    return iconMap[iconName] ?? Icons.star;
  }

  factory Achievement.fromJson(Map<String, dynamic> json, {
    bool isUnlocked = false,
    DateTime? unlockedAt,
    int currentProgress = 0,
    bool notified = false,
  }) {
    return Achievement(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      requirementType: _parseRequirementType(json['requirement_type']),
      requirementValue: json['requirement_value'] ?? 0,
      iconName: json['icon_name'],
      colorPrimary: json['color_primary'],
      colorSecondary: json['color_secondary'],
      sortOrder: json['sort_order'] ?? 0,
      isUnlocked: isUnlocked,
      unlockedAt: unlockedAt,
      currentProgress: currentProgress,
      targetProgress: json['requirement_value'] ?? 0,
      notified: notified,
    );
  }

  static AchievementType _parseRequirementType(String type) {
    switch (type) {
      case 'streak':
        return AchievementType.streak;
      case 'special':
        return AchievementType.special;
      default:
        return AchievementType.special;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'requirement_type': requirementType.toString().split('.').last,
      'requirement_value': requirementValue,
      'icon_name': iconName,
      'color_primary': colorPrimary,
      'color_secondary': colorSecondary,
      'sort_order': sortOrder,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'current_progress': currentProgress,
      'target_progress': targetProgress,
      'notified': notified,
    };
  }

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    AchievementType? requirementType,
    int? requirementValue,
    String? iconName,
    String? colorPrimary,
    String? colorSecondary,
    int? sortOrder,
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? currentProgress,
    int? targetProgress,
    bool? notified,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      requirementType: requirementType ?? this.requirementType,
      requirementValue: requirementValue ?? this.requirementValue,
      iconName: iconName ?? this.iconName,
      colorPrimary: colorPrimary ?? this.colorPrimary,
      colorSecondary: colorSecondary ?? this.colorSecondary,
      sortOrder: sortOrder ?? this.sortOrder,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      currentProgress: currentProgress ?? this.currentProgress,
      targetProgress: targetProgress ?? this.targetProgress,
      notified: notified ?? this.notified,
    );
  }
}

class UserAchievement {
  final String id;
  final String userId;
  final String achievementId;
  final DateTime unlockedAt;
  final bool notified;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAchievement({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.unlockedAt,
    this.notified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      id: json['id'],
      userId: json['user_id'],
      achievementId: json['achievement_id'],
      unlockedAt: DateTime.parse(json['unlocked_at']),
      notified: json['notified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class AchievementProgress {
  final String id;
  final String userId;
  final String achievementId;
  final int currentValue;
  final int targetValue;
  final DateTime lastUpdated;

  AchievementProgress({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.currentValue,
    required this.targetValue,
    required this.lastUpdated,
  });

  double get percentage => targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      id: json['id'],
      userId: json['user_id'],
      achievementId: json['achievement_id'],
      currentValue: json['current_value'] ?? 0,
      targetValue: json['target_value'] ?? 0,
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }
}