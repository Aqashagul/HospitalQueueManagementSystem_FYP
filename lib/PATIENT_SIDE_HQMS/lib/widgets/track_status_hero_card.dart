import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Big top card. Three states: waiting, your turn, completed.
class TrackStatusHeroCard extends StatefulWidget {
  final bool myTurn;
  final bool done;
  final int position;
  final int ahead;

  const TrackStatusHeroCard({
    super.key,
    required this.myTurn,
    required this.done,
    required this.position,
    required this.ahead,
  });

  @override
  State<TrackStatusHeroCard> createState() => _TrackStatusHeroCardState();
}

class _TrackStatusHeroCardState extends State<TrackStatusHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _turnContent() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) => Transform.scale(
            scale: 1 + _pulse.value * .08,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .2),
                border: Border.all(
                  color: Colors.white
                      .withValues(alpha: .35 * (1 - _pulse.value) + .1),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          "It's Your Turn!",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Please proceed to the doctor's room now",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.white.withValues(alpha: .9),
          ),
        ),
      ],
    );
  }

  Widget _doneContent() {
    return Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .2),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
        ),
        const SizedBox(height: 14),
        const Text(
          'Consultation Completed',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Thank you for visiting. Take care!',
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.white.withValues(alpha: .9),
          ),
        ),
      ],
    );
  }

  Widget _waitingContent() {
    final ahead = widget.ahead;
    return Column(
      children: [
        Text(
          'YOUR POSITION',
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: .85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '#${widget.position}',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            ahead == 0
                ? 'You are next!'
                : '$ahead ${ahead == 1 ? 'patient' : 'patients'} ahead of you',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool turn = widget.myTurn;

    final List<Color> colors = turn
        ? const [Color(0xFF43A878), Color(0xFF1F8A5B)]
        : const [AppColors.gradientStart, AppColors.gradientEnd];
    final Color shadow = turn ? const Color(0xFF1F8A5B) : AppColors.primary;

    final Widget content = turn
        ? _turnContent()
        : (widget.done ? _doneContent() : _waitingContent());

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey('${widget.myTurn}-${widget.done}'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: shadow.withValues(alpha: .3),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        // TODO:Lottie animation
        child: content,
      ),
    );
  }
}