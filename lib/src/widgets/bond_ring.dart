import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/social_models.dart';
import '../theme/app_tokens.dart';

/// Bond tier classification based on bond score.
enum BondTier {
  close,
  steady,
  drifting;

  /// Factory: score ≥80 → close, 50-79 → steady, <50 → drifting.
  factory BondTier.from(int score) {
    if (score >= 80) return BondTier.close;
    if (score >= 50) return BondTier.steady;
    return BondTier.drifting;
  }

  String get label => switch (this) {
        BondTier.close => 'close',
        BondTier.steady => 'steady',
        BondTier.drifting => 'drifting',
      };
}

/// Bond trend direction (up/down/flat).
enum BondTrend {
  up,
  down,
  flat;

  IconData get icon => switch (this) {
        BondTrend.up => Icons.arrow_upward,
        BondTrend.down => Icons.arrow_downward,
        BondTrend.flat => Icons.remove,
      };
}

/// BondRing: avatar wrapped by tier-colored arc showing bond strength.
///
/// Anatomy per DESIGN.md:
/// - Avatar CircleAvatar at center
/// - Background ring (full circle, border color at 40% opacity)
/// - Foreground arc (bondScore/100 fraction, tier color, 3px stroke)
/// - Optional trend arrow at 4 o'clock when trend != flat
///
/// Touch target: minimum 44×44 regardless of size.
/// Semantic label: "<name>, <tier>, <trend>" for screen readers.
class BondRing extends StatelessWidget {
  const BondRing({
    super.key,
    required this.connection,
    this.size = 64,
    this.onTap,
  });

  final Connection connection;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tier = BondTier.from(connection.bondScore);
    final trend = connection.bondTrend;

    // Tier color mapping per DESIGN.md
    final tierColor = switch (tier) {
      BondTier.close => tokens.primary,
      BondTier.steady => tokens.inkMuted,
      BondTier.drifting => tokens.secondary,
    };

    // Trend color mapping
    final trendColor = switch (trend) {
      BondTrend.up => tokens.success,
      BondTrend.down => tokens.secondary,
      BondTrend.flat => tokens.inkMuted,
    };

    final semanticLabel =
        '${connection.name}, ${tier.label}${trend != BondTrend.flat ? ', trending ${trend.name}' : ''}';

    final ringWidget = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring (full circle)
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: 1.0,
              color: tokens.border.withValues(alpha: 0.4),
              strokeWidth: 3,
            ),
          ),
          // Foreground arc (bond score fraction)
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: connection.bondScore / 100,
              color: tierColor,
              strokeWidth: 3,
            ),
          ),
          // Avatar
          CircleAvatar(
            radius: (size - 8) / 2,
            backgroundColor: tokens.primaryTint,
            child: Text(
              connection.avatar,
              style: TextStyle(fontSize: size * 0.4),
            ),
          ),
          // Trend arrow at 4 o'clock
          if (trend != BondTrend.flat)
            Positioned(
              right: size * 0.05,
              bottom: size * 0.15,
              child: Icon(
                trend.icon,
                size: 12,
                color: trendColor,
              ),
            ),
        ],
      ),
    );

    // Wrap in minimum touch target if needed
    final touchTargetWidget = size < 44
        ? SizedBox(
            width: 44,
            height: 44,
            child: Center(child: ringWidget),
          )
        : ringWidget;

    // Wrap in Semantics and optional GestureDetector
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: onTap != null
          ? GestureDetector(
              onTap: onTap,
              child: touchTargetWidget,
            )
          : touchTargetWidget,
    );
  }
}

/// CustomPainter for drawing the ring arc.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start at 12 o'clock (-90°), sweep clockwise
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth;
}
