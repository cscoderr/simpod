import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simpod_client/core/core.dart';

void showSimpodToast(
  BuildContext context,
  String message, {
  required bool isError,
  Uint8List? preview,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final foreground = isError ? Colors.white : colorScheme.onPrimary;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 280,
        backgroundColor: isError ? colorScheme.error : colorScheme.primary,
        duration: preview != null
            ? const Duration(seconds: 4)
            : const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allSm),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.memory(
                    preview,
                    width: 34,
                    height: 60,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              )
            else ...[
              Icon(
                isError
                    ? CupertinoIcons.exclamationmark_circle
                    : CupertinoIcons.check_mark_circled,
                color: foreground,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                message,
                style: GoogleFonts.inter(color: foreground, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
}
