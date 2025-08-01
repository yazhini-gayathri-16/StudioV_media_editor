import 'package:flutter/material.dart';

class TimelineRuler extends StatelessWidget {
  final Duration totalDuration;
  final double timelineWidth;
  final ScrollController? scrollController;

  const TimelineRuler({
    Key? key,
    required this.totalDuration,
    required this.timelineWidth,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: timelineWidth,
      child: CustomPaint(
        painter: TimelineRulerPainter(
          totalDuration: totalDuration,
          timelineWidth: timelineWidth,
        ),
      ),
    );
  }
}

class TimelineRulerPainter extends CustomPainter {
  final Duration totalDuration;
  final double timelineWidth;

  TimelineRulerPainter({
    required this.totalDuration,
    required this.timelineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Calculate interval based on total duration
    int intervalSeconds;
    if (totalDuration.inSeconds <= 30) {
      intervalSeconds = 2; // Every 2 seconds for short videos
    } else if (totalDuration.inSeconds <= 120) {
      intervalSeconds = 5; // Every 5 seconds for medium videos
    } else {
      intervalSeconds = 10; // Every 10 seconds for long videos
    }

    final totalSeconds = totalDuration.inSeconds;
    final pixelsPerSecond = timelineWidth / totalSeconds;

    // Draw major ticks and labels
    for (int i = 0; i <= totalSeconds; i += intervalSeconds) {
      final x = i * pixelsPerSecond;
      
      // Draw tick mark
      canvas.drawLine(
        Offset(x, size.height - 15),
        Offset(x, size.height),
        paint,
      );

      // Draw time label
      final timeText = _formatTime(Duration(seconds: i));
      textPainter.text = TextSpan(
        text: timeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
      );
      textPainter.layout();
      
      // Center the text over the tick mark
      final textX = x - (textPainter.width / 2);
      textPainter.paint(canvas, Offset(textX, 0));
    }

    // Draw minor ticks (every second for short intervals)
    if (intervalSeconds <= 5) {
      final minorPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 0.5;

      for (int i = 0; i <= totalSeconds; i++) {
        if (i % intervalSeconds != 0) { // Skip major ticks
          final x = i * pixelsPerSecond;
          canvas.drawLine(
            Offset(x, size.height - 8),
            Offset(x, size.height),
            minorPaint,
          );
        }
      }
    }
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '00:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

