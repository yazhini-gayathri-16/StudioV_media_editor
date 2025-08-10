// lib/screens/text_editor_screen.dart - FIXED VERSION

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
// Note: The corrected TextTimelineWidget is now included in this file below.

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

  // Playhead dragging state
  bool _isDraggingPlayhead = false;
  bool _wasPlayingBeforeDrag = false;

  @override
  void initState() {
    super.initState();
    _overlays = List.from(widget.initialOverlays);
    _calculateTotalDuration();
    _isPlaying = true;
    _initializeCurrentMedia(wasPlaying: _isPlaying);
    _startPositionTimer();
  }

  void _calculateTotalDuration() {
    _totalProjectDuration = widget.mediaClips.fold(Duration.zero, (total, clip) => total + clip.trimmedDuration);
  }

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
          _videoController!.play();
        }
      } else {
        if (!mounted || requestVersion != _mediaInitVersion) return;
        setState(() {
          _videoController = null;
          _isVideoInitialized = false;
        });
        if (wasPlaying) _imageStartTime = DateTime.now().millisecondsSinceEpoch;
      }
    } catch (e) {
      debugPrint("Error initializing media in TextEditor: $e");
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted && _isPlaying && !_isDraggingPlayhead) {
        _updateProjectPosition();
        _updateTimelineScroll();
      }
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

  void _updateTimelineScroll() {
    if (!_timelineScrollController.hasClients || _isDraggingPlayhead) return;

    final double playheadX = _projectPositionNotifier.value.inMilliseconds / 1000.0 * pixelsPerSecond;
    final double viewportWidth = _timelineScrollController.position.viewportDimension;
    final double currentOffset = _timelineScrollController.offset;

    final double safeZoneStart = currentOffset + viewportWidth * 0.3;
    final double safeZoneEnd = currentOffset + viewportWidth * 0.7;

    if (playheadX < safeZoneStart || playheadX > safeZoneEnd) {
      final double targetOffset = (playheadX - (viewportWidth / 2)).clamp(
        _timelineScrollController.position.minScrollExtent,
        _timelineScrollController.position.maxScrollExtent,
      );

      _timelineScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _onPlayheadDragStart() {
    _isDraggingPlayhead = true;
    _wasPlayingBeforeDrag = _isPlaying;
    if (_isPlaying) {
      _togglePlayPause(); // Pause during drag
    }
  }

  // --- FIXED: Playhead dragging logic ---
  void _onPlayheadDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingPlayhead) return;

    // Calculate how many milliseconds the drag corresponds to
    final double deltaMilliseconds = (details.delta.dx * 1000 / pixelsPerSecond);
    
    // Get the current position and add the delta
    final Duration currentPosition = _projectPositionNotifier.value;
    final Duration newPosition = currentPosition + Duration(milliseconds: deltaMilliseconds.round());
    
    // Clamp the new position to be within the project duration and update
    _projectPositionNotifier.value = newPosition.clamp(Duration.zero, _totalProjectDuration);
    
    // Seek the video to the new position
    _seekToPosition(_projectPositionNotifier.value);
  }

  void _onPlayheadDragEnd() {
    _isDraggingPlayhead = false;
    if (_wasPlayingBeforeDrag) {
      _togglePlayPause(); // Resume if was playing
    }
  }

  Future<void> _seekToPosition(Duration targetPosition) async {
    Duration accumulatedDuration = Duration.zero;
    int targetClipIndex = -1;

    for (int i = 0; i < widget.mediaClips.length; i++) {
      final clipDuration = widget.mediaClips[i].trimmedDuration;
      if (targetPosition <= accumulatedDuration + clipDuration) {
        targetClipIndex = i;
        break;
      }
      accumulatedDuration += clipDuration;
    }
    
    targetClipIndex = (targetClipIndex == -1) ? widget.mediaClips.length - 1 : targetClipIndex;

    if (targetClipIndex != _currentClipIndex && targetClipIndex < widget.mediaClips.length) {
      setState(() => _currentClipIndex = targetClipIndex);
      await _initializeCurrentMedia(wasPlaying: false);
    }

    if (_currentClipIndex < widget.mediaClips.length) {
      final currentClip = widget.mediaClips[_currentClipIndex];
      final positionInClip = targetPosition - accumulatedDuration;

      if (currentClip.asset.type == AssetType.video && _videoController != null) {
        final seekTime = (currentClip.startTime + positionInClip).clamp(currentClip.startTime, currentClip.endTime);
        await _videoController!.seekTo(seekTime);
        if (_isPlaying) await _videoController!.play();
      } else if (currentClip.asset.type == AssetType.image) {
        _imageStartTime = DateTime.now().millisecondsSinceEpoch - positionInClip.inMilliseconds;
      }
    }
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
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _videoController?.play();
      if (widget.mediaClips[_currentClipIndex].asset.type == AssetType.image) {
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
      Duration newEndTime = newStartTime + const Duration(seconds: 3);
      if (newEndTime > _totalProjectDuration) {
        newEndTime = _totalProjectDuration;
      }

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

  Widget _buildVideoPreview() {
    // ... (This widget build method has no changes)
    if (!_isVideoInitialized && _videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentClip = widget.mediaClips[_currentClipIndex];
    final intrinsicAspectRatio = currentClip.asset.type == AssetType.video && _videoController != null
        ? _videoController!.value.aspectRatio
        : currentClip.asset.width / currentClip.asset.height;

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
                    if (_videoController != null)
                      VideoPlayer(_videoController!)
                    else
                      FutureBuilder<File?>(
                        future: currentClip.asset.file,
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.file(snapshot.data!, fit: BoxFit.cover);
                          }
                          return Container(color: Colors.black);
                        },
                      ),
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
                    ValueListenableBuilder<Duration>(
                        valueListenable: _projectPositionNotifier,
                        builder: (context, position, child) {
                          final visibleOverlays = _overlays.where((overlay) => position >= overlay.startTime && position <= overlay.endTime);

                          return Stack(
                            fit: StackFit.expand,
                            children: visibleOverlays.map((overlay) {
                              return InteractiveTextWidget(
                                textOverlay: overlay,
                                isSelected: _selectedOverlayId == overlay.id,
                                onTap: () => setState(() {
                                  _selectedOverlayId = overlay.id;
                                  _textEditingController.text = overlay.text;
                                }),
                                onDrag: (pos) => _updateSelectedOverlay(overlay..position = pos),
                                onScaleAndRotate: (scale, angle) => _updateSelectedOverlay(overlay
                                  ..scale = scale
                                  ..angle = angle),
                                onDelete: () => _deleteOverlay(overlay.id),
                              );
                            }).toList(),
                          );
                        }),
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
    // ... (This widget build method has no changes)
    final double totalTimelineWidth = _totalProjectDuration.inMilliseconds / 1000.0 * pixelsPerSecond;

    return ValueListenableBuilder<Duration>(
      valueListenable: _projectPositionNotifier,
      builder: (context, position, child) {
        return SingleChildScrollView(
          controller: _timelineScrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalTimelineWidth,
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: _buildTextTracks(totalTimelineWidth),
                    ),
                    SizedBox(
                      height: 80,
                      child: _buildVideoTrack(totalTimelineWidth, position),
                    ),
                  ],
                ),
                _buildInteractivePlayhead(totalTimelineWidth, position),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextTracks(double totalTimelineWidth) {
    final double textStackHeight = 10.0 + (_overlays.length * 40.0); // Increased spacing
    return SizedBox(
      width: totalTimelineWidth,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
          height: textStackHeight,
          child: Stack(
            children: _overlays.asMap().entries.map((entry) {
              int index = entry.key;
              TextOverlay overlay = entry.value;
              // --- CHANGED: Using the new and improved TextTimelineWidget ---
              return TextTimelineWidget(
                textOverlay: overlay,
                pixelsPerSecond: pixelsPerSecond,
                isSelected: _selectedOverlayId == overlay.id,
                topPosition: 10.0 + (index * 40.0),
                onTap: () => setState(() {
                  _selectedOverlayId = overlay.id;
                  _textEditingController.text = overlay.text;
                }),
                onDurationChanged: (newStart, newEnd) {
                  _updateSelectedOverlay(overlay
                    ..startTime = newStart
                    ..endTime = newEnd);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTrack(double totalTimelineWidth, Duration position) {
    // ... (This widget build method has no changes)
    return ProportionalTimelineWidget(
      mediaClips: widget.mediaClips,
      currentClipIndex: _currentClipIndex,
      currentProjectPosition: position,
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
    );
  }

  // --- FIXED: GestureDetector now calls the corrected drag update function ---
  Widget _buildInteractivePlayhead(double timelineWidth, Duration position) {
    final double indicatorPosition = (position.inMilliseconds / 1000.0 * pixelsPerSecond).clamp(0.0, timelineWidth);

    return Positioned(
      left: indicatorPosition - 15, // Wider hit area
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onPanStart: (_) => _onPlayheadDragStart(),
        onPanUpdate: _onPlayheadDragUpdate, // Use the corrected function
        onPanEnd: (_) => _onPlayheadDragEnd(),
        child: Container(
          width: 30, // Wider hit area for easier dragging
          color: Colors.transparent, // Make the entire area tappable
          child: Center(
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: _isDraggingPlayhead ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 0,
                    height: 0,
                    decoration: BoxDecoration(
                      border: Border(
                        left: const BorderSide(width: 8, color: Colors.transparent),
                        right: const BorderSide(width: 8, color: Colors.transparent),
                        bottom: BorderSide(width: 10, color: _isDraggingPlayhead ? Colors.blue : Colors.white),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 3,
                      color: _isDraggingPlayhead ? Colors.blue : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(TextOverlay? selectedOverlay) {
    // ... (This widget build method has no changes)
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
    // ... (This widget build method has no changes)
    return Container(
      color: const Color(0xFF2A2A2A),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
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
              IconButton(
                  icon: const Icon(Icons.keyboard, color: Colors.white),
                  onPressed: () {
                    if (_textFocusNode.hasFocus)
                      _textFocusNode.unfocus();
                    else
                      _textFocusNode.requestFocus();
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
    // ... (This widget build method has no changes)
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

// --- NEW: Corrected and enhanced TextTimelineWidget ---
// (Based on the superior implementation from text_timeline_widget.dart)
class TextTimelineWidget extends StatefulWidget {
  final TextOverlay textOverlay;
  final double pixelsPerSecond;
  final Function(Duration newStart, Duration newEnd) onDurationChanged;
  final VoidCallback onTap;
  final bool isSelected;
  final double topPosition;

  const TextTimelineWidget({
    super.key,
    required this.textOverlay,
    required this.pixelsPerSecond,
    required this.onDurationChanged,
    required this.onTap,
    required this.isSelected,
    required this.topPosition,
  });

  @override
  State<TextTimelineWidget> createState() => _TextTimelineWidgetState();
}

class _TextTimelineWidgetState extends State<TextTimelineWidget> {
  bool _isDraggingLeft = false;
  bool _isDraggingRight = false;

  void _handleLeftTrim(double deltaX) {
    final deltaMilliseconds = (deltaX * 1000 / widget.pixelsPerSecond).round();
    Duration newStartTime = widget.textOverlay.startTime + Duration(milliseconds: deltaMilliseconds);

    if (newStartTime.isNegative) newStartTime = Duration.zero;
    if (newStartTime >= widget.textOverlay.endTime - const Duration(milliseconds: 200)) {
      newStartTime = widget.textOverlay.endTime - const Duration(milliseconds: 200);
    }

    widget.onDurationChanged(newStartTime, widget.textOverlay.endTime);
  }

  void _handleRightTrim(double deltaX) {
    final deltaMilliseconds = (deltaX * 1000 / widget.pixelsPerSecond).round();
    Duration newEndTime = widget.textOverlay.endTime + Duration(milliseconds: deltaMilliseconds);

    if (newEndTime <= widget.textOverlay.startTime + const Duration(milliseconds: 200)) {
      newEndTime = widget.textOverlay.startTime + const Duration(milliseconds: 200);
    }
    // Also ensure it doesn't go beyond total duration if available, not essential but good practice
    widget.onDurationChanged(widget.textOverlay.startTime, newEndTime);
  }

  @override
  Widget build(BuildContext context) {
    final leftPosition = widget.textOverlay.startTime.inMilliseconds / 1000.0 * widget.pixelsPerSecond;
    final width = (widget.textOverlay.endTime - widget.textOverlay.startTime).inMilliseconds / 1000.0 * widget.pixelsPerSecond;

    return Positioned(
      left: leftPosition,
      top: widget.topPosition,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: width < 60 ? 60 : width,
          height: 35, // A bit taller
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.blue.withOpacity(0.8) : Colors.green.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isSelected ? Colors.blue.shade200 : Colors.green.shade200,
              width: 1.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 35),
                  child: Text(
                    widget.textOverlay.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              // Left Drag Handle
              Positioned(
                left: -2,
                top: -2,
                bottom: -2,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDraggingLeft = true),
                  onPanUpdate: (details) => _handleLeftTrim(details.delta.dx),
                  onPanEnd: (_) => setState(() => _isDraggingLeft = false),
                  child: _buildDragHandle(isLeft: true, isDragging: _isDraggingLeft),
                ),
              ),
              // Right Drag Handle
              Positioned(
                right: -2,
                top: -2,
                bottom: -2,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDraggingRight = true),
                  onPanUpdate: (details) => _handleRightTrim(details.delta.dx),
                  onPanEnd: (_) => setState(() => _isDraggingRight = false),
                  child: _buildDragHandle(isLeft: false, isDragging: _isDraggingRight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle({required bool isLeft, required bool isDragging}) {
    return Container(
      width: 20, // Wider hit area
      decoration: BoxDecoration(
        color: isDragging ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.2),
        borderRadius: isLeft
            ? const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4))
            : const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (index) => Container(
            width: 8,
            height: 2,
            color: Colors.black.withOpacity(0.5),
          )),
        ),
      ),
    );
  }
}