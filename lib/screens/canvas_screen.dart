// lib/screens/canvas_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/canvas_options.dart';
import '../widgets/canvas_button_widget.dart';

// --- MODIFIED: Added transformation property ---
class CanvasResult {
  final double? aspectRatio;
  final Matrix4? transformation;
  final bool applyToAll;
  CanvasResult({this.aspectRatio, this.transformation, this.applyToAll = false});
}

class CanvasScreen extends StatefulWidget {
  final File videoFile;
  final double? initialAspectRatio;
  // --- NEW: To receive existing transformation for re-editing ---
  final Matrix4? initialTransformation;

  const CanvasScreen({
    super.key,
    required this.videoFile,
    this.initialAspectRatio,
    this.initialTransformation,
  });

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  VideoPlayerController? _controller;
  bool _isControllerInitialized = false;

  double? _selectedAspectRatio;
  bool _applyToAll = false;
  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0;
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;
  
  final GlobalKey _interactiveViewerKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    _selectedAspectRatio = widget.initialAspectRatio;
    // --- NEW: Apply initial transformation if it exists ---
    if (widget.initialTransformation != null) {
      _transformationController.value = widget.initialTransformation!;
      _currentScale = _transformationController.value.getMaxScaleOnAxis();
    }
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();
      if (mounted) {
        setState(() {
          _isControllerInitialized = true;
        });
      }
    } catch (e) {
      print("Error initializing canvas controller: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onScaleChanged(double scale) {
    setState(() {
      _currentScale = scale;
      final RenderBox? renderBox =
          _interactiveViewerKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox == null) {
        _transformationController.value = Matrix4.identity()..scale(scale);
      } else {
        final size = renderBox.size;
        final center = Offset(size.width / 2, size.height / 2);
        
        final newMatrix = Matrix4.identity()
          ..translate(center.dx, center.dy)
          ..scale(scale)
          ..translate(-center.dx, -center.dy);
        
        _transformationController.value = newMatrix;
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Canvas', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, 'CANCEL'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: () {
              // --- MODIFIED: Pass back the transformation matrix ---
              final result = CanvasResult(
                aspectRatio: _selectedAspectRatio,
                transformation: _transformationController.value,
                applyToAll: _applyToAll,
              );
              Navigator.pop(context, result);
            },
          ),
        ],
      ),
      body: !_isControllerInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            _selectedAspectRatio ?? _controller!.value.aspectRatio,
                        child: Container(
                          color: Colors.black,
                          child: ClipRRect(
                            child: InteractiveViewer(
                              key: _interactiveViewerKey,
                              transformationController: _transformationController,
                              minScale: _minScale,
                              maxScale: _maxScale,
                              panEnabled: true,
                              scaleEnabled: true,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: _controller!.value.aspectRatio,
                                  child: VideoPlayer(_controller!),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildControls(),
                _buildRatioSelector(),
              ],
            ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: const Color(0xFF1A1A1A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.zoom_out, color: Colors.white70),
              Expanded(
                child: Slider(
                  value: _currentScale,
                  min: _minScale,
                  max: _maxScale,
                  activeColor: Colors.purple,
                  inactiveColor: Colors.grey.shade600,
                  onChanged: _onScaleChanged,
                ),
              ),
              const Icon(Icons.zoom_in, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.layers, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Apply to all clips',
                style: TextStyle(color: Colors.white),
              ),
              const Spacer(),
              Switch(
                value: _applyToAll,
                onChanged: (value) {
                  setState(() {
                    _applyToAll = value;
                  });
                },
                activeColor: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioSelector() {
    return Container(
      height: 100,
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: canvasOptions.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final option = canvasOptions[index];
          return CanvasButtonWidget(
            option: option,
            isSelected: _selectedAspectRatio == option.value,
            onTap: () {
              setState(() {
                _selectedAspectRatio = option.value;
                _onScaleChanged(1.0); // Reset zoom/pan when ratio changes
              });
            },
          );
        },
      ),
    );
  }
}