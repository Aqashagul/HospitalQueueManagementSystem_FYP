import 'dart:async';
import 'package:flutter/material.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/widgets/premium_button.dart';
import '../utils/app_theme.dart';
import '../models/onboarding_data.dart';
import 'qr_scan_screen.dart';
import '../widgets/background_blobs.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentPage < onboardingItems.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0; // start again from 1st slide
      }
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _goToQrScan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QRScanScreen()));
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
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
            child: Column(
              children: [
                // Top-right Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20, top: 8),
                    child: TextButton(
                      onPressed: _goToQrScan,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // Swipeable slides
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: onboardingItems.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final item = onboardingItems[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            
                           
                            Image.asset(
                              item.imagePath,
                              height: 280,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                //If image fails to load, show fallback placeholder
                               
                                return Container(
                                  height: 240,
                                  width: 240,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: .08,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 60,
                                    color: AppColors.primary,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 36),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textGrey,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(onboardingItems.length, (index) {
                    final bool isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : const Color(0xFFE0D5F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),

                // Continue button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PremiumButton(
                    onPressed: _goToQrScan,
                    label: "Continue",
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
