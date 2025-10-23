import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/weight_provider.dart';
import '../models/weight_model.dart';
import '../utils/app_theme.dart';

class WeightMilestonesCard extends StatelessWidget {
  const WeightMilestonesCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, weightProvider, child) {
        final milestones = weightProvider.milestones;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, milestones.length),
              const SizedBox(height: 16),
              if (milestones.isEmpty)
                _buildEmptyState(context)
              else
                _buildMilestonesList(context, milestones),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Milestones Achieved',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🎉',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryAccent.withOpacity(0.2),
                    AppTheme.primaryHover.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                size: 32,
                color: AppTheme.primaryAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your first milestone is just around the corner!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestonesList(BuildContext context, List<WeightMilestone> milestones) {
    // Sort milestones by date (most recent first)
    final sortedMilestones = List<WeightMilestone>.from(milestones)
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sortedMilestones.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _MilestoneBadge(
            milestone: sortedMilestones[index],
            index: index,
          );
        },
      ),
    );
  }
}

class _MilestoneBadge extends StatefulWidget {
  final WeightMilestone milestone;
  final int index;

  const _MilestoneBadge({
    required this.milestone,
    required this.index,
  });

  @override
  State<_MilestoneBadge> createState() => _MilestoneBadgeState();
}

class _MilestoneBadgeState extends State<_MilestoneBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400 + (widget.index * 100)),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LinearGradient _getGradientForType(String type) {
    switch (type) {
      case 'loss':
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'target':
        return const LinearGradient(
          colors: [Color(0xFFFFB347), Color(0xFFFFCC33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'gain':
        return const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return AppTheme.primaryGradient;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'target':
        return Icons.celebration;
      case 'loss':
        return Icons.emoji_events;
      case 'gain':
        return Icons.star;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: _getGradientForType(widget.milestone.type),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _getGradientForType(widget.milestone.type)
                    .colors
                    .first
                    .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForType(widget.milestone.type),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.milestone.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, yyyy').format(widget.milestone.achievedAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
