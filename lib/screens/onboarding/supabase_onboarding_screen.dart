import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/onboarding_service.dart';
import '../../models/supabase_enums.dart';
import '../../models/profile_model.dart';
import '../../utils/app_theme.dart';
import '../../providers/supabase_auth_provider.dart';
import '../../providers/user_provider.dart';
import '../main/main_screen.dart';
import '../auth/welcome_screen.dart';

class SupabaseOnboardingScreen extends StatefulWidget {
  const SupabaseOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<SupabaseOnboardingScreen> createState() => _SupabaseOnboardingScreenState();
}

class _SupabaseOnboardingScreenState extends State<SupabaseOnboardingScreen>
    with TickerProviderStateMixin {
  // Service
  final OnboardingService _onboardingService = OnboardingService();

  // UI State
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isProcessing = false;
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  // Form keys for each step
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  // Step 1: Personal Info Controllers
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  String? _selectedGender;

  // Step 2: Fitness Goal
  String? _selectedFitnessGoal;

  // Step 3: Activity & Experience
  String? _selectedActivityLevel;
  String? _selectedExperienceLevel;
  String? _selectedWorkoutConsistency;

  // Calculated values
  double? _bmi;
  String? _bmiCategory;
  Map<String, int> _dailyTargets = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAuthAndLoadProfile();
  }

  void _initializeAnimations() {
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));
    _progressAnimationController.forward();
  }

  Future<void> _checkAuthAndLoadProfile() async {
    // Check authentication
    if (!_onboardingService.isAuthenticated) {
      print('❌ User not authenticated, redirecting to welcome');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
      return;
    }

    // Try to get existing profile
    final profile = await _onboardingService.getOrCreateProfile();
    if (profile != null) {
      // Pre-fill with existing data if available
      _nameController.text = profile.name;
      if (profile.hasCompletedOnboarding) {
        print('✅ User already completed onboarding, redirecting to main');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      }
    } else {
      // Pre-fill with auth data
      final user = _onboardingService.currentUser;
      if (user != null) {
        _nameController.text = user.userMetadata?['name'] ??
                              user.email?.split('@')[0] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _calculateBMI() {
    if (_heightController.text.isNotEmpty && _weightController.text.isNotEmpty) {
      final height = double.tryParse(_heightController.text) ?? 0;
      final weight = double.tryParse(_weightController.text) ?? 0;

      if (height > 0 && weight > 0) {
        final heightInMeters = height / 100;
        setState(() {
          _bmi = weight / (heightInMeters * heightInMeters);
          if (_bmi! < 18.5) _bmiCategory = 'Underweight';
          else if (_bmi! < 25) _bmiCategory = 'Normal';
          else if (_bmi! < 30) _bmiCategory = 'Overweight';
          else _bmiCategory = 'Obese';
        });
      }
    }
  }

  void _calculateDailyTargets() {
    if (_ageController.text.isNotEmpty && _heightController.text.isNotEmpty &&
        _weightController.text.isNotEmpty && _selectedActivityLevel != null &&
        _selectedFitnessGoal != null) {

      final age = int.parse(_ageController.text);
      final height = double.parse(_heightController.text);
      final weight = double.parse(_weightController.text);

      // BMR calculation
      final bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
      final tdee = (bmr * SupabaseEnums.getActivityMultiplier(_selectedActivityLevel!)).round();
      final calorieTarget = tdee + SupabaseEnums.getCalorieAdjustment(_selectedFitnessGoal!);

      setState(() {
        _dailyTargets = {
          'calories': calorieTarget.clamp(SupabaseEnums.dailyCaloriesMin, SupabaseEnums.dailyCaloriesMax),
          'steps': _getStepsTarget(_selectedActivityLevel!),
          'sleep': 8,
          'water': 3,
        };
      });
    }
  }

  int _getStepsTarget(String activityLevel) {
    switch (activityLevel) {
      case 'Sedentary': return 5000;
      case 'Lightly Active': return 7500;
      case 'Moderately Active': return 10000;
      case 'Very Active': return 12500;
      case 'Extra Active': return 15000;
      default: return 10000;
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep < _totalSteps - 1) {
      bool canProceed = false;

      if (_currentStep == 0) {
        // Validate and save Step 1
        if (_step1FormKey.currentState?.validate() ?? false) {
          setState(() => _isProcessing = true);

          final success = await _onboardingService.saveOnboardingStep1(
            name: _nameController.text.trim(),
            gender: _selectedGender!,
            age: int.parse(_ageController.text),
            height: double.parse(_heightController.text),
            weight: double.parse(_weightController.text),
            targetWeight: _targetWeightController.text.isNotEmpty
                ? double.parse(_targetWeightController.text)
                : null,
          );

          setState(() => _isProcessing = false);

          if (success) {
            _calculateBMI();
            canProceed = true;
          } else {
            _showError('Failed to save personal information. Please try again.');
          }
        }
      } else if (_currentStep == 1) {
        // Validate and save Step 2
        if (_selectedFitnessGoal != null) {
          setState(() => _isProcessing = true);

          final success = await _onboardingService.saveOnboardingStep2(
            fitnessGoal: _selectedFitnessGoal!,
          );

          setState(() => _isProcessing = false);

          if (success) {
            canProceed = true;
          } else {
            _showError('Failed to save fitness goal. Please try again.');
          }
        } else {
          _showError('Please select a fitness goal');
        }
      } else if (_currentStep == 2) {
        // Validate and save Step 3
        if (_selectedActivityLevel != null &&
            _selectedExperienceLevel != null &&
            _selectedWorkoutConsistency != null) {
          setState(() => _isProcessing = true);

          final success = await _onboardingService.saveOnboardingStep3(
            activityLevel: _selectedActivityLevel!,
            experienceLevel: _selectedExperienceLevel!,
            workoutConsistency: _selectedWorkoutConsistency!,
          );

          setState(() => _isProcessing = false);

          if (success) {
            _calculateDailyTargets();
            canProceed = true;
          } else {
            _showError('Failed to save activity information. Please try again.');
          }
        } else {
          _showError('Please complete all fields');
        }
      }

      if (canProceed) {
        setState(() {
          _currentStep++;
        });
        _progressAnimationController.forward();
      }
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isProcessing = true);

    final success = await _onboardingService.completeOnboarding();

    if (success) {
      print('✅ Onboarding completed successfully!');

      // Reload user data
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.reloadUserData();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const MainScreen(),
          ),
        );
      }
    } else {
      setState(() => _isProcessing = false);
      _showError('Failed to complete onboarding. Please try again.');
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _progressAnimationController.reverse();
    }
  }

  void _backToGetStarted() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            _buildProgressBar(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(),
                ),
              ),
            ),

            // Navigation Buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              IconButton(
                onPressed: _currentStep > 0 ? _previousStep : _backToGetStarted,
                icon: const Icon(Icons.arrow_back),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryAccent,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                '${((_currentStep / _totalSteps) * 100).toInt()}% complete',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + _progressAnimation.value) / _totalSteps,
                  backgroundColor: AppTheme.primaryAccent.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
                  minHeight: 8,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1PersonalInfo();
      case 1:
        return _buildStep2FitnessGoal();
      case 2:
        return _buildStep3ActivityLevel();
      case 3:
        return _buildStep4Summary();
      default:
        return Container();
    }
  }

  Widget _buildStep1PersonalInfo() {
    return Form(
      key: _step1FormKey,
      child: Column(
        key: const ValueKey('step1'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s get to know you better',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Gender
          Text(
            'Gender',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: SupabaseEnums.genderOptions.map((gender) {
              return DropdownMenuItem(
                value: gender,
                child: Text(
                  gender,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select your gender';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Age
          TextFormField(
            controller: _ageController,
            decoration: const InputDecoration(
              labelText: 'Age',
              prefixIcon: Icon(Icons.cake_outlined),
              suffixText: 'years',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter your age';
              }
              final age = int.tryParse(value!) ?? 0;
              if (age < SupabaseEnums.ageMin || age > SupabaseEnums.ageMax) {
                return 'Age must be between ${SupabaseEnums.ageMin} and ${SupabaseEnums.ageMax}';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Height
          TextFormField(
            controller: _heightController,
            decoration: const InputDecoration(
              labelText: 'Height',
              prefixIcon: Icon(Icons.height),
              suffixText: 'cm',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) => _calculateBMI(),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter your height';
              }
              final height = double.tryParse(value!) ?? 0;
              if (height < SupabaseEnums.heightMin || height > SupabaseEnums.heightMax) {
                return 'Height must be between ${SupabaseEnums.heightMin} and ${SupabaseEnums.heightMax} cm';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Weight
          TextFormField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Current Weight',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
              suffixText: 'kg',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) => _calculateBMI(),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter your weight';
              }
              final weight = double.tryParse(value!) ?? 0;
              if (weight < SupabaseEnums.weightMin || weight > SupabaseEnums.weightMax) {
                return 'Weight must be between ${SupabaseEnums.weightMin} and ${SupabaseEnums.weightMax} kg';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Target Weight (Optional)
          TextFormField(
            controller: _targetWeightController,
            decoration: const InputDecoration(
              labelText: 'Target Weight (Optional)',
              prefixIcon: Icon(Icons.flag_outlined),
              suffixText: 'kg',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            validator: (value) {
              if (value?.isNotEmpty ?? false) {
                final weight = double.tryParse(value!) ?? 0;
                if (weight < SupabaseEnums.targetWeightMin || weight > SupabaseEnums.targetWeightMax) {
                  return 'Target weight must be between ${SupabaseEnums.targetWeightMin} and ${SupabaseEnums.targetWeightMax} kg';
                }
              }
              return null;
            },
          ),

          // BMI Display
          if (_bmi != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getBMIColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getBMIColor()),
              ),
              child: Row(
                children: [
                  Icon(Icons.analytics_outlined, color: _getBMIColor()),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BMI: ${_bmi!.toStringAsFixed(1)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _bmiCategory ?? '',
                          style: TextStyle(color: _getBMIColor()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2FitnessGoal() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fitness Goal',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'What would you like to achieve?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),

        ...SupabaseEnums.fitnessGoals.map((goal) {
          IconData icon;
          String description;

          switch (goal) {
            case 'Lose Weight':
              icon = Icons.trending_down;
              description = 'Reduce body weight and fat percentage';
              break;
            case 'Maintain Weight':
              icon = Icons.balance;
              description = 'Keep your current weight stable';
              break;
            case 'Gain Muscle':
              icon = Icons.fitness_center;
              description = 'Build muscle mass and strength';
              break;
            case 'Improve Fitness':
              icon = Icons.directions_run;
              description = 'Enhance overall fitness and endurance';
              break;
            case 'Build Strength':
              icon = Icons.sports_martial_arts;
              description = 'Increase strength and power';
              break;
            default:
              icon = Icons.flag;
              description = goal;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _GoalOption(
              title: goal,
              subtitle: description,
              icon: icon,
              isSelected: _selectedFitnessGoal == goal,
              onTap: () {
                setState(() {
                  _selectedFitnessGoal = goal;
                });
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStep3ActivityLevel() {
    return Form(
      key: _step3FormKey,
      child: SingleChildScrollView(
        child: Column(
          key: const ValueKey('step3'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity & Experience',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Help us customize your workout plan',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Activity Level
            Text(
              'Activity Level',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedActivityLevel,
              isDense: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.directions_walk),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: SupabaseEnums.activityLevels.map((level) {
                String description;
                switch (level) {
                  case 'Sedentary':
                    description = 'LITTLE OR NO EXERCISE';
                    break;
                  case 'Lightly Active':
                    description = 'EXERCISE 1-3 DAYS/WEEK';
                    break;
                  case 'Moderately Active':
                    description = 'EXERCISE 3-5 DAYS/WEEK';
                    break;
                  case 'Very Active':
                    description = 'EXERCISE 6-7 DAYS/WEEK';
                    break;
                  case 'Extra Active':
                    description = 'VERY INTENSE EXERCISE DAILY';
                    break;
                  default:
                    description = level;
                }

                return DropdownMenuItem(
                  value: level,
                  child: Text(
                    level,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedActivityLevel = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select your activity level';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Experience Level
            Text(
              'Experience Level',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedExperienceLevel,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.star_outline),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: SupabaseEnums.experienceLevels.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(
                    level,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedExperienceLevel = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select your experience level';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Workout Experience
            Text(
              'Workout Experience',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedWorkoutConsistency,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.access_time),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: SupabaseEnums.workoutExperience.map((consistency) {
                return DropdownMenuItem(
                  value: consistency,
                  child: Text(
                    consistency,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWorkoutConsistency = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select your workout experience';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Summary() {
    return Column(
      key: const ValueKey('step4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Personalized Plan',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Based on your information, here are your daily targets',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),

        // Daily Targets
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryAccent.withOpacity(0.1),
                AppTheme.primaryHover.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryAccent.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              _buildTargetRow(
                icon: Icons.local_fire_department,
                label: 'Daily Calories',
                value: '${_dailyTargets['calories'] ?? 2000} kcal',
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildTargetRow(
                icon: Icons.directions_walk,
                label: 'Daily Steps',
                value: '${_dailyTargets['steps'] ?? 10000}',
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _buildTargetRow(
                icon: Icons.bedtime_outlined,
                label: 'Sleep Target',
                value: '${_dailyTargets['sleep'] ?? 8} hours',
                color: Colors.indigo,
              ),
              const SizedBox(height: 16),
              _buildTargetRow(
                icon: Icons.water_drop_outlined,
                label: 'Water Intake',
                value: '${_dailyTargets['water'] ?? 3} liters',
                color: Colors.blue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Profile Summary
        Text(
          'Profile Summary',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildSummaryItem('Goal', _selectedFitnessGoal ?? ''),
        _buildSummaryItem('Activity Level', _selectedActivityLevel ?? ''),
        _buildSummaryItem('Experience', _selectedExperienceLevel ?? ''),
        if (_bmi != null)
          _buildSummaryItem('BMI', '${_bmi!.toStringAsFixed(1)} ($_bmiCategory)'),
        if (_targetWeightController.text.isNotEmpty)
          _buildSummaryItem(
            'Weight Target',
            '${_weightController.text} kg → ${_targetWeightController.text} kg',
          ),

        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.successGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.successGreen),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successGreen),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Your profile is ready! Let\'s start your fitness journey.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTargetRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing
                  ? null
                  : (_currentStep > 0 ? _previousStep : _backToGetStarted),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : (_currentStep == _totalSteps - 1
                      ? _completeOnboarding
                      : _nextStep),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryAccent,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep == _totalSteps - 1 ? 'Complete' : 'Next',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBMIColor() {
    if (_bmi == null) return Colors.grey;
    if (_bmi! < 18.5) return Colors.orange;
    if (_bmi! < 25) return AppTheme.successGreen;
    if (_bmi! < 30) return Colors.orange;
    return AppTheme.errorRed;
  }
}

// Goal Option Widget
class _GoalOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAccent.withOpacity(0.1) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAccent : Theme.of(context).dividerColor,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? AppTheme.primaryGradient
                    : LinearGradient(
                        colors: [
                          AppTheme.primaryAccent.withOpacity(0.8),
                          AppTheme.primaryHover.withOpacity(0.8),
                        ],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isSelected ? AppTheme.primaryAccent : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryAccent,
              ),
          ],
        ),
      ),
    );
  }
}