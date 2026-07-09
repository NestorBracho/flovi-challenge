import 'package:flutter/material.dart';

import '../theme/flovi_tokens.dart';
import '../widgets/phone_width_layout.dart';

/// Shell only — the real Booked list (cancel/mark-complete) is built in
/// Stories 3.3/3.4.
class BookedScreen extends StatelessWidget {
  const BookedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;
    return Scaffold(
      backgroundColor: tokens.surfaceCanvas,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing5,
            vertical: tokens.spacing5,
          ),
          child: PhoneWidthLayout(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text('Booked', style: tokens.display),
            ),
          ),
        ),
      ),
    );
  }
}
