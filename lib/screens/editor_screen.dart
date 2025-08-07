// lib/screens/editor_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../models/media_clip.dart';
import '../widgets/proportional_timeline_widget.dart';
import '../widgets/timeline_ruler.dart';
import '../services/video_player_manager.dart';
import 'canvas_screen.dart';
import 'dart:async';

class EditorScreen extends StatefulWidget {
  final List<MediaClip> mediaClips;

  const EditorScreen({super.key, required this.mediaClips});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int _currentClipIndex = 0;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isVideoInitialized = false;
  Duration _totalProjectDuration = Duration.zero;
  static const double pixelsPerSecond = 20.0;

  final ValueNotifier<Duration> _projectPositionNotifier = ValueNotifier(Duration.zero);
  List<MediaClip> _mediaClips = [];
  Timer? _positionTimer;
  int _imageStartTime = 0;

  final VideoPlayerManager _videoManager = VideoPlayerManager();

  final ScrollController _timelineScrollController = ScrollController();
  final ScrollController _rulerScrollController = ScrollController();

  int _mediaInitVersion = 0;
  
  final Map<String, double?> _aspectRatios = {};
  final Map<String, Matrix4?> _transformations = {};

  @override
  void initState() {
    super.initState();
    _mediaClips = List.from(widget.mediaClips);
    _calculateTotalDuration();

    _timelineScrollController.addListener(_syncRulerScroll);
    _rulerScrollController.addListener(_syncTimelineScroll);

    _initializeCurrentMedia();
    _startPositionTimer();
    _preloadInitialVideos(); 
  }

  @override
  void dispose() {
    _mediaInitVersion++;

    _timelineScrollController.removeListener(_syncRulerScroll);
    _rulerScrollController.removeListener(_syncTimelineScroll);
    _timelineScrollController.dispose();
    _rulerScrollController.dispose();

    _videoManager.dispose();
    _positionTimer?.cancel();
    _projectPositionNotifier.dispose();
    super.dispose();
  }

  void _syncRulerScroll() {
    if (_rulerScrollController.hasClients && !_rulerScrollController.position.isScrollingNotifier.value && _rulerScrollController.offset != _timelineScrollController.offset) {
      _rulerScrollController.jumpTo(_timelineScrollController.offset);
    }
  }

