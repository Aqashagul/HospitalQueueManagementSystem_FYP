import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/department_list_screen.dart';
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

class _QRScanScreenState extends State<QRScanScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController();
  final ImagePicker _picker = ImagePicker();

  bool _busy = false; // a scan is being verified
  bool _done = false; // verified, navigating away
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // Camera off in background, back on when the app returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_done) _controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _controller.stop();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Scanning + verification
  // ---------------------------------------------------------------------------

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _done) return;
    final String? code =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null || code.isEmpty) return;
    _verify(code);
  }

  Future<void> _pickFromGallery() async {
    if (_busy || _done) return;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final capture = await _controller.analyzeImage(file.path);
      final String? code = (capture != null && capture.barcodes.isNotEmpty)
          ? capture.barcodes.first.rawValue
          : null;
      if (code == null || code.isEmpty) {
        _fail('No QR code found in that image.');
        return;
      }
      _verify(code);
    } catch (_) {
      _fail('Could not read that image. Please try again.');
    }
  }

  Future<void> _verify(String raw) async {
    if (_busy || _done) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    // 1. Format check
    final Uri? uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'hqms' ||
        uri.host != 'join' ||
        (uri.queryParameters['s'] ?? '').isEmpty) {
      _fail('Invalid QR code. Please scan the hospital QR at reception.');
      return;
    }
    final String scannedSecret = uri.queryParameters['s']!;
    final int? scannedVersion = int.tryParse(uri.queryParameters['v'] ?? '');

    // 2. Compare with the hospital document
    try {
      final snap = await FirebaseFirestore.instance
          .collection('hospital')
          .doc('main')
          .get()
          .timeout(const Duration(seconds: 12));

      if (!snap.exists) {
        _fail('The hospital is not set up yet. Please contact reception.');
        return;
      }

      final data = snap.data()!;
      final String realSecret = data['qrSecret']?.toString() ?? '';
      final int realVersion = (data['qrVersion'] as int?) ?? 1;

      if (scannedSecret != realSecret) {
        if (scannedVersion != null && scannedVersion < realVersion) {
          _fail('This QR code is outdated. Please scan the new one at reception.');
        } else {
          _fail('Invalid QR code. Please scan the hospital QR at reception.');
        }
        return;
      }

      // 3. Verified
      await _onVerified();
    } on FirebaseException catch (e) {
      _fail(e.code == 'unavailable'
          ? 'No internet connection. Please check and try again.'
          : 'Could not verify the QR code. Please try again.');
    } catch (_) {
      _fail('Could not verify the QR code. Check your internet and try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => _error = message);
    // Allow scanning again after a short pause
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_done) setState(() => _busy = false);
    });
  }

  Future<void> _onVerified() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _done = true;
      _error = null;
    });
    await _controller.stop();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _proceed();
  }

  // Patients who already verified their phone number go straight to the
  // departments; new patients register first.
  void _proceed() {
    final bool alreadyVerified = FirebaseAuth.instance.currentUser != null;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => alreadyVerified
            ? const DepartmentListScreen()
            : const RegistrationScreen(scannedQueueId: 'main'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

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
                  const Center(
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Camera, or the permission card if access was denied
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, _) {
                      final denied = state.error?.errorCode ==
                          MobileScannerErrorCode.permissionDenied;
                      if (denied) return const _PermissionCard();
                      return ScanFrame(
                        controller: _controller,
                        onDetect: _onDetect,
                        useDemoImage: false,
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Status: verifying / verified / error
                  _statusBanner(),

                  // Torch + gallery
                  Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (context, state, _) {
                            final on = state.torchState == TorchState.on;
                            return _ActionButton(
                              icon: on
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              label: on ? 'Flash on' : 'Flash',
                              onTap: (_done || !state.hasCameraPermission)
                                  ? null
                                  : () => _controller.toggleTorch(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.photo_library_outlined,
                          label: 'From gallery',
                          onTap: (_busy || _done) ? null : _pickFromGallery,
                        ),
                      ),
                    ],
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

  Widget _statusBanner() {
    if (_done) {
      return _Banner(
        color: Colors.green.shade700,
        icon: Icons.verified_rounded,
        text: 'Hospital verified',
      );
    }
    if (_error != null) {
      return _Banner(
        color: AppColors.error,
        icon: Icons.error_outline_rounded,
        text: _error!,
      );
    }
    if (_busy) {
      return _Banner(
        color: AppColors.primary,
        icon: Icons.hourglass_top_rounded,
        text: 'Verifying QR code...',
        loading: true,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final bool loading;
  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
                )
              : Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: .1),
            ),
            child: const Icon(Icons.no_photography_outlined,
                color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 14),
          const Text(
            'Camera access needed',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Allow camera access to scan the hospital QR code. '
            'You can also choose a QR image from your gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: openAppSettings,
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Open Settings'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}