import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/data/nav_items_data.dart';
import 'package:queue_management_system/models/nav_items_model.dart';
import 'package:queue_management_system/screens/auth/login_page.dart';
import 'package:queue_management_system/widgets/sidebar_glyph_icon.dart';
import 'package:queue_management_system/widgets/sidebar_item.dart';
import 'package:queue_management_system/widgets/top_appbar.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  int? hoveredIndex;
  bool isLogoutHovered = false;
  bool isCollapsed = false;

 
  bool _isRailHovered = false;


  static const double _autoCollapseBreakpoint = 900;

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Do you want to Logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrowScreen = screenWidth < _autoCollapseBreakpoint;
    final bool effectiveCollapsed = isNarrowScreen ? true : isCollapsed;

    void toggleSidebar() {
      if (!isNarrowScreen) {
        setState(() => isCollapsed = !isCollapsed);
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isRailHovered = true),
      onExit: (_) => setState(() => _isRailHovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: effectiveCollapsed ? 72 : 220,
            color: AppColors.white,
            child: Column(
              children: [
                TopAppbar(
                  isCollapsed: effectiveCollapsed,
                  forceShowToggleIcon: effectiveCollapsed && _isRailHovered,
                  onToggle: isNarrowScreen ? () {} : toggleSidebar,
                ),

                const Divider(
                  color: Color.fromARGB(255, 201, 201, 201),
                  thickness: 1,
                  height: 0.1,
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: ListView.builder(
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      final item = navItems[index];

                      return MouseRegion(
                        onEnter: (_) => setState(() => hoveredIndex = index),
                        onExit: (_) => setState(() => hoveredIndex = null),
                        child: SidebarItem(
                          item: item,
                          isSelected: widget.selectedIndex == index,
                          isHovered: hoveredIndex == index,
                          isCollapsed: effectiveCollapsed,
                          onTap: () {
                            setState(() {
                              widget.onItemSelected(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                const Divider(
                  color: Color.fromARGB(255, 201, 201, 201),
                  thickness: 1,
                  height: 20,
                ),

            
                MouseRegion(
                  onEnter: (_) => setState(() => isLogoutHovered = true),
                  onExit: (_) => setState(() => isLogoutHovered = false),
                  child: SidebarItem(
                    item: NavItem(
                      title: "Logout",
                      icon: Icons.logout_outlined,
                      pageBuilder: () => const SizedBox(),
                    ),
                    isSelected: false,
                    isHovered: isLogoutHovered,
                    isCollapsed: effectiveCollapsed,
                    onTap: () {
                      _handleLogout(context);
                    },
                  ),
                ),
              ],
            ),
          ),

         
          if (!effectiveCollapsed && !isNarrowScreen)
            Positioned(
              right: 7,
              top: 20,
              child: Tooltip(
                message: "Close sidebar",
                preferBelow: false,
                verticalOffset: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                child: GestureDetector(
                  onTap: toggleSidebar,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color.fromARGB(255, 215, 214, 214),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SidebarGlyphIcon(
                          key: const ValueKey('toggle-icon'),
                          color: AppColors.textPurple,
                          size: 16,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}