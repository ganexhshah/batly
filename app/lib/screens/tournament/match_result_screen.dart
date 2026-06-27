import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../widgets/battly_share_sheet.dart';
import '../../widgets/query_error_view.dart';
import 'match_details_screen.dart';
import 'prize_distribution_screen.dart';
import '../../core/theme/battly_theme.dart';

class MatchResultScreen extends StatefulWidget {
  final UpcomingTournament tournament;
  final String roundName;
  final String mapName;
  final String roundTime;

  const MatchResultScreen({
    super.key,
    required this.tournament,
    required this.roundName,
    required this.mapName,
    required this.roundTime,
  });

  @override
  State<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends State<MatchResultScreen> {
  bool _loadingResults = true;
  String? _resultsError;
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _myResult;

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
        _myResult = data['my_result'] as Map<String, dynamic>?;
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

  String get _winnerName {
    if (_leaderboard.isEmpty) return '—';
    return _playerName(_leaderboard.first as Map<String, dynamic>);
  }

  String get _myTeamLabel => _myResult != null ? _playerName(_myResult!) : _winnerName;

  String get _finalRank => _myResult?['rank']?.toString() ?? (_leaderboard.isNotEmpty ? '${(_leaderboard.first as Map)['rank'] ?? 1}' : '—');

  String get _totalKills => _myResult?['kills']?.toString() ?? '—';

  String get _totalPoints => _myResult?['points']?.toString() ?? '—';

  String get _mvpName {
    if (_leaderboard.isEmpty) return '—';
    final sorted = List<Map<String, dynamic>>.from(
      _leaderboard.whereType<Map<String, dynamic>>(),
    );
    sorted.sort((a, b) => ((b['kills'] as num?) ?? 0).compareTo((a['kills'] as num?) ?? 0));
    return sorted.isNotEmpty ? _playerName(sorted.first) : '—';
  }

  String get _mvpKills {
    if (_leaderboard.isEmpty) return '—';
    final sorted = List<Map<String, dynamic>>.from(
      _leaderboard.whereType<Map<String, dynamic>>(),
    );
    sorted.sort((a, b) => ((b['kills'] as num?) ?? 0).compareTo((a['kills'] as num?) ?? 0));
    return sorted.isNotEmpty ? '${sorted.first['kills'] ?? 0}' : '—';
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
          title: Text('Match Result', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 18)),
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
          title: Text('Match Result', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: QueryErrorView(message: _resultsError, onRetry: _loadResults),
      );
    }

