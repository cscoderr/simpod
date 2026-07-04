import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simpod_client/core/core.dart';

class SimpodCustomTextField extends StatefulWidget {
  const SimpodCustomTextField({
    required this.controller,
    required this.placeholder,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SimpodCustomTextField> createState() => _SimpodCustomTextFieldState();
}

class _SimpodCustomTextFieldState extends State<SimpodCustomTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final colorScheme = context.colorScheme;
    final inputBg = isDark
        ? AppColorsDark.tint(alpha: 0.04)
        : AppColorsLight.tint(alpha: 0.03);

    final borderCol = _isFocused
        ? colorScheme.primary.withValues(alpha: 0.7)
        : (isDark
              ? AppColorsDark.border(alpha: 0.12)
              : AppColorsLight.border(alpha: 0.15));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: inputBg,
        border: Border.all(color: borderCol, width: _isFocused ? 1.5 : 1.0),
        borderRadius: BorderRadius.circular(6),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.12 : 0.08,
                  ),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: CupertinoTextField(
        focusNode: _focusNode,
        controller: widget.controller,
        placeholder: widget.placeholder,
        onSubmitted: widget.onSubmitted,
        placeholderStyle: GoogleFonts.inter(
          color: colorScheme.onSurface.withValues(alpha: 0.3),
          fontSize: 12,
        ),
        style: GoogleFonts.inter(color: colorScheme.onSurface, fontSize: 12),
        decoration: const BoxDecoration(color: Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}
