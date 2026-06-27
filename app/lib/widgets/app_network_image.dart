import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme/battly_theme.dart';

/// Loads remote images on web via HTML img elements to avoid CORS fetch errors.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.errorWidget,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ??
        Container(
          color: context.battly.elevatedSurface,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFFA0A0A0),
          ),
        );

    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      webHtmlElementStrategy: kIsWeb
          ? WebHtmlElementStrategy.prefer
          : WebHtmlElementStrategy.never,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

/// Circular avatar with graceful fallback when Google/CDN images fail.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    this.fallbackIconSize,
  });

  final String? imageUrl;
  final double radius;
  final double? fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.battly.elevatedSurface,
        border: Border.all(color: const Color(0xFFFF6B00), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? AppNetworkImage(
              url: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Center(
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: fallbackIconSize ?? radius,
      ),
    );
  }
}
