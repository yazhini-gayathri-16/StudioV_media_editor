import 'package:flutter/material.dart';

class TimelineProgressIndicator extends StatelessWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final double timelineWidth;

  const TimelineProgressIndicator({
    Key? key,
    required this.currentPosition,
    required this.totalDuration,
    required this.timelineWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (totalDuration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    final progress = currentPosition.inMilliseconds / totalDuration.inMilliseconds;
    final indicatorPosition = (progress * timelineWidth).clamp(0.0, timelineWidth);

    return Positioned(
      left: indicatorPosition,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        decoration: BoxDecoration(
          color: Colors.red,
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(
                width: 2,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
