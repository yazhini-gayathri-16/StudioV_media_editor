import 'package:flutter/material.dart';
import '../utils/canvas_options.dart';

class CanvasButtonWidget extends StatelessWidget {
  final CanvasOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const CanvasButtonWidget({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              option.label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}