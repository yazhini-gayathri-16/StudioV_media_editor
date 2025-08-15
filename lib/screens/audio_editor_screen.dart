import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:studiov_media_editor/screens/text_editor_screen.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';

import '../models/audio_clip_model.dart';
import '../models/media_clip.dart';
import '../services/video_player_manager.dart';
import '../services/audio_manager.dart';
import '../widgets/audio_timeline_widget.dart';
import '../widgets/proportional_timeline_widget.dart';
import '../widgets/timeline_ruler.dart';
import 'audio_picker_screen.dart';

class AudioEditorScreen extends StatefulWidget {
  final List<MediaClip> mediaClips;
  final List<AudioClip> initialAudioClips;
  final VideoPlayerManager videoManager; // Pass manager for consistency

  const AudioEditorScreen({
    super.key,
    required this.mediaClips,
    required this.initialAudioClips,
    required this.videoManager,
  });

  @override
  State<AudioEditorScreen> createState() => _AudioEditorScreenState();
}

class _AudioEditorScreenState extends State<AudioEditorScreen> {
  List<AudioClip> _audioClips = [];
  String? _selectedAudioClipId;

  final ValueNotifier<Duration> _projectPositionNotifier = ValueNotifier(Duration.zero);
  final ScrollController _timelineScrollController = ScrollController();
  final ScrollController _rulerScrollController = ScrollController();

  Duration _totalProjectDuration = Duration.zero;
  static const double pixelsPerSecond = 20.0;

  // --- NEW: State for video playback ---
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  int _currentClipIndex = 0;
  int _imageStartTime = 0;
  int _mediaInitVersion = 0;
  Timer? _positionTimer;
  final AudioManager _audioManager = AudioManager();

  // ... other variables
  bool _isTransitioning = false; // Add this line
  DateTime _playbackStartTime = DateTime.now();
  Duration _positionAtPlaybackStart = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioClips = List.from(widget.initialAudioClips);
    _audioManager.setClips(_audioClips);
    _calculateTotalDuration();

    _timelineScrollController.addListener(_syncRulerScroll);
    _rulerScrollController.addListener(_syncTimelineScroll);

