import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';

class MediaCacheManager {
  static final MediaCacheManager _instance = MediaCacheManager._internal();
  factory MediaCacheManager() => _instance;
  MediaCacheManager._internal();

  final Map<String, Uint8List> _thumbnailCache = {};
  final Map<String, Widget> _widgetCache = {};
  static const int maxCacheSize = 200; // Limit cache size

  Future<Uint8List?> getThumbnail(AssetEntity asset, ThumbnailSize size) async {
    final key = '${asset.id}_${size.width}x${size.height}';
    
    if (_thumbnailCache.containsKey(key)) {
      return _thumbnailCache[key];
    }

    try {
      final thumbnail = await asset.thumbnailDataWithSize(size);
      if (thumbnail != null) {
        // Manage cache size
        if (_thumbnailCache.length >= maxCacheSize) {
          final firstKey = _thumbnailCache.keys.first;
          _thumbnailCache.remove(firstKey);
        }
        _thumbnailCache[key] = thumbnail;
        return thumbnail;
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
    }
    
    return null;
  }

  Widget? getCachedWidget(String key) {
    return _widgetCache[key];
  }

  void setCachedWidget(String key, Widget widget) {
    if (_widgetCache.length >= maxCacheSize) {
      final firstKey = _widgetCache.keys.first;
      _widgetCache.remove(firstKey);
    }
    _widgetCache[key] = widget;
  }

  void clearCache() {
    _thumbnailCache.clear();
    _widgetCache.clear();
  }

  void clearThumbnailCache() {
    _thumbnailCache.clear();
  }
}
