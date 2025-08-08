// lib/models/text_overlay_model.dart

import 'package:flutter/material.dart';

class TextOverlay {
  final String id;
  String text;
  TextStyle style;
  Offset position;
  double scale;
  double angle;
  // Timeline properties to be used later
  Duration startTime;
  Duration endTime;

  TextOverlay({
    required this.id,
    this.text = 'Tap to edit',
    this.style = const TextStyle(color: Colors.white, fontSize: 28),
    this.position = Offset.zero, // Initially centered
    this.scale = 1.0,
    this.angle = 0.0,
    this.startTime = Duration.zero,
    this.endTime = const Duration(seconds: 3),
  });
}