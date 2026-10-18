import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:queue_management_system/notification_service.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/premium_button.dart';
import '../widgets/step_progress_indicator.dart';
import 'verification_success_screen.dart';


class OtpScreen extends StatefulWidget {
  final String phoneNumber; // full number, e.g. +923001234567
  final String userName;
  final String verificationId;
  final int? resendToken;
  final String queueId;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.userName,
    required this.verificationId,
    required this.resendToken,
    required this.queueId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _timer;
  int _secondsLeft = 30;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;

  late String _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _secondsLeft = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft == 0) {
        timer.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _resendOtp() async {
    if (_isResending) return;
    _isResending = true;

    _otpController.clear();
    setState(() => _errorText = null);
    _startResendTimer();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          if (!mounted) return;
          _timer?.cancel();
          setState(() {
            _canResend = true;
            _errorText = e.code == 'too-many-requests'
                ? 'Too many attempts. Please try again later.'
                : (e.message ?? 'Could not resend OTP. Please try again.');
          });
        },
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          _showSnack('OTP resent successfully');
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = 'Could not resend OTP. Please try again.');
    } finally {
      _isResending = false;
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return; // onCompleted + button se double call na ho

    if (_otpController.text.length != 6) {
      setState(() => _errorText = 'Please enter the full 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user!;

      await user.updateDisplayName(widget.userName);

      final db = FirebaseFirestore.instance;

      // Patient profile (sirf pehli dafa banta hai)
      final userRef = db.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        await userRef.set({
          'name': widget.userName,
          'phone': user.phoneNumber,
          'role': 'patient',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

        try {
        await NotificationService.saveToken();
      }  catch (e) {
  debugPrint('saveToken failed: $e');
}

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerificationSuccessScreen(userName: widget.userName),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
     setState(() {
  switch (e.code) {
    case 'invalid-verification-code':
      _errorText = 'Invalid OTP. Please try again.';
      break;
    case 'session-expired':
      _errorText = 'OTP has expired. Please request a new one.';
      break;
    case 'too-many-requests':
      _errorText = 'Too many attempts. Please try again later.';
      break;
    case 'network-request-failed':
      _errorText = 'Please check your internet connection.';
      break;
    default:
      _errorText = e.message ?? 'Verification failed. Please try again.';
  }
});
    } on FirebaseException catch (e) {
      // Firestore error (rules / network)
      if (!mounted) return;
      setState(() => _errorText = 'Failed to save data: ${e.message ?? e.code}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
                  const SizedBox(height: 8),

                  // Step 2/3 indicator
                  const StepProgressIndicator(currentStep: 2),
                  const SizedBox(height: 28),

                  // Icon badge + heading
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.gradientStart,
                              AppColors.gradientEnd,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: .3),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Verify Your Number',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: 32,
                        margin: const EdgeInsets.only(top: 2, right: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.gradientStart,
                              AppColors.gradientEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'We sent a 6-digit code to ${widget.phoneNumber}',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textGrey,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // White card with OTP boxes
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        PinCodeTextField(
                          appContext: context,
                          length: 6,
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          animationType: AnimationType.scale,
                          animationDuration: const Duration(milliseconds: 200),
                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.box,
                            borderRadius: BorderRadius.circular(14),
                            fieldHeight: 48,
                            fieldWidth: 44,
                            activeColor: AppColors.primary,
                            selectedColor: AppColors.primary,
                            inactiveColor: AppColors.cardBorder,
                            activeFillColor: AppColors.background,
                            selectedFillColor: Colors.white,
                            inactiveFillColor: AppColors.background,
                            borderWidth: 1.5,
                          ),
                          enableActiveFill: true,
                          onChanged: (value) {
                            if (_errorText != null) {
                              setState(() => _errorText = null);
                            }
                          },
                          onCompleted: (value) => _verifyOtp(),
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Resend row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Didn't receive the code? ",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textGrey,
                              ),
                            ),
                            GestureDetector(
                              onTap: _canResend ? _resendOtp : null,
                              child: Text(
                                _canResend
                                    ? 'Resend OTP'
                                    : 'Resend in ${_secondsLeft}s',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _canResend
                                      ? AppColors.primary
                                      : AppColors.textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _isVerifying
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : PremiumButton(
                          label: 'Verify OTP',
                          onPressed: _verifyOtp,
                        ),
                  const SizedBox(height: 20),

                  // Security note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(18),
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
                            'This code will expire in a few minutes. Do not share it with anyone.',
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