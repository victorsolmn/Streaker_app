/// Profile Model - Exactly matches Supabase schema
///
/// This model is a 1:1 mapping with the public.profiles table

class ProfileModel {
  // Required fields (NOT NULL in database)
  final String id; // UUID from auth.users
  final String name; // Has default 'New User' in DB
  final String email;
  final bool hasCompletedOnboarding; // Default false
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Optional fields (NULL allowed in database)
  final int? age; // 13-120
  final String? gender; // Male, Female, Other, Prefer not to say
  final double? height; // 50-300 cm
  final double? weight; // 20-500 kg
  final String? photoUrl; // Profile photo URL from Supabase storage
  final String? weightUnit; // kg or lbs

  // Nutrition goals (added after cleanup)
  final int? calorieGoal; // Default 2000
  final double? proteinGoal; // Default 150
  final double? carbGoal; // Default 250
  final double? fatGoal; // Default 67

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.hasCompletedOnboarding = false,
    this.createdAt,
    this.updatedAt,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.photoUrl,
    this.weightUnit,
    this.calorieGoal,
    this.proteinGoal,
    this.carbGoal,
    this.fatGoal,
  });

  /// Create from Supabase JSON response
  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] ?? 'New User',
      email: json['email'] as String,
      hasCompletedOnboarding: json['has_completed_onboarding'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      height: json['height'] != null
          ? (json['height'] as num).toDouble()
          : null,
      weight: json['weight'] != null
          ? (json['weight'] as num).toDouble()
          : null,
      photoUrl: json['photo_url'] as String?,
      weightUnit: json['weight_unit'] as String?,
      calorieGoal: json['calorie_goal'] as int?,
      proteinGoal: json['protein_goal'] != null
          ? (json['protein_goal'] as num).toDouble()
          : null,
      carbGoal: json['carb_goal'] != null
          ? (json['carb_goal'] as num).toDouble()
          : null,
      fatGoal: json['fat_goal'] != null
          ? (json['fat_goal'] as num).toDouble()
          : null,
    );
  }

  /// Convert to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'has_completed_onboarding': hasCompletedOnboarding,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (weightUnit != null) 'weight_unit': weightUnit,
      if (calorieGoal != null) 'calorie_goal': calorieGoal,
      if (proteinGoal != null) 'protein_goal': proteinGoal,
      if (carbGoal != null) 'carb_goal': carbGoal,
      if (fatGoal != null) 'fat_goal': fatGoal,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  ProfileModel copyWith({
    String? id,
    String? name,
    String? email,
    bool? hasCompletedOnboarding,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? photoUrl,
    String? weightUnit,
    int? calorieGoal,
    double? proteinGoal,
    double? carbGoal,
    double? fatGoal,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      photoUrl: photoUrl ?? this.photoUrl,
      weightUnit: weightUnit ?? this.weightUnit,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbGoal: carbGoal ?? this.carbGoal,
      fatGoal: fatGoal ?? this.fatGoal,
    );
  }

  /// Calculate BMI from height and weight
  double? calculateBMI() {
    if (height != null && weight != null && height! > 0) {
      // BMI = weight(kg) / (height(m))^2
      final heightInMeters = height! / 100;
      return weight! / (heightInMeters * heightInMeters);
    }
    return null;
  }

  /// Get BMI category based on BMI value
  String? getBMICategory() {
    final bmi = calculateBMI();
    if (bmi == null) return null;

    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  /// Check if profile has minimum required onboarding data
  bool hasMinimumOnboardingData() {
    return age != null &&
           height != null &&
           weight != null;
  }

  /// Check if profile has complete onboarding data (including nutrition goals)
  bool hasCompleteOnboardingData() {
    return hasMinimumOnboardingData() &&
           calorieGoal != null &&
           proteinGoal != null &&
           carbGoal != null &&
           fatGoal != null;
  }

  /// Check if profile has required data for BMR calculation
  /// BMR calculation requires: age, gender, height, weight
  bool hasBMRCalculationData() {
    return age != null &&
           age! > 0 &&
           age! <= 120 &&
           gender != null &&
           gender!.isNotEmpty &&
           height != null &&
           height! > 0 &&
           height! <= 300 &&
           weight != null &&
           weight! > 0 &&
           weight! <= 500;
  }

  /// Get validated gender for BMR calculation
  /// Returns null if gender is invalid or missing
  String? getValidatedGender() {
    if (gender == null || gender!.trim().isEmpty) {
      return null;
    }

    final normalizedGender = gender!.toLowerCase().trim();

    // Check for valid gender values
    if (normalizedGender.contains('male') && !normalizedGender.contains('female')) {
      return 'male';
    } else if (normalizedGender.contains('female')) {
      return 'female';
    } else if (normalizedGender == 'other' || normalizedGender.contains('other')) {
      return 'other'; // Treat as female for BMR calculation (conservative approach)
    }

    return null; // Invalid gender
  }

  /// Get BMR calculation readiness status
  Map<String, dynamic> getBMRCalculationStatus() {
    final hasData = hasBMRCalculationData();
    final validGender = getValidatedGender();

    return {
      'isReady': hasData,
      'hasAge': age != null && age! > 0 && age! <= 120,
      'hasGender': validGender != null,
      'hasHeight': height != null && height! > 0 && height! <= 300,
      'hasWeight': weight != null && weight! > 0 && weight! <= 500,
      'validatedGender': validGender,
      'missingFields': _getMissingBMRFields(),
    };
  }

  /// Get list of missing fields for BMR calculation
  List<String> _getMissingBMRFields() {
    final missing = <String>[];

    if (age == null || age! <= 0 || age! > 120) {
      missing.add('age');
    }
    if (getValidatedGender() == null) {
      missing.add('gender');
    }
    if (height == null || height! <= 0 || height! > 300) {
      missing.add('height');
    }
    if (weight == null || weight! <= 0 || weight! > 500) {
      missing.add('weight');
    }

    return missing;
  }
}