// lib/widgets/interactive_text_widget.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/text_overlay_model.dart';

class InteractiveTextWidget extends StatefulWidget {
  final TextOverlay textOverlay;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(Offset newPosition) onDrag;
  final Function(double newScale, double newAngle) onScaleAndRotate;
  // --- NEW: Callback for when the delete button is tapped ---
  final VoidCallback onDelete;

  const InteractiveTextWidget({
    super.key,
    required this.textOverlay,
    required this.isSelected,
    required this.onTap,
    required this.onDrag,
    required this.onScaleAndRotate,
    required this.onDelete,
  });

  @override
  State<InteractiveTextWidget> createState() => _InteractiveTextWidgetState();
}

class _InteractiveTextWidgetState extends State<InteractiveTextWidget> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.textOverlay.position.dx,
      top: widget.textOverlay.position.dy,
      child: Transform.rotate(
        angle: widget.textOverlay.angle,
        child: Transform.scale(
          scale: widget.textOverlay.scale,
          child: GestureDetector(
            onTap: widget.onTap,
            onPanUpdate: (details) {
              final newPosition = widget.textOverlay.position + details.delta;
              widget.onDrag(newPosition);
            },
            child: _buildTextContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: widget.isSelected ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            widget.textOverlay.text,
            style: widget.textOverlay.style,
            textAlign: TextAlign.center,
          ),
          if (widget.isSelected) ...[
            // --- MODIFIED: Changed to a functional delete button ---
            Positioned(
              top: -15,
              left: -15,
              child: _buildControlHandle(
                icon: Icons.delete,
                onTap: widget.onDelete, // Use the new callback
                color: Colors.red,
                iconColor: Colors.white,
              ),
            ),
            // Scale and rotate button
            Positioned(
              bottom: -15,
              right: -15,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final newScale = widget.textOverlay.scale + (details.delta.dy / 100.0);
                  final newAngle = widget.textOverlay.angle + (details.delta.dx / 100.0);
                  widget.onScaleAndRotate(newScale.clamp(0.2, 5.0), newAngle);
                },
                child: _buildControlHandle(icon: Icons.sync),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // --- MODIFIED: To allow custom colors for the handle ---
  Widget _buildControlHandle({
    required IconData icon,
    VoidCallback? onTap,
    Color color = Colors.white,
    Color iconColor = Colors.black,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
    );
  }
}