import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import '../../providers/supabase_auth_provider.dart';
import '../../providers/supabase_user_provider.dart';
import '../../providers/supabase_nutrition_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/health_provider.dart';
import '../../services/unified_health_service.dart';
import '../../services/native_health_connect_service.dart';
import '../../services/flutter_health_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../health_debug_screen.dart';
import '../database_test_screen.dart';
import '../../utils/app_theme.dart';
import '../auth/welcome_screen.dart';
import 'edit_goals_screen.dart';
import 'edit_profile_screen.dart';
import 'main_screen.dart';
import '../../services/health_log_capture_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/fitness_goals_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  

  @override
  void initState() {
    super.initState();
    // Load actual data from Supabase
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Auto-reload profile data from Supabase
      final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
      await userProvider.reloadUserProfile();

    });
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          color: AppTheme.primaryAccent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(),
                _buildProfileInfo(),
                _buildFitnessGoalsSection(),
                _buildDailyTargetsSection(),
                _buildSettingsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshProfile() async {
    try {
      // Refresh profile data
      final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
      await userProvider.reloadUserProfile();

      // Refresh health data
      final healthProvider = Provider.of<HealthProvider>(context, listen: false);
      if (healthProvider.isHealthSourceConnected) {
        await healthProvider.syncWithHealth();
      }

      // Update UI
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile refreshed successfully!'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh profile: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardBackground : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(),
                ),
              ).then((_) {
                // Refresh profile data after returning from edit screen
                if (mounted) {
                  _refreshProfile();
                }
              });
            },
            icon: Icon(
              Icons.edit,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Consumer<SupabaseUserProvider>(
      builder: (context, userProvider, child) {
        final profile = userProvider.userProfile;
        
        return Container(
          color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardBackground : Colors.white,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Profile Image
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryAccent.withOpacity(0.1),
                    border: Border.all(
                      color: AppTheme.primaryAccent,
                      width: 3,
                    ),
                    image: _getProfileImage(),
                  ),
                  child: _getProfileImage() == null
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: AppTheme.primaryAccent,
                        )
                      : null,
                ),
              ),
              SizedBox(width: 20),
              // Profile Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.name ?? 'User',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (profile?.height != null)
                      _buildInfoRow(Icons.height, '${profile!.height!.toStringAsFixed(0)} cm'),
                    SizedBox(height: 4),
                    if (profile?.age != null)
                      _buildInfoRow(Icons.cake, '${profile!.age} years old'),
                    if (profile?.weight != null) ...[
                      SizedBox(height: 4),
                      _buildInfoRow(Icons.monitor_weight, '${profile!.weight!.toStringAsFixed(1)} kg'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.textSecondaryDark
              : AppTheme.textSecondary,
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }


  Widget _buildFitnessGoalsSection() {
    return Consumer<SupabaseUserProvider>(
      builder: (context, userProvider, child) {
        final profile = userProvider.userProfile;
        if (profile == null) return SizedBox.shrink();

        return FitnessGoalsCard(profile: profile);
      },
    );
  }

  Widget _buildDailyTargetsSection() {
    return Consumer<SupabaseUserProvider>(
      builder: (context, userProvider, child) {
        final profile = userProvider.userProfile;
        if (profile == null) return SizedBox.shrink();

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(20),
          color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Targets
              if (profile.dailyCaloriesTarget != null ||
                  profile.dailyStepsTarget != null ||
                  profile.dailySleepTarget != null ||
                  profile.dailyWaterTarget != null) ...[
                Text(
                  'Daily Targets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: 16),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (profile.dailyActiveCaloriesTarget != null)
                      _buildTargetChip(
                        icon: Icons.local_fire_department,
                        label: '${profile.dailyActiveCaloriesTarget} kcal burn',
                        color: Colors.orange,
                      ),
                    if (profile.dailyStepsTarget != null)
                      _buildTargetChip(
                        icon: Icons.directions_walk,
                        label: '${profile.dailyStepsTarget} steps',
                        color: Colors.blue,
                      ),
                    if (profile.dailySleepTarget != null)
                      _buildTargetChip(
                        icon: Icons.bedtime,
                        label: '${profile.dailySleepTarget!.toStringAsFixed(1)}h sleep',
                        color: Colors.purple,
                      ),
                    if (profile.dailyWaterTarget != null)
                      _buildTargetChip(
                        icon: Icons.water_drop,
                        label: '${profile.dailyWaterTarget!.toStringAsFixed(1)}L water',
                        color: Colors.cyan,
                      ),
                  ],
                ),
              ],

              // Weight Progress Navigation
              if (profile.targetWeight != null && profile.weight != null) ...[
                SizedBox(height: 20),
                InkWell(
                  onTap: () {
                    // Navigate to Progress tab
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MainScreen(initialIndex: 1), // Progress tab index
                      ),
                      (route) => false,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.show_chart,
                          color: AppTheme.primaryAccent,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weight Progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Current: ${profile.weight!.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryAccent,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Goal: ${profile.targetWeight!.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildGoalItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTargetChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
  
  String _formatGoal(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.weightLoss:
        return 'Weight Loss';
      case FitnessGoal.muscleGain:
        return 'Muscle Gain';
      case FitnessGoal.maintenance:
        return 'Maintenance';
      case FitnessGoal.endurance:
        return 'Endurance';
    }
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardBackground : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 16),
          _buildThemeToggle(),
          const Divider(height: 32),
          _buildSettingItem(
            icon: Icons.watch,
            title: 'Smartwatch Integration',
            subtitle: 'Manage health data sync',
            onTap: () => showSmartwatchIntegrationDialog(),
          ),
          _buildSettingItem(
            icon: Icons.track_changes,
            title: 'Nutrition Goals',
            subtitle: 'Adjust your daily targets',
            onTap: () => _showNutritionGoalsDialog(),
          ),
          _buildSettingItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage your reminders',
            onTap: () => _showNotificationsDialog(),
          ),
          _buildSettingItem(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Privacy settings',
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.backup_outlined,
            title: 'Data Export',
            subtitle: 'Export your fitness data',
            onTap: () => _showDataExportDialog(),
          ),
          _buildSettingItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: () => _showHelpDialog(),
          ),
          // Debug menu (only in debug mode)
          if (const bool.fromEnvironment('dart.vm.product') == false) ...[
            _buildSettingItem(
              icon: Icons.bug_report_outlined,
              title: 'Database Test',
              subtitle: 'Test database integration & generate test data',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DatabaseTestScreen(),
                  ),
                );
              },
            ),
            _buildSettingItem(
              icon: Icons.api_outlined,
              title: 'Capture Health Data Logs',
              subtitle: 'Export detailed Health Connect API responses',
              onTap: () async {
                _captureHealthDataLogs();
              },
            ),
          ],
          _buildSettingItem(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () => _showAboutDialog(),
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: const BorderSide(color: AppTheme.errorRed),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.logout),
              label: Text(
                'Sign Out',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: AppTheme.primaryAccent,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Switch between light and dark mode',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.textSecondaryDark 
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
            activeColor: AppTheme.primaryAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryAccent.withOpacity(0.1), AppTheme.primaryHover.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryAccent,
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.textSecondaryDark 
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.dividerDark 
                  : AppTheme.dividerLight,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });

      // Upload to Supabase storage
      try {
        final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
        final userId = SupabaseService().currentUser?.id;

        if (userId != null) {
          // Show loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Uploading profile photo...'),
                ],
              ),
              backgroundColor: AppTheme.primaryAccent,
              duration: Duration(seconds: 30),
            ),
          );

          // Upload photo and update profile
          await SupabaseService().updateProfilePhoto(
            userId: userId,
            filePath: image.path,
          );

          // Reload profile to get updated photo URL
          await userProvider.loadUserProfile();

          // Clear any existing snackbars
          ScaffoldMessenger.of(context).clearSnackBars();

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profile photo updated successfully!'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        }
      } catch (e) {
        // Clear loading snackbar
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload photo: ${e.toString()}'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  DecorationImage? _getProfileImage() {
    final userProvider = Provider.of<SupabaseUserProvider>(context);
    final photoUrl = userProvider.userProfile?.photoUrl;

    // First priority: Supabase photo URL
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return DecorationImage(
        image: NetworkImage(photoUrl),
        fit: BoxFit.cover,
      );
    }

    // Second priority: Local file (temporary during upload)
    if (_profileImage != null) {
      return DecorationImage(
        image: FileImage(_profileImage!),
        fit: BoxFit.cover,
      );
    }

    return null;
  }


  void _showNutritionGoalsDialog() {
    final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);
    final calorieController = TextEditingController(text: nutritionProvider.calorieGoal.toString());
    final proteinController = TextEditingController(text: nutritionProvider.proteinGoal.toString());
    final carbController = TextEditingController(text: nutritionProvider.carbGoal.toString());
    final fatController = TextEditingController(text: nutritionProvider.fatGoal.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nutrition Goals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: calorieController,
              decoration: const InputDecoration(
                labelText: 'Daily Calories',
                helperText: 'Range: 500-10000',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: proteinController,
              decoration: const InputDecoration(
                labelText: 'Protein (g)',
                helperText: 'Range: 0-999',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,1})?$')),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: carbController,
              decoration: const InputDecoration(
                labelText: 'Carbs (g)',
                helperText: 'Range: 0-999',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,1})?$')),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: fatController,
              decoration: const InputDecoration(
                labelText: 'Fat (g)',
                helperText: 'Range: 0-999',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,1})?$')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate inputs
              final calories = int.tryParse(calorieController.text);
              final protein = double.tryParse(proteinController.text);
              final carbs = double.tryParse(carbController.text);
              final fat = double.tryParse(fatController.text);

              // Check calorie range
              if (calories != null && (calories < 500 || calories > 10000)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Calories must be between 500 and 10000'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
                return;
              }

              // Check macros range
              if ((protein != null && (protein < 0 || protein > 999)) ||
                  (carbs != null && (carbs < 0 || carbs > 999)) ||
                  (fat != null && (fat < 0 || fat > 999))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Macros must be between 0 and 999 grams'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
                return;
              }

              await nutritionProvider.updateGoals(
                calorieGoal: calories,
                proteinGoal: protein,
                carbGoal: carbs,
                fatGoal: fat,
              );
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Nutrition goals updated successfully!'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notifications'),
        content: Text('Notification settings will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDataExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Data Export'),
        content: Text('Data export functionality will be added in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Help & Support'),
        content: Text('For support, please contact us at support@streaker.app\n\nWe\'re here to help you achieve your fitness goals!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About Streaker'),
        content: Text('Streaker v1.0.0\n\nYour personal fitness companion for tracking nutrition, building streaks, and achieving your health goals.\n\nBuilt with Flutter 💙'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _captureHealthDataLogs() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        title: Row(
          children: [
            Icon(Icons.api_outlined, color: AppTheme.primaryAccent),
            SizedBox(width: 12),
            Text('Capturing Health Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryAccent),
            const SizedBox(height: 16),
            Text('Fetching Health Connect API responses...'),
            const SizedBox(height: 8),
            Text(
              'This may take a few seconds',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      // Capture the health logs
      final result = await HealthLogCaptureService.captureAndSaveHealthLogs();

      // Close loading dialog
      Navigator.of(context).pop();

      if (result['success']) {
        // Show success dialog with analysis
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Logs Captured Successfully'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Health data logs have been exported!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text('📁 Saved to:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    result['filePath'] ?? 'Unknown location',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  SizedBox(height: 16),
                  if (result['analysis'] != null) ...[
                    Text('📊 Data Found:', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    if (result['analysis']['hasActiveCalories'] == true)
                      Text('✅ Active Calories: ${result['analysis']['activeCaloriesCount']} records'),
                    if (result['analysis']['hasTotalCalories'] == true)
                      Text('✅ Total Calories: ${result['analysis']['totalCaloriesCount']} records'),
                    if (result['analysis']['hasBasalMetabolicRate'] == true)
                      Text('✅ BMR: ${result['analysis']['basalMetabolicRateCount']} records'),
                    if (result['analysis']['hasExerciseSessions'] == true)
                      Text('✅ Exercise: ${result['analysis']['exerciseSessionCount']} sessions'),
                    SizedBox(height: 12),
                    if (result['analysis']['recommendations'] != null &&
                        (result['analysis']['recommendations'] as List).isNotEmpty) ...[
                      Text('💡 Recommendations:', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      ...(result['analysis']['recommendations'] as List).map((rec) =>
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '• $rec',
                              style: TextStyle(fontSize: 12),
                            ),
                          )),
                    ],
                  ],
                  SizedBox(height: 16),
                  Text(
                    'Please share this log file with the developer to debug calorie tracking issues.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Copy file path to clipboard
                  Clipboard.setData(ClipboardData(text: result['filePath'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📋 File path copied to clipboard'),
                      backgroundColor: AppTheme.primaryAccent,
                    ),
                  );
                },
                child: Text('Copy Path'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK', style: TextStyle(color: AppTheme.primaryAccent)),
              ),
            ],
          ),
        );

        // Also print summary to console
        await HealthLogCaptureService.printLogSummary(result);

      } else {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 12),
                Text('Failed to Capture Logs'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result['error'] ?? 'Unknown error occurred'),
                SizedBox(height: 12),
                Text(
                  'Please ensure:\n• Health Connect is installed\n• Permissions are granted\n• Device has health data',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK', style: TextStyle(color: AppTheme.primaryAccent)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
          title: Text('Error'),
          content: Text('Failed to capture health logs: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Get providers before closing dialog
              final supabaseAuthProvider = Provider.of<SupabaseAuthProvider>(context, listen: false);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);
              final healthProvider = Provider.of<HealthProvider>(context, listen: false);
              
              // Close the confirmation dialog
              Navigator.of(context).pop();
              
              try {
                print('Starting logout process...');
                
                // Clear all local data first
                await userProvider.clearUserData();
                await nutritionProvider.clearNutritionData();
                
                // Clear health provider connections
                if (healthProvider.isInitialized) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('health_connect_connected');
                  await prefs.remove('health_kit_connected');
                  await prefs.remove('connected_health_source');
                }
                
                // Navigate to welcome screen first
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                    (route) => false,
                  );
                }
                
                // Then sign out from auth providers (this won't affect navigation)
                await authProvider.signOut();
                await supabaseAuthProvider.signOut();
                
                print('Logout successful');
              } catch (e) {
                print('Logout error: $e');
                // Still navigate to welcome screen even if there's an error
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                    (route) => false,
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void showSmartwatchIntegrationDialog() async {
    final healthProvider = Provider.of<HealthProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Check current health source status
    final currentSource = healthProvider.dataSource;
    final isHealthConnected = healthProvider.isHealthSourceConnected;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Drag handle indicator
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.watch,
                      color: AppTheme.primaryAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Smartwatch Integration',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                if (isHealthConnected) ...[
                  // Already connected - show current status
                  _buildCurrentConnectionStatus(healthProvider, isDarkMode),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await healthProvider.syncWithHealth();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Health data synced successfully!'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          },
                          icon: Icon(Icons.sync, size: 20),
                          label: Text('Sync Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            // Force re-request all permissions including new data types
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => AlertDialog(
                                title: Text('Re-authorizing Health Permissions'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: AppTheme.primaryAccent),
                                    const SizedBox(height: 16),
                                    Text('Please grant all requested health permissions...'),
                                  ],
                                ),
                              ),
                            );

                            final success = await healthProvider.healthService.forceRequestAllPermissions();
                            Navigator.pop(context); // Close dialog

                            if (success) {
                              await healthProvider.fetchMetrics();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Permissions updated! Health data syncing...'),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Failed to update permissions. Please try again.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.security, size: 20),
                          label: Text('Re-authorize'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Not connected - show connection options
                  Text(
                    'Your smartwatch data syncs automatically through your phone\'s health app:',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Platform-specific health integration options
                  if (Platform.isAndroid) ...[
                    // Android: Health Connect Integration
                    _buildIntegrationOption(
                      context,
                      icon: Icons.favorite,
                      title: 'Google Health Connect',
                      subtitle: 'Recommended for Android',
                      description: 'Connect to Samsung Health, Google Fit, and other health apps. Works with all major smartwatch brands (Samsung Galaxy Watch, Pixel Watch, Wear OS devices).',
                      isRecommended: true,
                      onTap: () async {
                        Navigator.pop(context);
                        _connectNativeHealthConnect();
                      },
                      isDarkMode: isDarkMode,
                    ),
                  ] else if (Platform.isIOS) ...[
                    // iOS: HealthKit Integration  
                    _buildIntegrationOption(
                      context,
                      icon: Icons.health_and_safety,
                      title: 'Apple HealthKit',
                      subtitle: 'Recommended for iOS',
                      description: 'Connect to Apple Health app. Works with Apple Watch, and other compatible fitness trackers that sync to Apple Health.',
                      isRecommended: true,
                      onTap: () async {
                        Navigator.pop(context);
                        _connectAppleHealthKit();
                      },
                      isDarkMode: isDarkMode,
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // Flutter Health Integration - Universal cross-platform option
                  _buildIntegrationOption(
                    context,
                    icon: Icons.health_and_safety_outlined,
                    title: 'Flutter Health Integration',
                    subtitle: 'Universal cross-platform (Recommended)',
                    description: Platform.isIOS 
                      ? 'Advanced HealthKit integration supporting Apple Watch and all compatible fitness devices with comprehensive health metrics.'
                      : 'Enhanced Health Connect integration supporting Samsung Galaxy Watch, Google Pixel Watch, Fitbit, Garmin, and all Wear OS devices with comprehensive health data sync.',
                    isRecommended: true,
                    onTap: () async {
                      Navigator.pop(context);
                      _connectFlutterHealth();
                    },
                    isDarkMode: isDarkMode,
                  ),
                ],
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }
  // Helper method to build current connection status display
  Widget _buildCurrentConnectionStatus(HealthProvider healthProvider, bool isDarkMode) {
    String sourceName;
    IconData sourceIcon;
    Color sourceColor;
    
    switch (healthProvider.dataSource) {
      case HealthDataSource.healthKit:
        sourceName = 'Apple Health';
        sourceIcon = Icons.favorite;
        sourceColor = Colors.red;
        break;
      case HealthDataSource.healthConnect:
        sourceName = 'Samsung Health / Health Connect';
        sourceIcon = Icons.favorite;
        sourceColor = Colors.green;
        break;
      default:
        sourceName = 'Unknown';
        sourceIcon = Icons.help_outline;
        sourceColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.green.withOpacity(0.1) : Colors.green.withOpacity(0.05),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected to $sourceName',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your health data is being synced automatically',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(sourceIcon, color: sourceColor, size: 20),
        ],
      ),
    );
  }

  // Helper method to build integration option cards
  Widget _buildIntegrationOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required bool isRecommended,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isRecommended ? AppTheme.primaryAccent : Colors.grey.withOpacity(0.3),
            width: isRecommended ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isRecommended 
              ? AppTheme.primaryAccent.withOpacity(0.05) 
              : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isRecommended ? AppTheme.primaryAccent : Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isRecommended ? AppTheme.primaryAccent : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to connect using native Health Connect implementation
  Future<void> _connectNativeHealthConnect() async {
    if (!Platform.isAndroid) {
      _showDetailedError(
        'Android Only',
        'Native Health Connect is only available on Android devices',
        [],
      );
      return;
    }
    
    final nativeService = NativeHealthConnectService();
    
    // Show testing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Testing Native Health Connect'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryAccent),
            const SizedBox(height: 16),
            Text('Running native implementation...'),
            const SizedBox(height: 8),
            Text(
              'This uses the proper native Android SDK',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
    
    try {
      // Run the complete test flow
      final testResults = await nativeService.testHealthConnectFlow();
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (testResults['success'] == true) {
        // Success! Show the health data
        final healthData = testResults['healthData'] ?? {};
        
        // Start background sync automatically
        await nativeService.startBackgroundSync();
        
        // Get last sync info
        final syncInfo = await nativeService.getLastSyncInfo();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Native Health Connect works! Background sync enabled.'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Update health provider with the data
        final healthProvider = Provider.of<HealthProvider>(context, listen: false);
        healthProvider.updateMetricsFromHealth(healthData);
        
        // Extract data sources
        final dataSources = (healthData['dataSources'] as List<dynamic>?) ?? [];
        // Samsung Health uses com.sec.android.app.shealth
        final hasSamsungData = dataSources.any((source) => 
          source.toString().contains('samsung') || 
          source.toString().contains('shealth') || 
          source.toString().contains('com.sec.android') || 
          source.toString().contains('gear'));
        
        // Show success dialog with data
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Connected Successfully!'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasSamsungData) ...[
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.successGreen),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.watch, color: AppTheme.successGreen, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Samsung Health/Galaxy Watch detected!',
                              style: TextStyle(
                                color: AppTheme.successGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No Samsung Health data found',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  Text('Today\'s Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Steps: ${healthData['steps'] ?? 0}'),
                  if (healthData['stepsBySource'] != null) ...[
                    Text(
                      'Data Source: ${(healthData['stepsBySource'] as Map)['dataSource'] ?? 'Unknown'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Samsung: ${(healthData['stepsBySource'] as Map)['samsung'] ?? 0} | Google Fit: ${(healthData['stepsBySource'] as Map)['googleFit'] ?? 0}',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  Text('Heart Rate: ${healthData['heartRate'] ?? 0} bpm ${healthData['heartRateType'] == 'resting' ? '(resting)' : ''}'),
                  Text('Calories: ${healthData['calories'] ?? 0}'),
                  Text('Distance: ${(healthData['distance'] ?? 0.0).toStringAsFixed(2)} km'),
                  if (healthData['sleep'] != null && healthData['sleep'] > 0) ...[
                    Text('Sleep: ${(healthData['sleep'] as double).toStringAsFixed(1)} hours'),
                    if (healthData['sleepStages'] != null) 
                      Text(
                        'Sleep Stages: ${(healthData['sleepStages'] as Map).entries.map((e) => '${e.key}: ${e.value}m').join(', ')}',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ] else
                    Text('Sleep: No data'),
                  
                  const SizedBox(height: 16),
                  Divider(),
                  const SizedBox(height: 8),
                  
                  Text('Sync Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.sync, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Last sync: ${healthData['lastSync'] != null ? healthData['lastSync'].toString().substring(0, 19) : 'Just now'}'),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.refresh, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Auto-sync: On app open'),
                    ],
                  ),
                  
                  if (dataSources.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Data sources:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...dataSources.map((source) => Padding(
                      padding: EdgeInsets.only(left: 16, top: 2),
                      child: Text(
                        '• ${source}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )),
                  ],
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                ),
                child: Text('Great!', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        // Show detailed error with user guidance
        final errorMsg = testResults['message'] ?? testResults['error'] ?? 'Unknown error occurred';
        final permissionStatus = testResults['permissionRequest'] as Map<String, dynamic>?;
        
        String userGuidance = 'Health Connect integration failed.';
        if (permissionStatus != null && permissionStatus['granted'] == false) {
          final missing = permissionStatus['missingPermissions'] as List<dynamic>? ?? [];
          if (missing.isNotEmpty) {
            userGuidance = '''Health Connect permissions are required for data sync.

Missing permissions:
${missing.map((p) => '• ${p.toString().split('.').last}').join('\n')}

To fix this:
1. Open Health Connect app
2. Go to App permissions → Streaker
3. Grant all requested permissions
4. Return to Streaker and try again''';
          } else {
            userGuidance = '''Please grant all health permissions in Health Connect.

Steps to fix:
1. Open Health Connect app
2. Find Streaker in app permissions
3. Enable access to all health data types:
   • Steps, Heart Rate, Calories, Distance
   • Sleep, Water, Weight, Blood metrics
   • Exercise sessions
4. Return to Streaker and try connecting again''';
          }
        }
        
        _showDetailedError(
          'Health Connect Setup Needed',
          userGuidance,
          nativeService.debugLogs,
        );
      }
    } catch (e) {
      Navigator.pop(context);
      _showDetailedError(
        'Unexpected Error',
        e.toString(),
        nativeService.debugLogs,
      );
    }
  }

  // Method to connect to Apple HealthKit for iOS
  Future<void> _connectAppleHealthKit() async {
    if (!Platform.isIOS) {
      _showDetailedError(
        'iOS Only',
        'Apple HealthKit is only available on iOS devices',
        [],
      );
      return;
    }

    final healthProvider = Provider.of<HealthProvider>(context, listen: false);
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Connecting to Apple Health'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryAccent),
            const SizedBox(height: 16),
            Text('Please grant permissions in the Health app...'),
          ],
        ),
      ),
    );

    try {
      // Initialize health provider
      await healthProvider.initialize();
      
      // Check if health service is available
      if (healthProvider.dataSource != HealthDataSource.unavailable) {
        // Try to connect and sync data
        await healthProvider.syncWithHealth();
        
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connected to Apple Health! Your health data will now sync automatically.'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        Navigator.pop(context); // Close loading dialog
        
        _showDetailedError(
          'Apple Health Connection Failed',
          'Please ensure you have granted the necessary permissions in the Health app.',
          [],
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      
      _showDetailedError(
        'Apple Health Connection Error',
        e.toString(),
        [],
      );
    }
  }

  // Method to connect using Flutter Health plugin for cross-platform compatibility
  Future<void> _connectFlutterHealth() async {
    final flutterHealthService = FlutterHealthService();
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Connecting to Flutter Health'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryAccent),
            const SizedBox(height: 16),
            Text(Platform.isIOS 
              ? 'Requesting HealthKit permissions...'
              : 'Requesting Health Connect permissions...'),
            const SizedBox(height: 8),
            Text(
              'This uses the official Flutter Health plugin for optimal compatibility',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
    
    try {
      // Initialize the Flutter Health service
      await flutterHealthService.initialize();
      
      // Request permissions
      final permissionsGranted = await flutterHealthService.requestPermissions();
      
      if (!permissionsGranted) {
        Navigator.pop(context); // Close loading dialog
        _showDetailedError(
          'Health Permissions Required',
          'Please grant health permissions to sync your smartwatch data.',
          ['Open your device health app and grant permissions', 'Try the connection again'],
        );
        return;
      }
      
      // Check if permissions are properly granted
      final hasPermissions = await flutterHealthService.hasPermissions();
      
      if (!hasPermissions) {
        Navigator.pop(context); // Close loading dialog
        _showDetailedError(
          'Health Permissions Not Granted',
          'Health permissions were not properly granted. Please check your device settings.',
          ['Grant all requested health permissions', 'Restart the app if needed'],
        );
        return;
      }
      
      // Get today's health data to test the connection
      final healthData = await flutterHealthService.getTodaysHealthData();
      final deviceInfo = flutterHealthService.getDeviceInfo();
      
      Navigator.pop(context); // Close loading dialog
      
      // Update health provider with the data
      final healthProvider = Provider.of<HealthProvider>(context, listen: false);
      final convertedHealthData = {
        'steps': healthData['steps'] ?? 0,
        'heartRate': healthData['heartRate'] ?? 0,
        'calories': healthData['calories'] ?? 0,
        'distance': healthData['distance'] ?? 0.0,
        'sleep': healthData['sleep'] ?? 0.0,
      };
      healthProvider.updateMetricsFromHealth(convertedHealthData);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Flutter Health connected! Your smartwatch data will now sync automatically.'),
          backgroundColor: AppTheme.successGreen,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Show success dialog with smartwatch compatibility info
      final smartwatchSources = healthData['smartwatchSources'] as List<String>? ?? [];
      final hasSmartWatchData = healthData['hasSmartWatchData'] as bool? ?? false;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Flutter Health Connected!'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasSmartWatchData && smartwatchSources.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.successGreen),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.watch, color: AppTheme.successGreen, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Smartwatch Detected!',
                                style: TextStyle(
                                  color: AppTheme.successGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...smartwatchSources.map((source) => Padding(
                          padding: EdgeInsets.only(left: 28, bottom: 4),
                          child: Text(
                            '• $source',
                            style: TextStyle(color: AppTheme.successGreen, fontSize: 12),
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No smartwatch data detected yet. Data may appear after your next workout.',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                Text('Health System: ${deviceInfo['healthSystem']}', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                Text('Compatible Devices:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...(deviceInfo['supportedWatches'] as List<String>).map((watch) => 
                  Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 2),
                    child: Text('• $watch', style: TextStyle(fontSize: 12)),
                  )).toList(),
                
                const SizedBox(height: 16),
                Text('Today\'s Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Steps: ${healthData['steps']}'),
                Text('Heart Rate: ${healthData['heartRate']} bpm'),
                Text('Calories: ${healthData['calories']}'),
                Text('Distance: ${(healthData['distance'] as double).toStringAsFixed(2)} km'),
                if (healthData['sleep'] > 0) Text('Sleep: ${(healthData['sleep'] as double).toStringAsFixed(1)} hours'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Great!', style: TextStyle(color: AppTheme.primaryAccent)),
            ),
          ],
        ),
      );
      
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      
      _showDetailedError(
        'Flutter Health Connection Error',
        'Failed to connect to Flutter Health: $e',
        [
          'Make sure your device has the health app installed',
          Platform.isAndroid ? 'Install Health Connect from Play Store' : 'Check Apple Health app',
          'Grant all requested permissions',
          'Try connecting again',
        ],
      );
    }
  }

  // Method to connect to health app
  Future<void> _connectToHealthApp() async {
    final healthProvider = Provider.of<HealthProvider>(context, listen: false);
    final healthService = healthProvider.healthService;
    
    // First ensure the health service is initialized
    if (!healthService.isInitialized) {
      // Show initializing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryAccent),
              const SizedBox(height: 16),
              Text('Initializing health service...'),
            ],
          ),
        ),
      );
      
      await healthService.initialize();
      Navigator.pop(context);
    }
    
    // Show connecting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryAccent),
            const SizedBox(height: 16),
            Text('Connecting to health app...'),
            const SizedBox(height: 8),
            Text(
              'Please grant all permissions when prompted',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      // Request health permissions with detailed error handling
      final result = await healthService.requestHealthPermissions();
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (result.success) {
        // Test data fetching
        final canFetchData = await healthService.testHealthDataFetch();
        
        if (canFetchData) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Successfully connected to health app!'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Update provider state
          await healthProvider.updateHealthConnectionStatus(true);
          
          // Sync initial data
          await healthProvider.syncWithHealth();
        } else {
          _showDetailedError(
            'Connection Partially Successful',
            'Connected to health app but unable to fetch data. Please check permissions in your device settings.',
            healthService.debugLogs,
          );
        }
      } else {
        // Show detailed error based on error type
        _showDetailedError(
          result.error == HealthConnectionError.healthConnectNotInstalled
              ? 'Health Connect Not Installed'
              : result.error == HealthConnectionError.healthConnectNeedsUpdate
                  ? 'Health Connect Needs Update'
                  : result.error == HealthConnectionError.permissionsDenied
                      ? 'Permissions Denied'
                      : 'Connection Failed',
          result.errorMessage ?? 'An unknown error occurred',
          healthService.debugLogs,
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      _showDetailedError(
        'Unexpected Error',
        'An unexpected error occurred: ${e.toString()}',
        healthService.debugLogs,
      );
    }
  }

  // Show detailed error with debug info
  void _showDetailedError(String title, String message, List<String> debugLogs) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              
              // Show debug logs in development mode
              if (debugLogs.isNotEmpty) ...[
                ExpansionTile(
                  title: Row(
                    children: [
                      Text(
                        'Debug Information',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final debugText = debugLogs.take(50).join('\n');
                          Clipboard.setData(ClipboardData(text: debugText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('📋 Debug information copied to clipboard'),
                              backgroundColor: AppTheme.primaryAccent,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.copy,
                          size: 16,
                          color: AppTheme.primaryAccent,
                        ),
                        tooltip: 'Copy debug logs',
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      constraints: BoxConstraints(maxHeight: 200),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.black26 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          debugLogs.take(20).join('\n'),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          final debugText = debugLogs.take(50).join('\n');
                          Clipboard.setData(ClipboardData(text: debugText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('📋 Full debug logs copied to clipboard'),
                              backgroundColor: AppTheme.primaryAccent,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(Icons.copy, size: 16),
                        label: Text('Copy All Logs'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 16),
              Text(
                'What to try:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // Specific suggestions based on error
              if (title.contains('Not Installed')) ...[
                _buildSuggestion('1. Install Health Connect from Play Store'),
                _buildSuggestion('2. Open Health Connect and set it up'),
                _buildSuggestion('3. Come back and try again'),
              ] else if (title.contains('Permissions')) ...[
                _buildSuggestion('1. Open Settings > Apps > Streaker'),
                _buildSuggestion('2. Tap Permissions'),
                _buildSuggestion('3. Grant all health-related permissions'),
                _buildSuggestion('4. Try connecting again'),
              ] else ...[
                _buildSuggestion('1. Make sure Health Connect is installed'),
                _buildSuggestion('2. Check if your device is compatible'),
                _buildSuggestion('3. Try restarting the app'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          if (title.contains('Not Installed'))
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                // Open Play Store for Health Connect
                _openHealthConnectInStore();
              },
              child: Text('Open Play Store'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToHealthApp(); // Retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
            ),
            child: Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuggestion(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppTheme.primaryAccent)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _openHealthConnectInStore() async {
    try {
      final url = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';
      // You'll need to add url_launcher to open the URL
      // For now, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please search for "Health Connect" in Play Store'),
        ),
      );
    } catch (e) {
      debugPrint('Error opening Play Store: $e');
    }
  }

  // Show health connection error dialog with retry options
  void _showHealthConnectionError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 12),
            Text('Connection Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unable to connect to your health app. This might be due to:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '• Permissions not granted\n• Health app not available\n• Device compatibility issues',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToHealthApp(); // Retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
            ),
            child: Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
