import 'package:flutter/material.dart';

/// Renders a local asset with a themed fallback when the file is missing.
class BattlyAssetImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  const BattlyAssetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = fallbackColor ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35);

    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          fallbackIcon,
          size: (width != null && height != null)
              ? (width! < height! ? width! : height!) * 0.45
              : 24,
          color: color,
        ),
      ),
    );
  }
}
