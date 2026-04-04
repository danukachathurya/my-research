import 'dart:convert';
import 'package:flutter/material.dart';

class Base64ImageWidget extends StatelessWidget {
  final String? base64String;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final BorderRadius? borderRadius;

  const Base64ImageWidget({
    super.key,
    this.base64String,
    this.width = 100,
    this.height = 100,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (base64String == null || base64String!.isEmpty) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: borderRadius,
            ),
            child: const Icon(Icons.image, color: Colors.grey),
          );
    }

    try {
      final decodedBytes = base64Decode(base64String!);
      final image = Image.memory(
        decodedBytes,
        width: width,
        height: height,
        fit: fit,
      );

      if (borderRadius != null) {
        return ClipRRect(borderRadius: borderRadius!, child: image);
      }

      return image;
    } catch (e) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: borderRadius,
            ),
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
    }
  }
}
