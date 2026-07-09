import 'package:flutter/material.dart';

import '../theme/flovi_tokens.dart';

/// DESIGN.md's focus-ring component (2px accent outline, 2px offset),
/// applied to every interactive element per EXPERIENCE.md's Accessibility
/// Floor (AC #7). Shown only for keyboard/focus-visible focus — not on
/// every mouse tap — via [FocusableActionDetector.onShowFocusHighlight],
/// mirroring the web's `:focus-visible` semantics.
///
/// This wrapper is the single focus/tab-stop for whatever it wraps; wrap
/// plain tappable content (not another Material focusable widget) in it to
/// avoid a duplicate, competing focus node.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.borderRadius,
    this.focusNode,
  });

  final Widget child;
  final double? borderRadius;
  final FocusNode? focusNode;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _showRing = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;
    final radius = widget.borderRadius ?? tokens.roundedSm;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onShowFocusHighlight: (visible) => setState(() => _showRing = visible),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius + 2),
          border: Border.all(
            color: _showRing ? tokens.focusRing : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
