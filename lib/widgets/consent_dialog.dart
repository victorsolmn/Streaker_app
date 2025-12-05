import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';

/// Consent management dialog for analytics and data collection
/// Shows on first app launch to get explicit user consent
class ConsentDialog extends StatefulWidget {
  final VoidCallback onConsentComplete;

  const ConsentDialog({
    required this.onConsentComplete,
    Key? key,
  }) : super(key: key);

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _analyticsConsent = true; // Default to opt-in
  bool _crashReportsConsent = true;
  bool _aiFeatureConsent = true;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing
      child: AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        title: Column(
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              size: 48,
              color: AppTheme.primaryAccent,
            ),
            SizedBox(height: 12),
            Text(
              'Privacy & Consent',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help us improve Streaker! You have full control over your data.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode 
                      ? AppTheme.textSecondaryDark 
                      : AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: 20),
              
              // Analytics Consent
              _buildConsentOption(
                title: 'Analytics',
                description: 'Help us understand how you use the app to improve features and performance.',
                value: _analyticsConsent,
                onChanged: (value) => setState(() => _analyticsConsent = value),
                icon: Icons.analytics_outlined,
              ),
              
              SizedBox(height: 16),
              
              // Crash Reports Consent
              _buildConsentOption(
                title: 'Crash Reports',
                description: 'Automatically send crash reports to help us fix bugs and improve stability.',
                value: _crashReportsConsent,
                onChanged: (value) => setState(() => _crashReportsConsent = value),
                icon: Icons.bug_report_outlined,
              ),
              
              SizedBox(height: 16),
              
              // AI Features Consent
              _buildConsentOption(
                title: 'AI Features',
                description: 'Send meal photos to Google AI for nutrition analysis. Photos are not stored permanently.',
                value: _aiFeatureConsent,
                onChanged: (value) => setState(() => _aiFeatureConsent = value),
                icon: Icons.psychology_outlined,
              ),
              
              SizedBox(height: 20),
              
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withOpacity(isDarkMode ? 0.1 : 1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.shade200.withOpacity(isDarkMode ? 0.3 : 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can change these preferences anytime in Settings.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode 
                              ? Colors.blue.shade300 
                              : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _saveConsent(
              analytics: false,
              crashReports: false,
              aiFeatures: false,
            ),
            child: Text(
              'Decline All',
              style: TextStyle(
                color: isDarkMode 
                    ? AppTheme.textSecondaryDark 
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _saveConsent(
              analytics: _analyticsConsent,
              crashReports: _crashReportsConsent,
              aiFeatures: _aiFeatureConsent,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentOption({
    required String title,
    required String description,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value 
              ? AppTheme.primaryAccent.withOpacity(0.3) 
              : (isDarkMode ? AppTheme.dividerDark : AppTheme.dividerLight),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryAccent,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
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
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode 
                        ? AppTheme.textSecondaryDark 
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryAccent,
          ),
        ],
      ),
    );
  }

  Future<void> _saveConsent({
    required bool analytics,
    required bool crashReports,
    required bool aiFeatures,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save consent preferences
      await prefs.setBool('consent_analytics', analytics);
      await prefs.setBool('consent_crash_reports', crashReports);
      await prefs.setBool('consent_ai_features', aiFeatures);
      await prefs.setBool('consent_shown', true);
      
      debugPrint('✅ Consent saved: Analytics=$analytics, Crashes=$crashReports, AI=$aiFeatures');
      
      // Close dialog and notify parent
      Navigator.pop(context);
      widget.onConsentComplete();
    } catch (e) {
      debugPrint('❌ Error saving consent: $e');
      // Still close dialog on error
      Navigator.pop(context);
      widget.onConsentComplete();
    }
  }
}

/// Service class for managing user consent preferences
class ConsentService {
  static const String _keyConsentShown = 'consent_shown';
  static const String _keyAnalytics = 'consent_analytics';
  static const String _keyCrashReports = 'consent_crash_reports';
  static const String _keyAiFeatures = 'consent_ai_features';

  /// Check if consent has been obtained
  static Future<bool> hasConsentBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsentShown) ?? false;
  }

  /// Check if analytics is enabled
  static Future<bool> isAnalyticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAnalytics) ?? true; // Default opt-in
  }

  /// Check if crash reports are enabled
  static Future<bool> isCrashReportsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCrashReports) ?? true; // Default opt-in
  }

  /// Check if AI features are enabled
  static Future<bool> isAiFeaturesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAiFeatures) ?? true; // Default opt-in
  }

  /// Update analytics consent
  static Future<void> setAnalyticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAnalytics, enabled);
  }

  /// Update crash reports consent
  static Future<void> setCrashReportsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCrashReports, enabled);
  }

  /// Update AI features consent
  static Future<void> setAiFeaturesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAiFeatures, enabled);
  }

  /// Show consent dialog if not shown before
  static Future<void> showConsentDialogIfNeeded(BuildContext context, VoidCallback onComplete) async {
    final hasShown = await hasConsentBeenShown();
    
    if (!hasShown) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ConsentDialog(onConsentComplete: onComplete),
      );
    } else {
      onComplete();
    }
  }
}
