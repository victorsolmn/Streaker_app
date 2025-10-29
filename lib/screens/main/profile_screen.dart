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
import 'package:permission_handler/permission_handler.dart';
import '../database_test_screen.dart';
import '../../utils/app_theme.dart';
import '../auth/welcome_screen.dart';
import 'edit_goals_screen.dart';
import 'edit_profile_screen.dart';
import 'main_screen.dart';
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
        children: [
          IconButton(
            onPressed: () {
              // Navigate back to home screen (index 0)
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => MainScreen(initialIndex: 0),
                ),
              );
            },
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          Expanded(
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
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
                        label: '${profile.dailyActiveCaloriesTarget} Active kcal',
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

              // Close the confirmation dialog
              Navigator.of(context).pop();

              try {
                print('Starting logout process...');

                // Clear all local data first
                await userProvider.clearUserData();
                await nutritionProvider.clearNutritionData();

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
}
