import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// The loading animation shown while data is coming from Firebase.
///
/// On web, this Lottie file crashes (Stack Overflow in lazy_path.dart), so a
/// normal spinner is shown there. On mobile the Lottie animation plays.
class LoadingAnimation extends StatelessWidget {
  // Size of the animation (width and height).
  final double size;

  // Optional small text under the animation, e.g. "Loading doctors...".
  final String? message;

  // How far to push the animation down from the center. Increase to move
  // it lower, decrease (or 0) to bring it back to the center.
  final double topOffset;

  const LoadingAnimation({
    super.key,
    this.size = 110, // was 140 — make smaller/bigger here
    this.message,
    this.topOffset = 40,
  });

  // Path of the Lottie json file you downloaded.
  static const String assetPath = 'assets/images/loading.json';

  Widget _spinner() {
    return SizedBox(
      width: size * 0.4,
      height: size * 0.4,
      child: const CircularProgressIndicator(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: topOffset),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kIsWeb)
            _spinner()
          else
            Lottie.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) => _spinner(),
            ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
      ),
    );
  }
}