import 'package:flutter/material.dart';

class TimelineRuler extends StatelessWidget {
  final Duration totalDuration;
  // --- FIX: Use pixelsPerSecond instead of a fixed width ---
  final double pixelsPerSecond;

  const TimelineRuler({
    super.key,
    required this.totalDuration,
    required this.pixelsPerSecond,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TimelineRulerPainter(
        totalDuration: totalDuration,
        pixelsPerSecond: pixelsPerSecond,
      ),
    );
  }
}

class TimelineRulerPainter extends CustomPainter {
  final Duration totalDuration;
  final double pixelsPerSecond;

  TimelineRulerPainter({
    required this.totalDuration,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final majorTickPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1;

    final minorTickPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 0.5;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final totalSeconds = totalDuration.inSeconds;
    if (totalSeconds == 0) return;

    // --- FIX: Improved interval logic based on your screenshot ---
    int intervalSeconds;
    int minorTickInterval;
    if (totalSeconds <= 15) {
      intervalSeconds = 2; // Every 2 seconds
      minorTickInterval = 1;
    } else if (totalSeconds <= 60) {
      intervalSeconds = 5; // Every 5 seconds
      minorTickInterval = 1;
    } else {
      intervalSeconds = 10; // Every 10 seconds
      minorTickInterval = 5;
    }

    // Draw ticks and labels
    for (int s = 0; s <= totalSeconds; s++) {
      final x = s * pixelsPerSecond;
      
      // Draw major ticks with labels
      if (s % intervalSeconds == 0) {
        canvas.drawLine(Offset(x, size.height - 15), Offset(x, size.height), majorTickPaint);
        
        final timeText = _formatTime(Duration(seconds: s));
        textPainter.text = TextSpan(
          text: timeText,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, 0));
      } 
      // Draw minor ticks
      else if (s % minorTickInterval == 0) {
        canvas.drawLine(Offset(x, size.height - 8), Offset(x, size.height), minorTickPaint);
      }
    }
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant TimelineRulerPainter oldDelegate) {
    // Repaint only if duration or scale changes
    return oldDelegate.totalDuration != totalDuration || oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }
}