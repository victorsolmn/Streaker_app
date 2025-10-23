import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class DashboardMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final Color iconColor;
  final IconData icon;
  final Widget? chart;
  final VoidCallback? onTap;

  const DashboardMetricCard({
    Key? key,
    required this.title,
    required this.value,
    this.unit,
    required this.iconColor,
    required this.icon,
    this.chart,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (chart != null) 
              Expanded(
                child: chart!,
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (unit != null)
                        Text(
                          unit!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CircularProgressChart extends StatelessWidget {
  final double value;
  final double maxValue;
  final String displayValue;
  final String unit;
  final Color progressColor;

  const CircularProgressChart({
    Key? key,
    required this.value,
    required this.maxValue,
    required this.displayValue,
    required this.unit,
    required this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(8),
      child: CustomPaint(
        painter: CircularProgressPainter(
          percentage: percentage,
          progressColor: progressColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double percentage;
  final Color progressColor;

  CircularProgressPainter({
    required this.percentage,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 15;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final progressAngle = 2 * math.pi * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progressAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class MiniBarChart extends StatelessWidget {
  final List<double> values;
  final Color barColor;

  const MiniBarChart({
    Key? key,
    required this.values,
    required this.barColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxValue = values.reduce(math.max);
    
    return Container(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((value) {
          final height = (value / maxValue) * 40;
          return Container(
            width: 6,
            height: height,
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SemiCircularProgressChart extends StatelessWidget {
  final double value;
  final double maxValue;
  final String displayValue;
  final String unit;
  final Color progressColor;

  const SemiCircularProgressChart({
    Key? key,
    required this.value,
    required this.maxValue,
    required this.displayValue,
    required this.unit,
    required this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.only(top: 8),
      child: CustomPaint(
        painter: SemiCircularProgressPainter(
          percentage: percentage,
          progressColor: progressColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SemiCircularProgressPainter extends CustomPainter {
  final double percentage;
  final Color progressColor;

  SemiCircularProgressPainter({
    required this.percentage,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final radius = math.min(size.width, size.height) / 2 - 15;

    // Draw background arc
    final backgroundPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      backgroundPaint,
    );

    // Draw progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final progressAngle = math.pi * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      progressAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}