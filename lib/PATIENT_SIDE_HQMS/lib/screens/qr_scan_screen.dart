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
  bool _isTorchOn = false;

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

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: const Text(
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
                    child: const Text(
                    'Scan the QR code provided at the reception to join the queue.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                      height: 1.5,
                    ),
                  ),
                  ),
                  
                  const SizedBox(height: 20),

                  // Scan frame with demo QR image + animated scan line
                  GestureDetector(
                    onTap: () => _proceedToRegistration('DEMO-QUEUE-001'),
                    child: ScanFrame(
                    controller: _controller,
                    onDetect: _onDetect,
                    useDemoImage:
                        true, 
                  ),
                  ),
                  
                  const SizedBox(height: 20),

                  // Flashlight toggle 
                  Center(
                    child: TextButton.icon(
                      onPressed: _toggleTorch,
                      style: TextButton.styleFrom(
                        backgroundColor: _isTorchOn
                            ? Colors.green.withValues(alpha: .1)
                            : Colors.red.withValues(alpha: .08),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: _isTorchOn ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      label: Text(
                        _isTorchOn
                            ? 'Turn off flashlight'
                            : 'Tap to turn on flashlight',
                        style: TextStyle(
                          color: _isTorchOn
                              ? Colors.green.shade700
                              : Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Premium "How to scan" card
                  const HowToScanCard(),
                  
                  const SizedBox(height: 16),

               ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
