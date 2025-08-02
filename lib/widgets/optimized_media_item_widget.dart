import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/media_cache_manager.dart';

class OptimizedMediaItemWidget extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback onTap;
  final int selectionIndex;

  const OptimizedMediaItemWidget({
    Key? key,
    required this.asset,
    required this.isSelected,
    required this.onTap,
    required this.selectionIndex,
  }) : super(key: key);

  @override
  State<OptimizedMediaItemWidget> createState() => _OptimizedMediaItemWidgetState();
}

class _OptimizedMediaItemWidgetState extends State<OptimizedMediaItemWidget> {
  final MediaCacheManager _cacheManager = MediaCacheManager();
  Widget? _thumbnailWidget;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final cacheKey = '${widget.asset.id}_thumbnail';
    
    // Check if widget is cached
    final cachedWidget = _cacheManager.getCachedWidget(cacheKey);
    if (cachedWidget != null) {
      setState(() {
        _thumbnailWidget = cachedWidget;
        _isLoading = false;
      });
      return;
    }

    try {
      // Use smaller thumbnail size for better performance
      final thumbnail = await _cacheManager.getThumbnail(
        widget.asset, 
        const ThumbnailSize(150, 150)
      );
      
      if (thumbnail != null && mounted) {
        final imageWidget = Image.memory(
          thumbnail,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true, // Smooth image transitions
        );
        
        // Cache the widget
        _cacheManager.setCachedWidget(cacheKey, imageWidget);
        
        setState(() {
          _thumbnailWidget = imageWidget;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: widget.isSelected
                  ? Border.all(color: Colors.purple, width: 3)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1,
                child: _isLoading
                    ? Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                            ),
                          ),
                        ),
                      )
                    : _thumbnailWidget ?? Container(
                        color: Colors.grey[800],
                        child: Icon(
                          widget.asset.type == AssetType.video ? Icons.videocam : Icons.photo,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
              ),
            ),
          ),
          
          // Media type indicator
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                widget.asset.type == AssetType.video ? Icons.videocam : Icons.photo,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
          
          // Video duration indicator
          if (widget.asset.type == AssetType.video)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(widget.asset.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          // Selection indicator
          if (widget.isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.purple,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.selectionIndex.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          
          // Selection overlay
          if (widget.isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.purple.withOpacity(0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
