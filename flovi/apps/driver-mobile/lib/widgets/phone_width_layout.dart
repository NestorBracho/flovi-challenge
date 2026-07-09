import 'package:flutter/material.dart';

/// Caps content to a phone-width single column and centers it, so the layout
/// reads as phone-width (UX-DR19) regardless of whether the demo browser
/// window is phone-sized or a full desktop window (AC #6) — Flutter web's
/// own web-first layout would otherwise let content stretch edge-to-edge.
class PhoneWidthLayout extends StatelessWidget {
  const PhoneWidthLayout({super.key, required this.child, this.maxWidth = 430});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
