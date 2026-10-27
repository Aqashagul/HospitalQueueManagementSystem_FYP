import 'dart:math';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:queue_management_system/core/app_color.dart';

const String _hospitalName = 'MediQueue';

class HospitalQrPage extends StatefulWidget {
  const HospitalQrPage({super.key});

  @override
  State<HospitalQrPage> createState() => _HospitalQrPageState();
}

class _HospitalQrPageState extends State<HospitalQrPage> {
  final DocumentReference<Map<String, dynamic>> _ref =
      FirebaseFirestore.instance.collection('hospital').doc('main');
  final GlobalKey _posterKey = GlobalKey();

  bool _busy = false;
  bool _creating = false;

  String _newSecret() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // First time: the hospital document does not exist yet.
  Future<void> _createIfMissing() async {
    if (_creating) return;
    _creating = true;
    try {
      await _ref.set({
        'name': _hospitalName,
        'qrSecret': _newSecret(),
        'qrVersion': 1,
        'qrUpdatedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      _creating = false;
    }
  }

  Future<void> _regenerate(int currentVersion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate QR code?'),
        content: const Text(
          'The old QR code will stop working immediately. '
          'You will need to print and replace the poster at reception.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _ref.update({
        'qrSecret': _newSecret(),
        'qrVersion': currentVersion + 1,
        'qrUpdatedAt': FieldValue.serverTimestamp(),
      });
      _snack('New QR code generated');
    } catch (_) {
      _snack('Could not regenerate. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    try {
      final boundary = _posterKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await FileSaver.instance.saveFile(
        name: 'mediqueue_hospital_qr',
        bytes: data.buffer.asUint8List(),
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
    } catch (_) {
      _snack('Could not download the QR code.');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.data!.exists) {
          _createIfMissing();
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!.data()!;
        final secret = data['qrSecret']?.toString() ?? '';
        final version = (data['qrVersion'] as int?) ?? 1;
        final payload = 'hqms://join?v=$version&s=$secret';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  // ---- Poster (this is what gets downloaded) ----
                  RepaintBoundary(
                    key: _posterKey,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      color: Colors.white,
                      child: Column(
                        children: [
                          Text(
                            _hospitalName,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Scan to join the queue',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 22),
                          QrImageView(
                            data: payload,
                            size: 280,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '1. Open the MediQueue app\n'
                            '2. Tap Scan QR and point at this code\n'
                            '3. Choose your doctor and get your token',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _download,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download PNG'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _regenerate(version),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Regenerate QR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'QR version $version. Regenerating makes the old printed '
                    'QR invalid.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}