import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/weight_provider.dart';
import '../models/weight_model.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';

class ModernWeightChart extends StatefulWidget {
  final bool isCompact;
  final VoidCallback? onTap;

  const ModernWeightChart({
    Key? key,
    this.isCompact = false,
    this.onTap,
  }) : super(key: key);

  @override
  State<ModernWeightChart> createState() => _ModernWeightChartState();
}

class _ModernWeightChartState extends State<ModernWeightChart> {
  String selectedPeriod = '30D';
  DateTime currentDate = DateTime.now();
  int touchedIndex = -1;

  final Map<String, int> periodDays = {
    '7D': 7,
    '30D': 30,
    '90D': 90,
    '1Y': 365,
  };

  @override
  void initState() {
    super.initState();
    // Load weight data when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeightProvider>().loadWeightData();
    });
  }

  DateTime get startDate {
    final days = periodDays[selectedPeriod] ?? 30;
    return currentDate.subtract(Duration(days: days));
  }

  void _navigatePeriod(bool forward) {
    setState(() {
      final days = periodDays[selectedPeriod] ?? 30;
      if (forward) {
        // Don't go beyond today
        if (currentDate.add(Duration(days: days)).isAfter(DateTime.now())) {
          currentDate = DateTime.now();
        } else {
          currentDate = currentDate.add(Duration(days: days));
        }
      } else {
        currentDate = currentDate.subtract(Duration(days: days));
      }
    });
  }

  void _showAddWeightDialog(BuildContext context) {
    final TextEditingController weightController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    final provider = context.read<WeightProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.monitor_weight_outlined,
                color: AppTheme.primaryAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Weight Entry',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weight (${provider.weightProgress?.unit ?? 'kg'})',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter weight',
                  hintStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Note (optional)',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                maxLines: 2,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a note',
                  hintStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final weightText = weightController.text.trim();
                if (weightText.isNotEmpty) {
                  final weight = double.tryParse(weightText);
                  if (weight != null) {
                    final success = await provider.addWeightEntry(
                      weight,
                      note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
                    );
                    if (success) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Weight entry added successfully'),
                          backgroundColor: AppTheme.successGreen,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(provider.error ?? 'Failed to add weight entry'),
                          backgroundColor: AppTheme.errorRed,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<WeightProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && !provider.hasData) {
          return _buildLoadingState(context);
        }

        if (provider.error != null && !provider.hasData) {
          return _buildErrorState(context, provider.error!);
        }

        if (!provider.hasData || provider.entries.isEmpty) {
          return _buildEmptyState(context);
        }

        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: widget.isCompact ? Border.all(
                color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
                width: 1,
              ) : null,
              boxShadow: isDarkMode ? [] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, provider),
                if (!widget.isCompact) _buildPeriodSelector(context),
                _buildChart(context, provider),
                if (!widget.isCompact) _buildLegend(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WeightProvider provider) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentWeight = provider.weightProgress?.currentWeight ?? 0;
    final targetWeight = provider.weightProgress?.targetWeight ?? 0;
    final unit = provider.weightProgress?.unit ?? 'kg';
    final trend = provider.weeklyTrend;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.monitor_weight_outlined,
                      size: widget.isCompact ? 18 : 20,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Weight Progress',
                      style: TextStyle(
                        fontSize: widget.isCompact ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${currentWeight.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: widget.isCompact ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: widget.isCompact ? 14 : 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    if (trend != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: trend < 0
                            ? AppTheme.successGreen.withOpacity(0.1)
                            : AppTheme.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              trend < 0 ? Icons.trending_down : Icons.trending_up,
                              size: 14,
                              color: trend < 0 ? AppTheme.successGreen : AppTheme.errorRed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${trend.abs().toStringAsFixed(1)} $unit/week',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: trend < 0 ? AppTheme.successGreen : AppTheme.errorRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (!widget.isCompact && targetWeight > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Target: ${targetWeight.toStringAsFixed(1)} $unit',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!widget.isCompact)
            IconButton(
              onPressed: () => _showAddWeightDialog(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: AppTheme.primaryAccent,
                  size: 20,
                ),
              ),
            ),
          if (widget.isCompact)
            Row(
              children: [
                // Add weight button
                GestureDetector(
                  onTap: () => _showAddWeightDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: AppTheme.primaryAccent,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // View details indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDarkMode
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 20,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
            onPressed: () => _navigatePeriod(false),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: periodDays.keys.map((period) {
                final isSelected = period == selectedPeriod;
                return GestureDetector(
                  onTap: () => setState(() => selectedPeriod = period),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                        ? AppTheme.primaryAccent.withOpacity(0.2)
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      period,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                          ? AppTheme.primaryAccent
                          : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
            onPressed: () => _navigatePeriod(true),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, WeightProvider provider) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final filteredEntries = provider.getEntriesForDateRange(startDate, currentDate);

    if (filteredEntries.isEmpty) {
      // If no entries in date range but we have current weight, show a single point
      final currentWeight = provider.weightProgress?.currentWeight ?? 0;
      if (currentWeight > 0) {
        // Create a temporary entry for display
        final tempEntry = WeightEntry(
          id: 'temp',
          weight: currentWeight,
          timestamp: DateTime.now(),
        );
        return _buildSinglePointChart(context, tempEntry, provider.weightProgress?.unit ?? 'kg');
      }

      return Container(
        height: widget.isCompact ? 150 : 200,
        margin: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No data for selected period',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    // Sort entries by date
    filteredEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate 7-day moving average
    List<FlSpot> actualSpots = [];
    List<FlSpot> trendSpots = [];

    for (int i = 0; i < filteredEntries.length; i++) {
      final x = i.toDouble();
      actualSpots.add(FlSpot(x, filteredEntries[i].weight));

      // Calculate moving average
      int startIdx = (i - 3).clamp(0, i);
      int endIdx = (i + 3).clamp(i, filteredEntries.length - 1);
      double sum = 0;
      int count = 0;
      for (int j = startIdx; j <= endIdx; j++) {
        sum += filteredEntries[j].weight;
        count++;
      }
      trendSpots.add(FlSpot(x, sum / count));
    }

    // Calculate min and max for Y axis with better formatting
    final allWeights = filteredEntries.map((e) => e.weight).toList();
    final rawMin = allWeights.reduce((a, b) => a < b ? a : b);
    final rawMax = allWeights.reduce((a, b) => a > b ? a : b);

    // Round to nearest 0.5 for cleaner numbers
    final minWeight = (rawMin - 2).floorToDouble();
    final maxWeight = (rawMax + 2).ceilToDouble();

    return Container(
      height: widget.isCompact ? 150 : 200,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: LineChart(
        LineChartData(
          minY: minWeight,
          maxY: maxWeight,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxWeight - minWeight) / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (maxWeight - minWeight) / 4,
                getTitlesWidget: (value, meta) {
                  // Show cleaner number formatting - only show whole numbers
                  if (value == value.roundToDouble()) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: filteredEntries.length > 7 ? filteredEntries.length / 7 : 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= filteredEntries.length) return const SizedBox.shrink();
                  final date = filteredEntries[value.toInt()].timestamp;
                  return Text(
                    DateFormat('MM/dd').format(date),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
              if (!event.isInterestedForInteractions || response == null || response.lineBarSpots == null) {
                setState(() {
                  touchedIndex = -1;
                });
                return;
              }
              setState(() {
                touchedIndex = response.lineBarSpots!.first.spotIndex;
              });
            },
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: isDarkMode
                ? Colors.grey[800]!
                : Colors.grey[100]!,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  if (flSpot.x.toInt() >= filteredEntries.length) return null;

                  final entry = filteredEntries[flSpot.x.toInt()];
                  final isActualLine = barSpot.barIndex == 0;

                  return LineTooltipItem(
                    '${DateFormat('MMM d').format(entry.timestamp)}\n${flSpot.y.toStringAsFixed(1)} ${provider.weightProgress?.unit ?? 'kg'}',
                    TextStyle(
                      color: isActualLine
                        ? AppTheme.primaryAccent
                        : isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            // Actual weight line
            LineChartBarData(
              spots: actualSpots,
              isCurved: true,
              curveSmoothness: 0.35,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryAccent.withOpacity(0.7),
                  AppTheme.primaryAccent,
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: touchedIndex == index ? 6 : 4,
                    color: AppTheme.primaryAccent,
                    strokeWidth: 0,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryAccent.withOpacity(0.2),
                    AppTheme.primaryAccent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
            // Trend line (7-day moving average)
            if (filteredEntries.length > 3)
              LineChartBarData(
                spots: trendSpots,
                isCurved: true,
                color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
                barWidth: 1.5,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
                dashArray: [5, 5],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePointChart(BuildContext context, WeightEntry entry, String unit) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final weight = entry.weight;
    final minY = weight - 5;
    final maxY = weight + 5;

    return Container(
      height: widget.isCompact ? 150 : 200,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    DateFormat('MMM d').format(entry.timestamp),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [FlSpot(0, weight)],
              isCurved: false,
              color: AppTheme.primaryAccent,
              barWidth: 0,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: AppTheme.primaryAccent,
                    strokeWidth: 2,
                    strokeColor: AppTheme.primaryAccent.withOpacity(0.3),
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(
            context,
            'Actual',
            AppTheme.primaryAccent,
            solid: true,
          ),
          const SizedBox(width: 24),
          _buildLegendItem(
            context,
            '7-day trend',
            isDarkMode ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
            solid: false,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color, {bool solid = true}) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 2,
          decoration: BoxDecoration(
            color: solid ? color : Colors.transparent,
            border: !solid ? Border.all(color: color, width: 1) : null,
          ),
          child: !solid ? CustomPaint(
            painter: DashedLinePainter(color: color),
          ) : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
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

  Widget _buildErrorState(BuildContext context, String error) {
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
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load weight data',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                context.read<WeightProvider>().loadWeightData(forceRefresh: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      height: widget.isCompact ? 200 : 250,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: widget.isCompact ? Border.all(
          color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
          width: 1,
        ) : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monitor_weight_outlined,
                  size: widget.isCompact ? 40 : 48,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No weight data yet',
                  style: TextStyle(
                    fontSize: widget.isCompact ? 14 : 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first weight entry',
                  style: TextStyle(
                    fontSize: widget.isCompact ? 12 : 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                if (!widget.isCompact) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddWeightDialog(context),
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text(
                      'Add Weight',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.isCompact)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryAccent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showAddWeightDialog(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.isCompact && widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: content,
      );
    }

    return content;
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5;
    const dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset((startX + dashWidth).clamp(0, size.width), size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}