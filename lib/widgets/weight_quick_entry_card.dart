import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/weight_provider.dart';
import '../config/theme_config.dart';

class WeightQuickEntryCard extends StatefulWidget {
  const WeightQuickEntryCard({Key? key}) : super(key: key);

  @override
  State<WeightQuickEntryCard> createState() => _WeightQuickEntryCardState();
}

class _WeightQuickEntryCardState extends State<WeightQuickEntryCard> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();

  bool _isExpanded = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    _weightFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _logWeight() async {
    // Validate weight input
    final weightText = _weightController.text.trim();
    if (weightText.isEmpty) {
      _showSnackBar('Please enter your weight', isError: true);
      return;
    }

    final weight = double.tryParse(weightText);
    if (weight == null || weight <= 0 || weight > 500) {
      _showSnackBar('Please enter a valid weight between 1 and 500', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final weightProvider = context.read<WeightProvider>();
      final note = _noteController.text.trim();

      final success = await weightProvider.addWeightEntry(
        weight,
        note: note.isEmpty ? null : note,
      );

      if (!mounted) return;

      if (success) {
        _showSnackBar('Weight logged successfully!', isError: false);
        _clearFields();
      } else {
        _showSnackBar(
          weightProvider.error ?? 'Failed to log weight',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _clearFields() {
    _weightController.clear();
    _noteController.clear();
    setState(() {
      _isExpanded = false;
    });
    _weightFocusNode.unfocus();
    _noteFocusNode.unfocus();
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? ThemeConfig.errorColor : ThemeConfig.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, weightProvider, child) {
        // Get last recorded weight for reference
        final lastWeight = weightProvider.entries.isNotEmpty
            ? weightProvider.entries.first.weight
            : weightProvider.weightProgress?.currentWeight;
        final unit = weightProvider.weightProgress?.unit ?? 'kg';

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and last weight
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ThemeConfig.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.monitor_weight,
                          color: ThemeConfig.primaryColor,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Log Today\'s Weight',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (lastWeight != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: ThemeConfig.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Last: ${lastWeight.toStringAsFixed(1)} $unit',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeConfig.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 20),

              // Weight input field
              TextField(
                controller: _weightController,
                focusNode: _weightFocusNode,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'Weight ($unit)',
                  hintText: 'Enter your weight',
                  prefixIcon: Icon(Icons.fitness_center, color: ThemeConfig.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ThemeConfig.primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: ThemeConfig.textPrimary,
                ),
              ),

              SizedBox(height: 12),

              // Expandable note section
              GestureDetector(
                onTap: () {
                  if (!_isSaving) {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: ThemeConfig.primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _isExpanded ? 'Hide note' : 'Add note (optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeConfig.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Note input field (collapsible)
              AnimatedCrossFade(
                firstChild: SizedBox.shrink(),
                secondChild: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _noteController,
                    focusNode: _noteFocusNode,
                    enabled: !_isSaving,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Note',
                      hintText: 'Add any notes about your progress...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ThemeConfig.primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeConfig.textPrimary,
                    ),
                  ),
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: Duration(milliseconds: 300),
              ),

              SizedBox(height: 20),

              // Log Weight button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _logWeight,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: ThemeConfig.primaryColor.withOpacity(0.5),
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Logging...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Log Weight',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
