import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../models/app_models.dart';
import '../models/prize_distribution.dart';
import '../services/api_service.dart';
import '../screens/tournament/submit_result_screen.dart';
import '../screens/tournament/verification_status_screen.dart';
import '../core/theme/battly_theme.dart';
import '../core/auth_errors.dart';

class TournamentResultsTab extends StatefulWidget {
  final UpcomingTournament tournament;
  final bool isOwner;
  final VoidCallback? onRefresh;

  const TournamentResultsTab({
    super.key,
    required this.tournament,
    required this.isOwner,
    this.onRefresh,
  });

  @override
  State<TournamentResultsTab> createState() => _TournamentResultsTabState();
}

class _TournamentResultsTabState extends State<TournamentResultsTab> {
  bool _loading = true;
  bool _publishing = false;
  String? _loadError;
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _myResult;
  bool _resultsPublished = false;
  bool _resultsLocked = false;
  bool _canSubmit = false;
  bool _canManage = false;

  final Map<int, TextEditingController> _rankControllers = {};
  final Map<int, TextEditingController> _killsControllers = {};
  final Map<int, TextEditingController> _pointsControllers = {};

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    for (final c in _rankControllers.values) {
      c.dispose();
    }
    for (final c in _killsControllers.values) {
      c.dispose();
    }
    for (final c in _pointsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _roundName => widget.tournament.customSettings?['round_name'] as String? ?? 'Round 1';
  String get _mapName => widget.tournament.customSettings?['map'] as String? ?? 'Bermuda';
  String get _roundTime {
    final cs = widget.tournament.customSettings;
    if (cs?['round_time'] != null) return cs!['round_time'] as String;
    return widget.tournament.dateText.contains('•')
        ? widget.tournament.dateText.split('•').last.trim()
        : widget.tournament.dateText;
  }

  Future<void> _loadResults() async {
    if (widget.tournament.id == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await ApiService.getTournamentResults(widget.tournament.id!);
      if (!mounted) return;

      final board = data['leaderboard'] as List<dynamic>? ?? [];
      _initOwnerControllers(board);

      setState(() {
        _leaderboard = board;
        _myResult = data['my_result'] as Map<String, dynamic>?;
        _resultsPublished = data['results_published'] as bool? ?? false;
        _resultsLocked = data['results_locked'] as bool? ?? widget.tournament.resultsLocked;
        _canSubmit = data['can_submit'] as bool? ?? false;
        _canManage = data['can_manage_results'] as bool? ?? false;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = AuthErrors.isAuthException(e)
          ? 'You do not have access to view results for this tournament.'
          : 'Failed to load results: $e';
      setState(() {
        _loading = false;
        _loadError = message;
      });
    }
  }

  void _initOwnerControllers(List<dynamic> board) {
    if (!widget.isOwner) return;

    for (var i = 0; i < board.length; i++) {
      final row = board[i] as Map<String, dynamic>;
      final userId = (row['user_id'] as num?)?.toInt();
      if (userId == null) continue;
      _rankControllers[userId]?.dispose();
      _killsControllers[userId]?.dispose();
      _pointsControllers[userId]?.dispose();

      _rankControllers[userId] = TextEditingController(
        text: '${row['rank'] ?? (i + 1)}',
      );
      _killsControllers[userId] = TextEditingController(
        text: '${row['kills'] ?? 0}',
      );
      _pointsControllers[userId] = TextEditingController(
        text: '${row['points'] ?? 0}',
      );
    }
  }

  PrizeDistributionInfo get _prizeInfo =>
      widget.tournament.prizeDistribution ??
      PrizeDistributionInfo.fallback(
        prizePoolText: widget.tournament.prizePool,
        entryFeeText: widget.tournament.entryFee,
        maxPlayers: widget.tournament.maxPlayers,
        customSettings: widget.tournament.customSettings,
      );

  bool get _pendingReview {
    if (_resultsLocked) return false;
    if (widget.tournament.resultsPendingReview) return true;
    return _leaderboard.any(
      (row) => (row as Map<String, dynamic>)['status'] == 'pending_admin_review',
    );
  }

  bool get _locked => _resultsLocked || widget.tournament.resultsLocked;

  String get _publishConfirmMessage {
    if (_prizeInfo.isWinnerTakesAll) {
      return 'Submit final results for admin review? Prizes are credited only after Battly approves the outcome.';
    }
    return 'Submit final results for admin review? Top 3 prizes are credited only after Battly approves the outcome.';
  }

  String get _publishButtonLabel => 'Submit Results for Review';

  String get _leaderboardHint {
    if (_prizeInfo.isWinnerTakesAll) {
      return 'Set rank, kills, and points for each player. Rank #1 receives 100% of the prize pool.';
    }
    return 'Set rank, kills, and points for each player. Top 3 get 50% / 30% / 20% of the prize pool.';
  }

  Future<void> _publishResults() async {
    if (widget.tournament.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.battlyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Submit for Review', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
        content: Text(
          _publishConfirmMessage,
          style: GoogleFonts.poppins(color: context.battlyMuted, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins(color: context.battlyMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
            child: Text('Submit', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final payload = <Map<String, dynamic>>[];
    for (final row in _leaderboard) {
      final m = row as Map<String, dynamic>;
      final userId = (m['user_id'] as num?)?.toInt();
      if (userId == null) continue;
      final rankText = _rankControllers[userId]?.text.trim() ?? '';
      final killsText = _killsControllers[userId]?.text.trim() ?? '';
      final pointsText = _pointsControllers[userId]?.text.trim() ?? '';
      if (rankText.isEmpty || killsText.isEmpty || pointsText.isEmpty) {
        _showSnack('Rank, kills, and points are required for every player.', isError: true);
        return;
      }
      final rank = int.tryParse(rankText);
      final kills = int.tryParse(killsText);
      final points = int.tryParse(pointsText);
      if (rank == null || kills == null || points == null) {
        _showSnack('Enter valid numbers for rank, kills, and points.', isError: true);
        return;
      }
      payload.add({
        'user_id': userId,
        'rank': rank,
        'kills': kills,
        'points': points,
      });
    }

    setState(() => _publishing = true);
    final res = await ApiService.publishTournamentResults(widget.tournament.id!, payload);
    if (!mounted) return;
    setState(() => _publishing = false);

    if (res['success'] == true) {
      _showSnack(res['message'] ?? 'Results submitted for admin review.', isError: false);
      await _loadResults();
      widget.onRefresh?.call();
    } else {
      _showSnack(res['message'] ?? 'Failed to publish', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
        content: Text(msg, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _openSubmitResult() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmitResultScreen(
          tournament: widget.tournament,
          roundName: _roundName,
          mapName: _mapName,
          roundTime: _roundTime,
        ),
      ),
    ).then((_) => _loadResults());
  }

  void _openVerificationStatus() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationStatusScreen(
          tournament: widget.tournament,
          roundName: _roundName,
          mapName: _mapName,
          roundTime: _roundTime,
          myResult: _myResult,
        ),
      ),
    ).then((_) => _loadResults());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFF1E222A),
        highlightColor: const Color(0xFF2B3040),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, i) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 56,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_loadError!, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: context.battlyMuted)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadResults, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFF6B00),
      onRefresh: _loadResults,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.isOwner && _myResult != null) _buildMyResultCard(),
          if (!widget.isOwner && _canSubmit) ...[
            _buildSubmitCard(),
            const SizedBox(height: 16),
          ],
          if (_locked) ...[
            _buildResultsLockedBanner(),
            const SizedBox(height: 12),
          ],
          if (widget.isOwner && _canManage && _pendingReview && !_resultsPublished && !_locked) ...[
            _buildPendingReviewBanner(),
            const SizedBox(height: 12),
          ],
          if (widget.isOwner && _canManage && !_resultsPublished && !_pendingReview && !_locked) ...[
            _buildOwnerHint(),
            const SizedBox(height: 12),
          ],
          _buildSectionTitle('Leaderboard'),
          const SizedBox(height: 10),
          if (_leaderboard.isEmpty)
            _buildEmptyState()
          else if (widget.isOwner && _canManage && !_resultsPublished && !_pendingReview && !_locked)
            ..._leaderboard.map((row) => _buildOwnerEditRow(row as Map<String, dynamic>))
          else
            ..._leaderboard.asMap().entries.map((e) => _buildLeaderboardRow(e.key + 1, e.value as Map<String, dynamic>)),
          if (widget.isOwner && _canManage && !_resultsPublished && !_pendingReview && !_locked && _leaderboard.isNotEmpty) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _publishing ? null : _publishResults,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _publishing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_publishButtonLabel, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          if (_resultsPublished) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(_locked ? Icons.lock_rounded : Icons.emoji_events_rounded, color: const Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _locked
                          ? (_prizeInfo.isWinnerTakesAll
                              ? 'Results locked by admin. Rank, kills, and prize cannot be changed.'
                              : 'Results locked by admin. Rank, kills, and prizes cannot be changed.')
                          : (_prizeInfo.isWinnerTakesAll
                              ? 'Final results published. Winner prize has been credited to wallet.'
                              : 'Final results published. Top 3 prizes have been credited to wallets.'),
                      style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 15));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Image.asset('assets/background/tournment.png', height: 90, fit: BoxFit.contain),
            const SizedBox(height: 12),
            Text('No results yet', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              widget.isOwner ? 'Enter ranks after the match and publish results.' : 'Results will appear here after the match.',
              style: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: Color(0xFFFF6B00), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$_leaderboardHint Results are reviewed by Battly before prizes are paid out.',
              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReviewBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF6B00), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Results submitted and awaiting admin review. Prizes will be credited after approval.',
              style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsLockedBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Results locked after admin approval. Rank, kills, and prizes cannot be edited.',
              style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyResultCard() {
    final r = _myResult!;
    final status = r['status'] as String? ?? 'scheduled';
    final rank = r['rank'];
    final kills = r['kills'];
    final points = r['points'];
    final prize = (r['prize_amount'] as num?)?.toDouble() ?? 0;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'verified':
        statusColor = const Color(0xFF4CAF50);
        statusLabel = 'Verified';
        break;
      case 'pending_verification':
        statusColor = const Color(0xFFFF6B00);
        statusLabel = 'Under Review';
        break;
      case 'rejected':
        statusColor = const Color(0xFFE53935);
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = context.battlyMuted;
        statusLabel = 'Pending';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Your Result'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.battlyCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel, style: GoogleFonts.poppins(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  if (prize > 0) ...[
                    const Spacer(),
                    Text('NPR ${prize.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ],
              ),
              if (rank != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip('Rank', '#$rank'),
                    _buildStatChip('Kills', '$kills'),
                    _buildStatChip('Points', '$points'),
                  ],
                ),
              ],
              if (status == 'pending_verification' || status == 'rejected') ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _openVerificationStatus,
                  child: Text('View Verification Status', style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.battlyScaffold,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submit Your Result', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Upload rank, kills, points and screenshot proof after the match.', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _openSubmitResult,
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: Text('Submit Result', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow(int position, Map<String, dynamic> row) {
    final name = (row['ign'] as String? ?? row['name'] as String? ?? 'Player').trim();
    final rank = row['rank'];
    final kills = row['kills'];
    final points = row['points'];
    final prize = (row['prize_amount'] as num?)?.toDouble() ?? 0;
    final isOwner = row['is_owner'] == true;

    Color rankBg;
    if (rank == 1) {
      rankBg = const Color(0xFFFF9800);
    } else if (rank == 2) {
      rankBg = const Color(0xFF757575);
    } else if (rank == 3) {
      rankBg = const Color(0xFF8D6E63);
    } else {
      rankBg = const Color(0xFF263238);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: rank != null ? rankBg : context.battlyBorder, borderRadius: BorderRadius.circular(6)),
            child: Text('${rank ?? position}', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    if (isOwner) ...[
                      const SizedBox(width: 4),
                      Text('Host', style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                Text('${kills ?? '-'} kills • ${points ?? '-'} pts', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9)),
              ],
            ),
          ),
          if (prize > 0)
            Text('NPR ${prize.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildOwnerEditRow(Map<String, dynamic> row) {
    final userId = (row['user_id'] as num?)?.toInt();
    if (userId == null) return const SizedBox.shrink();
    final name = (row['ign'] as String? ?? row['name'] as String? ?? 'Player').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMiniField('Rank', _rankControllers[userId]!)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniField('Kills', _killsControllers[userId]!)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniField('Points', _pointsControllers[userId]!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.battlyScaffold,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF2B2F3A))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF2B2F3A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFFFF6B00))),
          ),
        ),
      ],
    );
  }
}
