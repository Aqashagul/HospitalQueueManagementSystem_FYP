import 'package:flutter/material.dart';
import 'package:queue_management_system/models/nav_items_model.dart';

class SidebarItem extends StatefulWidget {
  final NavItem item;
  final bool isSelected;
  final bool isHovered;
  final VoidCallback onTap;

  const SidebarItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
  });

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 360),
      vsync: this,
    );

    _offsetAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  

  
  @override
Widget build(BuildContext context) {
  final Color iconColor = widget.isSelected
      ? Colors.cyanAccent
      : (widget.isHovered ? Colors.white : Colors.grey);

  return GestureDetector(
    onTap: _handleTap,   // ab controller wala function call hoga
    child: AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offsetAnimation.value), // Y-axis mn neeche move
          child: child, // yahan neeche wala Container aayega (performance ke liye)
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
       padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Colors.grey.shade800
              : (widget.isHovered ? Colors.grey.shade900 : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.item.icon, color: iconColor, size: 24),
            if (!widget.isSelected) ...[
              const SizedBox(height: 4),
              Text(
                widget.item.title,
                style: TextStyle(color: iconColor, fontSize: 9),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
}
