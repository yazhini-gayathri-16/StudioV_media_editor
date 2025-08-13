// lib/services/video_player_manager.dart

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
  
  final Map<String, VideoPlayerController> _preloadCache = {};
  static const int maxPreloadCacheSize = 5;

  /// Gets a controller for a clip, making it the new active one.
  /// This method safely caches the previously active controller instead of disposing it.
  Future<VideoPlayerController?> getController(MediaClip clip) async {
    // If the requested clip's controller is already active, just return it.
    if (_activeControllerId == clip.asset.id && _activeController != null) {
      return _activeController;
    }

    // If a different controller was active, move it to the preload cache for later reuse.
    if (_activeController != null && _activeControllerId != null) {
      if (!_preloadCache.containsKey(_activeControllerId)) {
        // Manage cache size before adding a new item.
        if (_preloadCache.length >= maxPreloadCacheSize) {
          final oldestKey = _preloadCache.keys.first;
          await _preloadCache[oldestKey]?.dispose();
          _preloadCache.remove(oldestKey);
        }
        _preloadCache[_activeControllerId!] = _activeController!;
      }
    }
    
    _activeControllerId = clip.asset.id;

    // Check if the newly requested controller is in the preload cache.
    if (_preloadCache.containsKey(clip.asset.id)) {
      _activeController = _preloadCache.remove(clip.asset.id);
      return _activeController;
    }

    // If it's not active or preloaded, create a new one.
    try {
      final file = await _getCachedFile(clip.asset);
      if (file == null) return null;

      _activeController = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
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
          mixWithOthers: true,
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