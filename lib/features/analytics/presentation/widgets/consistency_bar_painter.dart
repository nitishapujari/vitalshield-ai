import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class BarChartPoint {
  final String label;
  final double value;

  const BarChartPoint({
    required this.label,
    required this.value,
  });
}

class ConsistencyBarChart extends StatelessWidget {
  final List<BarChartPoint> points;
  final double targetValue;
  final String targetLabel;
  final String Function(double) formatValue;
  final Color barColor;
  final double height;

  const ConsistencyBarChart({
    super.key,
    required this.points,
    required this.targetValue,
    required this.targetLabel,
    required this.formatValue,
    this.barColor = AppColors.primary,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: CustomPaint(
        size: Size.infinite,
        painter: ConsistencyBarPainter(
          points: points,
          targetValue: targetValue,
          targetLabel: targetLabel,
          formatValue: formatValue,
          barColor: barColor,
          textColor: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class ConsistencyBarPainter extends CustomPainter {
  final List<BarChartPoint> points;
  final double targetValue;
  final String targetLabel;
  final String Function(double) formatValue;
  final Color barColor;
  final Color textColor;

  ConsistencyBarPainter({
    required this.points,
    required this.targetValue,
    required this.targetLabel,
    required this.formatValue,
    required this.barColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double paddingX = 40.0;
    final double paddingY = 30.0;
    final double chartWidth = size.width - 2 * paddingX;
    final double chartHeight = size.height - 2 * paddingY;

    // Find the maximum value in dataset to scale, or use targetValue + padding
    final double maxValInPoints = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final double maxValue = MathUtils.max(targetValue * 1.25, maxValInPoints * 1.15);

    // 1. Draw Target Dotted Line
    final double targetRatio = targetValue / maxValue;
    final double targetY = size.height - paddingY - (targetRatio * chartHeight);

    final targetPaint = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw dashed line
    final double dashWidth = 5.0;
    final double dashSpace = 4.0;
    double currentX = paddingX;
    while (currentX < size.width - paddingX) {
      canvas.drawLine(
        Offset(currentX, targetY),
        Offset(currentX + dashWidth, targetY),
        targetPaint,
      );
      currentX += dashWidth + dashSpace;
    }

    // Draw Target label
    final targetSpan = TextSpan(
      text: '$targetLabel (${formatValue(targetValue)})',
      style: TextStyle(
        color: textColor.withValues(alpha: 0.5),
        fontSize: 8,
        fontWeight: FontWeight.w500,
      ),
    );
    final targetPainter = TextPainter(
      text: targetSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    targetPainter.paint(
      canvas,
      Offset(size.width - paddingX - targetPainter.width, targetY - targetPainter.height - 3),
    );

    // 2. Draw Bars
    final int count = points.length;
    final double spacingRatio = 0.35; // Spacing between bars
    final double totalSpacing = chartWidth * spacingRatio;
    final double totalBarWidth = chartWidth - totalSpacing;
    final double barWidth = totalBarWidth / count;
    final double gap = totalSpacing / (count - 1 > 0 ? count - 1 : 1);

    for (int i = 0; i < count; i++) {
      final p = points[i];
      final double ratio = p.value / maxValue;
      final double barHeight = ratio * chartHeight;
      
      final double bx = paddingX + i * (barWidth + gap);
      final double by = size.height - paddingY - barHeight;

      // Muted styling: 0.85 opacity for above target, 0.5 for below
      final isAboveTarget = p.value >= targetValue;
      final paintColor = isAboveTarget
          ? barColor.withValues(alpha: 0.85)
          : barColor.withValues(alpha: 0.5);

      final barPaint = Paint()
        ..color = paintColor
        ..style = PaintingStyle.fill;

      // Draw rounded rectangle bar
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(bx, by, barWidth, barHeight),
        topLeft: const Radius.circular(AppSpacing.radiusSm),
        topRight: const Radius.circular(AppSpacing.radiusSm),
      );
      canvas.drawRRect(rect, barPaint);

      // Draw value text above bar
      final valSpan = TextSpan(
        text: formatValue(p.value),
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
      final valPainter = TextPainter(
        text: valSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      valPainter.paint(
        canvas,
        Offset(bx + (barWidth - valPainter.width) / 2, by - valPainter.height - 4),
      );

      // Draw bottom day labels (e.g. M, T, W...)
      final daySpan = TextSpan(
        text: p.label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      final dayPainter = TextPainter(
        text: daySpan,
        textDirection: TextDirection.ltr,
      )..layout();
      dayPainter.paint(
        canvas,
        Offset(bx + (barWidth - dayPainter.width) / 2, size.height - paddingY + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConsistencyBarPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.targetValue != targetValue ||
        oldDelegate.barColor != barColor ||
        oldDelegate.textColor != textColor;
  }
}

class MathUtils {
  static double max(double a, double b) => a > b ? a : b;
}
