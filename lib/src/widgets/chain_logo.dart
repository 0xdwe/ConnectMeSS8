import 'package:flutter/material.dart';
import 'dart:math' as math;

class LinkedChainLogo extends StatelessWidget {
  const LinkedChainLogo({
    super.key,
    this.size = 120,
    this.color = Colors.white,
    this.strokeWidth = 0.1, // 8% of size by default (thinner, cleaner)
  });

  final double size;
  final Color color;
  final double strokeWidth; // As ratio of size (0.0 to 1.0)

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LinkedChainPainter(color, size * strokeWidth),
      ),
    );
  }
}

class _LinkedChainPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _LinkedChainPainter(this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Left C - slightly higher
    final leftRect = Rect.fromCircle(
      center: Offset(w * 0.37, h * 0.45),
      radius: w * 0.25,
    );

    canvas.drawArc(
      leftRect,
      math.pi * 0.03, // Start angle (36 degrees)
      math.pi * 1.6, // Sweep angle (288 degrees)
      false,
      paint,
    );

    // Right C - slightly lower, interlocking
    final rightRect = Rect.fromCircle(
      center: Offset(w * 0.64, h * 0.58),
      radius: w * 0.25,
    );

    canvas.drawArc(
      rightRect,
      -math.pi * 0.93, // Start angle (-144 degrees)
      math.pi * 1.6, // Sweep angle (288 degrees)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
