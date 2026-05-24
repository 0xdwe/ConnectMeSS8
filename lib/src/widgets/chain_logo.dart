import 'package:flutter/material.dart';

class LinkedChainLogo extends StatelessWidget {
  const LinkedChainLogo({
    super.key,
    this.size = 48,
    this.color,
    this.strokeWidth = 3.0,
  });
  
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LinkedChainPainter(
          color: color ?? const Color(0xFF6B4EFF),
          strokeWidth: strokeWidth * (size / 48), // Scale stroke width with size
        ),
      ),
    );
  }
}

class _LinkedChainPainter extends CustomPainter {
  _LinkedChainPainter({
    required this.color,
    required this.strokeWidth,
  });
  
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    // Calculate dimensions based on size
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.35;
    final offset = size.width * 0.15;
    
    // Left "C" (higher)
    final leftCenter = Offset(centerX - offset, centerY - offset * 0.5);
    const leftStartAngle = 0.8;  // ~45 degrees
    const leftSweepAngle = 2.8;  // ~160 degrees
    
    // Right "C" (lower, interlocks with left)
    final rightCenter = Offset(centerX + offset, centerY + offset * 0.3);
    const rightStartAngle = 3.2;  // ~185 degrees
    const rightSweepAngle = 2.6;  // ~150 degrees
    
    // Draw left chain link (higher)
    canvas.drawArc(
      Rect.fromCircle(center: leftCenter, radius: radius),
      leftStartAngle,
      leftSweepAngle,
      false,
      paint,
    );
    
    // Draw right chain link (lower, interlocks)
    canvas.drawArc(
      Rect.fromCircle(center: rightCenter, radius: radius),
      rightStartAngle,
      rightSweepAngle,
      false,
      paint,
    );
    
    // Optional: Add connecting line for chain effect
    final connectionPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.7;
    
    // Draw subtle connection between links
    canvas.drawLine(
      Offset(leftCenter.dx + radius * 0.7, leftCenter.dy + radius * 0.3),
      Offset(rightCenter.dx - radius * 0.7, rightCenter.dy - radius * 0.2),
      connectionPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}