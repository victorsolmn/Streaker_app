import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/weight_model.dart';
import '../providers/weight_provider.dart';
import '../utils/app_theme.dart';

class WeightProgressChart extends StatefulWidget {
  final bool isCompact;
  final VoidCallback? onTap;

  const WeightProgressChart({
    Key? key,
    this.isCompact = true,
    this.onTap,
  }) : super(key: key);

  @override
  State<WeightProgressChart> createState() => _WeightProgressChartState();
}

class _WeightProgressChartState extends State<WeightProgressChart> {
  @override
  void initState() {
    super.initState();
    // Load weight data when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeightProvider>().loadWeightData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, weightProvider, child) {
        if (weightProvider.isLoading) {
          return _buildLoadingState();
        }

        if (weightProvider.error != null) {
          return _buildErrorState(weightProvider.error!);
        }

        if (!weightProvider.hasData) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(weightProvider),
            const SizedBox(height: 20),
            _buildChart(weightProvider),
            if (!widget.isCompact) ...[
              const SizedBox(height: 20),
              _buildLegend(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(WeightProvider provider) {
    final progress = provider.weightProgress!;
    final trend = provider.weeklyTrend;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weight Progress',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            if (widget.onTap != null)
              IconButton(
                icon: Icon(Icons.fullscreen, color: AppTheme.textSecondary),
                onPressed: widget.onTap,
                tooltip: 'View details',
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatChip(
              label: 'Current',
              value: '${progress.currentWeight.toStringAsFixed(1)} ${progress.unit}',
              color: AppTheme.primaryAccent,
            ),
            const SizedBox(width: 12),
            _buildStatChip(
              label: 'Goal',
              value: '${progress.targetWeight.toStringAsFixed(1)} ${progress.unit}',
              color: Colors.green,
            ),
            if (trend != null) ...[
              const SizedBox(width: 12),
              _buildTrendChip(trend),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChip(double trend) {
    final isPositive = trend < 0; // Negative trend means losing weight (good)
    final color = isPositive ? Colors.green : Colors.orange;
    final icon = isPositive ? Icons.trending_down : Icons.trending_up;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${trend.abs().toStringAsFixed(1)} kg/week',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(WeightProvider provider) {
    final entries = provider.entries;
    final weightProgress = provider.weightProgress!;

    if (entries.isEmpty) {
      return _buildNoDataChart();
    }

    // Sort entries by date
    final sortedEntries = List<WeightEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate bounds
    final minWeight = _calculateMinWeight(sortedEntries, weightProgress.targetWeight);
    final maxWeight = _calculateMaxWeight(sortedEntries, weightProgress.targetWeight);
    final interval = _calculateInterval(maxWeight - minWeight);

    return Container(
      height: widget.isCompact ? 200 : 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.borderColor.withOpacity(0.3),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  return _buildDateLabel(value, sortedEntries);
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sortedEntries.length - 1).toDouble(),
          minY: minWeight,
          maxY: maxWeight,
          clipData: FlClipData.all(),
          lineBarsData: [
            // Actual weight line
            LineChartBarData(
              spots: _generateWeightSpots(sortedEntries),
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppTheme.primaryAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isToday = _isToday(sortedEntries[index].timestamp);
                  return FlDotCirclePainter(
                    radius: isToday ? 5 : 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: isToday ? Colors.green : AppTheme.primaryAccent,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryAccent.withOpacity(0.2),
                    AppTheme.primaryAccent.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Target weight line (dashed)
            LineChartBarData(
              spots: [
                FlSpot(0, weightProgress.targetWeight),
                FlSpot((sortedEntries.length - 1).toDouble(), weightProgress.targetWeight),
              ],
              isCurved: false,
              color: Colors.green,
              barWidth: 2,
              dashArray: [8, 4],
              dotData: FlDotData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  if (spot.barIndex == 0 && spot.spotIndex < sortedEntries.length) {
                    final entry = sortedEntries[spot.spotIndex];
                    return LineTooltipItem(
                      '${entry.weight.toStringAsFixed(1)} ${weightProgress.unit}\n${DateFormat('MMM dd, yyyy').format(entry.timestamp)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  } else if (spot.barIndex == 1) {
                    return LineTooltipItem(
                      'Target: ${weightProgress.targetWeight.toStringAsFixed(1)} ${weightProgress.unit}',
                      const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

  Widget _buildDateLabel(double value, List<WeightEntry> entries) {
    final index = value.toInt();
    if (index >= 0 && index < entries.length) {
      final date = entries[index].timestamp;
      final daysDiff = entries.isNotEmpty
          ? entries.last.timestamp.difference(entries.first.timestamp).inDays
          : 0;

      String format;
      if (daysDiff <= 7) {
        format = 'EEE';
      } else if (daysDiff <= 30) {
        format = 'MM/dd';
      } else if (daysDiff <= 90) {
        format = 'MMM dd';
      } else {
        format = 'MMM';
      }

      // Only show labels for certain indices to avoid crowding
      if (entries.length > 7) {
        final step = (entries.length / 7).ceil();
        if (index % step != 0 && index != entries.length - 1) {
          return const SizedBox.shrink();
        }
      }

      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          DateFormat(format).format(date),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  List<FlSpot> _generateWeightSpots(List<WeightEntry> entries) {
    return entries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weight);
    }).toList();
  }

  double _calculateMinWeight(List<WeightEntry> entries, double targetWeight) {
    final weights = entries.map((e) => e.weight).toList();
    weights.add(targetWeight);
    final min = weights.reduce((a, b) => a < b ? a : b);
    return (min * 0.95).floorToDouble(); // 5% padding below
  }

  double _calculateMaxWeight(List<WeightEntry> entries, double targetWeight) {
    final weights = entries.map((e) => e.weight).toList();
    weights.add(targetWeight);
    final max = weights.reduce((a, b) => a > b ? a : b);
    return (max * 1.05).ceilToDouble(); // 5% padding above
  }

  double _calculateInterval(double range) {
    if (range <= 10) return 2;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    return 20;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(
          color: AppTheme.primaryAccent,
          label: 'Actual Weight',
          isDashed: false,
        ),
        const SizedBox(width: 24),
        _buildLegendItem(
          color: Colors.green,
          label: 'Target Weight',
          isDashed: true,
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isDashed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            border: isDashed
                ? Border(
                    top: BorderSide(
                      color: color,
                      width: 2,
                      style: BorderStyle.none,
                    ),
                  )
                : null,
          ),
          child: isDashed
              ? CustomPaint(
                  painter: DashedLinePainter(color: color),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: widget.isCompact ? 200 : 250,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      height: widget.isCompact ? 200 : 250,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading weight data',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                context.read<WeightProvider>().loadWeightData(forceRefresh: true);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: widget.isCompact ? 200 : 250,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No weight entries yet',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first weight entry to see the chart',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
            ),
            if (widget.onTap != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: widget.onTap,
                icon: const Icon(Icons.add),
                label: const Text('Add Weight Entry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataChart() {
    final provider = context.read<WeightProvider>();
    final weightProgress = provider.weightProgress;

    if (weightProgress == null) {
      return Container(
        height: widget.isCompact ? 200 : 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No weight data available',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    // Show a simple chart with current and target weight
    final currentWeight = weightProgress.currentWeight;
    final targetWeight = weightProgress.targetWeight;
    final minWeight = (currentWeight < targetWeight ? currentWeight : targetWeight) - 5;
    final maxWeight = (currentWeight > targetWeight ? currentWeight : targetWeight) + 5;
    final interval = _calculateInterval(maxWeight - minWeight);

    return Container(
      height: widget.isCompact ? 200 : 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.borderColor.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return Text(
                            'Current',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: -0.5,
                maxX: 0.5,
                minY: minWeight,
                maxY: maxWeight,
                clipData: FlClipData.all(),
                lineBarsData: [
                  // Current weight point
                  LineChartBarData(
                    spots: [FlSpot(0, currentWeight)],
                    isCurved: false,
                    color: AppTheme.primaryAccent,
                    barWidth: 0,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: AppTheme.primaryAccent,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                  // Target weight line (horizontal)
                  LineChartBarData(
                    spots: [
                      FlSpot(-0.5, targetWeight),
                      FlSpot(0.5, targetWeight),
                    ],
                    isCurved: false,
                    color: Colors.green.withOpacity(0.5),
                    barWidth: 2,
                    dashArray: [8, 4],
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start tracking your weight progress',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          if (widget.onTap != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: Icon(Icons.add, size: 16, color: AppTheme.primaryAccent),
              label: Text(
                'Add Weight Entry',
                style: TextStyle(color: AppTheme.primaryAccent, fontSize: 12),
              ),
              onPressed: widget.onTap,
            ),
          ],
        ],
      ),
    );
  }
}

// Custom painter for dashed line in legend
class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 5;
    const dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}