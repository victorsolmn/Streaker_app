import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class DeleteAccountDialog extends StatefulWidget {
  final VoidCallback onConfirm;

  const DeleteAccountDialog({
    required this.onConfirm,
    Key? key,
  }) : super(key: key);

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _confirmChecked = false;
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
      title: Row(
        children: [
          Icon(Icons.warning, color: AppTheme.errorRed),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Delete Account?',
              style: TextStyle(
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
              'This action is permanent and cannot be undone.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.errorRed,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'The following data will be permanently deleted:',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 8),
            _buildDeleteItem('Your profile and account'),
            _buildDeleteItem('All health and fitness data'),
            _buildDeleteItem('Nutrition history and meal photos'),
            _buildDeleteItem('Workout logs and templates'),
            _buildDeleteItem('Achievements and streak progress'),
            _buildDeleteItem('Premium membership (no refunds)'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.errorRed.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.errorRed,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will be logged out immediately and cannot recover this data.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode 
                            ? AppTheme.textSecondaryDark 
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            CheckboxListTile(
              value: _confirmChecked,
              onChanged: (value) => setState(() => _confirmChecked = value!),
              title: Text(
                'I understand this is permanent',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppTheme.errorRed,
            ),
            SizedBox(height: 8),
            TextField(
              controller: _confirmationController,
              decoration: InputDecoration(
                labelText: 'Type DELETE to confirm',
                hintText: 'DELETE',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode 
                        ? AppTheme.dividerDark 
                        : AppTheme.dividerLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.errorRed,
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_confirmChecked && 
                      _confirmationController.text.trim().toUpperCase() == 'DELETE')
              ? () {
                  Navigator.pop(context);
                  widget.onConfirm();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorRed,
            disabledBackgroundColor: AppTheme.errorRed.withOpacity(0.3),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text('Delete My Account'),
        ),
      ],
    );
  }

  Widget _buildDeleteItem(String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode 
                  ? AppTheme.textSecondaryDark 
                  : AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode 
                    ? AppTheme.textSecondaryDark 
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
