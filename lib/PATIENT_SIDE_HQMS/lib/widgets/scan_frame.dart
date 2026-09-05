import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/app_theme.dart';
import 'corner_brackets.dart';
import 'scanning_line.dart';

class ScanFrame extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool useDemoImage;

  const ScanFrame({
    super.key,
    required this.controller,
    required this.onDetect,
    this.useDemoImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          children: [
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // QR image
                    Positioned.fill(
                      child: useDemoImage
                          ? Padding(
                              padding: const EdgeInsets.all(28),
                              child: Image.asset(
                                'assets/images/PATIENT_SIDE images/icons/images/demo_qr.png',
                                fit: BoxFit.contain,
                              ),
                            )
                          : MobileScanner(controller: controller, onDetect: onDetect),
                    ),


                    // Scanning line 
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: const ScanningLine(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            
            const Positioned.fill(child: CornerBrackets()),
          ],
        ),
      ),
    );
  }
}