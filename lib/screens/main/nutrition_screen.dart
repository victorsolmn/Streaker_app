import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/nutrition_provider.dart';
import '../../services/toast_service.dart';
import '../../services/popup_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/nutrition_card.dart';
import '../../widgets/nutrition_entry_card_enhanced.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({Key? key}) : super(key: key);

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Initialize toast service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ToastService().initialize(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scanFood() async {
    try {
      setState(() {
        _isScanning = true;
      });

      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _showErrorDialog(
          'Camera Permission Required',
          'Please enable camera access in your device settings to scan food items.'
        );
        return;
      }

      // Show camera options
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      // Get meal description from user
      final mealDescription = await _showFoodDetailsDialog();
      if (mealDescription == null || mealDescription.isEmpty) return;

      final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);

      // Process the meal description with image
      try {
        final entry = await nutritionProvider.scanFoodWithDescription(
          image.path,
          mealDescription,
        );

        if (entry != null && mounted) {
          // Show preview for the analyzed meal
          final shouldAdd = await _showFoodPreview(entry);
          if (shouldAdd) {
            await nutritionProvider.addNutritionEntry(entry);
            ToastService().showSuccess(
              'Added your meal to nutrition log! 🍎'
            );
          }
        } else {
          if (mounted) {
            _showErrorDialog('Could not analyze your meal. Please try again.');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to analyze meal: ${e.toString()}'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PopupService.showNetworkError(
          context,
          onRetry: () => _scanFood(),
          customMessage: 'Failed to scan food: ${e.toString()}. Please check your connection and try again.',
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
        title: Text(
          'Select Image Source',
          style: TextStyle(
            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.primaryAccent),
              title: Text(
                'Camera',
                style: TextStyle(
                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primaryAccent),
              title: Text(
                'Gallery',
                style: TextStyle(
                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showNutritionPreview(NutritionEntry entry) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
        title: Text(
          'Confirm Food Entry',
          style: TextStyle(
            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.foodName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            _NutritionDetailRow(label: 'Calories', value: '${entry.calories}', unit: 'cal'),
            _NutritionDetailRow(label: 'Protein', value: '${entry.protein.round()}', unit: 'g'),
            _NutritionDetailRow(label: 'Carbs', value: '${entry.carbs.round()}', unit: 'g'),
            _NutritionDetailRow(label: 'Fat', value: '${entry.fat.round()}', unit: 'g'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Add to Log'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildNutritionRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showFoodPreview(dynamic entry) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Extract metadata
    final isEstimated = entry.metadata?['isEstimated'] ?? false;
    final source = entry.metadata?['source'] ?? 'Unknown';
    final confidence = entry.metadata?['confidence'] ?? 0.5;
    final reason = entry.metadata?['reason'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
        title: Row(
          children: [
            Icon(Icons.restaurant_menu, color: AppTheme.primaryAccent, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nutrition Analysis',
                style: TextStyle(
                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // NEW: Source indicator badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isEstimated
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEstimated ? Icons.warning_amber : Icons.check_circle,
                    size: 14,
                    color: isEstimated ? Colors.orange : Colors.green,
                  ),
                  SizedBox(width: 4),
                  Text(
                    isEstimated ? 'Estimated' : 'AI Analyzed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isEstimated ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // NEW: Warning banner for estimated values
              if (isEstimated) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated Values',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              reason ?? 'AI analysis unavailable. Values estimated based on description and local database.',
                              style: TextStyle(
                                color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Confidence: ${(confidence * 100).toInt()}%',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Food name and description
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      entry.foodName,
                      style: TextStyle(
                        color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (entry.quantity != null) ...[
                      SizedBox(height: 4),
                      Text(
                        entry.quantity,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Nutrition summary
              _buildNutritionRow('Calories', '${entry.calories} kcal', Icons.local_fire_department, Colors.orange),
              _buildNutritionRow('Protein', '${entry.protein.toStringAsFixed(1)}g', Icons.fitness_center, Colors.blue),
              _buildNutritionRow('Carbs', '${entry.carbs.toStringAsFixed(1)}g', Icons.bakery_dining, Colors.green),
              _buildNutritionRow('Fat', '${entry.fat.toStringAsFixed(1)}g', Icons.opacity, Colors.purple),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.white,
            ),
            child: Text('Add to Log'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<bool> _showMultipleFoodPreview(List<dynamic> entries) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate total nutrition
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    
    for (var entry in entries) {
      totalCalories += entry.calories;
      totalProtein += entry.protein;
      totalCarbs += entry.carbs;
      totalFat += entry.fat;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
        title: Row(
          children: [
            Icon(Icons.restaurant_menu, color: AppTheme.primaryAccent, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirm Food Entries',
                style: TextStyle(
                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entries.length} item${entries.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: AppTheme.primaryAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, color: AppTheme.primaryAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Total Nutrition Summary',
                            style: TextStyle(
                              color: AppTheme.primaryAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionStat('Calories', '${totalCalories.toInt()}', 'kcal'),
                          ),
                          Expanded(
                            child: _buildNutritionStat('Protein', '${totalProtein.toInt()}', 'g'),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionStat('Carbs', '${totalCarbs.toInt()}', 'g'),
                          ),
                          Expanded(
                            child: _buildNutritionStat('Fat', '${totalFat.toInt()}', 'g'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                
                // Individual food items
                Text(
                  'Individual Food Items:',
                  style: TextStyle(
                    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 12),
                
                ...entries.asMap().entries.map((entry) {
                  int index = entry.key;
                  var foodEntry = entry.value;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                        ? AppTheme.darkCardBackground.withOpacity(0.5)
                        : AppTheme.cardBackgroundLight.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isDarkMode ? AppTheme.dividerDark : AppTheme.dividerLight).withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                foodEntry.foodName,
                                style: TextStyle(
                                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${foodEntry.calories.toInt()} kcal',
                                style: TextStyle(
                                  color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              'P: ${foodEntry.protein.toInt()}g • C: ${foodEntry.carbs.toInt()}g • F: ${foodEntry.fat.toInt()}g',
                              style: TextStyle(
                                color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: Icon(Icons.add, size: 18),
            label: Text('Add All to Log'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildNutritionStat(String label, String value, String unit) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 2),
        RichText(
          text: TextSpan(
            text: value,
            style: TextStyle(
              color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            children: [
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                  fontWeight: FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _showFoodDetailsDialog() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final descriptionController = TextEditingController();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.fromLTRB(20, 80, 20, 40),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).viewInsets.bottom - 120,
            ),
            child: AlertDialog(
              backgroundColor: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
              contentPadding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 16),
            title: Row(
              children: [
                Icon(Icons.restaurant_menu, color: AppTheme.primaryAccent, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Describe Your Meal',
                    style: TextStyle(
                      color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description input field
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                          ? AppTheme.darkCardBackground.withOpacity(0.5)
                          : AppTheme.cardBackgroundLight.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryAccent.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add description with quantity for more accurate results',
                            style: TextStyle(
                              color: AppTheme.primaryAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 12),
                          TextFormField(
                            controller: descriptionController,
                            maxLines: 2,
                            minLines: 2,
                            maxLength: 250,
                            autofocus: false,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: 'Example: 1 plate rice with dal, mixed vegetable curry, 2 chapatis, and a small bowl of curd',
                              hintStyle: TextStyle(
                                color: isDarkMode
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                ? AppTheme.darkBackground.withOpacity(0.5)
                                : Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.all(12),
                              counterText: '${descriptionController.text.length}/250',
                              counterStyle: TextStyle(
                                color: AppTheme.primaryAccent,
                                fontSize: 12,
                              ),
                            ),
                            style: TextStyle(
                              color: isDarkMode
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimary,
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: descriptionController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(descriptionController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text('Analyze'),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }


  void _showErrorDialog(String titleOrMessage, [String? message]) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String actualTitle = message != null ? titleOrMessage : 'Error';
    final String actualMessage = message ?? titleOrMessage;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorRed, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                actualTitle,
                style: TextStyle(
                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          actualMessage,
          style: TextStyle(
            color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal when keyboard appears
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85, // Give more room for keyboard
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: true, // Let Scaffold handle keyboard
            body: Column(
              children: [
                // Title
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add Food Manually',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Form content
                Expanded(
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Food Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16),

                          TextFormField(
                            controller: caloriesController,
                            decoration: InputDecoration(
                              labelText: 'Calories',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16),

                          TextFormField(
                            controller: proteinController,
                            decoration: InputDecoration(
                              labelText: 'Protein (g)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16),

                          TextFormField(
                            controller: carbsController,
                            decoration: InputDecoration(
                              labelText: 'Carbs (g)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16),

                          TextFormField(
                            controller: fatController,
                            decoration: InputDecoration(
                              labelText: 'Fat (g)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 20), // Extra space at bottom for keyboard
                        ],
                      ),
                    ),
                  ),
                ),
                // Actions
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel'),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final entry = NutritionEntry(
                              id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                              foodName: nameController.text,
                              calories: int.parse(caloriesController.text),
                              protein: double.parse(proteinController.text),
                              carbs: double.parse(carbsController.text),
                              fat: double.parse(fatController.text),
                              timestamp: DateTime.now(),
                            );

                            final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);
                            await nutritionProvider.addNutritionEntry(entry);

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added ${entry.foodName} to your nutrition log'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text('Add Food'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nutrition'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryAccent,
          labelColor: AppTheme.primaryAccent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'History'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'scan':
                  _scanFood();
                  break;
                case 'manual':
                  _showManualEntryDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'scan',
                child: ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Scan Food'),
                ),
              ),
              const PopupMenuItem(
                value: 'manual',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('Add Manually'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Manual Entry FAB - More visible and accessible
          FloatingActionButton.small(
            heroTag: 'manual_entry',
            onPressed: _showManualEntryDialog,
            backgroundColor: AppTheme.successGreen,
            child: Icon(Icons.edit, size: 20),
          ),
          SizedBox(height: 12),
          // Main Camera FAB
          FloatingActionButton(
            heroTag: 'camera_scan',
            onPressed: _isScanning ? null : _scanFood,
            backgroundColor: _isScanning
                ? AppTheme.borderColor
                : AppTheme.primaryAccent,
            child: _isScanning
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  )
                : Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    return Consumer<NutritionProvider>(
      builder: (context, nutritionProvider, child) {
        final todayNutrition = nutritionProvider.todayNutrition;
        
        return RefreshIndicator(
          onRefresh: () async {
            // Reload nutrition data from Supabase
            await nutritionProvider.loadDataFromSupabase();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nutrition overview
                NutritionOverviewCard(
                  dailyNutrition: todayNutrition,
                  calorieGoal: nutritionProvider.calorieGoal,
                  proteinGoal: nutritionProvider.proteinGoal,
                  carbGoal: nutritionProvider.carbGoal,
                  fatGoal: nutritionProvider.fatGoal,
                ),
                SizedBox(height: 24),
                
                // Macro breakdown
                MacroBreakdownCard(dailyNutrition: todayNutrition),
                SizedBox(height: 24),
                
                // Today's meals
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Meals',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${todayNutrition.entries.length} meals',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                if (todayNutrition.entries.isEmpty)
                  _buildEmptyState()
                else
                  ...todayNutrition.entries.map(
                    (entry) => NutritionEntryCardEnhanced(
                      entry: entry,
                      onDelete: () async {
                        final confirm = await _showDeleteConfirmation();
                        if (confirm) {
                          await nutritionProvider.removeNutritionEntry(entry.id);
                        }
                      },
                    ),
                  ),
                
                SizedBox(height: 80), // Space for FAB
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Consumer<NutritionProvider>(
      builder: (context, nutritionProvider, child) {
        final weeklyNutrition = nutritionProvider.getWeeklyNutrition();
        
        return RefreshIndicator(
          onRefresh: () async {
            // Reload nutrition data from Supabase
            await nutritionProvider.loadDataFromSupabase();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                
                ...weeklyNutrition.map((dailyNutrition) {
                  final dayName = _getDayName(dailyNutrition.date);
                  final isToday = _isToday(dailyNutrition.date);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dayName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isToday ? AppTheme.primaryAccent : null,
                                  ),
                                ),
                                if (isToday) ...[
                                  SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Today',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.primaryAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  '${dailyNutrition.totalCalories} cal',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            
                            Row(
                              children: [
                                Text(
                                  'P: ${dailyNutrition.totalProtein.round()}g',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  'C: ${dailyNutrition.totalCarbs.round()}g',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  'F: ${dailyNutrition.totalFat.round()}g',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${dailyNutrition.entries.length} meals',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                
                SizedBox(height: 80), // Space for FAB
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? AppTheme.darkCardBackground 
            : AppTheme.cardBackgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode 
              ? AppTheme.dividerDark 
              : AppTheme.dividerLight,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 40,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No meals logged today',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the camera button to scan your first meal',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
        title: Text(
          'Delete Entry',
          style: TextStyle(
            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this nutrition entry?',
          style: TextStyle(
            color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _getDayName(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[date.weekday - 1];
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }
}

class _NutritionDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _NutritionDetailRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            '$value $unit',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}