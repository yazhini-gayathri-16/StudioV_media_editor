// lib/widgets/text_timeline_widget.dart - ENHANCED VERSION

import 'package:flutter/material.dart';
import '../models/text_overlay_model.dart';

class TextTimelineWidget extends StatefulWidget {
  final TextOverlay textOverlay;
  final double pixelsPerSecond;
  final Function(Duration newStart, Duration newEnd) onDurationChanged;
  final VoidCallback onTap;
  final bool isSelected;
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
  bool _isDraggingLeft = false;
  bool _isDraggingRight = false;

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
      top: widget.topPosition,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: width < 60 ? 60 : width, // Minimum width to accommodate wider handles
          height: 30, // Slightly reduced height for better proportions
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? Colors.blue.withOpacity(0.8) 
                : Colors.green.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isSelected ? Colors.blue : Colors.green,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Text content with padding for wider handles
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 35), // More padding for handles
                  child: Text(
                    widget.textOverlay.text,
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
              
              // ENHANCED: Much wider and more accessible left drag handle
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDraggingLeft = true),
                  onPanUpdate: (details) => _handleLeftTrim(details.delta.dx),
                  onPanEnd: (_) => setState(() => _isDraggingLeft = false),
                  child: Container(
                    width: 30, // Much wider hit area
                    decoration: BoxDecoration(
                      color: _isDraggingLeft 
                          ? Colors.white.withOpacity(0.4) 
                          : Colors.white.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: _isDraggingLeft 
                          ? Border.all(color: Colors.white, width: 1)
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // Main drag indicator - much more visible
                        Center(
                          child: Container(
                            width: 8, // Wider visual indicator
                            height: 25,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 2,
                                  offset: const Offset(1, 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Grip lines for better visual indication
                        Positioned(
                          left: 8,
                          top: 6,
                          bottom: 6,
                          child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 6,
                          bottom: 6,
                          child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // ENHANCED: Much wider and more accessible right drag handle
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDraggingRight = true),
                  onPanUpdate: (details) => _handleRightTrim(details.delta.dx),
                  onPanEnd: (_) => setState(() => _isDraggingRight = false),
                  child: Container(
                    width: 30, // Much wider hit area
                    decoration: BoxDecoration(
                      color: _isDraggingRight 
                          ? Colors.white.withOpacity(0.4) 
                          : Colors.white.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                      border: _isDraggingRight 
                          ? Border.all(color: Colors.white, width: 1)
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // Main drag indicator - much more visible
                        Center(
                          child: Container(
                            width: 8, // Wider visual indicator
                            height: 25,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 2,
                                  offset: const Offset(-1, 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Grip lines for better visual indication
                        Positioned(
                          right: 8,
                          top: 6,
                          bottom: 6,
                          child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 6,
                          bottom: 6,
                          child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ],
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