    _initializeCurrentMedia();
    _startPositionTimer();
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    _rulerScrollController.dispose();
    _projectPositionNotifier.dispose();
    _positionTimer?.cancel();
    _audioManager.dispose();
    // Note: We don't dispose the videoManager here as it's managed by the main EditorScreen
    super.dispose();
  }
  
  // --- NEW: All playback and timeline logic from here ---

  void _calculateTotalDuration() {
    _totalProjectDuration = widget.mediaClips.fold(
      Duration.zero,
      (total, clip) => total + clip.trimmedDuration,
    );
    if (mounted) setState(() {});
  }

  void _syncRulerScroll() {
    if (_rulerScrollController.hasClients && _rulerScrollController.offset != _timelineScrollController.offset) {
      _rulerScrollController.jumpTo(_timelineScrollController.offset);
    }
  }

  void _syncTimelineScroll() {
    if (_timelineScrollController.hasClients && _timelineScrollController.offset != _rulerScrollController.offset) {
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

  Future<void> _initializeCurrentMedia({bool wasPlaying = false}) async {
    final int requestVersion = ++_mediaInitVersion;
    if (_currentClipIndex >= widget.mediaClips.length || !mounted) return;

    final currentClip = widget.mediaClips[_currentClipIndex];
    setState(() => _isVideoInitialized = false);

    try {
      if (currentClip.asset.type == AssetType.video) {
        final controller = await widget.videoManager.getController(currentClip);
        if (!mounted || requestVersion != _mediaInitVersion) return;

        setState(() {
          _videoController = controller;
          _isVideoInitialized = controller != null && controller.value.isInitialized;
        });

        if (wasPlaying && _videoController != null) {
          await _videoController!.seekTo(currentClip.startTime);
          await _videoController!.play();
        }
      } else { // Image
        if (!mounted || requestVersion != _mediaInitVersion) return;
        setState(() {
          _videoController = null;
          _isVideoInitialized = true; // Mark as initialized to show image
        });
        if (wasPlaying) {
          _imageStartTime = DateTime.now().millisecondsSinceEpoch - (_projectPositionNotifier.value.inMilliseconds - _getClipStartOffset(_currentClipIndex).inMilliseconds);
        }
      }
    } catch (e) {
      debugPrint("Error initializing media in AudioEditor: $e");
    }
  }

  void _updateProjectPosition() {
  if (!_isPlaying || _isTransitioning || !mounted) return;

  // --- FIX: This is the new, reliable logic for updating the timeline ---

  // 1. Calculate the new position based on real-world time elapsed
  final elapsed = DateTime.now().difference(_playbackStartTime);
  final newPosition = _positionAtPlaybackStart + elapsed;

  // 2. Update the ValueNotifier. This will make the white line move.
  final clampedPosition = newPosition.clamp(Duration.zero, _totalProjectDuration);
  _projectPositionNotifier.value = clampedPosition;

  // 3. Check if it's time to switch to the next video/image clip
  final currentClip = widget.mediaClips[_currentClipIndex];
  final currentClipEndPosition = _getClipStartOffset(_currentClipIndex) + currentClip.trimmedDuration;

  if (clampedPosition >= currentClipEndPosition && _currentClipIndex < widget.mediaClips.length - 1) {
    // The master clock has passed the end of the current clip, so move to the next one.
    _moveToNextClip();
  } else if (clampedPosition >= _totalProjectDuration) {
    // End of the entire project
    if (_isPlaying) _togglePlayPause();
    _seekToPosition(Duration.zero);
  }

  // 4. Auto-scroll the timeline to keep the playhead in view
  _updateTimelineScroll();
}
  
  Duration _getClipStartOffset(int index) {
    Duration offset = Duration.zero;
    for (int i = 0; i < index; i++) {
      offset += widget.mediaClips[i].trimmedDuration;
    }
    return offset;
  }

  Future<void> _moveToNextClip() async {
    // FIX: Add guard and wrap logic in a try/finally block with the lock
    if (_isTransitioning) return;

    setState(() {
      _isTransitioning = true;
    });

    try {
      if (_currentClipIndex < widget.mediaClips.length - 1) {
        setState(() => _currentClipIndex++);
        await _initializeCurrentMedia(wasPlaying: _isPlaying);
      } else { // End of project
        await _togglePlayPause(); // Pause everything
        await _seekToPosition(Duration.zero); // Reset to start
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
        });
      }
    }
}
  
  Future<void> _seekToPosition(Duration targetPosition) async {
  final clampedPosition = targetPosition.clamp(Duration.zero, _totalProjectDuration);
  _projectPositionNotifier.value = clampedPosition;

  // FIX: Reset the master clock's reference points whenever we seek
  _positionAtPlaybackStart = clampedPosition;
  _playbackStartTime = DateTime.now();
    
    int targetClipIndex = 0;
    Duration accumulatedDuration = Duration.zero;
    for (int i = 0; i < widget.mediaClips.length; i++) {
        final clipDuration = widget.mediaClips[i].trimmedDuration;
        if (targetPosition <= accumulatedDuration + clipDuration) {
            targetClipIndex = i;
            break;
        }
        accumulatedDuration += clipDuration;
    }

    if (targetClipIndex != _currentClipIndex) {
      setState(() => _currentClipIndex = targetClipIndex);
      await _initializeCurrentMedia(wasPlaying: _isPlaying);
    }

    final positionInClip = targetPosition - accumulatedDuration;
    final currentClip = widget.mediaClips[_currentClipIndex];

    if (currentClip.asset.type == AssetType.video && _videoController != null) {
      final seekTime = (currentClip.startTime + positionInClip).clamp(currentClip.startTime, currentClip.endTime);
      await _videoController!.seekTo(seekTime);
    } else if (currentClip.asset.type == AssetType.image) {
       _imageStartTime = DateTime.now().millisecondsSinceEpoch - positionInClip.inMilliseconds;
    }

    await _audioManager.seek(targetPosition);
  }

  Future<void> _togglePlayPause() async {
  setState(() => _isPlaying = !_isPlaying);
  if (_isPlaying) {
    // FIX: Record the starting point for our new "master clock"
    _playbackStartTime = DateTime.now();
    _positionAtPlaybackStart = _projectPositionNotifier.value;

    await _audioManager.play(_projectPositionNotifier.value);
    if (widget.mediaClips[_currentClipIndex].asset.type == AssetType.video) {
      await _videoController?.play();
    } else {
      final clipStartOffset = _getClipStartOffset(_currentClipIndex);
      final positionInClip = _projectPositionNotifier.value - clipStartOffset;
      _imageStartTime = DateTime.now().millisecondsSinceEpoch - positionInClip.inMilliseconds;
    }
  } else {
    await _audioManager.pause();
    await _videoController?.pause();
  }
}
  
  void _updateTimelineScroll() {
    if (!_timelineScrollController.hasClients || !_isPlaying) return;
    final double playheadX = _projectPositionNotifier.value.inMilliseconds / 1000.0 * pixelsPerSecond;
    final double viewportWidth = _timelineScrollController.position.viewportDimension;
    final double currentOffset = _timelineScrollController.offset;
    final double targetOffset = (playheadX - (viewportWidth / 2)).clamp(
      _timelineScrollController.position.minScrollExtent,
      _timelineScrollController.position.maxScrollExtent,
    );
    _timelineScrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 100), curve: Curves.linear);
  }

  Future<void> _navigateAndPickAudio() async {
    if (_isPlaying) await _togglePlayPause();

    final result = await Navigator.push<AssetEntity>(
      context,
      MaterialPageRoute(builder: (context) => const AudioPickerScreen()),
    );

    if (result != null) {
      final audioFile = await result.file;
      if (audioFile == null) return;

      final newClip = AudioClip.fromFile(
        path: audioFile.path,
        name: result.title ?? 'Unknown Audio',
        totalProjectDuration: _totalProjectDuration,
        audioFileDuration: Duration(seconds: result.duration),
        playheadPosition: _projectPositionNotifier.value,
      );
      
      setState(() {
        _audioClips.add(newClip);
        _audioManager.setClips(_audioClips);
        _selectedAudioClipId = newClip.id;
      });

      // --- FIX: Re-sync playback state after adding the clip ---
      // This ensures the current video clip (even if it's the first one)
      // is correctly positioned and ready to play.
      await _seekToPosition(_projectPositionNotifier.value);
    }
  }

  void _updateAudioClip(AudioClip updatedClip) {
    setState(() {
      final index = _audioClips.indexWhere((c) => c.id == updatedClip.id);
      if (index != -1) {
        _audioClips[index] = updatedClip;
        _audioManager.setClips(_audioClips);
      }
    });
  }
  
  void _deleteSelectedAudioClip() {
    if (_selectedAudioClipId == null) return;
    setState(() {
      _audioClips.removeWhere((clip) => clip.id == _selectedAudioClipId);
      _audioManager.setClips(_audioClips);
      _selectedAudioClipId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Edit Audio', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.pop(context, AudioEditorResult(audioClips: _audioClips));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              child: Column(
                children: [
                  Expanded(child: _buildVideoPreview()),
                  _buildPlaybackControls(),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildTimelineSection(),
          ),
          _buildBottomToolbar(),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (!_isVideoInitialized || widget.mediaClips.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.purple));
    }

    final currentClip = widget.mediaClips[_currentClipIndex];
    Widget content;

    if (currentClip.asset.type == AssetType.video && _videoController != null) {
      content = VideoPlayer(_videoController!);
    } else {
      content = FutureBuilder<File?>(
        future: currentClip.asset.file,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.file(snapshot.data!, fit: BoxFit.contain);
          }
          return Container(color: Colors.black);
        },
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
        child: content,
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ValueListenableBuilder<Duration>(
            valueListenable: _projectPositionNotifier,
            builder: (context, position, child) {
              return Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
          const Spacer(),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 40),
            onPressed: _togglePlayPause,
          ),
          const Spacer(),
          Text(
            _formatDuration(_totalProjectDuration),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final double totalTimelineWidth = _totalProjectDuration.inMilliseconds / 1000.0 * pixelsPerSecond;
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _timelineScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalTimelineWidth,
                child: GestureDetector(
                  onTapDown: (details) async {
                    if (_isPlaying) await _togglePlayPause();
                    final positionInSeconds = details.localPosition.dx / pixelsPerSecond;
                    _seekToPosition(Duration(milliseconds: (positionInSeconds * 1000).round()));
                  },
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: ProportionalTimelineWidget(
                          mediaClips: widget.mediaClips,
                          currentClipIndex: _currentClipIndex,
                          currentProjectPosition: _projectPositionNotifier.value,
                          totalProjectDuration: _totalProjectDuration,
                          onClipTap: (_) {},
                          onTrimChanged: (_, __, ___) {},
                          timelineWidth: totalTimelineWidth,
                          pixelsPerSecond: pixelsPerSecond,
                        ),
                      ),
                      ..._audioClips.asMap().entries.map((entry) {
                        int index = entry.key;
                        AudioClip clip = entry.value;
                        return AudioTimelineWidget(
                          audioClip: clip,
                          pixelsPerSecond: pixelsPerSecond,
                          isSelected: _selectedAudioClipId == clip.id,
                          topPosition: 10.0 + (index * 50.0),
                          totalProjectDuration: _totalProjectDuration,
                          onTap: () => setState(() => _selectedAudioClipId = clip.id),
                          onDurationChanged: (newStart, newEnd) {
                            _updateAudioClip(clip.copyWith(startTime: newStart, endTime: newEnd));
                          }, onPositionChanged: (Duration dragDelta) {  },
                        );
                      }).toList(),
                      ValueListenableBuilder<Duration>(
                        valueListenable: _projectPositionNotifier,
                        builder: (context, position, child) => _buildPlayhead(totalTimelineWidth, position),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayhead(double timelineWidth, Duration position) {
    return Positioned(
      left: (position.inMilliseconds / 1000.0 * pixelsPerSecond).clamp(0.0, timelineWidth) - 1.5,
      top: 0,
      bottom: 0,
      child: Container(
        width: 3,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    final bool isClipSelected = _selectedAudioClipId != null;
    return Container(
      height: 100,
      color: const Color(0xFF2A2A2A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolButton(
            icon: Icons.music_note,
            label: 'Music',
            onPressed: _navigateAndPickAudio,
          ),
          _buildToolButton(
            icon: Icons.volume_up,
            label: 'Volume',
            isEnabled: isClipSelected,
            onPressed: () { /* TODO: Implement volume adjustment UI */ },
          ),
          _buildToolButton(
            icon: Icons.content_cut,
            label: 'Split',
            isEnabled: isClipSelected,
            onPressed: () { /* TODO: Implement split logic */ },
          ),
          _buildToolButton(
            icon: Icons.delete,
            label: 'Delete',
            isEnabled: isClipSelected,
            onPressed: _deleteSelectedAudioClip,
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    final color = isEnabled ? Colors.white : Colors.grey.shade600;
    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}