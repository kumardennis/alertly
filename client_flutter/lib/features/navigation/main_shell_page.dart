import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class MainShellPage extends StatelessWidget {
  const MainShellPage({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  int _indexForLocation(String path) {
    if (path.startsWith('/alerts')) return 1;
    if (path.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _indexForLocation(location);
    const selectorWidth = 98.0;
    const selectorHeight = 104.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 104,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / 3;
              final selectorLeft =
                  (itemWidth * currentIndex) +
                  ((itemWidth - selectorWidth) / 2);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 94,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.secondary),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: selectorLeft,
                    top: 0,
                    width: selectorWidth,
                    height: selectorHeight,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            label: 'HOME',
                            icon: Icons.grid_view_rounded,
                            selectedIcon: Icons.home_rounded,
                            active: currentIndex == 0,
                            onTap: () => context.go('/'),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            label: 'ALERT',
                            icon: Icons.campaign_rounded,
                            selectedIcon: Icons.add,
                            active: currentIndex == 1,
                            onTap: () => context.go('/alerts'),
                            highlightDot: true,
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            label: 'PROFILE',
                            icon: Icons.person_outline_rounded,
                            selectedIcon: Icons.person_rounded,
                            active: currentIndex == 2,
                            onTap: () => context.go('/profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.active,
    required this.onTap,
    this.highlightDot = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool active;
  final VoidCallback onTap;
  final bool highlightDot;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.surface : AppColors.secondary;
    final iconWidget =
        (active && highlightDot)
            ? Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: AppColors.primary, size: 24),
            )
            : Icon(active ? selectedIcon : icon, color: color, size: 28);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
