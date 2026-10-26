import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

class TrackQueueTabScreen extends StatelessWidget {
  const TrackQueueTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: Text('Track Queue Screen')),
      bottomNavigationBar: AppBottomNav(currentIndex: 2),
    );
  }
}