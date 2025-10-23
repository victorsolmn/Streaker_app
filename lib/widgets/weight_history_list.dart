import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weight_provider.dart';
import '../models/weight_model.dart';
import '../utils/app_theme.dart';

class WeightHistoryList extends StatelessWidget {
  const WeightHistoryList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, weightProvider, child) {
        final entries = weightProvider.entries;
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        // Sort entries by date (most recent first)
        final sortedEntries = List<WeightEntry>.from(entries)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Empty state
        if (sortedEntries.isEmpty) {
          return _buildEmptyState(context, isDarkMode);
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedEntries.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemBuilder: (context, index) {
            final entry = sortedEntries[index];

            // Calculate change from previous entry
            double? changeFromPrevious;
            if (index < sortedEntries.length - 1) {
              final previousEntry = sortedEntries[index + 1];
              changeFromPrevious = entry.weight - previousEntry.weight;
            }

            return _WeightEntryCard(
              entry: entry,
              changeFromPrevious: changeFromPrevious,
              unit: weightProvider.weightProgress?.unit ?? 'kg',
              isDarkMode: isDarkMode,
              onDelete: () => _showDeleteConfirmation(context, entry, weightProvider),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.monitor_weight_outlined,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No weight entries yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WeightEntry entry,
    WeightProvider weightProvider,
  ) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningYellow, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Entry',
                style: TextStyle(
                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this weight entry from ${entry.formattedDateTime}?',
          style: TextStyle(
            color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      final success = await weightProvider.deleteWeightEntry(entry.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Weight entry deleted successfully'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _WeightEntryCard extends StatelessWidget {
  final WeightEntry entry;
  final double? changeFromPrevious;
  final String unit;
  final bool isDarkMode;
  final VoidCallback onDelete;

  const _WeightEntryCard({
    required this.entry,
    this.changeFromPrevious,
    required this.unit,
    required this.isDarkMode,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasChange = changeFromPrevious != null && changeFromPrevious != 0;
    final isWeightLoss = hasChange && changeFromPrevious! < 0;
    final isWeightGain = hasChange && changeFromPrevious! > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode
            ? AppTheme.dividerDark.withOpacity(0.5)
            : AppTheme.dividerLight.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {}, // Makes the card feel interactive
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Weight Icon Container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryAccent.withOpacity(0.2),
                      AppTheme.primaryAccent.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.monitor_weight,
                  color: AppTheme.primaryAccent,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Main Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and time
                    Text(
                      entry.formattedDate,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        // Time
                        Text(
                          entry.formattedTime,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDarkMode
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondary,
                          ),
                        ),

                        // Weight value
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${entry.weight.toStringAsFixed(1)} $unit',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Change indicator
                    if (hasChange) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isWeightLoss ? Icons.arrow_downward : Icons.arrow_upward,
                            size: 14,
                            color: isWeightLoss ? AppTheme.successGreen : AppTheme.errorRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${isWeightLoss ? '' : '+'}${changeFromPrevious!.toStringAsFixed(1)} $unit',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isWeightLoss ? AppTheme.successGreen : AppTheme.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Note if present
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                            ? AppTheme.darkCardBackground.withOpacity(0.5)
                            : AppTheme.cardBackgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode
                              ? AppTheme.dividerDark
                              : AppTheme.dividerLight,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 14,
                              color: isDarkMode
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.note!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDarkMode
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Delete Button
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.delete_outline,
                    color: AppTheme.errorRed.withOpacity(0.7),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
