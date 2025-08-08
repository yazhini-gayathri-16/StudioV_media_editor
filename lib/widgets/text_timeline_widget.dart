// lib/widgets/text_timeline_widget.dart

import 'package:flutter/material.dart';
import '../models/text_overlay_model.dart';

class TextTimelineWidget extends StatefulWidget {
  final TextOverlay textOverlay;
  final double pixelsPerSecond;
  final Function(Duration newStart, Duration newEnd) onDurationChanged;
  final VoidCallback onTap;
  final bool isSelected;
  // --- NEW: To allow for vertical stacking ---
  final double topPosition;

  const TextTimelineWidget({
    super.key,
    required this.textOverlay,
    required this.pixelsPerSecond,
    required this.onDurationChanged,
    required this.onTap,
    required this.isSelected,
    required this.topPosition,
  });

  @override
  State<TextTimelineWidget> createState() => _TextTimelineWidgetState();
}

class _TextTimelineWidgetState extends State<TextTimelineWidget> {
  // ... (keep _handleLeftTrim and _handleRightTrim methods exactly the same)
  void _handleLeftTrim(double deltaX) {
    final deltaMilliseconds = (deltaX * 1000 / widget.pixelsPerSecond).round();
    Duration newStartTime = widget.textOverlay.startTime + Duration(milliseconds: deltaMilliseconds);
    
    if (newStartTime.isNegative) newStartTime = Duration.zero;
    if (newStartTime >= widget.textOverlay.endTime - const Duration(milliseconds: 200)) {
      newStartTime = widget.textOverlay.endTime - const Duration(milliseconds: 200);
    }
    
    widget.onDurationChanged(newStartTime, widget.textOverlay.endTime);
  }

  void _handleRightTrim(double deltaX) {
    final deltaMilliseconds = (deltaX * 1000 / widget.pixelsPerSecond).round();
    Duration newEndTime = widget.textOverlay.endTime + Duration(milliseconds: deltaMilliseconds);

    if (newEndTime <= widget.textOverlay.startTime + const Duration(milliseconds: 200)) {
      newEndTime = widget.textOverlay.startTime + const Duration(milliseconds: 200);
    }

    widget.onDurationChanged(widget.textOverlay.startTime, newEndTime);
  }

  @override
  Widget build(BuildContext context) {
    final leftPosition = widget.textOverlay.startTime.inMilliseconds / 1000.0 * widget.pixelsPerSecond;
    final width = (widget.textOverlay.endTime - widget.textOverlay.startTime).inMilliseconds / 1000.0 * widget.pixelsPerSecond;

    return Positioned(
      left: leftPosition,
      // --- MODIFIED: Use the passed-in top position ---
      top: widget.topPosition,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: width < 12 ? 12 : width,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isSelected ? Colors.yellow : Colors.green,
              width: 2,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Text(
                  widget.textOverlay.text,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Positioned(
                left: -6,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (details) => _handleLeftTrim(details.delta.dx),
                  child: Container(
                    width: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (details) => _handleRightTrim(details.delta.dx),
                  child: Container(
                    width: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}