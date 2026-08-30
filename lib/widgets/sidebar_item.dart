import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/models/nav_items_model.dart';
import 'package:google_fonts/google_fonts.dart';

class SidebarItem extends StatefulWidget {
  final NavItem item;
  final bool isSelected;
  final bool isHovered;
  final VoidCallback onTap;
  final bool isCollapsed;

  const SidebarItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
    required this.isCollapsed,
  });

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

 
  OverlayEntry? _tooltipEntry;
  final GlobalKey _itemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _offsetAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant SidebarItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool shouldShow = widget.isCollapsed && widget.isHovered;
    final bool wasShowing = oldWidget.isCollapsed && oldWidget.isHovered;

    if (shouldShow && !wasShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTooltip());
    } else if (!shouldShow && wasShowing) {
      _removeTooltip();
    }
  }

  @override
  void dispose() {
    _removeTooltip();
    _controller.dispose();
    super.dispose();
  }

  void _showTooltip() {
    if (!mounted || !widget.isCollapsed || !widget.isHovered) return;

    final renderBox = _itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _removeTooltip();

    _tooltipEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx + size.width + 8,
        top: position.dy + (size.height / 2) - 16,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                widget.item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_tooltipEntry!);
  }

  void _removeTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  void _handleTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.isSelected
        ? AppColors.bgColor
        : (widget.isHovered ? AppColors.bgColor : AppColors.textPurple);

    return GestureDetector(
      key: _itemKey,
      onTap: _handleTap,
      child: SizedBox(
        height: 65,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _offsetAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _offsetAnimation.value),
                    child: child,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 6,
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: widget.isSelected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFBCA8E8), Color(0xFFA25AE6)],
                          )
                        : null,
                    color: widget.isSelected
                        ? null
                        : (widget.isHovered
                            ? AppColors.softPurple
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                    
                      final bool canShowLabel =
                          !widget.isCollapsed && constraints.maxWidth > 70;

                      return Row(
                        mainAxisAlignment: widget.isCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          Icon(
                            widget.item.icon,
                            color: iconColor,
                            size: 25,
                          ),
                  if (canShowLabel) ...[
  const SizedBox(width: 14),
  Expanded(
    child: Text(
  widget.item.title,
  softWrap: true,
  style: GoogleFonts.inter(
    color: iconColor,
    fontSize: 13,
    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
  ),
),
  ),
],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Selection indicator bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: widget.isSelected ? 4 : 0,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
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