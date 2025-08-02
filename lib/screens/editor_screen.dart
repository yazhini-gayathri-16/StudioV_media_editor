import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../models/media_clip.dart';
import '../widgets/proportional_timeline_widget.dart';
import '../widgets/timeline_ruler.dart';
import '../services/video_player_manager.dart';
import 'dart:async'; // Add this import for Timer and StreamSubscription
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class EditorScreen extends StatefulWidget {
  final List<MediaClip> mediaClips;

  const EditorScreen({
    Key? key,
    required this.mediaClips,
  }) : super(key: key);

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int _currentClipIndex = 0;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isVideoInitialized = false;
  Duration _totalProjectDuration = Duration.zero;
  Duration _currentProjectPosition = Duration.zero;
  List<MediaClip> _mediaClips = [];
  Timer? _imageTimer;
  Timer? _positionTimer;
  bool _isInitializing = false;
  StreamSubscription<dynamic>? _videoSubscription; 
  int _imageStartTime = 0;
  final ScrollController _timelineScrollController = ScrollController();
  final VideoPlayerManager _videoManager = VideoPlayerManager();

  @override
  void initState() {
    super.initState();
    _mediaClips = List.from(widget.mediaClips);
    _calculateTotalDuration();
    _initializeCurrentMedia();
    _startPositionTimer();
  }

  @override
  void dispose() {
    _videoManager.dispose();
    _imageTimer?.cancel();
    _positionTimer?.cancel();
    _videoSubscription?.cancel();
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel(); // Cancel any existing timer
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
    
    // Add duration of all previous clips
    for (int i = 0; i < _currentClipIndex; i++) {
      newPosition += _mediaClips[i].trimmedDuration;
    }
    
    // Add current position within the current clip
    if (currentClip.asset.type == AssetType.video && _videoController != null && _isVideoInitialized) {
      final videoPosition = _videoController!.value.position;
      final clipProgressMs = (videoPosition - currentClip.startTime)
          .inMilliseconds
          .clamp(0, currentClip.trimmedDuration.inMilliseconds);
      newPosition += Duration(milliseconds: clipProgressMs);
      
      // Check if we need to move to next clip
      if (videoPosition >= currentClip.endTime && !_isInitializing) {
        _moveToNextClip();
        return;
      }
    } else if (currentClip.asset.type == AssetType.image) {
      // For images, calculate based on how long it's been playing
      final elapsed = DateTime.now().millisecondsSinceEpoch - _imageStartTime;
      final imageProgressMs = elapsed.clamp(0, currentClip.trimmedDuration.inMilliseconds);
      newPosition += Duration(milliseconds: imageProgressMs);
      
      // Check if image duration is complete
      if (Duration(milliseconds: imageProgressMs) >= currentClip.trimmedDuration && !_isInitializing) {
        _moveToNextClip();
        return;
      }
    }
    
    setState(() {
      _currentProjectPosition = newPosition;
    });
  }

  void _calculateTotalDuration() {
    _totalProjectDuration = _mediaClips.fold(
      Duration.zero,
      (total, clip) => total + clip.trimmedDuration,
    );
  }

  Future<void> _initializeCurrentMedia() async {
    if (_currentClipIndex >= _mediaClips.length || _isInitializing) return;
    
    _isInitializing = true;
    final currentClip = _mediaClips[_currentClipIndex];
    
    try {
      if (currentClip.asset.type == AssetType.video) {
        await _initializeVideo(currentClip);
      } else {
        await _initializeImage(currentClip);
      }
    } catch (e) {
      print('Error initializing media: $e');
    } finally {
      _isInitializing = false;
    }
  }

Future<void> _initializeVideo(MediaClip clip) async {
  try {
    setState(() {
      _isVideoInitialized = false;
    });

    final controller = await _videoManager.getController(clip);
    if (controller != null) {
      _videoController = controller;
      
      // Seek to the start time of the clip
      await _videoController!.seekTo(clip.startTime);
      
      setState(() {
        _isVideoInitialized = true;
      });
      
      // If we were playing, continue playing the new video
      if (_isPlaying) {
        await _videoController!.play();
      }
    }
  } catch (e) {
    print('Error initializing video: $e');
    setState(() {
      _isVideoInitialized = false;
    });
  }
}

  Future<void> _initializeImage(MediaClip clip) async {
    // Dispose video controller for images
    await _videoController?.dispose();
    _videoController = null;
    _videoSubscription?.cancel();
    
    setState(() {
      _isVideoInitialized = false;
    });
    
    // Set image start time for duration tracking
    _imageStartTime = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _moveToNextClip() async {
    if (_isInitializing) return;
    
    if (_currentClipIndex < _mediaClips.length - 1) {
      setState(() {
        _currentClipIndex++;
      });
      
      await _initializeCurrentMedia();
    } else {
      // End of all clips - stop playback
      setState(() {
        _isPlaying = false;
      });
      
      if (_videoController != null) {
        await _videoController!.pause();
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isInitializing) return;
    
    final currentClip = _mediaClips[_currentClipIndex];
    
    if (currentClip.asset.type == AssetType.video && _videoController != null && _isVideoInitialized) {
      setState(() {
        _isPlaying = !_isPlaying;
      });
      
      if (_isPlaying) {
        await _videoController!.play();
      } else {
        await _videoController!.pause();
      }
    } else if (currentClip.asset.type == AssetType.image) {
      setState(() {
        _isPlaying = !_isPlaying;
      });
      
      if (_isPlaying) {
        _imageStartTime = DateTime.now().millisecondsSinceEpoch;
      }
    }
  }

  void _onClipTrimmed(int clipIndex, Duration newStartTime, Duration newEndTime) {
    setState(() {
      _mediaClips[clipIndex] = _mediaClips[clipIndex].copyWith(
        startTime: newStartTime,
        endTime: newEndTime,
      );
    });
    _calculateTotalDuration();
    
    // If we're currently playing the trimmed clip, reinitialize it
    if (clipIndex == _currentClipIndex) {
      _initializeCurrentMedia();
    }
  }

  void _jumpToClip(int clipIndex) async {
    if (clipIndex == _currentClipIndex || _isInitializing) return;
    
    final wasPlaying = _isPlaying;
    
    // Pause current playback
    if (_isPlaying) {
      setState(() {
        _isPlaying = false;
      });
      
      if (_videoController != null) {
        await _videoController!.pause();
      }
    }
    
    // Change to new clip
    setState(() {
      _currentClipIndex = clipIndex;
    });
    
    await _initializeCurrentMedia();
    
    // Resume playback if it was playing before
    if (wasPlaying) {
      await _togglePlayPause();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final milliseconds = (duration.inMilliseconds.remainder(1000) / 10).floor();
    return '${twoDigits(minutes)}:${twoDigits(seconds)}.${twoDigits(milliseconds)}';
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
          // Preview Area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  Center(
                    child: _buildPreview(),
                  ),
                  // Play/Pause overlay
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
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Project time indicator
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_currentProjectPosition),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            _formatDuration(_totalProjectDuration),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Loading indicator
                  if (_isInitializing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Editing Tools
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
          
          // Timeline Section
          Container(
            height: 140,
            color: const Color(0xFF1A1A1A),
            child: Column(
              children: [
                // Add button and timeline
                Row(
                  children: [
                    // Add button
                    Container(
                      margin: const EdgeInsets.all(16),
                      child: FloatingActionButton(
                        onPressed: () {
                          // Add new media functionality
                        },
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.add, color: Colors.white),
                        mini: true,
                      ),
                    ),
                    // Timeline with clips
                    Expanded(
                      child: Container(
                        height: 80,
                        child: _buildProportionalTimeline(),
                      ),
                    ),
                  ],
                ),
                // Timeline ruler with timestamps
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 56), // Account for add button
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
    if (_currentClipIndex >= _mediaClips.length) {
      return const Text('No media selected', style: TextStyle(color: Colors.white));
    }

    final currentClip = _mediaClips[_currentClipIndex];
    
    if (currentClip.asset.type == AssetType.video && _isVideoInitialized && _videoController != null) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else {
      return FutureBuilder<Widget>(
        future: _buildImagePreview(currentClip.asset),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return snapshot.data!;
          }
          return const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          );
        },
      );
    }
  }

  Future<Widget> _buildImagePreview(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null) {
        return Image.file(
          file,
          fit: BoxFit.contain,
        );
      }
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
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildProportionalTimeline() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final timelineWidth = constraints.maxWidth;
        
        return SingleChildScrollView(
          controller: _timelineScrollController,
          scrollDirection: Axis.horizontal,
          child: ProportionalTimelineWidget(
            mediaClips: _mediaClips,
            currentClipIndex: _currentClipIndex,
            currentProjectPosition: _currentProjectPosition,
            totalProjectDuration: _totalProjectDuration,
            timelineWidth: timelineWidth,
            onClipTap: _jumpToClip,
            onTrimChanged: _onClipTrimmed,
          ),
        );
      },
    );
  }

  Widget _buildTimelineRuler() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _timelineScrollController,
          scrollDirection: Axis.horizontal,
          child: TimelineRuler(
            totalDuration: _totalProjectDuration,
            timelineWidth: constraints.maxWidth,
            scrollController: _timelineScrollController,
          ),
        );
      },
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
              Text(
                'Total Duration: ${_formatDuration(_totalProjectDuration)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Text(
                'Clips: ${_mediaClips.length}',
                style: const TextStyle(color: Colors.white70),
              ),
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
                // Implement export logic
              },
              child: const Text('Export', style: TextStyle(color: Colors.purple)),
            ),
          ],
        );
      },
    );
  }
}
