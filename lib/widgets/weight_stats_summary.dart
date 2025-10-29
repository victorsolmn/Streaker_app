import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weight_provider.dart';
import '../config/theme_config.dart';

class WeightStatsSummary extends StatelessWidget {
  const WeightStatsSummary({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, weightProvider, child) {
        final weightProgress = weightProvider.weightProgress;
        final weeklyTrend = weightProvider.weeklyTrend;
        final daysTracking = weightProgress?.actualDaysTracking ?? 0;

        // Handle null cases
        final currentWeight = weightProgress?.currentWeight ?? 0.0;
        final targetWeight = weightProgress?.targetWeight ?? 0.0;
        final unit = weightProgress?.unit ?? 'kg';

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(
                icon: Icons.monitor_weight_outlined,
                iconColor: ThemeConfig.primaryColor,
                value: currentWeight > 0
                    ? currentWeight.toStringAsFixed(1)
                    : '--',
                label: 'CURRENT',
                unit: currentWeight > 0 ? unit : '',
              ),
              _buildStatCard(
                icon: Icons.flag_outlined,
                iconColor: ThemeConfig.accentColor,
                value: targetWeight > 0
                    ? targetWeight.toStringAsFixed(1)
                    : '--',
                label: 'TARGET',
                unit: targetWeight > 0 ? unit : '',
              ),
              _buildStatCard(
                icon: Icons.calendar_today_outlined,
                iconColor: Color(0xFF9B59B6), // Purple
                value: daysTracking.toString(),
                label: 'DAYS',
                unit: '',
              ),
              _buildStatCard(
                icon: weeklyTrend != null && weeklyTrend < 0
                    ? Icons.trending_down
                    : Icons.trending_up,
                iconColor: weeklyTrend != null && weeklyTrend < 0
                    ? ThemeConfig.successColor // Green for weight loss
                    : ThemeConfig.errorColor, // Red for weight gain
                value: weeklyTrend != null
                    ? weeklyTrend.abs().toStringAsFixed(1)
                    : '--',
                label: 'WEEKLY',
                unit: weeklyTrend != null ? unit : '',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String unit,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon at top
          Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
          SizedBox(height: 8),
          // Large number value
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.textPrimary,
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 1),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 10,
                      color: ThemeConfig.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),
          // Small label below
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: ThemeConfig.textSecondary,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
