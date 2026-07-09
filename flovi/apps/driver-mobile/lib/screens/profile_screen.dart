import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/flovi_tokens.dart';
import '../widgets/focus_ring.dart';
import '../widgets/phone_width_layout.dart';

/// Minimal signed-in identity + sign out (AC #5) — not a designed settings
/// area (EXPERIENCE.md `[ASSUMPTION]`).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;
    final user = AuthService.instance.currentSession?.user;
    final metadata = user?.userMetadata;
    final name =
        (metadata?['full_name'] as String?) ??
        (metadata?['name'] as String?) ??
        user?.email ??
        'Driver';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: tokens.surfaceCanvas,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing5,
            vertical: tokens.spacing5,
          ),
          child: PhoneWidthLayout(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile', style: tokens.display),
                SizedBox(height: tokens.spacing6),
                Text(name, style: tokens.bodyStrong),
                if (email.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing1),
                  Text(
                    email,
                    style: tokens.body.copyWith(color: tokens.textSecondary),
                  ),
                ],
                SizedBox(height: tokens.spacing6),
                FocusRing(
                  borderRadius: tokens.roundedFull,
                  child: Semantics(
                    button: true,
                    label: 'Sign out',
                    child: GestureDetector(
                      onTap: () => AuthService.instance.signOut(),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacing5,
                          vertical: tokens.spacing3,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          border: Border.all(color: tokens.borderSubtle),
                          borderRadius: BorderRadius.circular(
                            tokens.roundedFull,
                          ),
                        ),
                        child: Text(
                          'Sign out',
                          style: tokens.bodyStrong.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
