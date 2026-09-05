import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class StepProgressIndicator extends StatelessWidget {
  final int currentStep; // 1, 2, ya 3
  final List<String> labels;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    this.labels = const ['Your Info', 'Verify OTP', 'Join Queue'],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length * 2 - 1, (index) {
        
        
        if (index.isEven) {
          final int stepNumber = (index ~/ 2) + 1;
          final bool isActive = stepNumber == currentStep;
          final bool isCompleted = stepNumber < currentStep;

          return Expanded(
            flex: 0,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: (isActive || isCompleted)
                        ? const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd])
                        : null,
                    color: (isActive || isCompleted) ? null : Colors.white,
                    border: Border.all(
                      color: (isActive || isCompleted) ? Colors.transparent : AppColors.cardBorder,
                      width: 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: .35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '$stepNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isActive ? Colors.white : AppColors.textGrey,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[stepNumber - 1],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppColors.primary : AppColors.textGrey,
                  ),
                ),
              ],
            ),
          );
        } else {
          // Connecting line between circles
          final int leftStep = (index ~/ 2) + 1;
          final bool lineActive = leftStep < currentStep;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 22),
              height: 2,
              color: lineActive ? AppColors.gradientEnd : AppColors.cardBorder,
            ),
          );
        }
      }),
    );
  }
}