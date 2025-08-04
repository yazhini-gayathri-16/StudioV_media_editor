import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_clip.dart';

class VideoPlayerManager {
  static final VideoPlayerManager _instance = VideoPlayerManager._internal();
  factory VideoPlayerManager() => _instance;
  VideoPlayerManager._internal();

  VideoPlayerController? _activeController;
  String? _activeControllerId;

  final Map<String, File> _fileCache = {};
  static const int maxFileCacheSize = 50;
  
  // This cache is for preloaded (non-active) controllers
  final Map<String, VideoPlayerController> _preloadCache = {};
  static const int maxPreloadCacheSize = 5; // A smaller cache for only what's next

  /// Gets a controller for a clip, making it the new active one.
  /// This method intelligently disposes of the previously active controller.
  Future<VideoPlayerController?> getController(MediaClip clip) async {
    // --- FIX: Dispose the PREVIOUS active controller ---
    // If the new clip is different from the currently active one, dispose the old one.
    if (_activeController != null && _activeControllerId != clip.asset.id) {
        // Only dispose it if it's not in the preload cache for reuse.
        if (!_preloadCache.containsKey(_activeControllerId)) {
            await _activeController!.dispose();
        }
        _activeController = null;
    }
    
    _activeControllerId = clip.asset.id;

    // Check if the requested controller is already preloaded
    if (_preloadCache.containsKey(clip.asset.id)) {
      _activeController = _preloadCache.remove(clip.asset.id);
      return _activeController;
    }

    // If it's the same as the already active controller, just return it.
    if (_activeController != null) {
        return _activeController;
    }

    // Otherwise, create a new one
    try {
      final file = await _getCachedFile(clip.asset);
      if (file == null) return null;

      _activeController = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await _activeController!.initialize();
      return _activeController;
    } catch (e) {
      print('Error creating video controller: $e');
      return null;
    }
  }

  /// Preloads the next video into a separate cache.
  Future<void> preloadNextVideo(MediaClip clip) async {
    if (_preloadCache.containsKey(clip.asset.id) || _activeControllerId == clip.asset.id) {
        return;
    }

    try {
      final file = await _getCachedFile(clip.asset);
      if (file == null) return;

      final controller = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      await controller.initialize();
      await controller.seekTo(clip.startTime);

      // Manage preload cache size
      if (_preloadCache.length >= maxPreloadCacheSize) {
        final oldestKey = _preloadCache.keys.first;
        await _preloadCache[oldestKey]?.dispose();
        _preloadCache.remove(oldestKey);
      }
      _preloadCache[clip.asset.id] = controller;
    } catch (e) {
      print('Error preloading video: $e');
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
        if (_fileCache.length >= maxFileCacheSize) {
          _fileCache.remove(_fileCache.keys.first);
        }
        _fileCache[cacheKey] = file;
        return file;
      }
    } catch (e) {
      print('Error getting file: $e');
    }
    return null;
  }
  
  VideoPlayerController? get currentController => _activeController;

  Future<void> dispose() async {
    for (final controller in _preloadCache.values) {
      await controller.dispose();
    }
    _preloadCache.clear();
    await _activeController?.dispose();
    _activeController = null;
    _activeControllerId = null;
    _fileCache.clear();
  }
}