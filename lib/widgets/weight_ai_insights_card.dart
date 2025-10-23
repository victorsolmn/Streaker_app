import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weight_provider.dart';
import '../config/theme_config.dart';

/// A card widget that displays AI-generated insights about weight progress
/// with animated transitions and intelligent recommendations
class WeightAIInsightsCard extends StatefulWidget {
  const WeightAIInsightsCard({Key? key}) : super(key: key);

  @override
  State<WeightAIInsightsCard> createState() => _WeightAIInsightsCardState();
}

class _WeightAIInsightsCardState extends State<WeightAIInsightsCard>
    with SingleTickerProviderStateMixin {
  bool _isGenerating = false;
  late AnimationController _rotationController;
  late Animation<double> _fadeAnimation;
  String? _previousInsight;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _generateNewInsight(WeightProvider provider) async {
    setState(() {
      _isGenerating = true;
      _previousInsight = provider.aiInsight;
    });

    // Start rotation animation
    _rotationController.repeat();

    // Generate new insights
    await provider.generateAIInsights();

    // Stop rotation and fade in new content
    await _rotationController.forward(from: 0.0);
    _rotationController.stop();

    setState(() {
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, weightProvider, child) {
        final insight = weightProvider.aiInsight;
        final hasInsight = insight != null && insight.isNotEmpty;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6366F1), // Indigo
                Color(0xFF8B5CF6), // Purple
                Color(0xFFA855F7), // Light purple
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'AI Insights',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Insight content with animation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey<String>(insight ?? 'no-insight'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: _isGenerating
                          ? _buildLoadingState()
                          : hasInsight
                              ? _buildInsightContent(insight)
                              : _buildEmptyState(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Generate button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating
                          ? null
                          : () => _generateNewInsight(weightProvider),
                      icon: RotationTransition(
                        turns: _rotationController,
                        child: const Icon(Icons.refresh, size: 20),
                      ),
                      label: Text(
                        _isGenerating
                            ? 'Generating...'
                            : hasInsight
                                ? 'Generate New Insight'
                                : 'Generate Insight',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6366F1),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Analyzing your progress...',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightContent(String insight) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lightbulb,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            insight,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(
          Icons.pending_actions,
          color: Colors.white.withOpacity(0.7),
          size: 32,
        ),
        const SizedBox(height: 12),
        Text(
          'Not enough data yet. Keep tracking!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.9),
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add at least 3 weight entries to get personalized insights.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.7),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
