import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';

/// Age verification dialog for COPPA compliance
/// Prevents children under 13 from creating accounts
class AgeVerificationDialog extends StatefulWidget {
  final Function(bool isVerified) onVerified;

  const AgeVerificationDialog({
    required this.onVerified,
    Key? key,
  }) : super(key: key);

  @override
  State<AgeVerificationDialog> createState() => _AgeVerificationDialogState();
}

class _AgeVerificationDialogState extends State<AgeVerificationDialog> {
  bool _isOver13 = false;

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
              Icons.verified_user,
              size: 48,
              color: AppTheme.primaryAccent,
            ),
            SizedBox(height: 12),
            Text(
              'Age Verification',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'To use Streaker, you must be at least 13 years old.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryAccent.withOpacity(0.3),
                ),
              ),
              child: CheckboxListTile(
                value: _isOver13,
                onChanged: (value) => setState(() => _isOver13 = value ?? false),
                title: Text(
                  'I confirm that I am 13 years of age or older',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.primaryAccent,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'By confirming, you certify that you meet the minimum age requirement.',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode 
                    ? AppTheme.textSecondaryDark 
                    : AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isOver13 ? null : () => _handleUnderAge(),
            child: Text(
              'Under 13',
              style: TextStyle(
                color: _isOver13 
                    ? Colors.grey 
                    : (isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _isOver13 ? () => _handleVerified() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              disabledBackgroundColor: AppTheme.primaryAccent.withOpacity(0.3),
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

  Future<void> _handleVerified() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('age_verified', true);
      await prefs.setString('age_verified_date', DateTime.now().toIso8601String());
      
      debugPrint('✅ Age verified');
      
      Navigator.pop(context);
      widget.onVerified(true);
    } catch (e) {
      debugPrint('❌ Error saving age verification: $e');
      Navigator.pop(context);
      widget.onVerified(true); // Continue anyway
    }
  }

  void _handleUnderAge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Age Requirement'),
          ],
        ),
        content: Text(
          'We\'re sorry, but you must be at least 13 years old to use Streaker.\n\n'
          'This requirement helps us comply with children\'s privacy laws and ensures the app is used by our intended audience.\n\n'
          'Thank you for your understanding.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close warning dialog
              Navigator.pop(context); // Close age verification dialog
              widget.onVerified(false);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Service class for age verification
class AgeVerificationService {
  static const String _keyAgeVerified = 'age_verified';
  static const String _keyVerifiedDate = 'age_verified_date';

  /// Check if age has been verified
  static Future<bool> isAgeVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAgeVerified) ?? false;
  }

  /// Get the date when age was verified
  static Future<DateTime?> getVerifiedDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_keyVerifiedDate);
    if (dateStr != null) {
      return DateTime.parse(dateStr);
    }
    return null;
  }

  /// Show age verification dialog if not verified
  static Future<void> verifyAgeIfNeeded(
    BuildContext context,
    Function(bool) onResult,
  ) async {
    final isVerified = await isAgeVerified();
    
    if (!isVerified) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AgeVerificationDialog(onVerified: onResult),
      );
    } else {
      onResult(true);
    }
  }

  /// Reset age verification (for testing or account switching)
  static Future<void> resetVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAgeVerified);
    await prefs.remove(_keyVerifiedDate);
  }
}
