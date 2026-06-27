import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../core/theme/battly_theme.dart';

class LobbyTournamentCard extends StatelessWidget {
  final UpcomingTournament tournament;
  final VoidCallback onTap;

  const LobbyTournamentCard({
    super.key,
    required this.tournament,
    required this.onTap,
  });

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      final days = duration.inDays.toString().padLeft(2, '0');
      final hours = (duration.inHours % 24).toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      return '$days d : $hours h : $minutes m';
    } else {
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours : $minutes : $seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegistration = tournament.statusText == 'REGISTRATION';
    final isFull = tournament.currentPlayers >= tournament.maxPlayers;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Main Section
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo Badge
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.battlyScaffold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        UpcomingTournament.defaultLogoAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.emoji_events,
                          color: isRegistration ? const Color(0xFFFFD700) : const Color(0xFFFF6B00),
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Middle Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status outline badge
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isRegistration
                                      ? const Color(0xFFFF6B00).withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isRegistration
                                        ? const Color(0xFFFF6B00)
                                        : const Color(0xFFFF6B00).withValues(alpha: 0.5),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  tournament.statusText,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFF6B00),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isRegistration && isFull)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE53935), width: 1.0),
                                  ),
                                  child: Text(
                                    'FULL',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFE53935),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            tournament.title,
                            style: GoogleFonts.poppins(color: context.battlyOnSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Subtitle (Squad • Battle Royale)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: tournament.type,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFF6B00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' • ${tournament.mode}',
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
                          const SizedBox(height: 6),
                          // Date Time
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  color: Color(0xFFFF6B00),
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tournament.dateText,
                                  style: GoogleFonts.poppins(
                                    color: context.battlyMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (tournament.creatorName != null) ...[
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 7,
                                    backgroundColor: context.battlyBorder,
                                    backgroundImage: tournament.creatorAvatar != null &&
                                            tournament.creatorAvatar!.isNotEmpty
                                        ? NetworkImage(
                                                tournament.creatorAvatar!)
                                            as ImageProvider
                                        : const AssetImage(
                                            'assets/logo/battly_cup.png'),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Hosted by ',
                                    style: GoogleFonts.poppins(
                                      color: context.battlyMuted,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    tournament.creatorName!,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFF6B00),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right Details (Prize Pool & Entry Fee)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PRIZE POOL',
                          style: GoogleFonts.poppins(
                            color: context.battlyMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 12),
                            const SizedBox(width: 3),
                            Text(
                              tournament.prizePool,
                              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ENTRY FEE',
                          style: GoogleFonts.poppins(
                            color: context.battlyMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tournament.entryFee,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF4CAF50), // Vibrant green
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    // Chevron Right
                    const Padding(
                      padding: EdgeInsets.only(top: 24.0),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFA0A0A0),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Separator divider
              Container(
                height: 1.0,
                color: context.battlyBorder,
              ),
              // Bottom Footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Registered Teams Info
                    Expanded(
                      flex: 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_outline_rounded,
                              color: Color(0xFFA0A0A0),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${tournament.currentPlayers}/${tournament.maxPlayers} ',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFF6B00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Teams Registered',
                                    style: GoogleFonts.poppins(
                                      color: context.battlyMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Timer Ends in/Starts in
                    Expanded(
                      flex: 5,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          children: [
                            Text(
                              isRegistration ? 'Ends in ' : 'Starts in ',
                              style: GoogleFonts.poppins(
                                color: context.battlyMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              _formatDuration(tournament.timerDuration),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFF6B00),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
