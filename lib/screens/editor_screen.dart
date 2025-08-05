import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../models/media_clip.dart';
import '../widgets/proportional_timeline_widget.dart';
import '../widgets/timeline_ruler.dart';
import '../services/video_player_manager.dart';
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
  static const double pixelsPerSecond = 60.0;

  final ValueNotifier<Duration> _projectPositionNotifier = ValueNotifier(Duration.zero);
  List<MediaClip> _mediaClips = [];
  Timer? _positionTimer;
  int _imageStartTime = 0;

  final VideoPlayerManager _videoManager = VideoPlayerManager();

  final ScrollController _timelineScrollController = ScrollController();
  final ScrollController _rulerScrollController = ScrollController();

  int _mediaInitVersion = 0;

  @override
  void initState() {
    super.initState();
    _mediaClips = List.from(widget.mediaClips);
    _calculateTotalDuration();

    _timelineScrollController.addListener(_syncRulerScroll);
    _rulerScrollController.addListener(_syncTimelineScroll);

    _initializeCurrentMedia();
    _startPositionTimer();
    _preloadInitialVideos(); // This call will now work correctly
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
    if (_currentClipIndex >= _mediaClips.length) return;

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
  }

  void _calculateTotalDuration() {
    _totalProjectDuration = _mediaClips.fold(Duration.zero, (total, clip) => total + clip.trimmedDuration);
    if (mounted) setState(() {});
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

  // --- METHOD ADDED ---
  Future<void> _preloadInitialVideos() async {
    // Preload the first few clips on initial load
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
              color: Colors.black,
              child: Stack(
                children: [
                  Center(child: _buildPreview()),
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
          Container(
            height: 100,
            color: const Color(0xFF2A2A2A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolButton(Icons.crop_free, 'Canvas', false),
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

  Widget _buildPreview() {
    if (_mediaClips.isEmpty || _currentClipIndex >= _mediaClips.length) {
      return const Text('No media selected', style: TextStyle(color: Colors.white));
    }

    final currentClip = _mediaClips[_currentClipIndex];

    if (currentClip.asset.type == AssetType.video && _isVideoInitialized && _videoController != null && _videoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else if (currentClip.asset.type == AssetType.image) {
      return FutureBuilder<Widget>(
        future: _buildImagePreview(currentClip.asset),
        builder: (context, snapshot) {
          if (snapshot.hasData) return snapshot.data!;
          return const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.purple));
        },
      );
    } else {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.purple)));
    }
  }

  Future<Widget> _buildImagePreview(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null) return Image.file(file, fit: BoxFit.contain);
    } catch (e) {
      print('Error loading image preview: $e');
    }
    return const Text('Error loading preview', style: TextStyle(color: Colors.white));
  }

  Widget _buildToolButton(IconData icon, String label, bool hasNotification) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            if (hasNotification)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }

  Widget _buildProportionalTimeline() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final timelineWidth = constraints.maxWidth;
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
                // --- FIX: Pass the CALCULATED total width ---
                timelineWidth: totalTimelineWidth,
                // --- NEW: Pass the scale ---
                pixelsPerSecond: pixelsPerSecond,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTimelineRuler() {
    // --- FIX: Calculate the total width exactly as we did for the clips timeline ---
    final double totalTimelineWidth = _totalProjectDuration.inMilliseconds / 1000.0 * pixelsPerSecond;

    return SingleChildScrollView(
      controller: _rulerScrollController, // Uses the synchronized controller
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), // The user scrolls the top timeline
      child: SizedBox(
        width: totalTimelineWidth, // Crucial: Give the ruler its full width
        height: 40,
        child: TimelineRuler(
          totalDuration: _totalProjectDuration,
          pixelsPerSecond: pixelsPerSecond, // Pass the scale
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