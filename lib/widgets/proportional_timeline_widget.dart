import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_clip.dart';
// Added import for the cache manager
import '../services/media_cache_manager.dart';

class ProportionalTimelineWidget extends StatelessWidget {
  final List<MediaClip> mediaClips;
  final int currentClipIndex;
  final Duration currentProjectPosition;
  final Duration totalProjectDuration;
  final Function(int) onClipTap;
  final Function(int, Duration, Duration) onTrimChanged;
  final double timelineWidth;

  const ProportionalTimelineWidget({
    super.key,
    required this.mediaClips,
    required this.currentClipIndex,
    required this.currentProjectPosition,
    required this.totalProjectDuration,
    required this.onClipTap,
    required this.onTrimChanged,
    required this.timelineWidth,
  });

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
    super.key,
    required this.clip,
    required this.isSelected,
    required this.width,
    required this.onTap,
    required this.onTrimChanged,
  });

  @override
  State<ProportionalClipWidget> createState() => _ProportionalClipWidgetState();
}

class _ProportionalClipWidgetState extends State<ProportionalClipWidget> {
  bool _isLeftHandleActive = false;
  bool _isRightHandleActive = false;

  // --- MODIFICATION START ---
  // State variables for optimized thumbnail loading and caching.
  final MediaCacheManager _cacheManager = MediaCacheManager();
  Widget? _thumbnailWidget;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  /// Loads the thumbnail, checking the cache first to avoid redundant work.
  Future<void> _loadThumbnail() async {
    final cacheKey = '${widget.clip.asset.id}_proportional_thumb_${widget.width.round()}';

    // 1. Check if the widget is already cached
    final cachedWidget = _cacheManager.getCachedWidget(cacheKey);
    if (cachedWidget != null) {
      if (mounted) {
        setState(() {
          _thumbnailWidget = cachedWidget;
          _isLoading = false;
        });
      }
      return;
    }

    // 2. If not cached, fetch thumbnail data
    try {
      final thumbnailBytes = await widget.clip.asset.thumbnailDataWithSize(
        ThumbnailSize(widget.width.round(), 60),
      );

      if (thumbnailBytes != null && mounted) {
        final imageWidget = Image.memory(
          thumbnailBytes,
          fit: BoxFit.cover,
          width: widget.width,
          height: 60,
          gaplessPlayback: true, // Prevents flicker on image update
        );

        // 3. Cache the fully prepared widget for future use
        _cacheManager.setCachedWidget(cacheKey, imageWidget);
        
        setState(() {
          _thumbnailWidget = imageWidget;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading timeline thumbnail: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- MODIFICATION END ---


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
                  fit: StackFit.expand,
                  children: [
                    // --- MODIFICATION START ---
                    // Replaced FutureBuilder with a more performant state-based builder.
                    if (_isLoading)
                      Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                          ),
                        ),
                      )
                    else if (_thumbnailWidget != null)
                      _thumbnailWidget!
                    else
                      // Fallback view if thumbnail fails to load
                      Container(
                        color: Colors.grey[800],
                        child: Icon(
                          widget.clip.asset.type == AssetType.video ? Icons.videocam : Icons.photo,
                          color: Colors.white.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    // --- MODIFICATION END ---
                    
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
    // Avoid division by zero if width is somehow zero
    if (widget.width == 0) return;
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
    // Avoid division by zero if width is somehow zero
    if (widget.width == 0) return;
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}