import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Streaker Privacy Policy',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().toString().substring(0, 10)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              context,
              '1. Information We Collect',
              'We collect information you provide directly to us, such as when you create an account, update your profile, or use our fitness tracking features.\n\n'
              'This includes:\n'
              '• Personal information (name, email address)\n'
              '• Health and fitness data (steps, heart rate, calories burned, sleep patterns)\n'
              '• Photos of meals for nutrition tracking\n'
              '• Device information and usage data',
            ),

            _buildSection(
              context,
              '2. How We Use Your Information',
              'We use the information we collect to:\n\n'
              '• Provide and maintain our fitness tracking services\n'
              '• Personalize your experience and provide recommendations\n'
              '• Analyze your health and fitness progress\n'
              '• Process nutrition data from meal photos\n'
              '• Send you important updates about the service\n'
              '• Improve our app and develop new features',
            ),

            _buildSection(
              context,
              '3. Camera and Photo Permissions',
              'Our app requests camera access for the following purposes:\n\n'
              '• Taking photos of meals for nutrition tracking\n'
              '• Analyzing food content to provide nutritional information\n'
              '• Helping you log your daily caloric intake\n\n'
              'Photos are processed to extract nutritional data and are not shared with third parties for any other purpose. You can disable camera access at any time in your device settings.',
            ),

            _buildSection(
              context,
              '4. Health Data Privacy',
              'Your health and fitness data is extremely important to us:\n\n'
              '• We sync with Android Health Connect and Apple HealthKit with your permission\n'
              '• Health data is encrypted and stored securely\n'
              '• We never sell your health information to third parties\n'
              '• You can delete your health data at any time\n'
              '• Data is used only to provide you with personalized fitness insights',
            ),

            _buildSection(
              context,
              '5. Data Security',
              'We implement appropriate security measures to protect your personal information:\n\n'
              '• End-to-end encryption for sensitive data\n'
              '• Secure cloud storage with industry-standard protocols\n'
              '• Regular security audits and updates\n'
              '• Limited access to personal data by our team',
            ),

            _buildSection(
              context,
              '6. Third-Party Services',
              'We work with trusted third-party services:\n\n'
              '• Supabase for secure data storage and authentication\n'
              '• Google AI (Gemini) for nutrition analysis from meal photos\n'
              '• Firebase Analytics for anonymized usage statistics\n'
              '• Firebase Cloud Messaging for push notifications\n\n'
              'These services are bound by strict privacy agreements and cannot use your data for their own purposes.',
            ),

            _buildSection(
              context,
              '6.1 Data Safety Declaration',
              'COLLECTED DATA:\n'
              '• Personal Info: Email address, name, profile photo\n'
              '• Health & Fitness: Steps, heart rate, calories, sleep, weight, workouts\n'
              '• Photos: Meal photos for nutrition analysis only\n'
              '• Usage Data: App interactions, feature usage (anonymized)\n\n'
              'DATA SHARING:\n'
              '• Supabase: Securely stores all your data (encrypted)\n'
              '• Google AI: Analyzes meal photos (not permanently stored)\n'
              '• Firebase: Anonymized analytics only\n\n'
              'DATA SECURITY:\n'
              '• All data encrypted in transit (HTTPS/TLS)\n'
              '• Health data encrypted at rest\n'
              '• You can delete all data anytime\n'
              '• We NEVER sell your personal information\n'
              '• We do NOT use data for advertising',
            ),

            _buildSection(
              context,
              '6.2 Why We Need Permissions',
              'CAMERA: Take photos of meals for AI nutrition analysis\n'
              'HEALTH DATA: Sync steps, heart rate, sleep from Health Connect\n'
              'NOTIFICATIONS: Send streak reminders and achievement alerts\n'
              'STORAGE: Save meal photos temporarily during analysis\n\n'
              'All permissions can be revoked anytime in device Settings.',
            ),

            _buildSection(
              context,
              '7. Your Rights and Choices',
              'You have the following rights regarding your data:\n\n'
              '• Access and download your personal data\n'
              '• Correct inaccurate information\n'
              '• Delete your account and associated data\n'
              '• Opt out of non-essential communications\n'
              '• Control permissions for camera and health data access',
            ),

            _buildSection(
              context,
              '7.1 Account Deletion',
              'You have the right to delete your account and all associated data at any time.\n\n'
              'To delete your account:\n'
              '• Go to Profile > Settings > Delete Account\n'
              '• Confirm your decision in the dialog\n'
              '• Your account will be permanently deleted immediately\n\n'
              'What gets deleted:\n'
              '• Your profile and account credentials\n'
              '• All health and fitness data\n'
              '• Nutrition history and meal photos\n'
              '• Workout logs and templates\n'
              '• Achievements and streak progress\n'
              '• Premium membership (no refunds)\n\n'
              'Please note that account deletion is irreversible. You can also contact us at novatrient@gmail.com for assistance.',
            ),

            _buildSection(
              context,
              '8. Children\'s Privacy',
              'Our service is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us.',
            ),

            _buildSection(
              context,
              '9. Changes to This Policy',
              'We may update this privacy policy from time to time. We will notify you of any changes by posting the new privacy policy in the app and updating the "Last updated" date. Your continued use of the service after any changes constitutes acceptance of the updated policy.',
            ),

            _buildSection(
              context,
              '10. Contact Information',
              'If you have any questions about this privacy policy or our privacy practices, please contact us:\n\n'
              'Email: novatrient@gmail.com\n'
              'Address: Bangalore, India\n\n'
              'We are committed to protecting your privacy and will respond to your inquiries promptly.',
            ),

            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryAccent.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primaryAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Privacy Matters',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.primaryAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We are committed to transparency and giving you control over your data. This privacy policy explains exactly how we handle your information and protect your privacy.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}