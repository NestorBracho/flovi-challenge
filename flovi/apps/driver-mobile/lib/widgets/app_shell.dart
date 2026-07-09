import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/flovi_tokens.dart';
import 'focus_ring.dart';
import 'phone_width_layout.dart';

/// The driver app's bottom tab bar shell: exactly 3 tabs (Gigs / Booked /
/// Profile), always visible (AC #5) — DESIGN.md doesn't give this component
/// an explicit visual recipe, so each tab pairs a Material icon with a real
/// visible text label (satisfies "accessible label" trivially) rather than
/// an icon-only affordance.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;

    return Scaffold(
      backgroundColor: tokens.surfaceCanvas,
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          border: Border(top: BorderSide(color: tokens.borderHairline)),
        ),
        child: SafeArea(
          top: false,
          // Fixed height: PhoneWidthLayout's Center would otherwise expand
          // to fill whatever (loose, large) height Scaffold offers the
          // bottomNavigationBar slot, starving `body` of space above it.
          child: SizedBox(
            height: 68,
            child: PhoneWidthLayout(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TabBarItem(
                    icon: Icons.local_shipping_outlined,
                    selectedIcon: Icons.local_shipping,
                    label: 'Gigs',
                    selected: navigationShell.currentIndex == 0,
                    onTap: () => navigationShell.goBranch(0),
                  ),
                  _TabBarItem(
                    icon: Icons.event_available_outlined,
                    selectedIcon: Icons.event_available,
                    label: 'Booked',
                    selected: navigationShell.currentIndex == 1,
                    onTap: () => navigationShell.goBranch(1),
                  ),
                  _TabBarItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Profile',
                    selected: navigationShell.currentIndex == 2,
                    onTap: () => navigationShell.goBranch(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBarItem extends StatelessWidget {
  const _TabBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<FloviTokens>()!;
    final color = selected ? tokens.accent : tokens.textSecondary;

    return FocusRing(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: tokens.spacing2,
                horizontal: tokens.spacing3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? selectedIcon : icon, color: color),
                  SizedBox(height: tokens.spacing1 / 2),
                  Text(
                    label,
                    style: tokens.label.copyWith(
                      color: color,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
