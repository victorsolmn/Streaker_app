import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PermissionRationaleDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> reasons;
  final String? optionalNote;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  const PermissionRationaleDialog({
    required this.title,
    required this.icon,
    required this.reasons,
    this.optionalNote,
    required this.onContinue,
    required this.onCancel,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
      title: Row(
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
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
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
              'Streaker needs this permission to:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 12),
            ...reasons.map((reason) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryAccent,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode 
                            ? AppTheme.textSecondaryDark 
                            : AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            if (optionalNote != null) ...[
              SizedBox(height: 16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        optionalNote!,
                        style: TextStyle(
                          fontSize: 13,
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
            SizedBox(height: 12),
            Text(
              'You can change this permission anytime in Settings.',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode 
                    ? AppTheme.textSecondaryDark.withOpacity(0.7)
                    : Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Not Now',
            style: TextStyle(
              color: isDarkMode 
                  ? AppTheme.textSecondaryDark 
                  : AppTheme.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onContinue,
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
    );
  }
}
