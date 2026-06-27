import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/responsive/responsive.dart';
import '../core/theme/battly_theme.dart';

/// Opens the match room hosting rules sheet. Returns `true` when user taps "I Understand".
Future<bool?> showMatchRoomRulesSheet(BuildContext context) {
  return showAdaptiveSheet<bool>(
    context: context,
    isScrollControlled: true,
    maxWidth: 560,
    builder: (context) => const MatchRoomRulesSheet(),
  );
}

class MatchRoomRulesSheet extends StatelessWidget {
  const MatchRoomRulesSheet({super.key});

  static const _sections = [
    _RuleSection(
      title: '1. Host responsibilities',
      body:
          'As the room maker you must publish accurate lobby details (title, mode, entry fee, map, and schedule). '
          'You are responsible for creating the in-game room on time and sharing the room ID/password with registered players.',
    ),
    _RuleSection(
      title: '2. Entry fees & wallet',
      body:
          'Players pay the entry fee from their Battly wallet when joining. '
          'Prize pools are calculated from total collections. A 10% platform commission is deducted automatically before prize distribution.',
    ),
    _RuleSection(
      title: '3. Fair play',
      body:
          'Cheating, hacking, emulator abuse (unless allowed), team collusion, smurfing, or multi-accounting is strictly prohibited. '
          'Violations may result in disqualification, forfeiture of winnings, and account suspension.',
    ),
    _RuleSection(
      title: '4. Match settings',
      body:
          'Room settings you select (team size, throwable limits, character skills, map, and mode) are binding for all participants. '
          'Changing rules after players have joined requires cancelling and recreating the lobby.',
    ),
    _RuleSection(
      title: '5. Results & disputes',
      body:
          'Results must be submitted honestly with valid proof when requested. '
          'Disputes are reviewed by Battly moderators. False submissions or repeated disputes may lead to penalties.',
    ),
    _RuleSection(
      title: '6. Cancellations & refunds',
      body:
          'If a match is cancelled before start due to host error or insufficient players, entry fees are refunded to participants. '
          'No-shows or late room creation by the host may affect your hosting privileges.',
    ),
    _RuleSection(
      title: '7. Code of conduct',
      body:
          'Keep lobby chat respectful. Harassment, hate speech, or scam attempts are not tolerated. '
          'Battly may remove any lobby or suspend hosts who break community guidelines.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.battlyBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: Color(0xFFFF6B00),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rules & Regulations',
                          style: GoogleFonts.poppins(
                            color: context.battlyOnSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Custom match room hosting',
                          style: GoogleFonts.poppins(
                            color: context.battlyMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: context.battlyMuted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please read before publishing your lobby. By hosting a match room you agree to follow these rules.',
                      style: GoogleFonts.poppins(
                        color: context.battlyMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final section in _sections) ...[
                      _RuleBlock(section: section),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'I Understand',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleSection {
  final String title;
  final String body;

  const _RuleSection({required this.title, required this.body});
}

class _RuleBlock extends StatelessWidget {
  final _RuleSection section;

  const _RuleBlock({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: GoogleFonts.poppins(
              color: context.battlyOnSurface,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            section.body,
            style: GoogleFonts.poppins(
              color: context.battlyMuted,
              fontSize: 11.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
