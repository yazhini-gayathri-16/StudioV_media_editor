import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class EditorScreen extends StatefulWidget {
  final List<AssetEntity> selectedMedia;
  final String mediaType;

  const EditorScreen({
    Key? key,
    required this.selectedMedia,
    required this.mediaType,
  }) : super(key: key);

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isVideoInitialized = false;
  Duration _videoDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeCurrentMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCurrentMedia() async {
    final currentAsset = widget.selectedMedia[_currentIndex];
    
    if (currentAsset.type == AssetType.video) {
      await _initializeVideo(currentAsset);
    } else {
      _videoController?.dispose();
      _videoController = null;
      setState(() {
        _isVideoInitialized = false;
        _isPlaying = false;
      });
    }
  }

  Future<void> _initializeVideo(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null) {
        _videoController?.dispose();
        _videoController = VideoPlayerController.file(file);
        
        await _videoController!.initialize();
        
        _videoController!.addListener(() {
          if (mounted) {
            setState(() {
              _currentPosition = _videoController!.value.position;
              _videoDuration = _videoController!.value.duration;
            });
          }
        });

        setState(() {
          _isVideoInitialized = true;
          _isPlaying = false;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _togglePlayPause() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        if (_isPlaying) {
          _videoController!.pause();
          _isPlaying = false;
        } else {
          _videoController!.play();
          _isPlaying = true;
        }
      });
    }
  }

  void _seekTo(Duration position) {
    if (_videoController != null && _isVideoInitialized) {
      _videoController!.seekTo(position);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
                  // Play/Pause overlay for videos
                  if (widget.selectedMedia[_currentIndex].type == AssetType.video)
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
                  // Video controls
                  if (_isVideoInitialized && _videoController != null)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: _buildVideoControls(),
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
          
          // Timeline and Add Button
          Container(
            height: 120,
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
                    // Timeline
                    Expanded(
                      child: Container(
                        height: 80,
                        child: _buildTimeline(),
                      ),
                    ),
                  ],
                ),
                // Time indicators
                if (_isVideoInitialized)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          _formatDuration(_videoDuration),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final currentAsset = widget.selectedMedia[_currentIndex];
    
    if (currentAsset.type == AssetType.video && _isVideoInitialized && _videoController != null) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else {
      return FutureBuilder<Widget>(
        future: _buildImagePreview(currentAsset),
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

  Widget _buildVideoControls() {
    return Row(
      children: [
        IconButton(
          onPressed: _togglePlayPause,
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
        ),
        Expanded(
          child: Slider(
            value: _currentPosition.inMilliseconds.toDouble(),
            max: _videoDuration.inMilliseconds.toDouble(),
            onChanged: (value) {
              _seekTo(Duration(milliseconds: value.toInt()));
            },
            activeColor: Colors.purple,
            inactiveColor: Colors.grey,
          ),
        ),
        IconButton(
          onPressed: () {
            // Fullscreen functionality
          },
          icon: const Icon(Icons.fullscreen, color: Colors.white),
        ),
      ],
    );
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

  Widget _buildTimeline() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: widget.selectedMedia.length,
      itemBuilder: (context, index) {
        final asset = widget.selectedMedia[index];
        final isSelected = index == _currentIndex;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
            _initializeCurrentMedia();
          },
          child: Container(
            width: 80,
            height: 60,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.purple, width: 2)
                  : Border.all(color: Colors.grey, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FutureBuilder<Widget>(
                future: _buildThumbnail(asset),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return snapshot.data!;
                  }
                  return Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.photo, color: Colors.white),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Widget> _buildThumbnail(AssetEntity asset) async {
    try {
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize(80, 60),
      );
      
      if (thumbnail != null) {
        return Stack(
          children: [
            Image.memory(
              thumbnail,
              fit: BoxFit.cover,
              width: 80,
              height: 60,
            ),
            if (asset.type == AssetType.video)
              const Positioned(
                bottom: 2,
                right: 2,
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        );
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
    }
    
    return Container(
      color: Colors.grey[800],
      child: Icon(
        asset.type == AssetType.video ? Icons.videocam : Icons.photo,
        color: Colors.white,
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('Export Media', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Export functionality will be implemented here.',
            style: TextStyle(color: Colors.white70),
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