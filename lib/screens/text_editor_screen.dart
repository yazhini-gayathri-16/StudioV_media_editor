// lib/screens/text_editor_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../models/media_clip.dart';
import '../models/text_overlay_model.dart';
import '../services/video_player_manager.dart';
import '../widgets/interactive_text_widget.dart';
import '../widgets/proportional_timeline_widget.dart';
import '../widgets/text_timeline_widget.dart';

class TextEditorResult {
  final List<TextOverlay> overlays;
  TextEditorResult({required this.overlays});
}

extension DurationClamp on Duration {
  Duration clamp(Duration lowerLimit, Duration upperLimit) {
    if (this < lowerLimit) return lowerLimit;
    if (this > upperLimit) return upperLimit;
    return this;
  }
}

class TextEditorScreen extends StatefulWidget {
  final List<MediaClip> mediaClips;
  final double? canvasAspectRatio;
  final Matrix4? canvasTransform;
  final VideoPlayerManager videoManager;
  final List<TextOverlay> initialOverlays;

  const TextEditorScreen({
    super.key,
    required this.mediaClips,
    this.canvasAspectRatio,
    this.canvasTransform,
    required this.videoManager,
    required this.initialOverlays,
  });

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  Duration _totalProjectDuration = Duration.zero;
  static const double pixelsPerSecond = 20.0;
  final ValueNotifier<Duration> _projectPositionNotifier = ValueNotifier(Duration.zero);
  final ScrollController _timelineScrollController = ScrollController();
  
  List<TextOverlay> _overlays = [];
  String? _selectedOverlayId;

  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  Timer? _positionTimer;
  bool _isPlaying = false;
  int _currentClipIndex = 0;
  int _imageStartTime = 0;
  int _mediaInitVersion = 0;

  @override
  void initState() {
    super.initState();
    _overlays = List.from(widget.initialOverlays);
    _calculateTotalDuration();
    // Start playing immediately when entering the screen
    _isPlaying = true; 
    _initializeCurrentMedia(wasPlaying: _isPlaying);
    _startPositionTimer();
  }

  void _calculateTotalDuration() {
    _totalProjectDuration = widget.mediaClips.fold(Duration.zero, (total, clip) => total + clip.trimmedDuration);
  }
  
