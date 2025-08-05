import 'dart:typed_data';
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
    required this.pixelsPerSecond,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaClips.isEmpty || totalProjectDuration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: timelineWidth,
      height: 80,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Row(
            children: mediaClips.map((clip) {
              final index = mediaClips.indexOf(clip);
              final double clipWidth = clip.trimmedDuration.inMilliseconds / 1000.0 * pixelsPerSecond;
              return ProportionalClipWidget(
                key: ValueKey(clip.asset.id + clip.trimmedDuration.toString()),
                clip: clip,
                isSelected: index == currentClipIndex,
                width: clipWidth,
                pixelsPerSecond: pixelsPerSecond,
                onTap: () => onClipTap(index),
                onTrimChanged: (newStartTime, newEndTime) {
                  onTrimChanged(index, newStartTime, newEndTime);
                },
              );
            }).toList(),
          ),
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final double indicatorPosition = (currentProjectPosition.inMilliseconds / 1000.0 * pixelsPerSecond)
        .clamp(0.0, timelineWidth);

    return Positioned(
      left: indicatorPosition,
      child: Container(
        width: 3,
        height: 80, // Full height of the timeline
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 4) ],
        ),
      ),
    );
  }
}


// --- COMPLETELY REWRITTEN WIDGET FOR FILMSTRIP STYLE ---
class ProportionalClipWidget extends StatefulWidget {
  final MediaClip clip;
  final bool isSelected;
  final double width;
  final double pixelsPerSecond;
  final VoidCallback onTap;
  final Function(Duration startTime, Duration endTime) onTrimChanged;

  const ProportionalClipWidget({
    super.key,
    required this.clip,
    required this.isSelected,
    required this.width,
    required this.pixelsPerSecond,
    required this.onTap,
    required this.onTrimChanged,
  });

  @override
  State<ProportionalClipWidget> createState() => _ProportionalClipWidgetState();
}

class _ProportionalClipWidgetState extends State<ProportionalClipWidget> {
  bool _isLeftHandleActive = false;
  bool _isRightHandleActive = false;
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    // We only need one high-quality square thumbnail to create the filmstrip.
    // It will be tiled horizontally.
    try {
      final bytes = await widget.clip.asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200), // Request a square, high-quality thumbnail
      );
      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error loading filmstrip thumbnail: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: 80,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: widget.isSelected ? Colors.purple : Colors.white24,
            width: 2.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Filmstrip background
              if (_isLoading)
                Container(color: Colors.grey.shade900)
              else if (_thumbnailBytes != null)
                // Use a ListView to tile the thumbnail horizontally
                ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return Image.memory(
                      _thumbnailBytes!,
                      fit: BoxFit.cover,
                      width: 80, // Tile width equals the timeline height for a square look
                      height: 80,
                      gaplessPlayback: true,
                    );
                  },
                )
              else
                Container(color: Colors.grey.shade900, child: const Icon(Icons.error, color: Colors.white24)),

              // Trim handles
              if (widget.clip.asset.type == AssetType.video && widget.isSelected)
                _buildTrimHandles(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrimHandles() {
    return Stack(
      children: [
        Positioned(
          left: 0, top: 0, bottom: 0,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isLeftHandleActive = true),
            onPanUpdate: (details) => _handleLeftTrim(details.delta.dx),
            onPanEnd: (_) => setState(() => _isLeftHandleActive = false),
            child: _buildTrimHandle(isLeft: true, isActive: _isLeftHandleActive),
          ),
        ),
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
    );
  }

  Widget _buildTrimHandle({required bool isLeft, required bool isActive}) {
    return Container(
      width: 12,
      color: (isActive ? Colors.purpleAccent : Colors.white).withOpacity(0.9),
      child: const Center(
        child: Icon(Icons.drag_handle_rounded, color: Colors.black54, size: 12),
      ),
    );
  }
  
  // The trim logic remains the same as it correctly uses pixelsPerSecond
  void _handleLeftTrim(double deltaX) {
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
}