    final String cleanPrize = widget.tournament.prizePool.replaceAll(RegExp(r'[^0-9]'), '');
    final double prizeValue = double.tryParse(cleanPrize) ?? 0.0;
    final double teamEarnings = prizeValue * 0.5;
    final double mvpReward = teamEarnings * 0.3;

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
          'Match Result',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              showBattlyShareSheet(
                context,
                title: 'Share Match Result',
                shareText: '$_winnerName Victory! Result in ${widget.tournament.title} ${widget.roundName}!',
              );
            },
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchDetailsScreen(
                      tournament: widget.tournament,
                      roundName: widget.roundName,
                      mapName: widget.mapName,
                      roundTime: widget.roundTime,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF9800), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: Color(0xFFFF9800), size: 11),
                    const SizedBox(width: 4),
                    Text(
                      'Match Details',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFF9800),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

            // 2. WINNER DINNER CARD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 54),
                      Positioned(
                        top: 10,
                        child: Text(
                          '#1',
                          style: GoogleFonts.poppins(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WINNER WINNER',
                          style: GoogleFonts.poppins(color: const Color(0xFFFF8C00), fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'CHICKEN DINNER!',
                          style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.battlyScaffold,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.battlyBorder),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      widget.tournament.logoAsset ?? 'assets/logo/night_showdown.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, color: Colors.purple, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _myTeamLabel,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'YOUR TEAM',
                          style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. STATS METRICS ROW (5 Cards)
            Row(
              children: [
                _buildMetricCard(Icons.emoji_events_outlined, 'Final Position', _finalRank, '/ ${widget.tournament.maxPlayers}'),
                const SizedBox(width: 6),
                _buildMetricCard(Icons.gps_fixed_rounded, 'Total Kills', _totalKills, 'Kills'),
                const SizedBox(width: 6),
                _buildMetricCard(Icons.stars_rounded, 'Total Points', _totalPoints, 'Points'),
                const SizedBox(width: 6),
                _buildMetricCard(Icons.shield_outlined, 'Placement Points', '—', 'Points'),
                const SizedBox(width: 6),
                _buildMetricCard(Icons.track_changes_rounded, 'Kill Points', '—', 'Points'),
              ],
            ),
            const SizedBox(height: 12),

            // 4. MVP CARD
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 42),
                      Positioned(
                        top: 20,
                        child: Text(
                          'MVP',
                          style: GoogleFonts.poppins(color: Colors.black, fontSize: 7.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF6B00), width: 1.5),
                    ),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundImage: AssetImage('assets/logo/profile_avatar.png'),
                      backgroundColor: Color(0xFF1E222A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _mvpName,
                              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$_mvpKills KILLS',
                                style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 7, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _buildMvpMiniStat('Damage Dealt', '2456'),
                            const SizedBox(width: 10),
                            _buildMvpMiniStat('Survival Time', '22:45'),
                            const SizedBox(width: 10),
                            _buildMvpMiniStat('Headshots', '6'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16181C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF222630)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Match Reward',
                              style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatAmount(mvpReward),
                              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. TEAM MEMBERS PERFORMANCE SECTION
            _buildSectionHeader('Team Members Performance'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Column(
                children: [
                  _buildPerformanceHeader(),
                  Container(height: 1, color: const Color(0xFF222630)),
                  if (_leaderboard.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No performance data yet.',
                        style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12),
                      ),
                    )
                  else
                    ..._leaderboard.take(4).toList().asMap().entries.map((entry) {
                      final row = entry.value as Map<String, dynamic>;
                      final name = _playerName(row);
                      final isYou = _myResult != null && row['user_id'] == _myResult!['user_id'];
                      final isMvp = name == _mvpName;
                      return Column(
                        children: [
                          if (entry.key > 0) Container(height: 1, color: const Color(0xFF1A1C22)),
                          _buildPerformanceRow(
                            name,
                            isYou,
                            isMvp,
                            '${row['kills'] ?? '—'}',
                            '—',
                            '—',
                            '—',
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. FINAL STANDINGS SECTION
            _buildSectionHeader(
              'Final Standings',
              trailing: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFFFF6B00),
                      content: Text('Viewing Full Leaderboard...', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Full Leaderboard',
                      style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF6B00), size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  if (_leaderboard.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No standings published yet.',
                        style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12),
                      ),
                    )
                  else
                    ..._leaderboard.take(4).toList().asMap().entries.expand((entry) {
                      final row = entry.value as Map<String, dynamic>;
                      final rank = '${row['rank'] ?? entry.key + 1}';
                      final widgets = <Widget>[];
                      if (entry.key > 0) {
                        widgets.add(Container(height: 1, color: const Color(0xFF1A1C22)));
                      }
                      widgets.add(_buildStandingRow(
                        rank,
                        _playerName(row),
                        widget.tournament.logoAsset ?? 'assets/logo/battly_cup.png',
                        '${row['kills'] ?? '—'}',
                        '—',
                        '${row['points'] ?? '—'}',
                      ));
                      return widgets;
                    }),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 7. YOUR EARNINGS PANEL
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrizeDistributionScreen(
                      tournament: widget.tournament,
                      roundName: widget.roundName,
                      mapName: widget.mapName,
                      roundTime: widget.roundTime,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
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
                            'Your Earnings',
                            style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 24),
                              const SizedBox(width: 6),
                              Text(
                                formatAmount(teamEarnings),
                                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reward Status',
                          style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'CREDITED',
                                style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Image.asset(
                      'assets/logo/glowing_gift.png',
                      width: 58,
                      height: 58,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 42),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Color(0xFF07080A),
          border: Border(
            top: BorderSide(color: Color(0xFF1C1F26), width: 1.0),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFFF6B00),
                        content: Text('Opening Match Timeline...', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 14),
                  label: Text(
                    'Match Timeline',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Color(0xFF2B2F3A), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Back to Matches',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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

  Widget _buildMetricCard(IconData icon, String label, String value, String subValue) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF101216),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF222630)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFF6B00), size: 14),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 7.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    subValue,
                    style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 7.5, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMvpMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: const Color(0x40A0A0A0), fontSize: 7, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPerformanceHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Player', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Kills', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Damage', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('Survival Time', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Revives', style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(String name, bool isYou, bool isMvp, String kills, String damage, String survival, String revives) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundImage: AssetImage('assets/logo/profile_avatar.png'),
                  backgroundColor: Color(0xFF1E222A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: name,
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        if (isYou)
                          TextSpan(
                            text: ' (You)',
                            style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        if (isMvp) ...[
                          const WidgetSpan(child: SizedBox(width: 4)),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'MVP',
                                style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 7, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              kills,
              style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              damage,
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              survival,
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              revives,
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingRow(String rank, String teamName, String logoPath, String kills, String placementPts, String totalPoints) {
    Color rankColor;
    if (rank == '1') {
      rankColor = const Color(0xFFFF9800);
    } else if (rank == '2') {
      rankColor = const Color(0xFF757575);
    } else if (rank == '3') {
      rankColor = const Color(0xFF8D6E63);
    } else {
      rankColor = const Color(0xFF263238);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rankColor,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              rank,
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          // Logo + Team Name
          Expanded(
            flex: 5,
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
          // Kills
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  kills,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  'KILLS',
                  style: GoogleFonts.poppins(color: const Color(0x30A0A0A0), fontSize: 6.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Placement Pts
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  placementPts,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  'PLACEMENT PTS',
                  style: GoogleFonts.poppins(color: const Color(0x30A0A0A0), fontSize: 6.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Total Points
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  totalPoints,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  'TOTAL POINTS',
                  style: GoogleFonts.poppins(color: const Color(0x30A0A0A0), fontSize: 6.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