  // --- MODIFIED: Removed setLooping(true) to allow continuous playback ---
  Future<void> _initializeCurrentMedia({bool wasPlaying = false}) async {
    final int requestVersion = ++_mediaInitVersion;
    if (_currentClipIndex >= widget.mediaClips.length) return;

    final currentClip = widget.mediaClips[_currentClipIndex];
    if (mounted) setState(() => _isVideoInitialized = false);

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
        } else if (_videoController != null) {
          // No longer sets looping, allowing our custom timeline logic to take over
          _videoController!.play();
        }
      } else { 
        await widget.videoManager.getController(currentClip);
        if (!mounted || requestVersion != _mediaInitVersion) return;
        setState(() {
          _videoController = null;
          _isVideoInitialized = false;
        });
        if (wasPlaying) _imageStartTime = DateTime.now().millisecondsSinceEpoch;
      }
    } catch (e) {
      print("Error initializing media in TextEditor: $e");
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted && _isPlaying) _updateProjectPosition();
    });
  }

  void _updateProjectPosition() {
    if (_currentClipIndex >= widget.mediaClips.length) return;
    final currentClip = widget.mediaClips[_currentClipIndex];
    Duration newPosition = Duration.zero;
    for (int i = 0; i < _currentClipIndex; i++) {
      newPosition += widget.mediaClips[i].trimmedDuration;
    }

    if (currentClip.asset.type == AssetType.video && _videoController != null && _isVideoInitialized) {
      final videoPosition = _videoController!.value.position;
      newPosition += (videoPosition - currentClip.startTime);
      if (videoPosition >= currentClip.endTime) _moveToNextClip();
    } else if (currentClip.asset.type == AssetType.image) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - _imageStartTime;
      newPosition += Duration(milliseconds: elapsed);
      if (Duration(milliseconds: elapsed) >= currentClip.trimmedDuration) _moveToNextClip();
    }
    
    _projectPositionNotifier.value = newPosition.clamp(Duration.zero, _totalProjectDuration);
  }

  Future<void> _moveToNextClip() async {
    if (_currentClipIndex < widget.mediaClips.length - 1) {
      setState(() => _currentClipIndex++);
      await _initializeCurrentMedia(wasPlaying: _isPlaying);
    } else {
      setState(() => _currentClipIndex = 0);
      await _initializeCurrentMedia(wasPlaying: _isPlaying);
      _projectPositionNotifier.value = Duration.zero;
    }
  }

  Future<void> _togglePlayPause() async {
     setState(() { _isPlaying = !_isPlaying; });
      if (_isPlaying) {
        _videoController?.play();
        if(widget.mediaClips[_currentClipIndex].asset.type == AssetType.image) {
          _imageStartTime = DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        _videoController?.pause();
      }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _textFocusNode.dispose();
    _projectPositionNotifier.dispose();
    _timelineScrollController.dispose();
    _positionTimer?.cancel();
    super.dispose();
  }
  
  void _deleteOverlay(String overlayId) {
    setState(() {
      _overlays.removeWhere((o) => o.id == overlayId);
      if (_selectedOverlayId == overlayId) {
        _selectedOverlayId = null;
        _textFocusNode.unfocus();
      }
    });
  }

  void _onAddText() {
    setState(() {
      final newId = const Uuid().v4();
      final newStartTime = _projectPositionNotifier.value.clamp(Duration.zero, _totalProjectDuration);
      final newEndTime = (newStartTime + const Duration(seconds: 3)).clamp(Duration.zero, _totalProjectDuration);

      _overlays.add(TextOverlay(
        id: newId,
        startTime: newStartTime,
        endTime: newEndTime,
      ));
      _selectedOverlayId = newId;
      _textEditingController.text = 'Tap to edit';
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _textFocusNode.requestFocus();
    });
  }
  
  void _updateSelectedOverlay(TextOverlay updatedOverlay) {
    setState(() {
      final index = _overlays.indexWhere((o) => o.id == updatedOverlay.id);
      if (index != -1) {
        _overlays[index] = updatedOverlay;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedOverlay = _selectedOverlayId != null
        ? _overlays.firstWhere((o) => o.id == _selectedOverlayId, orElse: () => _overlays.first)
        : null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: () {
              Navigator.pop(context, TextEditorResult(overlays: _overlays));
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildVideoPreview(),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF1A1A1A),
              child: _buildFullTimeline(),
            ),
          ),
          _buildBottomToolbar(selectedOverlay),
        ],
      ),
    );
  }

  // --- MODIFIED: Added Stack for play/pause overlay ---
  Widget _buildVideoPreview() {
    if (!_isVideoInitialized && _videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final currentClip = widget.mediaClips[_currentClipIndex];
    final intrinsicAspectRatio = currentClip.asset.type == AssetType.video && _videoController != null
        ? _videoController!.value.aspectRatio
        : currentClip.asset.width / currentClip.asset.height;
    
    final visibleOverlays = _overlays.where((overlay) =>
        _projectPositionNotifier.value >= overlay.startTime &&
        _projectPositionNotifier.value <= overlay.endTime
    );

    return AspectRatio(
      aspectRatio: widget.canvasAspectRatio ?? intrinsicAspectRatio,
      child: Container(
        color: Colors.black,
        child: ClipRect(
          child: Transform(
            transform: widget.canvasTransform ?? Matrix4.identity(),
            child: Center(
              child: AspectRatio(
                aspectRatio: intrinsicAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Layer 0: Video or Image content
                    if (_videoController != null) VideoPlayer(_videoController!)
                    else FutureBuilder<File?>(
                      future: currentClip.asset.file,
                      builder: (context, snapshot) {
                          if(snapshot.hasData && snapshot.data != null) {
                            return Image.file(snapshot.data!, fit: BoxFit.cover);
                          }
                          return Container(color: Colors.black);
                      },
                    ),
                    
                    // Layer 1: Deselection and Play/Pause Gesture Detector
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                           if (_textFocusNode.hasFocus) {
                            _textFocusNode.unfocus();
                           } else if (_selectedOverlayId != null) {
                            setState(() => _selectedOverlayId = null);
                           } else {
                            _togglePlayPause();
                           }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // Layer 2: Interactive Text Overlays
                    ...visibleOverlays.map((overlay) {
                      return InteractiveTextWidget(
                        textOverlay: overlay,
                        isSelected: _selectedOverlayId == overlay.id,
                        onTap: () => setState(() {
                          _selectedOverlayId = overlay.id;
                          _textEditingController.text = overlay.text;
                        }),
                        onDrag: (pos) => _updateSelectedOverlay(overlay..position = pos),
                        onScaleAndRotate: (scale, angle) => _updateSelectedOverlay(
                          overlay..scale = scale..angle = angle
                        ),
                        onDelete: () => _deleteOverlay(overlay.id),
                      );
                    }).toList(),

                    // Layer 3: Play/Pause Icon Overlay
                    Center(
                      child: AnimatedOpacity(
                        opacity: _isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullTimeline() {
    final double totalTimelineWidth = _totalProjectDuration.inMilliseconds / 1000.0 * pixelsPerSecond;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Column(
            children: [
              Expanded(
                child: _buildTextTracks(totalTimelineWidth),
              ),
              SizedBox(
                height: 80,
                child: _buildVideoTrack(totalTimelineWidth),
              ),
            ],
          ),
          _buildPlayhead(totalTimelineWidth),
        ],
      ),
    );
  }

  Widget _buildTextTracks(double totalTimelineWidth) {
    final double textStackHeight = 10.0 + (_overlays.length * 35.0);
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SizedBox(
        width: totalTimelineWidth,
        height: textStackHeight,
        child: Stack(
          children: _overlays.asMap().entries.map((entry) {
            int index = entry.key;
            TextOverlay overlay = entry.value;
            return TextTimelineWidget(
              textOverlay: overlay,
              pixelsPerSecond: pixelsPerSecond,
              isSelected: _selectedOverlayId == overlay.id,
              topPosition: 10.0 + (index * 35.0),
              onTap: () => setState(() {
                  _selectedOverlayId = overlay.id;
                  _textEditingController.text = overlay.text;
              }),
              onDurationChanged: (newStart, newEnd) {
                _updateSelectedOverlay(overlay..startTime = newStart..endTime = newEnd);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVideoTrack(double totalTimelineWidth) {
    return SingleChildScrollView(
      controller: _timelineScrollController,
      scrollDirection: Axis.horizontal,
      child: ProportionalTimelineWidget(
        mediaClips: widget.mediaClips,
        currentClipIndex: _currentClipIndex,
        currentProjectPosition: _projectPositionNotifier.value,
        totalProjectDuration: _totalProjectDuration,
        onClipTap: (index) {
          if (_currentClipIndex != index) {
              setState(() => _currentClipIndex = index);
              _initializeCurrentMedia(wasPlaying: _isPlaying);
          }
        },
        onTrimChanged: (_, __, ___) {},
        timelineWidth: totalTimelineWidth,
        pixelsPerSecond: pixelsPerSecond,
      ),
    );
  }
  
  Widget _buildPlayhead(double timelineWidth) {
    final double indicatorPosition = (_projectPositionNotifier.value.inMilliseconds / 1000.0 * pixelsPerSecond)
        .clamp(0.0, timelineWidth);

    return LayoutBuilder(builder: (context, constraints) {
      return Positioned(
        left: indicatorPosition,
        top: 0,
        bottom: 0,
        child: Container(
          width: 3,
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 4) ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomToolbar(TextOverlay? selectedOverlay) {
    if (selectedOverlay != null) {
      return _buildTextStylingToolbar(selectedOverlay);
    }
    
    return Container(
      height: 100,
      color: const Color(0xFF2A2A2A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolButton(Icons.text_fields, 'Text', _onAddText),
          _buildToolButton(Icons.brush, 'Doodle', () {}),
        ],
      ),
    );
  }
  
  Widget _buildTextStylingToolbar(TextOverlay selectedOverlay) {
     return Container(
      color: const Color(0xFF2A2A2A),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 
        MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textEditingController,
            focusNode: _textFocusNode,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter text...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
            ),
            onChanged: (text) => _updateSelectedOverlay(selectedOverlay..text = text),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(icon: const Icon(Icons.keyboard, color: Colors.white), onPressed: () {
                if (_textFocusNode.hasFocus) _textFocusNode.unfocus();
                else _textFocusNode.requestFocus();
              }),
              IconButton(icon: const Icon(Icons.color_lens, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Text('Aa', style: TextStyle(color: Colors.white, fontSize: 24)), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}