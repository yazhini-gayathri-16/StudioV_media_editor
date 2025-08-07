// lib/screens/canvas_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/canvas_options.dart';
import '../widgets/canvas_button_widget.dart';

// This class definition remains the same
class CanvasResult {
  final double? aspectRatio;
  final bool applyToAll;
  CanvasResult({this.aspectRatio, this.applyToAll = false});
}

class CanvasScreen extends StatefulWidget {
  final File videoFile;
  final double? initialAspectRatio;

  const CanvasScreen({
    super.key,
    required this.videoFile,
    this.initialAspectRatio,
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

  @override
  void initState() {
    super.initState();
    _selectedAspectRatio = widget.initialAspectRatio;
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
      _transformationController.value = Matrix4.identity()..scale(_currentScale);
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
              final result = CanvasResult(
                aspectRatio: _selectedAspectRatio,
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
                // --- MODIFIED LAYOUT ---
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    // Center allows the AspectRatio to size itself correctly
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            _selectedAspectRatio ?? _controller!.value.aspectRatio,
                        // ClipRect prevents the zoomed content from painting outside the frame
                        child: ClipRect(
                          child: InteractiveViewer(
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
                // Reset zoom and pan when ratio changes
                _onScaleChanged(1.0);
              });
            },
          );
        },
      ),
    );
  }
}