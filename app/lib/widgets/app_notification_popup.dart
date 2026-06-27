import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/responsive/responsive.dart';
import '../core/theme/battly_theme.dart';
import '../core/notification_navigation.dart';
import '../services/api_config.dart';
import 'app_network_image.dart';

bool _isTrustedNotificationImageUrl(String url) {
  try {
    final uri = Uri.parse(url);
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;

    final host = uri.host.toLowerCase();
    final apiHost = Uri.parse(ApiConfig.baseUrl).host.toLowerCase();

    if (host == apiHost ||
        host == '127.0.0.1' ||
        host == 'localhost' ||
        host.contains('battly')) {
      return true;
    }

    const knownCdnHosts = [
      'storage.googleapis.com',
      'cdn.jsdelivr.net',
      'images.unsplash.com',
    ];
    return knownCdnHosts.any((cdn) => host == cdn || host.endsWith('.$cdn'));
  } catch (_) {
    return false;
  }
}

void showAppNotificationPopup(
  BuildContext context, {
  required int id,
  required String title,
  required String message,
  String? deepLink,
  required Function(bool doNotShowAgain) onClosed,
}) {
  bool doNotShowAgain = false;

  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final bool hasImage = isNotificationImageUrl(deepLink) &&
              _isTrustedNotificationImageUrl(deepLink!);
          final tournamentId = parseTournamentDeepLink(deepLink);

          return Container(
            decoration: BoxDecoration(
              color: context.battlyScaffold,
              borderRadius: context.useNavigationRail
                  ? BorderRadius.circular(24)
                  : const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
              border: Border.all(color: context.battlyBorder, width: 1.5),
            ),
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle indicator
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E4351),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: context.battlyOnSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onClosed(doNotShowAgain);
                      },
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Banner image
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppNetworkImage(
                      url: deepLink,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        height: 160,
                        width: double.infinity,
                        color: const Color(0xFF1E222A),
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Notification content message
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Checkbox toggle
                GestureDetector(
                  onTap: () {
                    setSheetState(() {
                      doNotShowAgain = !doNotShowAgain;
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: doNotShowAgain,
                            activeColor: const Color(0xFFFF6B00),
                            checkColor: Colors.white,
                            side: BorderSide(color: context.battlyBorder, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) {
                              setSheetState(() {
                                doNotShowAgain = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Don't show this again",
                          style: GoogleFonts.poppins(
                            color: context.battlyMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (tournamentId != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onClosed(doNotShowAgain);
                        openTournamentDeepLink(context, deepLink);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF6B00)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Open Tournament',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFF6B00),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Primary acknowledge button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onClosed(doNotShowAgain);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Acknowledge',
                      style: GoogleFonts.poppins(
                        color: context.battlyOnSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
