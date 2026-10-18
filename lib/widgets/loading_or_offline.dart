import 'dart:async';

import 'package:flutter/material.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/widgets/loading_animation.dart';

// >>> KEEP YOUR OTHER EXISTING IMPORTS HERE <<<
// (AppdataStore, and LoadingAnimation from loading_animation.dart,
//  from the same paths your other files use.)

/// Shown instead of a page's content while data is still coming from
/// Firebase. It plays the loading animation, and if nothing has arrived after
/// [timeout] (usually no internet) it shows a message and a Retry button.
///
/// This widget only exists while loading. As soon as the data arrives the
/// page replaces it with the real content, even if the message was already
/// showing, so nothing else has to be done when the internet comes back.
class LoadingOrOffline extends StatefulWidget {
  final String message;
  final Duration timeout;

  const LoadingOrOffline({
    super.key,
    this.message = 'Loading...',
    this.timeout = const Duration(seconds: 10),
  });

  @override
  State<LoadingOrOffline> createState() => _LoadingOrOfflineState();
}

class _LoadingOrOfflineState extends State<LoadingOrOffline> {
  Timer? _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Connects to Firebase again, and shows the animation for another round.
  Future<void> _retry() async {
    setState(() => _timedOut = false);
    _startTimer();
    await AppdataStore().stopListening();
    AppdataStore().startListening();
  }

  @override
  Widget build(BuildContext context) {
    if (!_timedOut) {
      return LoadingAnimation(message: widget.message);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 52, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            const Text(
              'Taking longer than usual',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Please check your internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}