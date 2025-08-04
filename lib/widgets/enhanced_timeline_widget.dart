import 'package:flutter/material.dart';
import '../models/media_clip.dart';
import 'timeline_clip_widget.dart';
import 'timeline_progress_indicator.dart';

class EnhancedTimelineWidget extends StatelessWidget {
  final List<MediaClip> mediaClips;
  final int currentClipIndex;
  final Duration currentProjectPosition;
  final Duration totalProjectDuration;
  final Function(int) onClipTap;
  final Function(int, Duration, Duration) onTrimChanged;

  const EnhancedTimelineWidget({
    super.key,
    required this.mediaClips,
    required this.currentClipIndex,
    required this.currentProjectPosition,
    required this.totalProjectDuration,
    required this.onClipTap,
    required this.onTrimChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Timeline clips
            ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: mediaClips.length,
              itemBuilder: (context, index) {
                final clip = mediaClips[index];
                final isSelected = index == currentClipIndex;
                
                return TimelineClipWidget(
                  clip: clip,
                  isSelected: isSelected,
                  onTap: () => onClipTap(index),
                  onTrimChanged: (newStartTime, newEndTime) {
                    onTrimChanged(index, newStartTime, newEndTime);
                  },
                );
              },
            ),
            // Progress indicator
            TimelineProgressIndicator(
              currentPosition: currentProjectPosition,
              totalDuration: totalProjectDuration,
              timelineWidth: constraints.maxWidth - 16, // Account for padding
            ),
          ],
        );
      },
    );
  }
}