  void _syncTimelineScroll() {
    if (_timelineScrollController.hasClients && !_timelineScrollController.position.isScrollingNotifier.value && _timelineScrollController.offset != _rulerScrollController.offset) {
      _timelineScrollController.jumpTo(_rulerScrollController.offset);
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted && _isPlaying) {
        _updateProjectPosition();
      }
    });
  }

  void _updateProjectPosition() {
    if (_currentClipIndex >= _mediaClips.length || !mounted) return;

    final currentClip = _mediaClips[_currentClipIndex];
    Duration newPosition = Duration.zero;
    for (int i = 0; i < _currentClipIndex; i++) {
      newPosition += _mediaClips[i].trimmedDuration;
    }

    if (currentClip.asset.type == AssetType.video && _videoController != null && _isVideoInitialized) {
      final videoPosition = _videoController!.value.position;
      final clipProgressMs = (videoPosition - currentClip.startTime).inMilliseconds.clamp(0, currentClip.trimmedDuration.inMilliseconds);
      newPosition += Duration(milliseconds: clipProgressMs);

      if (videoPosition >= currentClip.endTime) {
        _moveToNextClip();
      }
    } else if (currentClip.asset.type == AssetType.image) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - _imageStartTime;
      final imageProgressMs = elapsed.clamp(0, currentClip.trimmedDuration.inMilliseconds);
      newPosition += Duration(milliseconds: imageProgressMs);

      if (Duration(milliseconds: imageProgressMs) >= currentClip.trimmedDuration) {
        _moveToNextClip();
      }
    }
    
    _projectPositionNotifier.value = newPosition;

    if (_isPlaying && _timelineScrollController.hasClients) {
      final double playheadX = newPosition.inMilliseconds / 1000.0 * pixelsPerSecond;
      final double viewportWidth = _timelineScrollController.position.viewportDimension;
      final double currentOffset = _timelineScrollController.offset;
      
      final double safeZoneStart = currentOffset + viewportWidth * 0.4;
      final double safeZoneEnd = currentOffset + viewportWidth * 0.6;

      if (playheadX < safeZoneStart || playheadX > safeZoneEnd) {
        final double targetOffset = playheadX - (viewportWidth / 2);
        
        final double clampedOffset = targetOffset.clamp(
          _timelineScrollController.position.minScrollExtent,
          _timelineScrollController.position.maxScrollExtent,
        );

        _timelineScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _calculateTotalDuration() {
    _totalProjectDuration = _mediaClips.fold(Duration.zero, (total, clip) => total + clip.trimmedDuration);
    if (mounted) setState(() {});
  }

  void _navigateToCanvasScreen() async {
    if (_mediaClips.isEmpty) return;
    final currentClip = _mediaClips[_currentClipIndex];
    final File? assetFile = await currentClip.asset.file;
    if (assetFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load the media file.')),
      );
      return;
    }

    if (_isPlaying) await _togglePlayPause();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CanvasScreen(
          videoFile: assetFile,
          initialAspectRatio: _aspectRatios[currentClip.asset.id],
          initialTransformation: _transformations[currentClip.asset.id],
        ),
      ),
    );

    if (result == 'CANCEL' || result == null) return;

    if (result is CanvasResult) {
      setState(() {
        if (result.applyToAll) {
          for (var clip in _mediaClips) {
            _aspectRatios[clip.asset.id] = result.aspectRatio;
            _transformations[clip.asset.id] = result.transformation;
          }
        } else {
          _aspectRatios[currentClip.asset.id] = result.aspectRatio;
          _transformations[currentClip.asset.id] = result.transformation;
        }
      });
    }
  }

  Future<void> _initializeCurrentMedia({bool wasPlaying = false}) async {
    final int requestVersion = _mediaInitVersion;

    if (_currentClipIndex >= _mediaClips.length) return;
    final currentClip = _mediaClips[_currentClipIndex];

    if(mounted) {
      setState(() {
        _isVideoInitialized = false;
      });
    }

    try {
      if (currentClip.asset.type == AssetType.video) {
        final controller = await _videoManager.getController(currentClip);

        if (!mounted || requestVersion != _mediaInitVersion) {
          return;
        }

        setState(() {
          _videoController = controller;
          _isVideoInitialized = controller != null && controller.value.isInitialized;
        });

        if (wasPlaying && _videoController != null) {
          await _videoController!.seekTo(currentClip.startTime);
          await _videoController!.play();
        }
        _preloadNextVideos();
      } else { // Image asset
        await _videoManager.getController(currentClip);

        if (!mounted || requestVersion != _mediaInitVersion) return;

        setState(() {
          _videoController = null;
          _isVideoInitialized = false;
        });
        _imageStartTime = DateTime.now().millisecondsSinceEpoch;
      }
    } catch (e) {
      print('Error initializing media: $e');
       if (mounted && requestVersion == _mediaInitVersion) {
         setState(() {
            _isVideoInitialized = false;
         });
       }
    }
  }

  Future<void> _moveToNextClip() async {
    _mediaInitVersion++;

    if (_currentClipIndex < _mediaClips.length - 1) {
      setState(() {
        _currentClipIndex++;
      });
      await _initializeCurrentMedia(wasPlaying: _isPlaying);
    } else {
      setState(() { _isPlaying = false; });
      await _videoController?.pause();
      _projectPositionNotifier.value = _totalProjectDuration;
    }
  }

  Future<void> _jumpToClip(int clipIndex) async {
    if (clipIndex == _currentClipIndex) return;

    final wasPlaying = _isPlaying;
    if (wasPlaying) {
      await _togglePlayPause();
    }

    _mediaInitVersion++;

    setState(() {
      _currentClipIndex = clipIndex;
    });

    await _initializeCurrentMedia(wasPlaying: wasPlaying);

    _updateProjectPosition();
  }

  Future<void> _preloadInitialVideos() async {
    for (int i = 0; i <= 2; i++) {
      if (i < _mediaClips.length) {
        final clip = _mediaClips[i];
        if (clip.asset.type == AssetType.video) {
          await _videoManager.preloadNextVideo(clip);
        }
      }
    }
  }
  
  Future<void> _togglePlayPause() async {
    setState(() { _isPlaying = !_isPlaying; });

    if (_mediaClips[_currentClipIndex].asset.type == AssetType.video) {
      if (_videoController != null && _isVideoInitialized) {
        final currentClip = _mediaClips[_currentClipIndex];
        if (_isPlaying) {
          if (_videoController!.value.position >= currentClip.endTime) {
            await _videoController!.seekTo(currentClip.startTime);
          }
          await _videoController!.play();
        } else {
          await _videoController!.pause();
        }
      }
    } else { // Image
      if (_isPlaying) {
        _imageStartTime = DateTime.now().millisecondsSinceEpoch;
      }
    }
  }
  
  Future<void> _preloadNextVideos() async {
      for (int i = 1; i <= 2; i++) {
        if (_currentClipIndex + i < _mediaClips.length) {
          final clip = _mediaClips[_currentClipIndex + i];
          if (clip.asset.type == AssetType.video) {
            await _videoManager.preloadNextVideo(clip);
          }
        }
      }
  }

  void _onClipTrimmed(int clipIndex, Duration newStartTime, Duration newEndTime) {
    setState(() {
      _mediaClips[clipIndex] = _mediaClips[clipIndex].copyWith(startTime: newStartTime, endTime: newEndTime);
    });
    _calculateTotalDuration();
    if (clipIndex == _currentClipIndex) {
      _mediaInitVersion++;
      _initializeCurrentMedia(wasPlaying: _isPlaying);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = (duration.inMilliseconds.remainder(1000) / 10).floor();
    return '${twoDigits(int.parse(minutes))}:${twoDigits(int.parse(seconds))}.${twoDigits(milliseconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.help_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _showExportDialog,
            child: const Text(
              'Export',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF1A1A1A), 
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildPreview(),
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          color: Colors.transparent,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ValueListenableBuilder<Duration>(
                              valueListenable: _projectPositionNotifier,
                              builder: (context, position, child) {
                                return Text(
                                  _formatDuration(position),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                            Text(
                              _formatDuration(_totalProjectDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 100,
            color: const Color(0xFF2A2A2A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolButton(
                  Icons.crop_free, 
                  'Canvas', 
                  false, 
                  onPressed: _navigateToCanvasScreen,
                ),
                _buildToolButton(Icons.music_note, 'Audio', false),
                _buildToolButton(Icons.emoji_emotions, 'Sticker', false),
                _buildToolButton(Icons.text_fields, 'Text', false),
                _buildToolButton(Icons.auto_awesome, 'Effect', true),
                _buildToolButton(Icons.filter, 'Filter', false),
                _buildToolButton(Icons.picture_in_picture, 'PIP', false),
              ],
            ),
          ),
          Container(
            height: 140,
            color: const Color(0xFF1A1A1A),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      child: FloatingActionButton(
                        onPressed: () {},
                        backgroundColor: Colors.red,
                        mini: true,
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 80,
                        child: _buildProportionalTimeline(),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: _buildTimelineRuler(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- MODIFIED: Rewritten to correctly apply the transformation ---
  Widget _buildPreview() {
    if (_mediaClips.isEmpty || _currentClipIndex >= _mediaClips.length) {
      return const Text('No media selected', style: TextStyle(color: Colors.white));
    }

    final currentClip = _mediaClips[_currentClipIndex];
    final canvasAspectRatio = _aspectRatios[currentClip.asset.id];
    final transformation = _transformations[currentClip.asset.id];
    Widget? content;
    double? intrinsicAspectRatio;

    if (currentClip.asset.type == AssetType.video && _isVideoInitialized && _videoController != null && _videoController!.value.isInitialized) {
      content = VideoPlayer(_videoController!);
      intrinsicAspectRatio = _videoController!.value.aspectRatio;
    } else if (currentClip.asset.type == AssetType.image) {
      content = FutureBuilder<Widget>(
        future: _buildImagePreview(currentClip.asset),
        builder: (context, snapshot) {
          if (snapshot.hasData) return snapshot.data!;
          return const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.purple));
        },
      );
      intrinsicAspectRatio = currentClip.asset.width / currentClip.asset.height;
    } else {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.purple)));
    }
    
    // The outer AspectRatio sets the final frame size.
    return AspectRatio(
      aspectRatio: canvasAspectRatio ?? intrinsicAspectRatio ?? 16 / 9,
      child: Container(
        color: Colors.black,
        child: ClipRect(
          // The Transform is now OUTSIDE the Center widget. This is the fix.
          // It transforms the entire viewport, and then the media is centered within it.
          // This correctly mimics the InteractiveViewer's behavior.
          child: Transform(
            transform: transformation ?? Matrix4.identity(),
            child: Center(
              child: AspectRatio(
                aspectRatio: intrinsicAspectRatio ?? 16 / 9,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Widget> _buildImagePreview(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null) {
        return Image.file(file, fit: BoxFit.cover);
      }
    } catch (e) {
      print('Error loading image preview: $e');
    }
    return const Text('Error loading preview', style: TextStyle(color: Colors.white));
  }

  Widget _buildToolButton(IconData icon, String label, bool hasNotification, {VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                if (hasNotification)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildProportionalTimeline() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalTimelineWidth = _totalProjectDuration.inMilliseconds / 1000.0 * pixelsPerSecond;
        return SingleChildScrollView(
          controller: _timelineScrollController,
          scrollDirection: Axis.horizontal,
          child: ValueListenableBuilder<Duration>(
            valueListenable: _projectPositionNotifier,
            builder: (context, position, child) {
              return ProportionalTimelineWidget(
                mediaClips: _mediaClips,
                currentClipIndex: _currentClipIndex,
                currentProjectPosition: position,
                totalProjectDuration: _totalProjectDuration,
                onClipTap: _jumpToClip,
                onTrimChanged: _onClipTrimmed,
                timelineWidth: totalTimelineWidth,
                pixelsPerSecond: pixelsPerSecond,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTimelineRuler() {
    final double totalTimelineWidth = _totalProjectDuration.inMilliseconds / 1000.0 * pixelsPerSecond;

    return SingleChildScrollView(
      controller: _rulerScrollController, 
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: SizedBox(
        width: totalTimelineWidth, 
        height: 40,
        child: TimelineRuler(
          totalDuration: _totalProjectDuration,
          pixelsPerSecond: pixelsPerSecond, 
        ),
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('Export Project', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Duration: ${_formatDuration(_totalProjectDuration)}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Text('Clips: ${_mediaClips.length}', style: const TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Export', style: TextStyle(color: Colors.purple)),
            ),
          ],
        );
      },
    );
  }
}