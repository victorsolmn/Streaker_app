import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streak_provider.dart';
import '../utils/app_theme.dart';

class StreakDisplayWidget extends StatelessWidget {
  final bool isCompact;
  
  const StreakDisplayWidget({
    Key? key,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<StreakProvider>(
      builder: (context, streakProvider, child) {
        final stats = streakProvider.getStreakStats();
        final currentStreak = stats['current'] as int;
        final isActive = stats['isActive'] as bool;
        final todayProgress = stats['todayProgress'] as double;
        final goalsCompleted = stats['goalsCompleted'] as int;
        
        if (isCompact) {
          return _buildCompactView(context, currentStreak, isActive);
        }
        
        return _buildFullView(
          context,
          stats,
          currentStreak,
          isActive,
          todayProgress,
          goalsCompleted,
        );
      },
    );
  }
  
  Widget _buildCompactView(BuildContext context, int currentStreak, bool isActive) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: isActive ? AppTheme.primaryGradient : null,
        color: !isActive 
            ? (isDarkMode ? Colors.grey[800] : Colors.grey[200])
            : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: isActive ? Colors.white : Colors.grey,
            size: 20,
          ),
          SizedBox(width: 6),
          Text(
            '$currentStreak',
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFullView(
    BuildContext context,
    Map<String, dynamic> stats,
    int currentStreak,
    bool isActive,
    double todayProgress,
    int goalsCompleted,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final message = stats['message'] as String;
    final longestStreak = stats['longest'] as int;
    final totalDays = stats['total'] as int;
    
    // Grace Period data
    final isInGracePeriod = stats['isInGracePeriod'] as bool;
    final graceDaysUsed = stats['graceDaysUsed'] as int;
    final remainingGraceDays = stats['remainingGraceDays'] as int;
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isActive ? AppTheme.primaryGradient : null,
        color: !isActive 
            ? (isDarkMode ? AppTheme.darkCardBackground : Colors.white)
            : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isActive 
                ? AppTheme.primaryAccent.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: isActive ? Colors.white : AppTheme.primaryAccent,
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Streak',
                        style: TextStyle(
                          color: isActive 
                              ? Colors.white70
                              : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$currentStreak days',
                        style: TextStyle(
                          color: isActive 
                              ? Colors.white
                              : (isDarkMode ? Colors.white : Colors.black),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildStreakBadge(currentStreak),
            ],
          ),
          
          // Progress bar removed - now using StreakChecklistWidget in progress_screen_new.dart

          SizedBox(height: 16),
          
          // Grace Period Warning (if applicable)
          if (isInGracePeriod) ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: remainingGraceDays == 1 
                    ? AppTheme.errorRed.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: remainingGraceDays == 1 
                      ? AppTheme.errorRed.withOpacity(0.5)
                      : Colors.orange.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    remainingGraceDays == 1 ? Icons.warning : Icons.info_outline,
                    color: remainingGraceDays == 1 ? AppTheme.errorRed : Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grace Period Active',
                          style: TextStyle(
                            color: remainingGraceDays == 1 ? AppTheme.errorRed : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$remainingGraceDays excuse ${remainingGraceDays == 1 ? 'day' : 'days'} remaining',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Grace days visual indicator
                  Row(
                    children: List.generate(2, (index) => Container(
                      margin: EdgeInsets.only(left: 4),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < graceDaysUsed 
                            ? AppTheme.errorRed
                            : (remainingGraceDays == 1 && index == 1) 
                                ? Colors.orange
                                : Colors.grey.withOpacity(0.3),
                      ),
                    )),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],
          
          // Motivational Message
          Text(
            message,
            style: TextStyle(
              color: isActive 
                  ? Colors.white
                  : (isDarkMode ? Colors.white : Colors.black87),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          SizedBox(height: 16),
          
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Longest',
                '$longestStreak days',
                Icons.emoji_events,
                isActive,
                isDarkMode,
              ),
              _buildStatItem(
                'Total Days',
                '$totalDays',
                Icons.calendar_today,
                isActive,
                isDarkMode,
              ),
              _buildStatItem(
                'This Month',
                '${stats['currentMonthDays'] ?? 0}',
                Icons.date_range,
                isActive,
                isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStreakBadge(int streak) {
    IconData icon;
    Color color;
    
    if (streak >= 100) {
      icon = Icons.local_fire_department;
      color = Colors.purple;
    } else if (streak >= 30) {
      icon = Icons.whatshot;
      color = Colors.orange;
    } else if (streak >= 7) {
      icon = Icons.star;
      color = Colors.amber;
    } else if (streak >= 3) {
      icon = Icons.trending_up;
      color = AppTheme.successGreen;
    } else {
      icon = Icons.schedule;
      color = Colors.grey;
    }
    
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
  
  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    bool isActive,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: isActive 
              ? Colors.white70
              : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
          size: 20,
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isActive 
                ? Colors.white
                : (isDarkMode ? Colors.white : Colors.black),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isActive 
                ? Colors.white70
                : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}