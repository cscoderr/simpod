import 'package:flutter/material.dart';

class NetworkImageWidget extends StatelessWidget {
  const NetworkImageWidget({super.key, required this.url, this.fit = .contain});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      webHtmlElementStrategy: .prefer,
      errorBuilder: (ctx, _, __) => const SizedBox.shrink(),
    );
  }
}
