import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../models/media_clip.dart';
import '../widgets/timeline_clip_widget.dart';
import 'dart:async';

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
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _mediaClips = List.from(widget.mediaClips);
    _calculateTotalDuration();
    _initializeCurrentMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _imageTimer?.cancel();
    super.dispose();
  }

  void _calculateTotalDuration() {
    _totalProjectDuration = _mediaClips.fold(
      Duration.zero,
      (total, clip) => total + clip.trimmedDuration,
    );
  }

  Future<void> _initializeCurrentMedia() async {
    if (_currentClipIndex >= _mediaClips.length) return;
    
    final currentClip = _mediaClips[_currentClipIndex];
    
    if (currentClip.asset.type == AssetType.video) {
      await _initializeVideo(currentClip);
    } else {
      await _initializeImage(currentClip);
    }
  }

  Future<void> _initializeVideo(MediaClip clip) async {
    try {
      final file = await clip.asset.file;
      if (file != null) {
        _videoController?.dispose();
        _videoController = VideoPlayerController.file(file);
        
        await _videoController!.initialize();
        
        // Seek to the start time of the clip
        await _videoController!.seekTo(clip.startTime);
        
        _videoController!.addListener(_videoListener);

        setState(() {
          _isVideoInitialized = true;
          _isPlaying = false;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  Future<void> _initializeImage(MediaClip clip) async {
    _videoController?.dispose();
    _videoController = null;
    _imageTimer?.cancel();
    
    setState(() {
      _isVideoInitialized = false;
      _isPlaying = false;
    });
  }

  void _videoListener() {
    if (!mounted || _videoController == null || _isTransitioning) return;
    
    final currentClip = _mediaClips[_currentClipIndex];
    final position = _videoController!.value.position;
    
    setState(() {
      _currentProjectPosition = _getProjectPosition(position);
    });
    
    // Check if we've reached the end of the current clip (with trimming)
    if (position >= currentClip.endTime) {
      _playNextClip();
    }
  }

    Duration _getProjectPosition(Duration currentClipPosition) {
    Duration projectPosition = Duration.zero;
    
    // Add duration of all previous clips
    for (int i = 0; i < _currentClipIndex; i++) {
      projectPosition += _mediaClips[i].trimmedDuration;
    }
    
    // Add current position within the current clip
    final currentClip = _mediaClips[_currentClipIndex];
    if (currentClip.asset.type == AssetType.video) {
      // Convert to milliseconds, clamp, then convert back to Duration
      final clipProgressMs = (currentClipPosition - currentClip.startTime)
          .inMilliseconds
          .clamp(0, currentClip.trimmedDuration.inMilliseconds);
      projectPosition += Duration(milliseconds: clipProgressMs);
    } else {
      // For images, calculate based on elapsed time
      projectPosition += _currentProjectPosition - _getPreviousClipsDuration();
    }
    
    return projectPosition;
  }

  Duration _getPreviousClipsDuration() {
    Duration duration = Duration.zero;
    for (int i = 0; i < _currentClipIndex; i++) {
      duration += _mediaClips[i].trimmedDuration;
    }
    return duration;
  }

  void _playNextClip() async {
    if (_isTransitioning) return;
    
    _isTransitioning = true;
    
    if (_currentClipIndex < _mediaClips.length - 1) {
      setState(() {
        _currentClipIndex++;
      });
      
      await _initializeCurrentMedia();
      
      if (_isPlaying) {
        // Auto-play the next clip after a short delay
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _isTransitioning = false;
            _togglePlayPause();
          }
        });
      } else {
        _isTransitioning = false;
      }
    } else {
      // End of all clips
      setState(() {
        _isPlaying = false;
        _isTransitioning = false;
      });
    }
  }

  void _togglePlayPause() {
    final currentClip = _mediaClips[_currentClipIndex];
    
    if (currentClip.asset.type == AssetType.video && _videoController != null && _isVideoInitialized) {
      setState(() {
        if (_isPlaying) {
          _videoController!.pause();
          _isPlaying = false;
        } else {
          _videoController!.play();
          _isPlaying = true;
        }
      });
    } else if (currentClip.asset.type == AssetType.image) {
      setState(() {
        _isPlaying = !_isPlaying;
      });
      
      if (_isPlaying) {
        _imageTimer?.cancel();
        _imageTimer = Timer(currentClip.trimmedDuration, () {
          if (mounted && _isPlaying) {
            _playNextClip();
          }
        });
      } else {
        _imageTimer?.cancel();
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
                        child: _buildEnhancedTimeline(),
                      ),
                    ),
                  ],
                ),
                // Time indicators
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTimeIndicators(),
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

  Widget _buildEnhancedTimeline() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _mediaClips.length,
      itemBuilder: (context, index) {
        final clip = _mediaClips[index];
        final isSelected = index == _currentClipIndex;
        
        return TimelineClipWidget(
          clip: clip,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _currentClipIndex = index;
            });
            _initializeCurrentMedia();
          },
          onTrimChanged: (newStartTime, newEndTime) {
            _onClipTrimmed(index, newStartTime, newEndTime);
          },
        );
      },
    );
  }

  Widget _buildTimeIndicators() {
    List<Widget> indicators = [];
    Duration currentTime = Duration.zero;
    
    for (int i = 0; i < _mediaClips.length; i++) {
      final clip = _mediaClips[i];
      
      indicators.add(
        Positioned(
          left: (currentTime.inMilliseconds / _totalProjectDuration.inMilliseconds) * 
                (MediaQuery.of(context).size.width - 80),
          child: Text(
            _formatDuration(currentTime),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      );
      
      currentTime += clip.trimmedDuration;
    }
    
    // Add final time indicator
    indicators.add(
      Positioned(
        right: 0,
        child: Text(
          _formatDuration(_totalProjectDuration),
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
    );
    
    return Stack(children: indicators);
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
