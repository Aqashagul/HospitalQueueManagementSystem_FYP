
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/models/doctor.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/payment_service.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/track_queue_screen.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/widgets/background_blobs.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/widgets/premium_button.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:shared_preferences/shared_preferences.dart';



/// Shown right after the patient taps "Join Queue".
///
/// Pending   -> "Pay at the reception" (or "waiting for approval" for an
///              emergency request), with a countdown.
/// Paid/Accepted -> the token is created automatically and the tracking
///              screen opens.
/// Rejected / Expired / Cancelled -> a clear message and a Back button.
class PaymentPendingScreen extends StatefulWidget {
  final Doctor doctor;
  final String paymentId;

  const PaymentPendingScreen({
    super.key,
    required this.doctor,
    required this.paymentId,
  });

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen> {
  final PaymentService _payments = PaymentService();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _ticker; // updates the countdown every second

  Map<String, dynamic>? _data;
  bool _loaded = false;

  bool _issuing = false; // the token is being created
  String? _error; // a readable error, if creating the token failed
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _sub = _payments.watchPayment(widget.paymentId).listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _data = snap.data();
          _loaded = true;
        });
        _react();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loaded = true;
          _error = 'Could not load your request. Please check your internet.';
        });
      },
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String get _status => PaymentService.effectiveStatus(_data);
  bool get _isEmergency => _data?['type'] == 'emergency';

  // Reacts to a status change: Paid / Accepted creates the token.
  void _react() {
    final status = _status;
    if ((status == 'Paid' || status == 'Accepted') && !_issuing) {
      _issueToken();
    } else if (status == 'Used') {
      // The token already exists (for example the screen was reopened).
      final entryId = _data?['entryId']?.toString();
      if (entryId != null && entryId.isNotEmpty) _openTracking(entryId);
    }
  }

  Future<void> _issueToken() async {
    setState(() {
      _issuing = true;
      _error = null;
    });
    try {
      final result = await _payments.issueToken(widget.doctor, widget.paymentId);
      if (!mounted) return;
      _openTracking(result.entryId);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _issuing = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _issuing = false;
        _error = 'Could not create your token. Please try again.';
      });
    }
  }

  Future<void> _openTracking(String entryId) async {
    _sub?.cancel();
    _ticker?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_entry_id', entryId);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            TrackQueueScreen(doctor: widget.doctor, entryId: entryId),
      ),
    );
  }

  Future<void> _cancelRequest() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      await _payments.cancel(widget.paymentId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not cancel the request. Please try again.'),
        ),
      );
    }
  }

  // Minutes and seconds left for a pending request, like "24:15".
  String? get _timeLeft {
    final t = _data?['createdAt'];
    if (t is! Timestamp) return null;
    final end = t.toDate().add(
      const Duration(minutes: PaymentService.requestValidMinutes),
    );
    final left = end.difference(DateTime.now());
    if (left.isNegative) return '00:00';
    final m = left.inMinutes.toString().padLeft(2, '0');
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // A short code the cashier can read out: the first 6 characters of the id.
  String get _code => widget.paymentId.substring(0, 6).toUpperCase();

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: !_loaded
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _data == null
                ? _buildMessage(
                    icon: Icons.error_outline_rounded,
                    color: AppColors.error,
                    title: 'Request not found',
                    text: 'This payment request no longer exists.',
                    showBack: true,
                  )
                : _buildForStatus(),
          ),
        ],
      ),
    );
  }

  Widget _buildForStatus() {
    final status = _status;

    // The token is being created (or creating it failed).
    if (status == 'Paid' || status == 'Accepted' || status == 'Used') {
      if (_error != null) {
        return _buildMessage(
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          title: 'Could not create your token',
          text: _error!,
          primaryLabel: 'Try Again',
          onPrimary: _issuing ? null : _issueToken,
          showBack: true,
        );
      }
      return _buildBusy(
        _isEmergency
            ? 'Your request was accepted.\nCreating your token...'
            : 'Payment confirmed.\nCreating your token...',
      );
    }

    switch (status) {
      case 'Rejected':
        return _buildMessage(
          icon: Icons.block_rounded,
          color: AppColors.error,
          title: 'Request not accepted',
          text:
              'The reception did not accept this request. '
              'Please speak to the reception desk.',
          showBack: true,
        );
      case 'Expired':
        return _buildMessage(
          icon: Icons.timer_off_outlined,
          color: Colors.orange.shade800,
          title: 'Request expired',
          text:
              'Your request expired because it was not confirmed in time. '
              'You can send a new request.',
          showBack: true,
        );
      case 'Cancelled':
        return _buildMessage(
          icon: Icons.cancel_outlined,
          color: Colors.grey.shade600,
          title: 'Request cancelled',
          text: 'You cancelled this request.',
          showBack: true,
        );
      case 'Refunded':
        return _buildMessage(
          icon: Icons.undo_rounded,
          color: Colors.grey.shade600,
          title: 'Payment refunded',
          text: 'This payment was refunded to you at the reception.',
          showBack: true,
        );
      default:
        return _buildPending();
    }
  }

  // The main screen: waiting for the cash payment / the emergency approval.
  Widget _buildPending() {
    final bool emergency = _isEmergency;
    final int amount = (_data?['amount'] as num?)?.toInt() ?? 0;
    final String name = _data?['patientName']?.toString() ?? '';
    final String phone = _data?['phone']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.arrow_back, color: AppColors.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (emergency ? AppColors.error : AppColors.primary)
                    .withValues(alpha: .12),
              ),
              child: Icon(
                emergency
                    ? Icons.emergency_outlined
                    : Icons.payments_outlined,
                size: 42,
                color: emergency ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 18),

          Center(
            child: Text(
              emergency ? 'Waiting for approval' : 'Pay at the reception',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            emergency
                ? 'Your emergency request was sent to the reception. '
                      'Please go to the reception desk. Your token will be '
                      'created as soon as the request is accepted.'
                : 'Please pay your consultation fee in cash at the hospital '
                      'reception. Your token will be created automatically as '
                      'soon as the payment is confirmed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 22),

          // Details card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary),
            ),
            child: Column(
              children: [
                _detailRow('Doctor', widget.doctor.name),
                _detailRow('Department', widget.doctor.departmentName),
                _detailRow('Patient', name),
                if (phone.isNotEmpty) _detailRow('Phone', phone),
                _detailRow('Request code', '#$_code'),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      emergency ? 'Fee' : 'Amount to pay',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ),
                    Text(
                      emergency ? 'No fee' : PaymentService.money(amount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Countdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _timeLeft == null
                        ? 'This request is valid for '
                              '${PaymentService.requestValidMinutes} minutes.'
                        : 'This request expires in $_timeLeft',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _cancelling ? null : _cancelRequest,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(
                  color: AppColors.error.withValues(alpha: .4),
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _cancelling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cancel Request'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13.5, color: AppColors.textGrey),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusy(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    String? primaryLabel,
    VoidCallback? onPrimary,
    bool showBack = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .12),
              ),
              child: Icon(icon, size: 42, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 24),
            if (primaryLabel != null) ...[
              SizedBox(
                width: double.infinity,
                child: Opacity(
                  opacity: onPrimary == null ? 0.5 : 1.0,
                  child: IgnorePointer(
                    ignoring: onPrimary == null,
                    child: PremiumButton(
                      label: primaryLabel,
                      onPressed: onPrimary ?? () {},
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (showBack)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: .35),
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}