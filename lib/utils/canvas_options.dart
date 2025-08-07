import 'package:flutter/material.dart';

class CanvasOption {
  final String label;
  final double? value; // Aspect ratio value. Null for 'Fit'.
  final IconData icon;

  const CanvasOption({required this.label, this.value, required this.icon});
}

// List of all canvas options you requested
const List<CanvasOption> canvasOptions = [
  CanvasOption(label: 'Fit', icon: Icons.fullscreen),
  CanvasOption(label: '1:1', value: 1.0, icon: Icons.crop_square),
  CanvasOption(label: '4:5', value: 4 / 5, icon: Icons.crop_portrait),
  CanvasOption(label: '9:16', value: 9 / 16, icon: Icons.crop_portrait),
  CanvasOption(label: '16:9', value: 16 / 9, icon: Icons.crop_landscape),
  CanvasOption(label: '3:4', value: 3 / 4, icon: Icons.crop_portrait),
  CanvasOption(label: '4:3', value: 4 / 3, icon: Icons.crop_landscape),
  CanvasOption(label: '2:3', value: 2 / 3, icon: Icons.crop_portrait),
  CanvasOption(label: '3:2', value: 3 / 2, icon: Icons.crop_landscape),
  CanvasOption(label: '2.35:1', value: 2.35 / 1, icon: Icons.crop_landscape),
  CanvasOption(label: '2:1', value: 2.0, icon: Icons.crop_landscape),
  CanvasOption(label: '1:2', value: 1 / 2, icon: Icons.crop_portrait),
];