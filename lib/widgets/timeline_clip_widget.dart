import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_clip.dart';

class TimelineClipWidget extends StatefulWidget {
  final MediaClip clip;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(Duration startTime, Duration endTime) onTrimChanged;

  const TimelineClipWidget({
    super.key,
    required this.clip,
    required this.isSelected,
    required this.onTap,
    required this.onTrimChanged,
  });

  @override
  State<TimelineClipWidget> createState() => _TimelineClipWidgetState();
}

class _TimelineClipWidgetState extends State<TimelineClipWidget> {
  bool _isLeftHandleActive = false;
  bool _isRightHandleActive = false;
  double _clipWidth = 120.0;
  final double _minClipWidth = 60.0;
  final double _maxClipWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    // Calculate width based on duration (minimum 60px, maximum 200px)
    final durationRatio = widget.clip.trimmedDuration.inMilliseconds / 
                         widget.clip.originalDuration.inMilliseconds;
    _clipWidth = (_minClipWidth + (durationRatio * (_maxClipWidth - _minClipWidth)))
        .clamp(_minClipWidth, _maxClipWidth);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: _clipWidth,
        height: 60,
        margin: const EdgeInsets.only(right: 4),
        child: Stack(
          children: [
            // Main clip container
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: widget.isSelected
                    ? Border.all(color: Colors.purple, width: 2)
                    : Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
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
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          widget.clip.asset.type == AssetType.video 
                              ? Icons.videocam 
                              : Icons.photo,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Left trim handle (only for videos)
            if (widget.clip.asset.type == AssetType.video)
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
                    width: 12,
                    decoration: BoxDecoration(
                      color: _isLeftHandleActive ? Colors.purple : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 2,
                          offset: const Offset(1, 0),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.black54,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Right trim handle (only for videos)
            if (widget.clip.asset.type == AssetType.video)
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
                    width: 12,
                    decoration: BoxDecoration(
                      color: _isRightHandleActive ? Colors.purple : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 2,
                          offset: const Offset(-1, 0),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.black54,
                        size: 12,
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
    // Calculate the time change based on pixel movement
    final totalPixels = _maxClipWidth;
    final totalDuration = widget.clip.originalDuration.inMilliseconds;
    final millisecondsPerPixel = totalDuration / totalPixels;
    
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
    // Calculate the time change based on pixel movement
    final totalPixels = _maxClipWidth;
    final totalDuration = widget.clip.originalDuration.inMilliseconds;
    final millisecondsPerPixel = totalDuration / totalPixels;
    
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
        const ThumbnailSize(120, 60),
      );
      
      if (thumbnail != null) {
        return Image.memory(
          thumbnail,
          fit: BoxFit.cover,
          width: _clipWidth,
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
        size: 30,
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
