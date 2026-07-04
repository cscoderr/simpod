import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';

class SimpodSwitch extends StatelessWidget {
  const SimpodSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 30,
    this.height = 18,
    this.activeColor = const Color(0xFF34C759),
    this.inactiveColor,
    this.thumbColor = Colors.white,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;
  final Color activeColor;
  final Color? inactiveColor;
  final Color thumbColor;

  @override
  Widget build(BuildContext context) {
    final thumbSize = height - 4;
    final offTrack =
        inactiveColor ??
        (context.isDarkMode ? Colors.white24 : Colors.black12);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: height,
          width: width,
          padding: const .all(2),
          decoration: BoxDecoration(
            color: value ? activeColor : offTrack,
            borderRadius: .circular(height / 2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: value ? .centerRight : .centerLeft,
            child: Container(
              height: thumbSize,
              width: thumbSize,
              decoration: BoxDecoration(
                color: thumbColor,
                shape: .circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
