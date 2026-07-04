import 'package:flutter/material.dart';

class SimpodIconButton extends StatelessWidget {
  const SimpodIconButton({
    required this.icon,
    this.iconSize = 20.0,
    super.key,
    this.tooltip,
    this.color,
    this.onPressed,
    this.onDoubleTap,
  });
  final IconData icon;
  final String? tooltip;
  final double iconSize;
  final Color? color;
  final VoidCallback? onPressed;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: iconSize,
        color: color,
        tooltip: tooltip,
        padding: .zero,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
