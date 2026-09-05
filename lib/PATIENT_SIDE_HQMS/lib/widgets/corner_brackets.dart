import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Purple corner brackets of scan 
class CornerBrackets extends StatelessWidget {
  const CornerBrackets({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        _Corner(top: true, left: true),
        _Corner(top: true, left: false),
        _Corner(top: false, left: true),
        _Corner(top: false, left: false),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  final bool top;
  final bool left;
  const _Corner({required this.top, required this.left});

  static const double _length = 30;
  static const double _thickness = 4;
  static const Color _color = AppColors.gradientEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: SizedBox(
        width: _length,
        height: _length,
        child: Stack(
          children: [
            Positioned(
              top: top ? 0 : null,
              bottom: top ? null : 0,
              left: left ? 0 : null,
              right: left ? null : 0,
              child: Container(
                width: _length,
                height: _thickness,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              top: top ? 0 : null,
              bottom: top ? null : 0,
              left: left ? 0 : null,
              right: left ? null : 0,
              child: Container(
                width: _thickness,
                height: _length,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}