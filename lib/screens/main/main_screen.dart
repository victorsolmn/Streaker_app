import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/app_theme.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/weight_provider.dart';
import '../../services/toast_service.dart';
import '../../services/popup_service.dart';
import 'nutrition_home_screen.dart';
import 'weight_home_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isDataLoaded = false;
  GlobalKey? _profileKey;
  final ImagePicker _picker = ImagePicker();
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Set initial index from widget parameter
    _currentIndex = widget.initialIndex;
    _profileKey = GlobalKey();
    // Add observer for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    // Initialize toast service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ToastService().initialize(context);
      }
    });
    // Load nutrition data on startup
    _loadUserData();
  }

  @override
  void dispose() {
    // Remove observer when widget is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);

    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // App has come to foreground - refresh nutrition data if needed
      _loadUserData();
    } else if (state == AppLifecycleState.paused) {
      // App is going to background - sync nutrition data to Supabase
      nutritionProvider.syncOnPause();
    }
  }

  Future<void> _loadUserData() async {
    if (_isDataLoaded) return;

    // Early return if widget is not mounted
    if (!mounted) return;

    try {
      // Load nutrition data from Supabase
      final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);
      await nutritionProvider.loadDataFromSupabase();

      if (mounted) {
        setState(() {
          _isDataLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('MainScreen: Error during initial data load: $e');
      if (mounted && context.mounted) {
        ToastService().showError('Failed to load data. Please check your connection and try again.');
      }
    }
  }

  List<Widget> get _screens => [
    const NutritionHomeScreen(),
    const WeightHomeScreen(),
    const ChatScreen(),
    ProfileScreen(key: _profileKey),
  ];

  final List<BottomNavigationBarItem> _bottomNavItems = [
    BottomNavigationBarItem(
      icon: SizedBox(
        width: 24,
        height: 24,
        child: SvgPicture.asset(
          'assets/images/streaker_logo.svg',
          colorFilter: ColorFilter.mode(
            AppTheme.textSecondary,
            BlendMode.srcIn,
          ),
        ),
      ),
      activeIcon: SizedBox(
        width: 24,
        height: 24,
        child: SvgPicture.asset(
          'assets/images/streaker_logo.svg',
          colorFilter: ColorFilter.mode(
            AppTheme.primaryAccent,
            BlendMode.srcIn,
          ),
        ),
      ),
      label: 'Streaks',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.monitor_weight_outlined),
      activeIcon: Icon(Icons.monitor_weight),
      label: 'Weight',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.fitness_center_outlined),
      activeIcon: Icon(Icons.fitness_center_rounded),
      label: 'Workouts',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline_rounded),
      activeIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

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
                            'Meal Description',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _scanFood,
        backgroundColor: _isScanning ? AppTheme.borderColor : AppTheme.primaryAccent,
        child: _isScanning
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(Icons.camera_alt, color: Colors.white, size: 26),
        elevation: 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 6,
        color: Colors.white,
        elevation: 8,
        height: 68,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavBarItem(0, Icons.home_outlined, 'Home'),
              _buildNavBarItem(1, Icons.monitor_weight_outlined, 'Weight'),
              SizedBox(width: 56), // Space for FAB
              _buildNavBarItem(2, Icons.fitness_center_outlined, 'Workouts'),
              _buildNavBarItem(3, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryAccent : AppTheme.textSecondary,
                size: 22,
              ),
              if (isSelected) ...[
                SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.primaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}