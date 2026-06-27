import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../widgets/query_error_view.dart';
import '../../core/theme/battly_theme.dart';

class PrizeDistributionScreen extends StatefulWidget {
  final UpcomingTournament tournament;
  final String roundName;
  final String mapName;
  final String roundTime;

  const PrizeDistributionScreen({
    super.key,
    required this.tournament,
    required this.roundName,
    required this.mapName,
    required this.roundTime,
  });

  @override
  State<PrizeDistributionScreen> createState() => _PrizeDistributionScreenState();
}

class _PrizeDistributionScreenState extends State<PrizeDistributionScreen> {
  bool _loadingResults = true;
  String? _resultsError;
  List<dynamic> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    if (widget.tournament.id == null) {
      if (mounted) setState(() => _loadingResults = false);
      return;
    }
    setState(() {
      _loadingResults = true;
      _resultsError = null;
    });
    try {
      final data = await ApiService.getTournamentResults(widget.tournament.id!);
      if (!mounted) return;
      setState(() {
        _leaderboard = data['leaderboard'] as List<dynamic>? ?? [];
        _loadingResults = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultsError = e.toString().replaceFirst('Exception: ', '');
        _loadingResults = false;
      });
    }
  }

  String _playerName(Map<String, dynamic> row) {
    return (row['team_name'] as String? ??
            row['ign'] as String? ??
            row['name'] as String? ??
            'Player')
        .trim();
  }

  double _prizeForRank(int rank) {
    final String cleanPrize = widget.tournament.prizePool.replaceAll(RegExp(r'[^0-9]'), '');
    final double prizeValue = double.tryParse(cleanPrize) ?? 0.0;
    if (rank == 1) return prizeValue * 0.5;
    if (rank == 2) return prizeValue * 0.3;
    if (rank == 3) return prizeValue * 0.2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingResults) {
      return Scaffold(
        backgroundColor: context.battly.navBar,
        appBar: AppBar(
          backgroundColor: context.battly.navBar,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Prize Distribution', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
      );
    }

    if (_resultsError != null) {
      return Scaffold(
        backgroundColor: context.battly.navBar,
        appBar: AppBar(
          backgroundColor: context.battly.navBar,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Prize Distribution', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: QueryErrorView(message: _resultsError, onRetry: _loadResults),
      );
    }

    final String cleanPrize = widget.tournament.prizePool.replaceAll(RegExp(r'[^0-9]'), '');
    final double prizeValue = double.tryParse(cleanPrize) ?? 0.0;
    final double firstPrize = prizeValue * 0.5;
    final double secondPrize = prizeValue * 0.3;
    final double thirdPrize = prizeValue * 0.2;

    String formatAmount(double amount) {
      if (amount <= 0) return 'TBD';
      return 'NPR ${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    }

    return Scaffold(
      backgroundColor: context.battly.navBar,
      appBar: AppBar(
        backgroundColor: context.battly.navBar,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Prize Distribution',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {
              // How it works bottom sheet
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF0F1115),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      border: Border(top: BorderSide(color: Color(0xFF2B2F3A), width: 1.5)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(color: const Color(0xFF3E4351), borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Prize Payout Process',
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Upon completion and verification of match results, the prize pool is distributed directly to the team captain\'s wallets or registered accounts by Battly administrators. Transfers are final and verified on-chain or via local bank channels.',
                          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12, height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
                            child: Text('Understood', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFFFF9800), size: 14),
            label: Text(
              'How it works',
              style: GoogleFonts.poppins(color: const Color(0xFFFF9800), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. MATCH HEADER CARD
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: context.battlyScaffold,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.battlyBorder),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      widget.tournament.logoAsset ?? 'assets/logo/battly_cup.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_esports_rounded, color: Color(0xFFFF6B00), size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.roundName.toUpperCase()} • MATCH 3',
                          style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.tournament.title,
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Color(0xFFFF9800), size: 10),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.tournament.dateText.contains('•') ? widget.tournament.dateText.split('•')[0].trim() : widget.tournament.dateText} • ${widget.roundTime}',
                              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9.5),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.people_outline_rounded, color: Color(0xFFFF9800), size: 10),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.tournament.maxPlayers} Teams',
                              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'COMPLETED',
                              style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Image.asset(
                        'assets/logo/treasure_chest.png',
                        width: 42,
                        height: 42,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.inventory_2_outlined, color: Colors.amber, size: 28),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. TOTAL PRIZE POOL CARD
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3), width: 1.2),
                    ),
                    child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Prize Pool',
                          style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              widget.tournament.prizePool,
                              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(100% Distributed)',
                              style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Small list table on the right
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Distributed',
                            style: GoogleFonts.poppins(color: const Color(0x40A0A0A0), fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.tournament.prizePool,
                            style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pending',
                            style: GoogleFonts.poppins(color: const Color(0x40A0A0A0), fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'NPR 0',
                            style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. PRIZE BREAKDOWN SECTION
            _buildSectionHeader('Prize Breakdown'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildBreakdownCard(
                    Icons.emoji_events_rounded,
                    '1st Place',
                    formatAmount(firstPrize),
                    'PAID',
                    const Color(0xFFFFD700),
                    const Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 8),
                  _buildBreakdownCard(
                    Icons.emoji_events_rounded,
                    '2nd Place',
                    formatAmount(secondPrize),
                    'PAID',
                    const Color(0xFFC0C0C0),
                    const Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 8),
                  _buildBreakdownCard(
                    Icons.emoji_events_rounded,
                    '3rd Place',
                    formatAmount(thirdPrize),
                    'PAID',
                    const Color(0xFFCD7F32),
                    const Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 8),
                  _buildBreakdownCard(
                    Icons.tag_rounded,
                    '4th - 10th Place',
                    'NPR 0',
                    'NOT APPLICABLE',
                    const Color(0x30A0A0A0),
                    const Color(0x40A0A0A0),
                    isNa: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. PAYOUT DETAILS SECTION
            _buildSectionHeader('Payout Details'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Column(
                children: [
                  _buildPayoutHeader(),
                  Container(height: 1, color: const Color(0xFF222630)),
                  if (_leaderboard.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No payout data published yet.',
                        style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12),
                      ),
                    )
                  else
                    ..._leaderboard.take(3).toList().asMap().entries.map((entry) {
                      final row = entry.value as Map<String, dynamic>;
                      final rank = (row['rank'] as num?)?.toInt() ?? entry.key + 1;
                      final prize = (row['prize_amount'] as num?)?.toDouble() ?? _prizeForRank(rank);
                      return Column(
                        children: [
                          if (entry.key > 0) Container(height: 1, color: const Color(0xFF1A1C22)),
                          _buildPayoutRow(
                            '$rank',
                            _playerName(row),
                            widget.tournament.logoAsset ?? 'assets/logo/battly_cup.png',
                            formatAmount(prize),
                            prize > 0 ? 'PAID' : 'PENDING',
                            '—',
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. PAYMENT INFORMATION SECTION
            _buildSectionHeader('Payment Information'),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildInfoBlock(Icons.account_balance_rounded, 'Payment Method', 'Bank Transfer'),
                const SizedBox(width: 6),
                _buildInfoBlock(Icons.verified_user_outlined, 'Processed By', 'Battly Admin'),
                const SizedBox(width: 6),
                _buildInfoBlock(Icons.calendar_today_rounded, 'Distribution Completed On', '26 May, 2024\n10:45 PM'),
              ],
            ),
            const SizedBox(height: 16),

            // Green Confirmation Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4CAF50), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All prizes have been successfully distributed to the respective teams. Thank you for participating in ${widget.tournament.title}! 🎉',
                      style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 10.5, fontWeight: FontWeight.w500, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. NEED HELP SECTION
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Help?',
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'If you have any issues regarding your prize, contact our support team.',
                          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFFFF6B00),
                          content: Text('Opening Support Ticket...', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.headset_mic_outlined, color: Color(0xFFFF9800), size: 14),
                    label: Text(
                      'Contact Support',
                      style: GoogleFonts.poppins(color: const Color(0xFFFF9800), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFFFF9800), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 7. FAIR PLAY FOOTER BANNER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gpp_good_outlined, color: Color(0xFFFF6B00), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fair Play. Fair Rewards.',
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'We appreciate your dedication and sportsmanship. Keep competing, keep winning!',
                          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Image.asset(
                    'assets/logo/glowing_gift.png',
                    width: 58,
                    height: 58,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 42),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 3.5,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // ignore: use_null_aware_elements
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildBreakdownCard(IconData icon, String title, String amount, String statusText, Color themeColor, Color statusColor, {bool isNa = false}) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101216),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF222630)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: themeColor, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            amount,
            style: GoogleFonts.poppins(color: isNa ? context.battlyMuted : const Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.poppins(color: statusColor, fontSize: 7, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Position', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text('Team', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text('Prize Amount', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Status', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('Paid On', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildPayoutRow(String position, String teamName, String logoPath, String prizeAmount, String statusText, String paidOn, {bool isNa = false}) {
    Color rankColor;
    if (position == '1') {
      rankColor = const Color(0xFFFF9800);
    } else if (position == '2') {
      rankColor = const Color(0xFF757575);
    } else if (position == '3') {
      rankColor = const Color(0xFF8D6E63);
    } else {
      rankColor = const Color(0xFF263238);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        children: [
          // Position Rank Box
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  position,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          // Team Name + Logo
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: context.battlyScaffold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(
                    logoPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, color: Colors.white24, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teamName,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11.5, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Prize Amount
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 12),
                const SizedBox(width: 4),
                Text(
                  prizeAmount,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isNa ? const Color(0x30A0A0A0) : const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.poppins(color: isNa ? context.battlyMuted : const Color(0xFF4CAF50), fontSize: 7.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          // Paid On
          Expanded(
            flex: 3,
            child: Text(
              paidOn,
              style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8.5, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF101216),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF222630)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFF6B00), size: 16),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(color: const Color(0x40A0A0A0), fontSize: 7.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 9.5, fontWeight: FontWeight.bold, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
