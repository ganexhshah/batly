import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../core/theme/battly_theme.dart';

// -----------------------------------------------------------------------------
// TOURNAMENT CARD WIDGET
// -----------------------------------------------------------------------------
class TournamentCard extends StatelessWidget {
  final UpcomingTournament tournament;
  final VoidCallback onTap;

  const TournamentCard({
    super.key,
    required this.tournament,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFFF6B00);
    final isRegistration = tournament.statusText == 'REGISTRATION';

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.2),
            primaryColor.withValues(alpha: 0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(1.0), // Outer gradient border thickness
      child: Container(
        decoration: BoxDecoration(
          color: context.battlyCard,
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: isDark
                ? [context.battlyCard, context.battly.elevatedSurface]
                : [Colors.white, const Color(0xFFF9FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              // Reduced horizontal and vertical padding as requested
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo (Rectangle shape as requested)
                  _LogoBadge(
                    isRegistration: isRegistration,
                  ),
                  const SizedBox(width: 10), // Reduced space between columns
                  // Middle & Info details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row for Title & Status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                tournament.title,
                                style: GoogleFonts.poppins(
                                  color: context.battlyOnSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isRegistration
                                    ? primaryColor.withValues(alpha: 0.1)
                                    : context.battlyBorder.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isRegistration ? primaryColor : context.battlyBorder,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                tournament.statusText,
                                style: GoogleFonts.poppins(
                                  color: isRegistration
                                      ? primaryColor
                                      : context.battlyOnSurface.withValues(alpha: 0.7),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Format chips (Wrap instead of Row to avoid overflow)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _FormatChip(text: tournament.type, isPrimary: true),
                            _FormatChip(text: tournament.mode),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Slots capacity bar
                        _SlotsProgressBar(
                          current: tournament.currentPlayers,
                          max: tournament.maxPlayers,
                        ),
                        const SizedBox(height: 8),
                        // Rewards and entry fee badges (Wrap to prevent overflow)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _RewardPill(
                              text: tournament.prizePool,
                              icon: Icons.emoji_events_rounded,
                              color: const Color(0xFFFFD700), // Gold
                            ),
                            _RewardPill(
                              text: tournament.entryFee,
                              icon: Icons.local_activity_rounded,
                              color: const Color(0xFF4CAF50), // Green
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Divider
                        Container(
                          height: 0.5,
                          color: context.battlyBorder.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 6),
                        // Bottom row: Date and Timer
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Date
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  color: context.battlyMuted,
                                  size: 10,
                                ),
                                const SizedBox(width: 4),
                                 Text(
                                  tournament.dateText,
                                  style: GoogleFonts.poppins(
                                    color: context.battlyMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (tournament.creatorName != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: context.battlyBorder,
                                backgroundImage: tournament.creatorAvatar != null &&
                                        tournament.creatorAvatar!.isNotEmpty
                                    ? NetworkImage(tournament.creatorAvatar!)
                                        as ImageProvider
                                    : const AssetImage(
                                        'assets/logo/battly_cup.png'),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Hosted by ',
                                style: GoogleFonts.poppins(
                                  color: context.battlyMuted,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                tournament.creatorName!,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFF6B00),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Chevron right
                  const Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(top: 24.0),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFA0A0A0),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LOGO BADGE EXTRACTED COMPONENT
// -----------------------------------------------------------------------------
class _LogoBadge extends StatelessWidget {
  final bool isRegistration;

  const _LogoBadge({required this.isRegistration});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF6B00);
    const goldColor = Color(0xFFFFD700);

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6), // Rectangle shape
        border: Border.all(
          color: (isRegistration ? goldColor : primaryColor).withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.5), // Inner rectangle
        child: Image.asset(
          UpcomingTournament.defaultLogoAsset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: context.battlyScaffold,
            child: Icon(
              Icons.emoji_events,
              color: isRegistration ? goldColor : primaryColor,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FORMAT CHIP EXTRACTED COMPONENT
// -----------------------------------------------------------------------------
class _FormatChip extends StatelessWidget {
  final String text;
  final bool isPrimary;

  const _FormatChip({required this.text, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFFF6B00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPrimary
            ? accentColor.withValues(alpha: 0.08)
            : context.battlyBorder.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPrimary
              ? accentColor.withValues(alpha: 0.2)
              : context.battlyBorder.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: isPrimary ? accentColor : context.battlyOnSurface.withValues(alpha: 0.8),
          fontSize: 10,
          fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SLOTS PROGRESS BAR EXTRACTED COMPONENT
// -----------------------------------------------------------------------------
class _SlotsProgressBar extends StatelessWidget {
  final int current;
  final int max;

  const _SlotsProgressBar({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final percent = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    const accentColor = Color(0xFFFF6B00);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  color: context.battlyMuted,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Text(
                  '$current/$max Slots Filled',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: GoogleFonts.poppins(
                color: accentColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: context.battlyBorder.withValues(alpha: 0.4),
              valueColor: const AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// REWARD PILL EXTRACTED COMPONENT
// -----------------------------------------------------------------------------
class _RewardPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _RewardPill({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
