import 'package:flutter/material.dart';

import '../theme/flovi_tokens.dart';

/// Dashed-border panel: icon circle in the tint surface color, message, and
/// an optional single recovery action — same Empty-state panel component
/// pattern as the dispatcher app's `EmptyStatePanel.vue` (UX-DR12),
/// independently implemented here per AD-1.
///
/// Flutter's [BorderStyle] has no dashed option, so the dashed edge is drawn
/// with a small [CustomPainter] rather than pulling in a package dependency
/// for one border style.
class EmptyStatePanel extends StatelessWidget {
  const EmptyStatePanel({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

    return CustomPaint(
      foregroundPainter: _DashedRoundedRectPainter(
        color: tokens.borderSubtle,
        radius: tokens.roundedMd,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing6,
          vertical: tokens.spacing8,
        ),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(tokens.roundedMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.surfaceTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 20,
                color: tokens.textTertiary,
              ),
            ),
            SizedBox(height: tokens.spacing4),
            Text(
              message,
              style: tokens.body.copyWith(color: tokens.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              SizedBox(height: tokens.spacing4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _strokeWidth = 1.5;
  static const _dashLength = 6.0;
  static const _gapLength = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return color != oldDelegate.color || radius != oldDelegate.radius;
  }
}
