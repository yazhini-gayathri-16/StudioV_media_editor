import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_clip.dart';

class ProportionalTimelineWidget extends StatelessWidget {
  final List<MediaClip> mediaClips;
  final int currentClipIndex;
  final Duration currentProjectPosition;
  final Duration totalProjectDuration;
  final Function(int) onClipTap;
  final Function(int, Duration, Duration) onTrimChanged;
  final double timelineWidth;

  const ProportionalTimelineWidget({
    Key? key,
    required this.mediaClips,
    required this.currentClipIndex,
    required this.currentProjectPosition,
    required this.totalProjectDuration,
    required this.onClipTap,
    required this.onTrimChanged,
    required this.timelineWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaClips.isEmpty || totalProjectDuration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Timeline clips
        Row(
          children: _buildProportionalClips(),
        ),
        // Progress indicator
        _buildProgressIndicator(),
      ],
    );
  }

  List<Widget> _buildProportionalClips() {
    List<Widget> clips = [];
    
    for (int i = 0; i < mediaClips.length; i++) {
      final clip = mediaClips[i];
      final isSelected = i == currentClipIndex;
      
      // Calculate proportional width based on clip duration
      final clipDurationRatio = clip.trimmedDuration.inMilliseconds / 
                               totalProjectDuration.inMilliseconds;
      final clipWidth = (timelineWidth * clipDurationRatio).clamp(40.0, timelineWidth);
      
      clips.add(
        ProportionalClipWidget(
          clip: clip,
          isSelected: isSelected,
          width: clipWidth,
          onTap: () => onClipTap(i),
          onTrimChanged: (newStartTime, newEndTime) {
            onTrimChanged(i, newStartTime, newEndTime);
          },
        ),
      );
    }
    
    return clips;
  }

  Widget _buildProgressIndicator() {
    if (totalProjectDuration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    final progress = currentProjectPosition.inMilliseconds / 
                    totalProjectDuration.inMilliseconds;
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

class ProportionalClipWidget extends StatefulWidget {
  final MediaClip clip;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;
  final Function(Duration startTime, Duration endTime) onTrimChanged;

  const ProportionalClipWidget({
    Key? key,
    required this.clip,
    required this.isSelected,
    required this.width,
    required this.onTap,
    required this.onTrimChanged,
  }) : super(key: key);

  @override
  State<ProportionalClipWidget> createState() => _ProportionalClipWidgetState();
}

class _ProportionalClipWidgetState extends State<ProportionalClipWidget> {
  bool _isLeftHandleActive = false;
  bool _isRightHandleActive = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: 60,
        margin: const EdgeInsets.only(right: 1),
        child: Stack(
          children: [
            // Main clip container
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: widget.isSelected
                    ? Border.all(color: Colors.purple, width: 2)
                    : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    // Thumbnail
                    FutureBuilder<Widget>(
                      future: _buildThumbnail(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return snapshot.data!;
                        }
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                            ),
                          ),
                        );
                      },
                    ),
                    // Duration overlay
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _formatDuration(widget.clip.trimmedDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Media type indicator
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(
                          widget.clip.asset.type == AssetType.video 
                              ? Icons.videocam 
                              : Icons.photo,
                          color: Colors.white,
                          size: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Left trim handle (only for videos and if width is sufficient)
            if (widget.clip.asset.type == AssetType.video && widget.width > 60)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isLeftHandleActive = true;
                    });
                  },
                  onPanUpdate: (details) {
                    _handleLeftTrim(details.delta.dx);
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isLeftHandleActive = false;
                    });
                  },
                  child: Container(
                    width: 8,
                    decoration: BoxDecoration(
                      color: _isLeftHandleActive ? Colors.purple : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.black54,
                        size: 8,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Right trim handle (only for videos and if width is sufficient)
            if (widget.clip.asset.type == AssetType.video && widget.width > 60)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isRightHandleActive = true;
                    });
                  },
                  onPanUpdate: (details) {
                    _handleRightTrim(details.delta.dx);
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isRightHandleActive = false;
                    });
                  },
                  child: Container(
                    width: 8,
                    decoration: BoxDecoration(
                      color: _isRightHandleActive ? Colors.purple : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.black54,
                        size: 8,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleLeftTrim(double deltaX) {
    // Calculate the time change based on pixel movement relative to clip width
    final totalDuration = widget.clip.originalDuration.inMilliseconds;
    final millisecondsPerPixel = totalDuration / widget.width;
    
    final deltaMilliseconds = (deltaX * millisecondsPerPixel).round();
    
    Duration newStartTime = widget.clip.startTime + Duration(milliseconds: deltaMilliseconds);
    
    // Ensure start time doesn't go below 0 or beyond end time
    newStartTime = Duration(
      milliseconds: newStartTime.inMilliseconds.clamp(
        0,
        widget.clip.endTime.inMilliseconds - 500, // Minimum 0.5 second clip
      ),
    );
    
    if (newStartTime != widget.clip.startTime) {
      widget.onTrimChanged(newStartTime, widget.clip.endTime);
    }
  }

  void _handleRightTrim(double deltaX) {
    // Calculate the time change based on pixel movement relative to clip width
    final totalDuration = widget.clip.originalDuration.inMilliseconds;
    final millisecondsPerPixel = totalDuration / widget.width;
    
    final deltaMilliseconds = (deltaX * millisecondsPerPixel).round();
    
    Duration newEndTime = widget.clip.endTime + Duration(milliseconds: deltaMilliseconds);
    
    // Ensure end time doesn't go beyond original duration or before start time
    newEndTime = Duration(
      milliseconds: newEndTime.inMilliseconds.clamp(
        widget.clip.startTime.inMilliseconds + 500, // Minimum 0.5 second clip
        widget.clip.originalDuration.inMilliseconds,
      ),
    );
    
    if (newEndTime != widget.clip.endTime) {
      widget.onTrimChanged(widget.clip.startTime, newEndTime);
    }
  }

  Future<Widget> _buildThumbnail() async {
    try {
      final thumbnail = await widget.clip.asset.thumbnailDataWithSize(
        ThumbnailSize(widget.width.round(), 60),
      );
      
      if (thumbnail != null) {
        return Image.memory(
          thumbnail,
          fit: BoxFit.cover,
          width: widget.width,
          height: 60,
        );
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
    }
    
    return Container(
      color: Colors.grey[800],
      child: Icon(
        widget.clip.asset.type == AssetType.video ? Icons.videocam : Icons.photo,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
