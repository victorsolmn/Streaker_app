import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/weight_provider.dart';
import '../../config/theme_config.dart';
import '../../widgets/modern_weight_chart.dart';
import '../../widgets/weight_stats_summary.dart';
import '../../widgets/weight_goal_dialog.dart';
import '../../widgets/weight_history_list.dart';
import 'weight_details_screen.dart';

class WeightHomeScreen extends StatefulWidget {
  const WeightHomeScreen({Key? key}) : super(key: key);

  @override
  State<WeightHomeScreen> createState() => _WeightHomeScreenState();
}

class _WeightHomeScreenState extends State<WeightHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load data after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final weightProvider = context.read<WeightProvider>();
    await weightProvider.loadWeightData();
  }

  void _showGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => const WeightGoalDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<WeightProvider>().loadWeightData(forceRefresh: true);
          },
          color: ThemeConfig.primaryColor,
          child: CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: ThemeConfig.primaryColor.withOpacity(0.15),
                        child: Icon(Icons.person, color: ThemeConfig.primaryColor, size: 20),
                      ),
                      Text(
                        'Weight Tracking',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.headlineMedium?.color,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: Theme.of(context).iconTheme.color),
                        onPressed: _showGoalDialog,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

              // Weight Chart (moved to top)
              SliverToBoxAdapter(
                child: ModernWeightChart(
                  isCompact: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WeightDetailsScreen()),
                    );
                  },
                ),
              ),

              // Weight Statistics Summary
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: WeightStatsSummary(),
                ),
              ),

              // Weight History
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: WeightHistoryList(),
                ),
              ),

              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
