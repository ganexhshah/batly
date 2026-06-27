import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_network_image.dart';
import '../core/responsive/responsive.dart';
import '../models/app_models.dart';
import '../services/api_config.dart';
import '../core/theme/battly_theme.dart';

// -----------------------------------------------------------------------------
// FEATURED CAROUSEL
// -----------------------------------------------------------------------------
class FeaturedCarousel extends StatefulWidget {
  final List<FeaturedTournament> items;

  const FeaturedCarousel({super.key, required this.items});

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  int _activeSlide = 0;

  String _getImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      // If the URL points to localhost or 127.0.0.1 (local storage on backend),
      // rewrite it to use the dynamic ApiConfig.baseUrl host (correct IP/port).
      if (path.contains('://localhost') || path.contains('://127.0.0.1')) {
        try {
          final uri = Uri.parse(path);
          return '${ApiConfig.baseUrl}${uri.path}';
        } catch (_) {
          // Fallback if parsing fails
        }
      }
      return path;
    }
    if (path.startsWith('assets/')) {
      return path;
    }
    // Remove leading slash if any, then prepend ApiConfig.baseUrl
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '${ApiConfig.baseUrl}/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBannerHeight = context.isExpanded ? 320.0 : 260.0;
        final aspectRatio = 1000 / 600;
        final naturalHeight = constraints.maxWidth / aspectRatio;
        final height = naturalHeight.clamp(160.0, maxBannerHeight);

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
            onPageChanged: (index) {
              setState(() {
                _activeSlide = index;
              });
            },
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final hasImage = item.imagePath.trim().isNotEmpty;
              final imageUrl = hasImage ? _getImageUrl(item.imagePath) : '';

              return Container(
                margin: EdgeInsets.zero,
                child: Stack(
                  children: [
                    // Background Character/Flames layout
                    Positioned.fill(
                      child: hasImage
                          ? (imageUrl.startsWith('assets/')
                                ? Image.asset(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0.4, -0.2),
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _TextOnlyBanner(item: item),
                                  )
                                : AppNetworkImage(
                                    url: imageUrl,
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0.4, -0.2),
                                    errorWidget: _TextOnlyBanner(item: item),
                                  ))
                          : _TextOnlyBanner(item: item),
                    ),
                    if (hasImage)
                      // Vignette Overlay Effect
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 1.2,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                                stops: const [0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Gradient Dark Overlay (Bottom to Top) for dots readability
                    if (hasImage)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.5),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          // Stationary Pagination Dots
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.items.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _activeSlide == index ? 18 : 8,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: _activeSlide == index
                        ? const Color(0xFFFF6B00)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}

class _TextOnlyBanner extends StatelessWidget {
  final FeaturedTournament item;

  const _TextOnlyBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/background/tournment.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.88),
                Colors.black.withValues(alpha: 0.55),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.isLive)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'LIVE',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              Text(
                item.title.replaceAll('\\n', '\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: context.battlyOnSurface,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (item.prizePool.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.prizePool,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFD700),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (item.dateText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.dateText,
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
