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
/// - Avatar CircleAvatar at center (or numeric score when [showAvatar] is
///   false on the connection-aware constructor)
/// - Background ring (full circle, border color at 40% opacity)
/// - Foreground arc (bondScore/100 fraction, tier color, 3px stroke)
/// - Optional trend arrow at 4 o'clock when trend != flat
///
/// Animation:
/// - Animates arc from old to new score over 600ms with Curves.easeOutQuart
/// - Only animates on score changes, not on first mount
/// - Respects MediaQuery.disableAnimations
///
/// Touch target: minimum 44×44 regardless of size.
/// Semantic label: "name, tier, trend" for screen readers.
///
/// Set [showAvatar] to false on the connection-aware constructor to render
/// the numeric bond score in the center instead of the connection's avatar.
/// Trend arrow, tier color, animation, and semantic label are preserved.
class BondRing extends StatefulWidget {
  const BondRing({
    super.key,
    required Connection connection,
    this.size = 64,
    this.onTap,
    this.showAvatar = true,
    this.strokeWidth = 3,
  }) : _connection = connection,
       _score = null,
       _label = null;

  /// Named constructor for displaying a raw score without a Connection object.
  const BondRing.fromScore({
    super.key,
    required int score,
    required String label,
    this.size = 64,
    this.onTap,
    this.strokeWidth = 3,
  }) : _connection = null,
       _score = score,
       _label = label,
       showAvatar = true;

  final Connection? _connection;
  final int? _score;
  final String? _label;
  final double size;
  final VoidCallback? onTap;
  final bool showAvatar;
  final double strokeWidth;

  // Convenience getters
  Connection? get connection => _connection;
  int get score => _connection?.bondScore ?? _score ?? 0;
  String get label => _connection?.name ?? _label ?? '';
  String? get avatar => _connection?.avatar;
  BondTrend? get trend => _connection?.bondTrendAt(DateTime.now());

  @override
  State<BondRing> createState() => _BondRingState();
}

class _BondRingState extends State<BondRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: widget.score / 100,
      end: widget.score / 100,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
  }

  @override
  void didUpdateWidget(BondRing oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldScore = oldWidget.score;
    final newScore = widget.score;

    // Only animate if score changed.
    if (oldScore != newScore) {
      final disableAnimations = MediaQuery.of(context).disableAnimations;

      if (disableAnimations) {
        // Skip animation, render immediately
        setState(() {
          _animation = Tween<double>(
            begin: newScore / 100,
            end: newScore / 100,
          ).animate(_controller);
        });
      } else {
        // Animate from old to new score
        _controller.reset();
        setState(() {
          _animation = Tween<double>(begin: oldScore / 100, end: newScore / 100)
              .animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutQuart,
                ),
              );
        });
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tier = BondTier.from(widget.score);
    final currentTrend = widget.trend;

    // Tier color mapping per DESIGN.md
    final tierColor = switch (tier) {
      BondTier.close => tokens.primary,
      BondTier.steady => tokens.inkMuted,
      BondTier.drifting => tokens.secondary,
    };

    // Trend color mapping: green for up, red for down
    final trendColor = currentTrend == null
        ? tokens.inkMuted
        : switch (currentTrend) {
            BondTrend.up => tokens.success,
            BondTrend.down => tokens.danger,
            BondTrend.flat => tokens.inkMuted,
          };

    final semanticLabel = currentTrend != null && currentTrend != BondTrend.flat
        ? '${widget.label}, ${tier.label}, trending ${currentTrend.name}'
        : '${widget.label}, ${tier.label}';

    final ringWidget = SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Background ring (full circle)
              CustomPaint(
                size: Size.square(widget.size),
                painter: _RingPainter(
                  progress: 1.0,
                  color: tokens.border.withValues(alpha: 0.4),
                  strokeWidth: widget.strokeWidth,
                ),
              ),
              // Foreground arc (bond score fraction, animated)
              CustomPaint(
                size: Size.square(widget.size),
                painter: _RingPainter(
                  progress: _animation.value,
                  color: tierColor,
                  strokeWidth: widget.strokeWidth,
                ),
              ),
              // Avatar (only for Connection-based rings when showAvatar is true)
              if (widget.avatar != null && widget.showAvatar)
                CircleAvatar(
                  radius: (widget.size - 8) / 2,
                  backgroundColor: tokens.primaryTint,
                  child: Text(
                    widget.avatar!,
                    style: TextStyle(fontSize: widget.size * 0.4),
                  ),
                ),
              // Score number for fromScore constructor or showAvatar=false
              if (widget.avatar == null || !widget.showAvatar)
                Text(
                  '${widget.score}',
                  style: TextStyle(
                    fontSize: widget.size * 0.28,
                    fontWeight: FontWeight.w700,
                    color: tokens.primary,
                  ),
                ),
              // Trend arrow at 4 o'clock (bold arrows)
              if (currentTrend != null && currentTrend != BondTrend.flat)
                Positioned(
                  right: widget.size * 0.05,
                  bottom: widget.size * 0.15,
                  child: Icon(currentTrend.icon, size: 16, color: trendColor),
                ),
            ],
          );
        },
      ),
    );

    // Wrap in minimum touch target if needed
    final touchTargetWidget = widget.size < 44
        ? SizedBox(width: 44, height: 44, child: Center(child: ringWidget))
        : ringWidget;

    // Wrap in Semantics and optional GestureDetector
    return Semantics(
      label: semanticLabel,
      button: widget.onTap != null,
      child: widget.onTap != null
          ? GestureDetector(onTap: widget.onTap, child: touchTargetWidget)
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
