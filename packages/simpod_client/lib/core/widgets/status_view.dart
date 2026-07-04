import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';

class StatusView extends StatefulWidget {
  const StatusView({
    required this.title,
    this.message,
    this.isLoading = false,
    this.isError = false,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  const StatusView.loading({Key? key, String? message})
    : this(key: key, title: 'Connecting…', message: message, isLoading: true);

  const StatusView.error({
    Key? key,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) : this(
         key: key,
         title: title,
         message: message,
         isError: true,
         actionLabel: actionLabel,
         onAction: onAction,
       );

  final String title;
  final String? message;
  final bool isLoading;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<StatusView> createState() => _StatusViewState();
}

class _StatusViewState extends State<StatusView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final accent = widget.isError ? scheme.error : scheme.primary;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xlg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleMedium,
                ),
                if (widget.message != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SimpodOutlineButton(
                    text: widget.actionLabel!,
                    onTap: widget.onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
