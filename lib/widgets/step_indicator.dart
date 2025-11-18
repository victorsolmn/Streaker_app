import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Animated step indicator for multi-step flows (onboarding, forms, etc.)
class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;

  const StepIndicator({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Visual dots with connecting lines
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps, (index) {
            return _buildStep(index);
          }),
        ),
        SizedBox(height: 12),
        // Text label
        Text(
          'Step ${currentStep + 1} of $totalSteps${stepLabels != null && stepLabels!.length > currentStep ? ": ${stepLabels![currentStep]}" : ""}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStep(int index) {
    final isActive = index == currentStep;
    final isCompleted = index < currentStep;

    return Row(
      children: [
        // Step dot
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isActive ? 40 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? AppTheme.primaryAccent
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        // Connecting line (except for last step)
        if (index < totalSteps - 1)
          Container(
            width: 24,
            height: 2,
            margin: EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.primaryAccent
                  : Colors.grey[300],
            ),
          ),
      ],
    );
  }
}
