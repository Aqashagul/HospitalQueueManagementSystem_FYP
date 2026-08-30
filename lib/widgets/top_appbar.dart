import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/widgets/sidebar_glyph_icon.dart';

class TopAppbar extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;


  final bool forceShowToggleIcon;

  const TopAppbar({
    super.key,
    required this.isCollapsed,
    required this.onToggle,
    this.forceShowToggleIcon = false,
  });

  @override
  State<TopAppbar> createState() => _TopAppbarState();
}

class _TopAppbarState extends State<TopAppbar> {
  bool _isLogoHovered = false;
  OverlayEntry? _tooltipEntry;
  final GlobalKey _logoKey = GlobalKey();

  void _showTooltip() {
    final renderBox = _logoKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _removeTooltip();

    _tooltipEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx + size.width + 8,
        top: position.dy + (size.height / 2) - 14,
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
              child: const Text(
                "Open sidebar",
                style: TextStyle(
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

  @override
void didUpdateWidget(covariant TopAppbar oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (!widget.isCollapsed && oldWidget.isCollapsed) {
    _isLogoHovered = false;
    _removeTooltip();
  }
}

@override
void dispose() {
  _removeTooltip();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    final bool showToggleIcon =
        widget.isCollapsed && (_isLogoHovered || widget.forceShowToggleIcon);

    return Container(
      height: 55,
      color: AppColors.white,
      padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 0 : 16),
      child: Row(
        mainAxisAlignment: widget.isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          MouseRegion(
            key: _logoKey,
            cursor: widget.isCollapsed
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onEnter: (_) {
              if (!widget.isCollapsed) return; 
              setState(() => _isLogoHovered = true);
              _showTooltip();
            },
            onExit: (_) {
              if (!widget.isCollapsed) return;
              setState(() => _isLogoHovered = false);
              _removeTooltip();
            },
            child: GestureDetector(
             
              onTap: widget.isCollapsed ? widget.onToggle : null,
              child: SizedBox(
                width: 22,
                height: 22,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: showToggleIcon
                      ? SidebarGlyphIcon(
                          key: const ValueKey('toggle-icon'),
                          color: AppColors.textPurple,
                        )
                      : Image.asset(
                          'assets/images/app_logo.png',
                          key: const ValueKey('logo-image'),
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
          ),
          if (!widget.isCollapsed) ...[
            const SizedBox(width: 15),
            const Expanded(
              child: Text(
                "Medi-Queue",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

