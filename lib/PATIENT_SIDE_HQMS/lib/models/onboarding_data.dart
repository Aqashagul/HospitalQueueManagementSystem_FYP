

class OnboardingItem {
  final String imagePath; 
  final String title;
  final String description;

  OnboardingItem({
    required this.imagePath,
    required this.title,
    required this.description,
  });
}

final List<OnboardingItem> onboardingItems = [
  OnboardingItem(
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/onboarding/slide1.png',
    title: 'Scan & Join',
    description: 'Simply scan the QR code at any counter\nto join the queue instantly.',
  ),
  OnboardingItem(
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/onboarding/slide2.png',
    title: 'No More Standing in Line',
    description: 'Join the queue remotely and wait\ncomfortably wherever you are.',
  ),
  OnboardingItem(
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/onboarding/slide3.png',
    title: 'Track in Real-Time',
    description: 'Get live updates on your position\nand know exactly when it\'s your turn.',
  ),
];