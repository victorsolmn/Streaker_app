import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help and FAQ screen for user support
class HelpScreen extends StatefulWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final filteredFaqs = _getFilteredFaqs();

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search help topics...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDarkMode ? AppTheme.darkBackground : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions
                  if (_searchQuery.isEmpty) ...[
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickAction(
                      context,
                      icon: Icons.video_library,
                      title: 'Video Tutorials',
                      subtitle: 'Watch step-by-step guides',
                      onTap: () {
                        // Open video tutorials
                        _showComingSoon(context);
                      },
                      isDarkMode: isDarkMode,
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.support_agent,
                      title: 'Contact Support',
                      subtitle: 'Get help from our team',
                      onTap: () => _contactSupport(context),
                      isDarkMode: isDarkMode,
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.bug_report,
                      title: 'Report a Bug',
                      subtitle: 'Help us improve the app',
                      onTap: () => _reportBug(context),
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // FAQs
                  Text(
                    _searchQuery.isEmpty ? 'Frequently Asked Questions' : 'Search Results',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (filteredFaqs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredFaqs.map((faq) => _FaqItem(
                          question: faq.question,
                          answer: faq.answer,
                          category: faq.category,
                          isDarkMode: isDarkMode,
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_FaqData> _getFilteredFaqs() {
    final faqs = _allFaqs;
    if (_searchQuery.isEmpty) return faqs;

    return faqs.where((faq) {
      return faq.question.toLowerCase().contains(_searchQuery) ||
          faq.answer.toLowerCase().contains(_searchQuery) ||
          faq.category.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
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
      ),
    );
  }

  void _contactSupport(BuildContext context) async {
    const email = 'support@streaker.app';
    final uri = Uri.parse('mailto:$email?subject=Streaker App Support Request');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please email us at: $email')),
        );
      }
    }
  }

  void _reportBug(BuildContext context) async {
    const email = 'support@streaker.app';
    final uri = Uri.parse('mailto:$email?subject=Bug Report - Streaker App');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please email us at: $email')),
        );
      }
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon! Video tutorials will be available in the next update.'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;
  final String category;
  final bool isDarkMode;

  const _FaqItem({
    required this.question,
    required this.answer,
    required this.category,
    required this.isDarkMode,
  });

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryAccent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.question,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.answer,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: widget.isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
        ),
      ),
    );
  }
}

class _FaqData {
  final String category;
  final String question;
  final String answer;

  const _FaqData({
    required this.category,
    required this.question,
    required this.answer,
  });
}

final List<_FaqData> _allFaqs = [
  _FaqData(
    category: 'Streaks',
    question: 'How do streaks work?',
    answer: 'Streaks track consecutive days of meeting your daily goals. Complete your calories, steps, sleep, or water targets to maintain your streak. Missing a day will reset your streak to zero.',
  ),
  _FaqData(
    category: 'Streaks',
    question: 'What happens if I miss a day?',
    answer: 'Your streak will reset to 0, but you can start building it again the next day. Consider this motivation to stay consistent!',
  ),
  _FaqData(
    category: 'Nutrition',
    question: 'How accurate is the food scanning?',
    answer: 'Our AI-powered food scanning provides estimates based on your meal description and photo. For best results, be as detailed as possible (e.g., portion sizes, cooking methods). You can always edit the nutrition values after scanning.',
  ),
  _FaqData(
    category: 'Nutrition',
    question: 'Can I manually log my meals?',
    answer: 'Yes! You can manually enter nutrition information for any meal. Just tap the "+" button on the Nutrition screen and choose "Manual Entry".',
  ),
  _FaqData(
    category: 'Health Data',
    question: 'How does Apple Health/Google Fit integration work?',
    answer: 'Streaker automatically syncs your steps, active calories, and other health data from Apple Health (iOS) or Google Fit (Android). Make sure to grant the necessary permissions in Settings.',
  ),
  _FaqData(
    category: 'Health Data',
    question: 'Why isn\'t my data syncing?',
    answer: 'Check that you\'ve granted health data permissions in your device settings. On iOS: Settings > Privacy > Health. On Android: Google Fit > Settings > Manage connected apps.',
  ),
  _FaqData(
    category: 'Goals',
    question: 'How are my daily targets calculated?',
    answer: 'Your targets are calculated based on your age, weight, height, activity level, and fitness goals entered during onboarding. You can adjust them anytime in your Profile settings.',
  ),
  _FaqData(
    category: 'Goals',
    question: 'Can I change my daily targets?',
    answer: 'Yes! Go to Profile > Settings > Daily Targets to customize your calorie, step, sleep, and water goals.',
  ),
  _FaqData(
    category: 'Achievements',
    question: 'How do I unlock achievements?',
    answer: 'Achievements are unlocked by reaching specific milestones like completing workouts, maintaining streaks, or hitting nutrition goals. Check the Achievements section in your Profile to see what\'s available.',
  ),
  _FaqData(
    category: 'Premium',
    question: 'What are the benefits of Premium?',
    answer: 'Premium members get exclusive discounts on marketplace products, advanced analytics, personalized workout plans, and priority support.',
  ),
  _FaqData(
    category: 'Marketplace',
    question: 'How do I order products?',
    answer: 'Add items to your cart and click "Order via WhatsApp". This will open WhatsApp with your order details pre-filled. Our team will confirm availability and delivery details.',
  ),
  _FaqData(
    category: 'Account',
    question: 'How do I delete my account?',
    answer: 'Go to Profile > Settings > Account and select "Delete Account". Note: This action is permanent and will delete all your data.',
  ),
  _FaqData(
    category: 'Technical',
    question: 'The app is running slowly. What should I do?',
    answer: 'Try clearing the app cache in Settings > Storage. If the issue persists, uninstall and reinstall the app. Make sure you\'re running the latest version.',
  ),
  _FaqData(
    category: 'Technical',
    question: 'I found a bug. How do I report it?',
    answer: 'Use the "Report a Bug" option in Help & Support, or email us at support@streaker.app with details about the issue and screenshots if possible.',
  ),
];
