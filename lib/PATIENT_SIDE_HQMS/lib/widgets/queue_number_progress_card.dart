import 'package:flutter/material.dart';
import '../utils/app_theme.dart';


class QueueNumberProgress extends StatefulWidget {
  final int totalInQueue;
  final int currentPosition;

  const QueueNumberProgress({
    super.key,
    required this.totalInQueue,
    required this.currentPosition,
  });

  @override
  State<QueueNumberProgress> createState() => _QueueNumberProgressState();
}

class _QueueNumberProgressState extends State<QueueNumberProgress> {
  final ScrollController _scrollController = ScrollController();
  static const double _itemWidth = 46;
  static const double _dotAreaHeight = 34;

  @override
  void didUpdateWidget(covariant QueueNumberProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition) {
      _scrollToCurrentPosition();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPosition());
  }

  void _scrollToCurrentPosition() {
    if (!_scrollController.hasClients) return;
    final double targetOffset = (widget.currentPosition - 1) * _itemWidth - 100;
    _scrollController.animateTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double totalTrackWidth = (widget.totalInQueue - 1) * _itemWidth;
    final double filledWidth = (widget.currentPosition - 1) * _itemWidth;
    const double lineTop = (_dotAreaHeight - 3) / 2; 

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'QUEUE PROGRESS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: .5),
                  ),
                ],
              ),
              Text(
                'Total in Queue: ${widget.totalInQueue}',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 68,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: widget.totalInQueue * _itemWidth,
                height: 68,
                child: Stack(
                  children: [
                    // Background line 
                    Positioned(
                      left: _itemWidth / 2,
                      top: lineTop,
                      child: Container(
                        width: totalTrackWidth,
                        height: 3,
                        decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                   
                    Positioned(
                      left: _itemWidth / 2,
                      top: lineTop,
                      child: Container(
                        width: filledWidth.clamp(0, totalTrackWidth),
                        height: 3,
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),

                    
                    Row(
                      children: List.generate(widget.totalInQueue, (i) {
                        final int number = i + 1;
                        final bool isPassed = number < widget.currentPosition;
                        final bool isCurrent = number == widget.currentPosition;
                        final bool isFilled = isPassed || isCurrent;

                        return SizedBox(
                          width: _itemWidth,
                          height: 68,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              SizedBox(
                                height: _dotAreaHeight,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    width: isCurrent ? 34 : 22,
                                    height: isCurrent ? 34 : 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: isFilled
                                          ? const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd])
                                          : null,
                                      color: isFilled ? null : AppColors.cardBorder,
                                      boxShadow: isCurrent
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary.withValues(alpha: .4),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: isCurrent
                                        ? Center(
                                            child: Text(
                                              '$number',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: _dotAreaHeight + 8,
                                child: isCurrent
                                    ? const SizedBox.shrink()
                                    : Text(
                                        '$number',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isFilled ? AppColors.primary : AppColors.textGrey,
                                        ),
                                      ),
                              ),
                              if (isCurrent)
                                Positioned(
                                  top: _dotAreaHeight + 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}