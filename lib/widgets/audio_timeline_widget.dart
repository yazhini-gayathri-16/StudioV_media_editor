import 'package:flutter/material.dart';
import '../models/audio_clip_model.dart';

class AudioTimelineWidget extends StatefulWidget {
  final AudioClip audioClip;
  final double pixelsPerSecond;
  final Function(Duration newStart, Duration newEnd) onDurationChanged;
  final VoidCallback onTap;
  final bool isSelected;
  final double topPosition;
  final Duration totalProjectDuration;

  const AudioTimelineWidget({
    super.key,
    required this.audioClip,
    required this.pixelsPerSecond,
    required this.onDurationChanged,
    required this.onTap,
    required this.isSelected,
    required this.topPosition,
    required this.totalProjectDuration, required Function(Duration dragDelta) onPositionChanged,
  });

  @override
  State<AudioTimelineWidget> createState() => _AudioTimelineWidgetState();
}

class _AudioTimelineWidgetState extends State<AudioTimelineWidget> {
  bool _isDraggingLeft = false;
  bool _isDraggingRight = false;
  bool _isDraggingMiddle = false;
  
  void _handleLeftTrim(double deltaX) {
    final deltaMilliseconds = (deltaX * 1000 / widget.pixelsPerSecond).round();
    Duration newStartTime = widget.audioClip.startTime + Duration(milliseconds: deltaMilliseconds);

    if (newStartTime.isNegative) newStartTime = Duration.zero;
    // Prevent start time from crossing the end time (with a minimum duration)
    if (newStartTime >= widget.audioClip.endTime - const Duration(milliseconds: 200)) {
      newStartTime = widget.audioClip.endTime - const Duration(milliseconds: 200);
    }

    widget.onDurationChanged(newStartTime, widget.audioClip.endTime);
  }

  void _handleRightTrim(double deltaX) {
    final deltaMilliseconds = (deltaX * 1000 / widget.pixelsPerSecond).round();
    Duration newEndTime = widget.audioClip.endTime + Duration(milliseconds: deltaMilliseconds);

    // Prevent end time from crossing the start time
    if (newEndTime <= widget.audioClip.startTime + const Duration(milliseconds: 200)) {
      newEndTime = widget.audioClip.startTime + const Duration(milliseconds: 200);
    }
    // Prevent end time from exceeding the project duration
    if (newEndTime > widget.totalProjectDuration) {
      newEndTime = widget.totalProjectDuration;
    }

    widget.onDurationChanged(widget.audioClip.startTime, newEndTime);
  }

  void _handleMiddleDrag(double deltaX) {
    final deltaMilliseconds = (deltaX * 1000 / widget.pixelsPerSecond).round();
    final clipDuration = widget.audioClip.duration;
    
    Duration newStartTime = widget.audioClip.startTime + Duration(milliseconds: deltaMilliseconds);
    
    if (newStartTime.isNegative) newStartTime = Duration.zero;
    
    Duration newEndTime = newStartTime + clipDuration;
    if (newEndTime > widget.totalProjectDuration) {
      newEndTime = widget.totalProjectDuration;
      newStartTime = newEndTime - clipDuration;
    }

    widget.onDurationChanged(newStartTime, newEndTime);
  }


  @override
  Widget build(BuildContext context) {
    final leftPosition = widget.audioClip.startTime.inMilliseconds / 1000.0 * widget.pixelsPerSecond;
    final width = widget.audioClip.duration.inMilliseconds / 1000.0 * widget.pixelsPerSecond;

    return Positioned(
      left: leftPosition,
      top: widget.topPosition,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (_) => setState(() => _isDraggingMiddle = true),
        onPanUpdate: (details) => _handleMiddleDrag(details.delta.dx),
        onPanEnd: (_) => setState(() => _isDraggingMiddle = false),
        child: Container(
          width: width < 60 ? 60 : width,
          height: 40,
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.purple.withOpacity(0.9) : Colors.deepPurple.withOpacity(0.7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isSelected ? Colors.purple.shade200 : Colors.deepPurple.shade200,
              width: 2,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.audioClip.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              // Left Drag Handle
              Positioned(
                left: -2,
                top: -2,
                bottom: -2,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDraggingLeft = true),
                  onPanUpdate: (details) => _handleLeftTrim(details.delta.dx),
                  onPanEnd: (_) => setState(() => _isDraggingLeft = false),
                  child: _buildDragHandle(isLeft: true, isDragging: _isDraggingLeft),
                ),
              ),
              // Right Drag Handle
              Positioned(
                right: -2,
                top: -2,
                bottom: -2,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDraggingRight = true),
                  onPanUpdate: (details) => _handleRightTrim(details.delta.dx),
                  onPanEnd: (_) => setState(() => _isDraggingRight = false),
                  child: _buildDragHandle(isLeft: false, isDragging: _isDraggingRight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle({required bool isLeft, required bool isDragging}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: Container(
        width: 20,
        decoration: BoxDecoration(
          color: isDragging ? Colors.white.withOpacity(0.6) : Colors.white.withOpacity(0.3),
          borderRadius: isLeft
              ? const BorderRadius.only(topLeft: Radius.circular(6), bottomLeft: Radius.circular(6))
              : const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
          border: Border.all(color: Colors.white, width: 2.5),
        ),
      ),
    );
  }
}