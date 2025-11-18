import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tutorial overlay system for first-run user onboarding
/// Shows contextual tooltips to guide users through key features
class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final String tutorialKey; // Unique key to track if tutorial was shown

  const TutorialOverlay({
    Key? key,
    required this.steps,
    required this.onComplete,
    required this.tutorialKey,
  }) : super(key: key);

  /// Show tutorial if not already completed
  static Future<void> showIfNeeded({
    required BuildContext context,
    required List<TutorialStep> steps,
    required String tutorialKey,
    VoidCallback? onComplete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('tutorial_$tutorialKey') ?? false;

    if (!hasShown && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => TutorialOverlay(
          steps: steps,
          tutorialKey: tutorialKey,
          onComplete: () {
            Navigator.of(context).pop();
            onComplete?.call();
          },
        ),
      );
    }
  }

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _currentStep = 0;
  bool _showSkipConfirmation = false;

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_${widget.tutorialKey}', true);
    widget.onComplete();
  }

  void _skipTutorial() {
    setState(() {
      _showSkipConfirmation = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_showSkipConfirmation) {
      return _buildSkipConfirmation(isDarkMode);
    }

    return Material(
      color: Colors.black.withOpacity(0.8),
      child: Stack(
        children: [
          // Highlight area (if position provided)
          if (step.targetPosition != null && step.targetSize != null)
            Positioned(
              left: step.targetPosition!.dx - 8,
              top: step.targetPosition!.dy - 8,
              child: Container(
                width: step.targetSize!.width + 16,
                height: step.targetSize!.height + 16,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryAccent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryAccent.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

          // Tutorial content
          Positioned(
            left: 20,
            right: 20,
            bottom: 60,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          step.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      // Step indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentStep + 1}/${widget.steps.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Progress dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.steps.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _currentStep ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentStep
                              ? AppTheme.primaryAccent
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Navigation buttons
                  Row(
                    children: [
                      // Skip button
                      TextButton(
                        onPressed: _skipTutorial,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Previous button
                      if (_currentStep > 0)
                        OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text('Back'),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),

                      // Next/Done button
                      ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          backgroundColor: AppTheme.primaryAccent,
                        ),
                        child: Text(
                          _currentStep == widget.steps.length - 1 ? 'Got it!' : 'Next',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipConfirmation(bool isDarkMode) {
    return Material(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline,
                size: 48,
                color: AppTheme.primaryAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Skip Tutorial?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You can always access help from the Profile screen later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showSkipConfirmation = false;
                        });
                      },
                      child: const Text('Continue Tutorial'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _completeTutorial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data model for a single tutorial step
class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Offset? targetPosition; // Position of element to highlight
  final Size? targetSize; // Size of element to highlight

  const TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    this.targetPosition,
    this.targetSize,
  });
}
