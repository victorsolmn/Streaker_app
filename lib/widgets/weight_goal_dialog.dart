import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weight_provider.dart';
import '../config/theme_config.dart';
import 'package:intl/intl.dart';

class WeightGoalDialog extends StatefulWidget {
  const WeightGoalDialog({Key? key}) : super(key: key);

  @override
  State<WeightGoalDialog> createState() => _WeightGoalDialogState();
}

class _WeightGoalDialogState extends State<WeightGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _targetWeightController = TextEditingController();
  double _selectedWeeklyGoal = 0.5; // Default to 0.5kg per week
  bool _isLoading = false;

  final List<double> _weeklyGoalOptions = [0.25, 0.5, 0.75, 1.0];

  @override
  void initState() {
    super.initState();
    // Pre-fill with current target weight
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final weightProvider = Provider.of<WeightProvider>(context, listen: false);
      if (weightProvider.weightProgress != null) {
        _targetWeightController.text =
            weightProvider.weightProgress!.targetWeight.toStringAsFixed(1);
      }
    });
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    super.dispose();
  }

  // Calculate projected completion date
  DateTime? _calculateProjectedDate(double currentWeight, double targetWeight) {
    if (currentWeight == 0 || targetWeight == 0) return null;

    final weightDifference = (currentWeight - targetWeight).abs();
    if (weightDifference == 0) return DateTime.now();

    final weeksNeeded = weightDifference / _selectedWeeklyGoal;
    final daysNeeded = (weeksNeeded * 7).round();

    return DateTime.now().add(Duration(days: daysNeeded));
  }

  String _formatProjectedDate(DateTime? date) {
    if (date == null) return 'Enter target weight';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  Future<void> _saveGoal(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final weightProvider = Provider.of<WeightProvider>(context, listen: false);
    final targetWeight = double.tryParse(_targetWeightController.text);

    if (targetWeight == null) {
      setState(() => _isLoading = false);
      return;
    }

    final success = await weightProvider.updateTargetWeight(targetWeight);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Weight goal updated successfully!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: ThemeConfig.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  weightProvider.error ?? 'Failed to update weight goal',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: ThemeConfig.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, weightProvider, child) {
        final currentWeight = weightProvider.weightProgress?.currentWeight ?? 0;
        final targetWeight = double.tryParse(_targetWeightController.text) ?? 0;
        final projectedDate = _calculateProjectedDate(currentWeight, targetWeight);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxWidth: 400,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: ThemeConfig.primaryGradient,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.flag,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weight Goal',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Set your target weight',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          fixedSize: Size(40, 40),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Weight Display
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ThemeConfig.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ThemeConfig.primaryColor.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.monitor_weight,
                                    color: ThemeConfig.primaryColor,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Current Weight',
                                    style: TextStyle(
                                      color: ThemeConfig.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${currentWeight.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeConfig.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Target Weight Input
                        Text(
                          'Target Weight',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ThemeConfig.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _targetWeightController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'Enter target weight',
                            suffixText: 'kg',
                            prefixIcon: Icon(Icons.flag, color: ThemeConfig.primaryColor),
                            filled: true,
                            fillColor: ThemeConfig.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: ThemeConfig.primaryColor.withOpacity(0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: ThemeConfig.primaryColor.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: ThemeConfig.primaryColor,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: ThemeConfig.errorColor,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter target weight';
                            }
                            final weight = double.tryParse(value);
                            if (weight == null) {
                              return 'Please enter a valid number';
                            }
                            if (weight <= 0 || weight > 500) {
                              return 'Please enter a weight between 1 and 500 kg';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {}); // Rebuild to update projected date
                          },
                        ),

                        SizedBox(height: 24),

                        // Weekly Goal Dropdown
                        Text(
                          'Weekly Goal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ThemeConfig.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: ThemeConfig.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ThemeConfig.primaryColor.withOpacity(0.2),
                            ),
                          ),
                          child: DropdownButtonFormField<double>(
                            value: _selectedWeeklyGoal,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.trending_down,
                                color: ThemeConfig.primaryColor,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            items: _weeklyGoalOptions.map((goal) {
                              return DropdownMenuItem(
                                value: goal,
                                child: Text(
                                  '${goal.toStringAsFixed(2)} kg per week',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedWeeklyGoal = value);
                              }
                            },
                          ),
                        ),

                        SizedBox(height: 24),

                        // Projected Completion Date
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                ThemeConfig.accentColor.withOpacity(0.1),
                                ThemeConfig.primaryColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ThemeConfig.primaryColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: ThemeConfig.primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  color: ThemeConfig.primaryColor,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Projected Completion',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ThemeConfig.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _formatProjectedDate(projectedDate),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: ThemeConfig.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (projectedDate != null && targetWeight > 0) ...[
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ThemeConfig.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: ThemeConfig.successColor,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    currentWeight > targetWeight
                                        ? 'You need to lose ${(currentWeight - targetWeight).abs().toStringAsFixed(1)} kg'
                                        : 'You need to gain ${(targetWeight - currentWeight).abs().toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ThemeConfig.successColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: ThemeConfig.primaryColor,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: ThemeConfig.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _saveGoal(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConfig.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBackgroundColor:
                                ThemeConfig.primaryColor.withOpacity(0.5),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Save',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
