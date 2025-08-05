import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_clip.dart';
import '../services/media_cache_manager.dart';

class ProportionalTimelineWidget extends StatelessWidget {
  final List<MediaClip> mediaClips;
  final int currentClipIndex;
  final Duration currentProjectPosition;
  final Duration totalProjectDuration;
  final Function(int) onClipTap;
  final Function(int, Duration, Duration) onTrimChanged;
  final double timelineWidth;
  // --- NEW: Added pixelsPerSecond ---
  final double pixelsPerSecond;

  const ProportionalTimelineWidget({
    super.key,
    required this.mediaClips,
    required this.currentClipIndex,
    required this.currentProjectPosition,
    required this.totalProjectDuration,
    required this.onClipTap,
    required this.onTrimChanged,
    required this.timelineWidth,
    required this.pixelsPerSecond, // --- NEW ---
  });

  @override
  Widget build(BuildContext context) {
    if (mediaClips.isEmpty || totalProjectDuration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: timelineWidth, // Set the total width for the Stack
      height: 80, // Explicit height
      child: Stack(
        children: [
          // Timeline clips
          Row(
            children: _buildProportionalClips(),
          ),
          // Progress indicator
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  List<Widget> _buildProportionalClips() {
    return mediaClips.map((clip) {
      final index = mediaClips.indexOf(clip);
      final isSelected = index == currentClipIndex;

      // --- FIX: Calculate width based on a fixed scale ---
      final double clipWidth = clip.trimmedDuration.inMilliseconds / 1000.0 * pixelsPerSecond;

      return ProportionalClipWidget(
        key: ValueKey(clip.asset.id), // Add a key for better performance
        clip: clip,
        isSelected: isSelected,
        width: clipWidth,
        pixelsPerSecond: pixelsPerSecond, // Pass down the scale
        onTap: () => onClipTap(index),
        onTrimChanged: (newStartTime, newEndTime) {
          onTrimChanged(index, newStartTime, newEndTime);
        },
      );
    }).toList();
  }

  Widget _buildProgressIndicator() {
    if (totalProjectDuration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    // --- FIX: Calculate position based on the fixed scale ---
    final double indicatorPosition = (currentProjectPosition.inMilliseconds / 1000.0 * pixelsPerSecond)
        .clamp(0.0, timelineWidth);

    return Positioned(
      left: indicatorPosition,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2.5,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 3,
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
  final double pixelsPerSecond; // --- NEW ---
  final VoidCallback onTap;
  final Function(Duration startTime, Duration endTime) onTrimChanged;

  const ProportionalClipWidget({
    super.key,
    required this.clip,
    required this.isSelected,
    required this.width,
    required this.pixelsPerSecond, // --- NEW ---
    required this.onTap,
    required this.onTrimChanged,
  });

  @override
  State<ProportionalClipWidget> createState() => _ProportionalClipWidgetState();
}

class _ProportionalClipWidgetState extends State<ProportionalClipWidget> {
  // ... (keep all the state variables: _isLeftHandleActive, _cacheManager, etc.)
  bool _isLeftHandleActive = false;
  bool _isRightHandleActive = false;
  final MediaCacheManager _cacheManager = MediaCacheManager();
  Widget? _thumbnailWidget;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant ProportionalClipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload thumbnail if width changes significantly
    if ((widget.width - oldWidget.width).abs() > 2.0) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    // ... (Keep the _loadThumbnail method exactly as it was, it's already optimized)
    final cacheKey = '${widget.clip.asset.id}_proportional_thumb_${widget.width.round()}';
    final cachedWidget = _cacheManager.getCachedWidget(cacheKey);
    if (cachedWidget != null) {
      if (mounted) setState(() { _thumbnailWidget = cachedWidget; _isLoading = false; });
      return;
    }
    try {
      final thumbnailBytes = await widget.clip.asset.thumbnailDataWithSize(
        ThumbnailSize(widget.width.round(), 80),
      );
      if (thumbnailBytes != null && mounted) {
        final imageWidget = Image.memory(
          thumbnailBytes,
          fit: BoxFit.cover,
          width: widget.width,
          height: 80,
          gaplessPlayback: true,
        );
        _cacheManager.setCachedWidget(cacheKey, imageWidget);
        setState(() { _thumbnailWidget = imageWidget; _isLoading = false; });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading timeline thumbnail: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // --- The entire build method for ProportionalClipWidget remains the same ---
    // --- EXCEPT for the trim handlers. We need to update their logic. ---
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: 80, // Set height to match timeline
        margin: const EdgeInsets.only(right: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: widget.isSelected ? Colors.purple : Colors.white24, 
            width: 1.5
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail logic (remains the same)
              if (_isLoading)
                Container(color: Colors.grey[850])
              else if (_thumbnailWidget != null)
                _thumbnailWidget!
              else
                Container(color: Colors.grey[850], child: Icon(Icons.error, color: Colors.white24)),
              
              // Trim handles (update their logic)
              if (widget.clip.asset.type == AssetType.video && widget.isSelected)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: GestureDetector(
                    onPanStart: (_) => setState(() => _isLeftHandleActive = true),
                    onPanUpdate: (details) => _handleLeftTrim(details.delta.dx),
                    onPanEnd: (_) => setState(() => _isLeftHandleActive = false),
                    child: _buildTrimHandle(isLeft: true, isActive: _isLeftHandleActive),
                  ),
                ),
              if (widget.clip.asset.type == AssetType.video && widget.isSelected)
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  child: GestureDetector(
                    onPanStart: (_) => setState(() => _isRightHandleActive = true),
                    onPanUpdate: (details) => _handleRightTrim(details.delta.dx),
                    onPanEnd: (_) => setState(() => _isRightHandleActive = false),
                    child: _buildTrimHandle(isLeft: false, isActive: _isRightHandleActive),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrimHandle({required bool isLeft, required bool isActive}) {
    return Container(
      width: 10,
      color: (isActive ? Colors.purple : Colors.white).withOpacity(0.9),
      child: const Center(
        child: Icon(Icons.drag_handle, color: Colors.black54, size: 10),
      ),
    );
  }

  void _handleLeftTrim(double deltaX) {
    // --- FIX: Use pixelsPerSecond for accurate time calculation ---
    final deltaMilliseconds = (deltaX * 1000 / widget.pixelsPerSecond).round();
    Duration newStartTime = widget.clip.startTime + Duration(milliseconds: deltaMilliseconds);
    
    newStartTime = Duration(
      milliseconds: newStartTime.inMilliseconds.clamp(0, widget.clip.endTime.inMilliseconds - 500),
    );
    
    if (newStartTime != widget.clip.startTime) {
      widget.onTrimChanged(newStartTime, widget.clip.endTime);
    }
  }

  void _handleRightTrim(double deltaX) {
    // --- FIX: Use pixelsPerSecond for accurate time calculation ---
    final deltaMilliseconds = (deltaX * 1000 / widget.pixelsPerSecond).round();
    Duration newEndTime = widget.clip.endTime + Duration(milliseconds: deltaMilliseconds);
    
    newEndTime = Duration(
      milliseconds: newEndTime.inMilliseconds.clamp(
        widget.clip.startTime.inMilliseconds + 500,
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