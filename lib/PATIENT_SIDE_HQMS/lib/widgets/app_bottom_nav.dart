import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/department_list_screen.dart';
import '../screens/patient_profile_screen.dart';
import '../screens/track_queue_tab_screen.dart';
import '../utils/app_theme.dart';

/// 0 = Profile (left), 1 = Home (center), 2 = Track Queue (right)
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();

    final Widget page = switch (index) {
      0 => const PatientProfileScreen(),
      1 => const DepartmentListScreen(),
      _ => const TrackQueueTabScreen(),
    };

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 8),
      child: SizedBox(
        height: 88,
        child: Stack(
          children: [
            // ---- Floating bar ----
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 66,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .14),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SideItem(
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        label: 'Profile',
                        selected: currentIndex == 0,
                        onTap: () => _go(context, 0),
                      ),
                    ),
                  
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _go(context, 1),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: currentIndex == 1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: currentIndex == 1
                                    ? AppColors.primary
                                    : AppColors.textGrey,
                              ),
                              child: const Text('Home'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _SideItem(
                        icon: Icons.confirmation_number_outlined,
                        activeIcon: Icons.confirmation_number_rounded,
                        label: 'Track Queue',
                        selected: currentIndex == 2,
                        onTap: () => _go(context, 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---- Raised center Home button ----
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _go(context, 1),
                  child: AnimatedScale(
                    scale: currentIndex == 1 ? 1.0 : 0.92,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.gradientStart,
                            AppColors.gradientEnd,
                          ],
                        ),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: currentIndex == 1 ? .45 : .22,
                            ),
                            blurRadius: currentIndex == 1 ? 20 : 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textGrey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // sliding indicator on top
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: selected ? 22 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          AnimatedScale(
            scale: selected ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: Icon(selected ? activeIcon : icon, color: color, size: 25),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}