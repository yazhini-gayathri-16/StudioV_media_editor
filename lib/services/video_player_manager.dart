import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_clip.dart';

class VideoPlayerManager {
  static final VideoPlayerManager _instance = VideoPlayerManager._internal();
  factory VideoPlayerManager() => _instance;
  VideoPlayerManager._internal();

  VideoPlayerController? _currentController;
  final Map<String, File> _fileCache = {};
  static const int maxFileCacheSize = 10;

  Future<VideoPlayerController?> getController(MediaClip clip) async {
    try {
      // Get file from cache or load it
      final file = await _getCachedFile(clip.asset);
      if (file == null) return null;

      // Dispose previous controller if different clip
      if (_currentController != null) {
        await _currentController!.dispose();
      }

      // Create new controller with optimized settings
      _currentController = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize with timeout
      await _currentController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Video initialization timeout');
        },
      );

      // Set video quality for better performance
      await _currentController!.setLooping(false);
      
      return _currentController;
    } catch (e) {
      print('Error creating video controller: $e');
      return null;
    }
  }

  Future<File?> _getCachedFile(AssetEntity asset) async {
    final cacheKey = asset.id;
    
    if (_fileCache.containsKey(cacheKey)) {
      return _fileCache[cacheKey];
    }

    try {
      final file = await asset.file;
      if (file != null) {
        // Manage cache size
        if (_fileCache.length >= maxFileCacheSize) {
          final firstKey = _fileCache.keys.first;
          _fileCache.remove(firstKey);
        }
        _fileCache[cacheKey] = file;
        return file;
      }
    } catch (e) {
      print('Error getting file: $e');
    }
    
    return null;
  }

  Future<void> preloadVideo(MediaClip clip) async {
    // Preload video file in background
    await _getCachedFile(clip.asset);
  }

  Future<void> dispose() async {
    await _currentController?.dispose();
    _currentController = null;
    _fileCache.clear();
  }

  VideoPlayerController? get currentController => _currentController;
}
