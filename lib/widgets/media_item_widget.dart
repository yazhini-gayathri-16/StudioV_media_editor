import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class MediaItemWidget extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback onTap;
  final int selectionIndex;

  const MediaItemWidget({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.onTap,
    required this.selectionIndex,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.purple, width: 3)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1,
                child: FutureBuilder<Widget>(
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
                asset.type == AssetType.video ? Icons.videocam : Icons.photo,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
          
          // Video duration indicator
          if (asset.type == AssetType.video)
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
                  _formatDuration(asset.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          // Selection indicator
          if (isSelected)
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
                    selectionIndex.toString(),
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
          if (isSelected)
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

  Future<Widget> _buildThumbnail() async {
    try {
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );
      
      if (thumbnail != null) {
        return Image.memory(
          thumbnail,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
    }
    
    return Container(
      color: Colors.grey[800],
      child: Icon(
        asset.type == AssetType.video ? Icons.videocam : Icons.photo,
        color: Colors.white,
        size: 40,
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