import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../core/cache_debug.dart';
import '../../services/auth_service.dart';
import '../../widgets/battly_share_sheet.dart';
import '../../widgets/tournament_results_tab.dart';
import '../../widgets/tournament_player_row.dart';
import '../../widgets/tournament_chat_tab.dart';
import 'tournament_dispute_screen.dart';
import 'submit_result_screen.dart';
import '../../core/json_parse.dart';
import '../../core/theme/battly_theme.dart';
import '../../models/match_flow_state.dart';
import '../../widgets/match_flow_panel.dart';
import '../../widgets/query_error_view.dart';

class JoinedTournamentScreen extends StatefulWidget {
  final UpcomingTournament tournament;
  final List<dynamic> participants;
  final VoidCallback onRefresh;

  const JoinedTournamentScreen({
    super.key,
    required this.tournament,
    required this.participants,
    required this.onRefresh,
  });

  @override
  State<JoinedTournamentScreen> createState() => _JoinedTournamentScreenState();
}

class _JoinedTournamentScreenState extends State<JoinedTournamentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UpcomingTournament _tournament;
  late List<dynamic> _participants;

  bool _isRefreshing = false;
  int? _currentUserId;
  bool _isReady = false;
  bool _leaving = false;
  TournamentRegistrationMeta _registrationMeta = const TournamentRegistrationMeta();
  int _readyCount = 0;
  List<dynamic> _readyPlayers = [];
  bool _loadingReady = false;
  MatchFlowState _matchFlow = const MatchFlowState();
  String? _loadError;

  static const _statusColors = {
    'registration': Color(0xFFFF6B00),
    'upcoming': Color(0xFF2196F3),
    'live': Color(0xFF4CAF50),
    'completed': Color(0xFFA0A0A0),
    'cancelled': Color(0xFFE53935),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tournament = widget.tournament;
    _participants = List.from(widget.participants);
    _loadCurrentUser();
  }

  Future<void> _loadInitialMeta() async {
    if (_tournament.id == null) return;
    try {
      final details = await ApiService.getTournamentDetails(_tournament.id!);
      if (!mounted) return;
      setState(() {
        _registrationMeta = details['registration'] as TournamentRegistrationMeta? ?? const TournamentRegistrationMeta();
        _matchFlow = details['match_flow'] as MatchFlowState? ?? const MatchFlowState();
        final me = _participants.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p?['id'] == _currentUserId,
          orElse: () => null,
        );
        _isReady = me?['is_ready'] as bool? ?? false;
        _loadError = null;
      });
      _loadReadyStatus();
    } catch (e, st) {
      logCacheRefreshFailure('joinedTournamentMeta', e, st);
      if (mounted) {
        setState(() => _loadError = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCachedUser();
    if (mounted && user != null) {
      setState(() => _currentUserId = AuthService.parseUserId(user));
      _loadInitialMeta();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final tournamentId = _tournament.id;
    if (tournamentId == null) {
      if (mounted) setState(() => _isRefreshing = false);
      return;
    }
    setState(() => _isRefreshing = true);
    try {
      final details = await ApiService.getTournamentDetails(tournamentId);
      if (mounted) {
        setState(() {
          _tournament = details['tournament'] as UpcomingTournament;
          _participants = parseParticipantList(details['participants']);
          _registrationMeta = details['registration'] as TournamentRegistrationMeta? ?? const TournamentRegistrationMeta();
          _matchFlow = details['match_flow'] as MatchFlowState? ?? const MatchFlowState();
          final me = _participants.cast<Map<String, dynamic>?>().firstWhere(
            (p) => p?['id'] == _currentUserId,
            orElse: () => null,
          );
          _isReady = me?['is_ready'] as bool? ?? false;
          _isRefreshing = false;
        });
        widget.onRefresh();
        _loadReadyStatus();
      }
    } catch (e, st) {
      logCacheRefreshFailure('joinedTournamentRefresh', e, st);
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _toggleReady(bool ready) async {
    if (_tournament.id == null) return;
    final res = await ApiService.setTournamentReady(_tournament.id!, ready: ready);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _isReady = res['is_ready'] as bool? ?? ready);
      _showSnack(res['message'] ?? (ready ? 'Ready!' : 'Not ready'), isError: false);
      _loadReadyStatus();
    } else {
      _showSnack(res['message'] ?? 'Failed', isError: true);
    }
  }

  Future<void> _leaveTournament() async {
    if (_tournament.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.battlyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Leave Tournament?', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
        content: Text(
          _registrationMeta.roomCodesShared
              ? 'Room codes were already shared. You cannot leave with a refund.'
              : 'Your entry fee will be refunded to your wallet.',
          style: GoogleFonts.poppins(color: context.battlyMuted, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins(color: context.battlyMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: Text('Leave', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _leaving = true);
    final res = await ApiService.leaveTournament(_tournament.id!);
    if (!mounted) return;
    setState(() => _leaving = false);
    if (res['success'] == true) {
      _showSnack(res['message'] ?? 'Left tournament', isError: false);
      widget.onRefresh();
      Navigator.pop(context);
    } else {
      _showSnack(res['message'] ?? 'Could not leave', isError: true);
    }
  }

  void _openDispute() {
    if (_tournament.id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentDisputeScreen(
          tournamentId: _tournament.id!,
          tournamentTitle: _tournament.title,
        ),
      ),
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
        content: Text(msg, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('$label copied!', isError: false);
  }

  void _shareTournament() {
    final t = _tournament;
    showBattlyShareSheet(
      context,
      title: 'Share Tournament',
      shareText: 'Join the ${t.title} Tournament on Battly!\n'
          'Entry Fee: ${t.entryFee}\n'
          'Prize Pool: ${t.prizePool}\n'
          'Players: ${_participants.length}/${t.maxPlayers}',
    );
  }

  Color get _statusColor {
    final key = _tournament.statusText.toLowerCase();
    return _statusColors[key] ?? context.battlyMuted;
  }

  bool get _isLive => _tournament.statusText.toLowerCase() == 'live';

  @override
  Widget build(BuildContext context) {
    final t = _tournament;

    return Scaffold(
      backgroundColor: context.battlyScaffold,
      appBar: AppBar(
        backgroundColor: context.battlyScaffold,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'My Lobby',
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              t.title,
              style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
            onPressed: _shareTournament,
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CAF50),
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: context.battlyMuted,
          dividerColor: const Color(0xFF1E2129),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
          tabs: const [
            Tab(text: 'LOBBY'),
            Tab(text: 'CHAT'),
            Tab(text: 'ROOM'),
            Tab(text: 'PLAYERS'),
            Tab(text: 'RESULTS'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildRegisteredBanner(t),
          _buildStatsBar(t),
          Expanded(
            child: _loadError != null
                ? QueryErrorView(
                    message: _loadError,
                    onRetry: () {
                      setState(() => _loadError = null);
                      _loadInitialMeta();
                    },
                  )
                : TabBarView(
              controller: _tabController,
              children: [
                _buildLobbyTab(t),
                TournamentChatTab(tournament: _tournament),
                _buildRoomTab(t.customSettings),
                _buildPlayersTab(),
                TournamentResultsTab(
                  tournament: _tournament,
                  isOwner: false,
                  onRefresh: () {
                    _refresh();
                    widget.onRefresh();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadReadyStatus() async {
    if (_tournament.id == null) return;
    setState(() => _loadingReady = true);
    try {
      final data = await ApiService.getReadyStatus(_tournament.id!);
      if (mounted) {
        final players = parseApiList(data['players']);
        setState(() {
          _readyPlayers = players;
          _readyCount = data['ready_count'] as int? ?? 0;
          _loadingReady = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReady = false);
    }
  }

  void _showReadyPlayersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1115),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFF2B2F3A), width: 1.5),
                ),
              ),
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Checked In Players',
                            style: GoogleFonts.poppins(
                              color: context.battlyOnSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$_readyCount / ${_participants.length} ready',
                            style: GoogleFonts.poppins(
                              color: context.battlyMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E222A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Color(0xFFA0A0A0), size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await _loadReadyStatus();
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF4CAF50)),
                      label: Text('Refresh', style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _readyPlayers.isEmpty
                        ? Center(
                            child: Text(
                              'No players have checked in yet',
                              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _readyPlayers.length,
                            itemBuilder: (context, index) {
                              final player = _readyPlayers[index] as Map<String, dynamic>;
                              final ready = player['is_ready'] as bool? ?? false;
                              final name = player['name'] as String? ?? 'Player';
                              final playerId = player['id'] ?? player['user_id'];
                              final isMe = _currentUserId != null && playerId == _currentUserId;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: ready
                                      ? const Color(0xFF132A13).withValues(alpha: 0.3)
                                      : context.battlyCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: ready
                                        ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                                        : context.battlyBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      ready ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                      color: ready ? const Color(0xFF4CAF50) : const Color(0xFF6B6F7A),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          color: context.battlyOnSurface,
                                          fontWeight: ready ? FontWeight.bold : FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (isMe)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          'YOU',
                                          style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    else
                                      Text(
                                        ready ? 'Ready' : 'Waiting',
                                        style: GoogleFonts.poppins(
                                          color: ready ? const Color(0xFF4CAF50) : const Color(0xFF6B6F7A),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
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

  Widget _buildReadyCheckToggleBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isReady ? const Color(0xFF132A13) : context.battlyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isReady ? const Color(0xFF4CAF50) : context.battlyBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            _isReady ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
            color: _isReady ? const Color(0xFF4CAF50) : const Color(0xFFFF6B00),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isReady ? 'Checked In' : 'Lobby Check-in',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  _isReady ? 'Room host can see you are ready.' : 'Mark ready to confirm your check-in status.',
                  style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch(
            value: _isReady,
            onChanged: (v) => _toggleReady(v),
            activeThumbColor: const Color(0xFF4CAF50),
            activeTrackColor: const Color(0xFF4CAF50).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildReadySummaryCard() {
    return GestureDetector(
      onTap: _showReadyPlayersSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.battlyCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.battlyBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.people_outline_rounded, color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Who\'s Ready?',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    '$_readyCount / ${_participants.length} players checked in',
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (_loadingReady)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)),
              )
            else ...[
              Text(
                'View List',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF4CAF50), size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRegisteredBanner(UpcomingTournament t) {
    final status = t.statusText.toLowerCase();
    final isCancelled = status == 'cancelled';
    final isCompleted = status == 'completed';

    String headline;
    String subtitle;
    Color accent;
    IconData icon;

    if (isCancelled) {
      headline = 'Tournament Cancelled';
      subtitle = 'Entry fee has been refunded to your wallet.';
      accent = const Color(0xFFE53935);
      icon = Icons.cancel_outlined;
    } else if (isCompleted) {
      headline = 'Tournament Completed';
      subtitle = 'Thanks for playing! Check results on the tournament page.';
      accent = context.battlyMuted;
      icon = Icons.emoji_events_outlined;
    } else if (_isLive) {
      headline = 'Match is Live!';
      subtitle = 'Join the room now using the codes in the ROOM tab.';
      accent = const Color(0xFF4CAF50);
      icon = Icons.play_circle_filled_rounded;
    } else {
      headline = 'You\'re Registered';
      subtitle = 'Room codes will appear here once the host sets them.';
      accent = const Color(0xFF4CAF50);
      icon = Icons.check_circle_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: GoogleFonts.poppins(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(UpcomingTournament t) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Row(
        children: [
          _buildStatChip('${_participants.length}/${t.maxPlayers}', 'Players', Icons.people_outline_rounded, const Color(0xFFFF6B00)),
          _buildStatDivider(),
          _buildStatChip(t.entryFee, 'Entry Paid', Icons.monetization_on_outlined, const Color(0xFF4CAF50)),
          _buildStatDivider(),
          _buildStatChip(t.statusText, 'Status', Icons.circle, _statusColor),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
          Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() => Container(width: 1, height: 36, color: context.battlyBorder);

  Widget _buildLobbyTab(UpcomingTournament t) {
    final status = t.statusText.toLowerCase();
    final cs = t.customSettings;
    final remaining = t.timerDuration;

    final isRegistration = status == 'registration';
    final isUpcoming = status == 'upcoming' && (cs?['room_id'] as String? ?? '').isEmpty;
    final isRoomShared = (cs?['room_id'] as String? ?? '').isNotEmpty && (status == 'upcoming' || status == 'room_shared' || status == 'roomshared');
    final isLiveState = status == 'live';
    final isPendingReview = t.resultsPendingReview || status == 'pending_review';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.isCustomMatchFlow && _matchFlow.applies) ...[
            MatchFlowPanel(
              tournamentId: _tournament.id!,
              initial: _matchFlow,
              isReady: _isReady,
              onToggleReady: _toggleReady,
              onFlowUpdated: (flow) => setState(() => _matchFlow = flow),
              onSnack: _showSnack,
            ),
            const SizedBox(height: 16),
          ],
          // ─── 1. REGISTRATION STATE ───
          if (isRegistration) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder, width: 1.5),
                gradient: LinearGradient(
                  colors: [context.battlyCard, const Color(0xFF1E2129)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.people_outline_rounded, color: Color(0xFFFF6B00), size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Waiting for Registrations',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Slots filled: ${t.currentPlayers} / ${t.maxPlayers}',
                    style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: t.maxPlayers > 0 ? t.currentPlayers / t.maxPlayers : 0,
                      backgroundColor: context.battlyScaffold,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Lobby will lock and move to UPCOMING once slots are filled.',
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildReadyCheckToggleBlock(),
            const SizedBox(height: 12),
            _buildReadySummaryCard(),
            const SizedBox(height: 16),
          ],

          // ─── 2. UPCOMING STATE (READY CHECK & COUNTDOWN) ───
          if (isUpcoming) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder, width: 1.5),
              ),
              child: Column(
                children: [
                  Text('Lobby Starts In', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11)),
                  const SizedBox(height: 8),
                  Text(
                    _formatCountdown(remaining),
                    style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 32),
                  ),
                  const SizedBox(height: 4),
                  Text(t.dateText, style: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildReadyCheckToggleBlock(),
            const SizedBox(height: 12),
            _buildReadySummaryCard(),
            const SizedBox(height: 16),
          ],

          // ─── 3. ROOM SHARED STATE (CODES) ───
          if (isRoomShared) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1B15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
                gradient: LinearGradient(
                  colors: [const Color(0xFF0F1B15), const Color(0xFF132A1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, color: Color(0xFF4CAF50), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Room Credentials Shared',
                        style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRoomCodeCard('Room ID', cs?['room_id'] as String? ?? '', Icons.tag_rounded),
                  const SizedBox(height: 12),
                  _buildRoomCodeCard('Password', cs?['room_password'] as String? ?? '', Icons.lock_outline_rounded),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.battlyScaffold,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.battlyBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFFF6B00), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Launch your game client and enter these credentials to join the custom room.',
                            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildReadyCheckToggleBlock(),
            const SizedBox(height: 12),
            _buildReadySummaryCard(),
            const SizedBox(height: 16),
          ],

          // ─── 4. LIVE STATE ───
          if (isLiveState) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1010),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE53935), width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.play_circle_filled_rounded, color: Color(0xFFE53935), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Match in Progress',
                    style: GoogleFonts.poppins(color: const Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The custom game is live. Do not leave the in-game lobby or violate rules.',
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── 5. PENDING REVIEW STATE (SUBMIT RESULTS TRIGGER) ───
          if (isPendingReview) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2C1A0A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF6B00), width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.rate_review_outlined, color: Color(0xFFFF6B00), size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Awaiting Review & Proofs',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upload your placement standing and score screenshots to claim your rewards.',
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Open SubmitResultScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubmitResultScreen(
                              tournament: _tournament,
                              roundName: 'Round 1',
                              mapName: cs?['map'] as String? ?? 'Bermuda',
                              roundTime: '',
                            ),
                          ),
                        ).then((_) => _refresh());
                      },
                      icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),
                      label: Text(
                        'Submit Match Score',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── 6. COMPLETED STATE ───
          if (isCompleted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1B13),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Tournament Completed',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Final brackets and verified cashout amounts have been computed.',
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        // Switch to RESULTS tab
                        _tabController.animateTo(4);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'View Leaderboard & Standings',
                        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── 7. CANCELLED STATE ───
          if (isCancelled) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1010),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE53935), width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cancel_outlined, color: Color(0xFFE53935), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Tournament Cancelled',
                    style: GoogleFonts.poppins(color: const Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All players have been refunded. Audited transaction amounts returned to wallets.',
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── GENERAL INFO DETAIL CARD ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.battlyBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Match Info', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                _buildInfoRow('Type', '${t.type} • ${t.mode}'),
                _buildInfoDivider(),
                _buildInfoRow('Prize Pool', t.prizePool),
                _buildInfoDivider(),
                _buildInfoRow('Scheduled', t.dateText),
                if (cs != null && cs['map'] != null) ...[
                  _buildInfoDivider(),
                  _buildInfoRow('Map', cs['map'] as String? ?? 'Bermuda'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── ACTION TRIGGER BUTTONS ───
          if (_registrationMeta.canLeave && !isRoomShared && !isLiveState && !isCompleted && !isCancelled) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _leaving ? null : _leaveTournament,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _leaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE53935)))
                    : Text('Leave & Refund', style: GoogleFonts.poppins(color: const Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isLiveState || isCompleted || isPendingReview) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openDispute,
                icon: const Icon(Icons.gavel_outlined, size: 16, color: Color(0xFFFF6B00)),
                label: Text('Raise Dispute', style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.battlyBorder, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _shareTournament,
            icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFFFF6B00)),
            label: Text('Invite Friends', style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTab(Map<String, dynamic>? cs) {
    final roomId = cs?['room_id'] as String? ?? '';
    final roomPass = cs?['room_password'] as String? ?? '';
    final hasCodes = roomId.isNotEmpty || roomPass.isNotEmpty;

    if (!hasCodes) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/background/tournment.png', height: 120, fit: BoxFit.contain),
              const SizedBox(height: 16),
              Text('Room Not Ready Yet', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              Text(
                'The room maker will share lobby ID and password here before the match starts. You\'ll also get a notification.',
                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.videogame_asset_rounded, color: Color(0xFF4CAF50), size: 18),
                    const SizedBox(width: 8),
                    Text('Lobby Details', style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 16),
                if (roomId.isNotEmpty) _buildRoomCodeCard('Room ID', roomId, Icons.tag_rounded),
                if (roomPass.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildRoomCodeCard('Password', roomPass, Icons.lock_outline_rounded),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.battlyBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFF6B00), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Copy the room ID and password, then join the in-game lobby before the match starts.',
                    style: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 10, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCodeCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.battlyScaffold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B6F7A), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10)),
                Text(value, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _copyToClipboard(value, label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
              ),
              child: Text('Copy', style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersTab() {
    if (_isRefreshing) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFF1E222A),
        highlightColor: const Color(0xFF2B3040),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (_, i) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 62,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    if (_participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/background/tournment.png', height: 100, fit: BoxFit.contain),
            const SizedBox(height: 12),
            Text('Waiting for players...', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final p = _participants[index] as Map<String, dynamic>;
        return TournamentPlayerRow(
          rank: index + 1,
          participant: p,
          style: TournamentPlayerRowStyle.lobby,
          isMe: _currentUserId != null && p['id'] == _currentUserId,
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11)),
          Flexible(
            child: Text(value, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDivider() => Divider(color: Color(0xFF2B2F3A), height: 8);

  String _formatCountdown(Duration d) {
    if (d.isNegative) return 'Starting soon';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
