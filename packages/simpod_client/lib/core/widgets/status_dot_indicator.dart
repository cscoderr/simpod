import 'package:flutter/cupertino.dart';
import 'package:simpod_client/core/core.dart';

class StatusDotIndicator extends StatelessWidget {
  const StatusDotIndicator({super.key, this.isBooted = false});
  final bool isBooted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isBooted
            ? AppColorsDark.statusLiveGlow
            : context.colorScheme.onSurface.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        boxShadow: isBooted
            ? [
                BoxShadow(
                  color: AppColorsDark.statusLiveGlow.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
