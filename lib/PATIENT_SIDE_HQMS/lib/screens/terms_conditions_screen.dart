import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Terms & Conditions',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),

                // Scrollable content card
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: .05),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last updated: September 2026',
                            style: TextStyle(fontSize: 12, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 20),

                          const _TermsSection(
                            number: '1',
                            title: 'Acceptance of Terms',
                            content:
                                'By accessing and using the Smart Queue Management System app, you agree to be '
                                'bound by these Terms and Conditions. If you do not agree with any part of these '
                                'terms, please do not use the app.',
                          ),
                          const _TermsSection(
                            number: '2',
                            title: 'Use of the App',
                            content:
                                'This app allows you to join a virtual queue by scanning a QR code and provide your '
                                'name and phone number for verification purposes. You agree to provide accurate '
                                'and truthful information at all times.',
                          ),
                          const _TermsSection(
                            number: '3',
                            title: 'Queue & Token System',
                            content:
                                'Your position in the queue and estimated waiting time are provided for guidance '
                                'only and may vary based on real-world conditions. The app does not guarantee '
                                'exact wait times or consultation availability.',
                          ),
                          const _TermsSection(
                            number: '4',
                            title: 'Privacy & Data',
                            content:
                                'Your name and phone number are collected solely to verify your identity and '
                                'manage your queue position. We do not share your personal information with '
                                'third parties without your consent.',
                          ),
                          const _TermsSection(
                            number: '5',
                            title: 'User Responsibilities',
                            content:
                                'You are responsible for arriving at the designated location on time once notified. '
                                'The app is not liable for missed appointments due to late arrival or failure to '
                                'monitor your queue status.',
                          ),
                          const _TermsSection(
                            number: '6',
                            title: 'Changes to Terms',
                            content:
                                'These Terms and Conditions may be updated from time to time. Continued use of '
                                'the app after any changes constitutes your acceptance of the revised terms.',
                          ),

                          const SizedBox(height: 8),
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
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Questions about these terms? Contact us at support@smartqueue.com',
                                    style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String number;
  final String title;
  final String content;

  const _TermsSection({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              content,
              style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}