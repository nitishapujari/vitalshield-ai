import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/trend_data_model.dart';

class LineChart extends StatelessWidget {
  final List<WellnessScorePoint> points;
  final double height;

  const LineChart({
    super.key,
    required this.points,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: CustomPaint(
        size: Size.infinite,
        painter: LineChartPainter(
          points: points,
          textColor: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<WellnessScorePoint> points;
  final Color textColor;

  LineChartPainter({
    required this.points,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double paddingX = 40.0;
    final double paddingY = 20.0;
    final double chartWidth = size.width - 2 * paddingX;
    final double chartHeight = size.height - 2 * paddingY;

    // Determine min/max values
    double maxVal = 100.0;
    double minVal = 0.0;

    // Calculate Coordinates
    final coords = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final double percentX = points.length > 1 ? i / (points.length - 1) : 0.5;
      final double percentY = (points[i].score - minVal) / (maxVal - minVal);

      final double cx = paddingX + percentX * chartWidth;
      final double cy = size.height - paddingY - (percentY * chartHeight);
      coords.add(Offset(cx, cy));
    }

    // Draw Grid Lines (Dotted background lines)
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double steps = 4;
    for (int i = 0; i <= steps; i++) {
      final double ratio = i / steps;
      final double gy = size.height - paddingY - (ratio * chartHeight);
      
      // Draw grid line
      canvas.drawLine(Offset(paddingX, gy), Offset(size.width - paddingX, gy), gridPaint);
      
      // Draw y-axis labels (0, 25, 50, 75, 100)
      final textSpan = TextSpan(
        text: (minVal + ratio * (maxVal - minVal)).toInt().toString(),
        style: TextStyle(
          color: textColor.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(paddingX - textPainter.width - 8, gy - textPainter.height / 2));
    }

    // Draw Curve
    final path = Path();
    if (coords.length > 1) {
      path.moveTo(coords[0].dx, coords[0].dy);
      for (int i = 0; i < coords.length - 1; i++) {
        final p0 = coords[i];
        final p1 = coords[i + 1];
        
        // Bezier control points
        final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY1 = p0.dy;
        final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY2 = p1.dy;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
      }
    } else if (coords.length == 1) {
      path.moveTo(paddingX, coords[0].dy);
      path.lineTo(size.width - paddingX, coords[0].dy);
    }

    // Draw Gradient Fill under path
    if (coords.length > 1) {
      final fillPath = Path.from(path);
      fillPath.lineTo(coords.last.dx, size.height - paddingY);
      fillPath.lineTo(coords.first.dx, size.height - paddingY);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(paddingX, paddingY, size.width - paddingX, size.height - paddingY))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // Paint line path
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw point nodes & labels on top
    final dotPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < coords.length; i++) {
      final offset = coords[i];
      
      // Draw outer circle
      canvas.drawCircle(offset, 4.5, dotPaint);
      canvas.drawCircle(offset, 4.5, dotBorderPaint);

      // Draw short day labels below the axis (Mon, Tue, Wed...)
      final String labelText = points[i].date.day.toString();
      final daySpan = TextSpan(
        text: labelText,
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
        Offset(offset.dx - dayPainter.width / 2, size.height - paddingY + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.textColor != textColor;
  }
}
