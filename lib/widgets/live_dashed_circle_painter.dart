import 'package:flutter/material.dart';

/// 虚线同心圆绘制器 — Live 标识外圈用
class LiveDashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  LiveDashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    this.dashLength = 1.5,
    this.gapLength = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant LiveDashedCirclePainter old) =>
      color != old.color || strokeWidth != old.strokeWidth;
}
