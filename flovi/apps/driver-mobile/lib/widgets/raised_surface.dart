import 'package:flutter/material.dart';

import '../theme/flovi_tokens.dart';

/// A "raised" surface per DESIGN.md's Elevation & Depth section: a soft,
/// warm-toned shadow — never Flutter's own default Material [Card]/[Material]
/// elevation shadow, which renders a neutral gray/black shadow that looks
/// plausible but is the wrong hue relative to DESIGN.md's explicit
/// requirement. Use this instead of `Card(elevation: N)` for cards, modals,
/// and any other surface DESIGN.md calls "raised".
class RaisedSurface extends StatelessWidget {
  const RaisedSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.color,
    this.border,
    this.padding,
  });

  final Widget child;
  final double? borderRadius;
  final Color? color;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;
    final radius = borderRadius ?? tokens.roundedMd;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: tokens.raisedShadow,
      ),
      child: child,
    );
  }
}
