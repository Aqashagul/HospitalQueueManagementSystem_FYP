import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppLoader extends StatelessWidget {
  final double size;
  const AppLoader({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/images/loading.json',
        width: size,
        height: size,
      ),
    );
  }
}