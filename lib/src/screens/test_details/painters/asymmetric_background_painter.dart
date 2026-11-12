import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter for asymmetric gradient background with organic shapes
class AsymmetricBackgroundPainter extends CustomPainter {
  final Animation<double> animation;

  AsymmetricBackgroundPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF8378F4),
        const Color(0xFF6B5FE0),
        const Color(0xFF6366F1),
      ],
    );

    final gradientRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradientPaint = Paint()..shader = gradient.createShader(gradientRect);
    canvas.drawRect(gradientRect, gradientPaint);

    // Organic blob shapes with animation
    final blobPaint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.06 + math.sin(animation.value * 2) * 0.02)
      ..style = PaintingStyle.fill;

    final blobPaint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.04 + math.cos(animation.value * 1.5) * 0.02)
      ..style = PaintingStyle.fill;

    final blobPaint3 = Paint()
      ..color = Colors.white.withValues(alpha: 0.08 + math.sin(animation.value * 2.5) * 0.03)
      ..style = PaintingStyle.fill;

    // Create asymmetric blob positions
    final blob1 = _createAsymmetricBlob(
      size.width * 0.85,
      size.height * 0.25,
      140 + math.sin(animation.value * 2 * math.pi) * 30,
    );

    final blob2 = _createAsymmetricBlob(
      size.width * 0.15,
      size.height * 0.75,
      100 + math.cos(animation.value * 1.5 * math.pi) * 20,
    );

    final blob3 = _createAsymmetricBlob(
      size.width * 0.7,
      size.height * 0.9,
      120 + math.sin(animation.value * math.pi) * 25,
    );

    canvas.drawPath(blob1, blobPaint1);
    canvas.drawPath(blob2, blobPaint2);
    canvas.drawPath(blob3, blobPaint3);

    // Asymmetric accent lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path1 = Path()
      ..moveTo(size.width * 0.1, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.35,
        size.width * 0.5,
        size.height * 0.3,
      );

    final path2 = Path()
      ..moveTo(size.width * 0.8, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.65,
        size.width * 0.4,
        size.height * 0.7,
      );

    canvas.drawPath(path1, linePaint);
    canvas.drawPath(path2, linePaint);
  }

  Path _createAsymmetricBlob(double x, double y, double radius) {
    final path = Path();
    final segments = 10;
    final angleStep = 2 * math.pi / segments;

    for (int i = 0; i <= segments; i++) {
      final angle = i * angleStep;
      // Create asymmetry by varying radius based on angle
      final variation = math.sin(angle * 3) * 0.3 + math.cos(angle * 2) * 0.2;
      final r = radius * (0.7 + variation);

      final px = x + r * math.cos(angle);
      final py = y + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant AsymmetricBackgroundPainter oldDelegate) => true;
}
