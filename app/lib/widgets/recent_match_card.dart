import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../core/theme/battly_theme.dart';

// -----------------------------------------------------------------------------
// RECENT MATCH CARD
// -----------------------------------------------------------------------------
class RecentMatchCard extends StatelessWidget {
  final RecentMatch match;
  final VoidCallback onTap;

  const RecentMatchCard({
    super.key,
    required this.match,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Game Emblem
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: context.battlyScaffold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    match.logoAsset ?? 'assets/logo/battly_cup.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.videogame_asset,
                      color: Color(0xFFFF6B00),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.title,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: match.type,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFF6B00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: ' • ${match.dateText}',
                                style: GoogleFonts.poppins(
                                  color: context.battlyMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Vertical divider
                Container(width: 1, height: 24, color: context.battlyBorder),
                const SizedBox(width: 16),
                // Position Stat Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: match.rankString.split('/').first,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFF6B00),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (match.rankString.contains('/'))
                            TextSpan(
                              text: '/${match.rankString.split('/').last}',
                              style: GoogleFonts.poppins(
                                color: context.battlyMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      match.rankString.contains('/') ? 'Position' : 'Status',
                      style: GoogleFonts.poppins(
                        color: context.battlyMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Vertical divider
                Container(width: 1, height: 24, color: context.battlyBorder),
                const SizedBox(width: 16),
                // Kills Stat Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      match.killsText,
                      style: GoogleFonts.poppins(color: context.battlyOnSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kills',
                      style: GoogleFonts.poppins(
                        color: context.battlyMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA0A0A0),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
