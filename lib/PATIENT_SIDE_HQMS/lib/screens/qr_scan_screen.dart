import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/scan_frame.dart';
import '../widgets/how_to_scan_card.dart';
import 'registration_screen.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final String? code = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (code != null) _proceedToRegistration(code);
  }

  void _proceedToRegistration(String queueId) {
    if (_hasScanned) return;
    setState(() => _hasScanned = true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrationScreen(scannedQueueId: queueId),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Scan QR Code',

                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Scan the QR code provided at the reception to join the queue.',
                      
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Real camera
                  GestureDetector(
                    onTap: () => _proceedToRegistration('DEMO-QUEUE-001'),
                    child: ScanFrame(
                      controller: _controller,
                      onDetect: _onDetect,
                      useDemoImage: false, // Real camera dikhega
                    ),
                  ),
                  const SizedBox(height: 20),

                  const HowToScanCard(),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This QR code is unique to this location. Do not share it with others.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textGrey,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
