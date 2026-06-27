import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/app_models.dart';
import '../../models/match_flow_state.dart';
import '../../services/api_service.dart';
import '../../core/cache_debug.dart';
import '../../services/auth_service.dart';
import '../../widgets/battly_share_sheet.dart';
import '../../widgets/tournament_player_row.dart';
import '../../widgets/tournament_team_invite_sheet.dart';
import '../../widgets/tournament_chat_tab.dart';
import 'submit_result_screen.dart';
import '../../core/json_parse.dart';
import '../../core/theme/battly_theme.dart';
import '../../widgets/match_flow_panel.dart';

class ManageTournamentScreen extends StatefulWidget {
  final UpcomingTournament tournament;
  final List<dynamic> participants;
  final VoidCallback onRefresh;

  const ManageTournamentScreen({
    super.key,
    required this.tournament,
    required this.participants,
    required this.onRefresh,
  });

  @override
  State<ManageTournamentScreen> createState() => _ManageTournamentScreenState();
}

class _ManageTournamentScreenState extends State<ManageTournamentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UpcomingTournament _tournament;
  late List<dynamic> _participants;

  bool _isRefreshing = false;
  bool _isSavingRoom = false;
  bool _isStopping = false;
  bool _loadingReady = false;
  int _readyCount = 0;
  List<dynamic> _readyPlayers = [];
  int? _currentUserId;
  bool _isReady = false;
  MatchFlowState _matchFlow = const MatchFlowState();

  final _roomIdController = TextEditingController();
  final _roomPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tournament = widget.tournament;
    _participants = List.from(widget.participants);

    final cs = _tournament.customSettings;
    if (cs != null) {
      _roomIdController.text = cs['room_id'] ?? '';
      _roomPassController.text = cs['room_password'] ?? '';
    }
    _loadReadyStatus();
    _loadCurrentUser();
    _loadMatchFlow();
  }

  Future<void> _loadMatchFlow() async {
    if (_tournament.id == null) return;
    try {
      final details = await ApiService.getTournamentDetails(_tournament.id!);
      if (mounted) {
        setState(() {
          _matchFlow = details['match_flow'] as MatchFlowState? ?? const MatchFlowState();
        });
      }
    } catch (e, st) {
      logCacheRefreshFailure('manageTournamentFlow', e, st);
    }
  }

  Future<void> _loadReadyStatus() async {
    if (_tournament.id == null) return;
    setState(() => _loadingReady = true);
    try {
      final data = await ApiService.getReadyStatus(_tournament.id!);
      if (mounted) {
        setState(() {
          _readyPlayers = parseApiList(data['players']);
          _readyCount = data['ready_count'] as int? ?? 0;
          _loadingReady = false;
        });
      }
    } catch (e, st) {
      logCacheRefreshFailure('manageTournamentReady', e, st);
      if (mounted) setState(() => _loadingReady = false);
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCachedUser();
    if (mounted && user != null) {
      setState(() {
        _currentUserId = AuthService.parseUserId(user);
        _updateIsReady();
      });
    }
  }

  void _updateIsReady() {
    final me = _participants.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['id'] == _currentUserId,
      orElse: () => null,
    );
    _isReady = me?['is_ready'] as bool? ?? false;
  }

  Future<void> _toggleReady(bool ready) async {
    if (_tournament.id == null) return;
    final res = await ApiService.setTournamentReady(_tournament.id!, ready: ready);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _isReady = res['is_ready'] as bool? ?? ready);
      _showSnack(res['message'] ?? (ready ? 'Ready!' : 'Not ready'), isError: false);
      _loadReadyStatus();
      _refresh();
    } else {
      _showSnack(res['message'] ?? 'Failed', isError: true);
    }
  }

  Future<void> _openTeamInvites() async {
    if (_tournament.id == null) return;
    await TournamentTeamInviteSheet.show(
      context,
      tournamentId: _tournament.id!,
      tournamentTitle: _tournament.title,
      isOwner: true,
      onChanged: _refresh,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomIdController.dispose();
    _roomPassController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final details = await ApiService.getTournamentDetails(_tournament.id!);
      if (mounted) {
        setState(() {
          _tournament = details['tournament'] as UpcomingTournament;
          _participants = parseParticipantList(details['participants']);
          _matchFlow = details['match_flow'] as MatchFlowState? ?? const MatchFlowState();
          _isRefreshing = false;
          final cs = _tournament.customSettings;
          if (cs != null) {
            _roomIdController.text = cs['room_id'] ?? '';
            _roomPassController.text = cs['room_password'] ?? '';
          }
          _updateIsReady();
        });
        widget.onRefresh();
        _loadReadyStatus();
      }
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _removeParticipant(Map<String, dynamic> p) async {
    if (p['is_owner'] == true) return;

    final userId = p['id'] as int?;
    if (userId == null) return;

    final entryFeePaid = (p['entry_fee_paid'] as num?)?.toDouble() ?? 0;
    final refundNote = entryFeePaid > 0
        ? '\n\nTheir entry fee (NPR ${entryFeePaid.toStringAsFixed(0)}) will be refunded to their wallet.'
        : '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.battlyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Player', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
        content: Text(
          'Remove "${p['ign'] ?? p['name']}" from this tournament?$refundNote',
          style: GoogleFonts.poppins(color: context.battlyMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: context.battlyMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: Text('Remove', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.removeParticipant(_tournament.id!, userId);
    if (!mounted) return;
    if (res['success'] == true) {
      _showSnack(res['message'] ?? 'Removed', isError: false);
      await _refresh();
    } else {
      _showSnack(res['message'] ?? 'Failed to remove', isError: true);
    }
  }

  Future<void> _saveRoomCode() async {
    setState(() => _isSavingRoom = true);
    final res = await ApiService.updateRoomCode(
      _tournament.id!,
      roomId: _roomIdController.text.trim(),
      roomPassword: _roomPassController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSavingRoom = false);
    if (res['success'] == true) {
      _showSnack('Room codes shared with players!', isError: false);
      if (res['tournament'] != null) {
        setState(() {
          _tournament = UpcomingTournament.fromJson(res['tournament'] as Map<String, dynamic>);
        });
      }
      await _loadMatchFlow();
      widget.onRefresh();
    } else {
      _showSnack(res['message'] ?? 'Failed to save', isError: true);
    }
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

  bool get _isTerminalStatus {
    final s = _tournament.statusText.toLowerCase();
    return s == 'cancelled' || s == 'completed';
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

  @override
  Widget build(BuildContext context) {
    final t = _tournament;
    final cs = t.customSettings;

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
              'Manage Tournament',
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              t.title,
              style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 10, fontWeight: FontWeight.w600),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B00),
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor: context.battlyMuted,
          dividerColor: const Color(0xFF1E2129),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
          tabs: const [
            Tab(text: 'PLAYERS'),
            Tab(text: 'CHAT'),
            Tab(text: 'ROOM'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats bar
          _buildStatsBar(t),
          if (_tournament.isCustomMatchFlow && _matchFlow.applies)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: MatchFlowPanel(
                tournamentId: _tournament.id!,
                initial: _matchFlow,
                isReady: _isReady,
                onToggleReady: _toggleReady,
                roomIdController: _roomIdController,
                roomPassController: _roomPassController,
                onSaveRoom: _saveRoomCode,
                savingRoom: _isSavingRoom,
                onFlowUpdated: (flow) => setState(() => _matchFlow = flow),
                onSnack: _showSnack,
              ),
            ),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlayersTab(),
                TournamentChatTab(tournament: _tournament),
                _buildRoomTab(cs),
              ],
            ),
          ),
          if (_tournament.isCustomMatchFlow &&
              _matchFlow.applies &&
              _matchFlow.phase == MatchFlowState.phaseLive)
            const SizedBox.shrink()
          else if (_tournament.statusText.toUpperCase() == 'LIVE')
            _buildLiveMatchBottomBar(),
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
        border: Border.all(color: context.battlyBorder, width: 1),
      ),
      child: Row(
        children: [
          _buildStatChip(
            '${_participants.length}/${t.maxPlayers}',
            'Players',
            Icons.people_outline_rounded,
            const Color(0xFFFF6B00),
          ),
          _buildStatDivider(),
          _buildStatChip(
            t.entryFee,
            'Entry Fee',
            Icons.monetization_on_outlined,
            const Color(0xFF4CAF50),
          ),
          _buildStatDivider(),
          _buildStatChip(
            t.statusText,
            'Status',
            Icons.circle,
            t.statusText == 'LIVE'
                ? const Color(0xFF4CAF50)
                : t.statusText == 'REGISTRATION'
                    ? const Color(0xFFFF6B00)
                    : context.battlyMuted,
          ),
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
          Text(value, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 11)),
          Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 36, color: context.battlyBorder);
  }

  // ─────────── PLAYERS TAB ───────────────────────────────────────────

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/background/tournment.png',
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text('No players registered yet', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 14)),
              const SizedBox(height: 6),
              Text('Share the tournament to get registrations', style: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 11)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _shareTournament,
                icon: const Icon(Icons.ios_share_rounded, size: 16, color: Color(0xFFFF6B00)),
                label: Text('Share Tournament', style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFFFF6B00)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                _buildReadyCheckPanel(),
                if (_tournament.isTeamFormat) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _openTeamInvites,
                      icon: const Icon(Icons.group_add_outlined, size: 16, color: Color(0xFFFF6B00)),
                      label: Text('Team Invites', style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFFFF6B00)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final p = _participants[index] as Map<String, dynamic>;
                return TournamentPlayerRow(
                  rank: index + 1,
                  participant: p,
                  style: TournamentPlayerRowStyle.manage,
                  onCopyUid: () => _copyToClipboard(p['game_uid'] as String? ?? '', 'UID'),
                  onRemove: !_isTerminalStatus && p['is_owner'] != true
                      ? () => _removeParticipant(p)
                      : null,
                );
              },
              childCount: _participants.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadyCheckPanel() {
    final total = _participants.length;
    return GestureDetector(
      onTap: _showReadyPlayersSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.battlyCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.battlyBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined, color: Color(0xFFFF6B00), size: 18),
                const SizedBox(width: 8),
                Text('Ready Check', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                if (_loadingReady)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B00)))
                else ...[
                  Text('$_readyCount/$total ready', style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF6B00), size: 16),
                ],
              ],
            ),
            if (_readyPlayers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _readyPlayers.map((player) {
                  final p = player as Map<String, dynamic>;
                  final ready = p['is_ready'] as bool? ?? false;
                  final name = p['name'] as String? ?? 'Player';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ready ? const Color(0xFF1A2E1A) : context.battlyScaffold,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ready ? const Color(0xFF4CAF50) : context.battlyBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ready ? Icons.check_circle : Icons.radio_button_unchecked, size: 12, color: ready ? const Color(0xFF4CAF50) : const Color(0xFF6B6F7A)),
                        const SizedBox(width: 4),
                        Text(name, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (_currentUserId != null && _participants.any((p) => p['id'] == _currentUserId)) ...[
              const SizedBox(height: 10),
              const Divider(color: Color(0xFF2B2F3A), height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Check-in Status',
                    style: GoogleFonts.poppins(
                      color: context.battlyOnSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _isReady ? 'READY' : 'NOT READY',
                        style: GoogleFonts.poppins(
                          color: _isReady ? const Color(0xFF4CAF50) : const Color(0xFFFF6B00),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 24,
                        width: 40,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: Switch(
                            value: _isReady,
                            onChanged: (v) => _toggleReady(v),
                            activeThumbColor: const Color(0xFF4CAF50),
                            activeTrackColor: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                            inactiveThumbColor: const Color(0xFFFF6B00),
                            inactiveTrackColor: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFFF6B00)),
                      label: Text('Refresh', style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold)),
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

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: ready
                                      ? const Color(0xFF1A2E1A).withValues(alpha: 0.3)
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

  // ─────────── ROOM CODE TAB ─────────────────────────────────────────

  Widget _buildRoomTab(Map<String, dynamic>? cs) {
    final currentRoomId = cs?['room_id'] as String? ?? '';
    final currentRoomPass = cs?['room_password'] as String? ?? '';
    final codesLocked = currentRoomId.isNotEmpty || currentRoomPass.isNotEmpty;

    if (codesLocked) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Room codes shared with all registered players',
                      style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFF4CAF50), size: 16),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (currentRoomId.isNotEmpty)
              _buildLockedRoomCodeCard('Room ID', currentRoomId, Icons.tag_rounded),
            if (currentRoomPass.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildLockedRoomCodeCard('Password', currentRoomPass, Icons.lock_outline_rounded),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.battlyBorder, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFFF6B00), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Room ID and password cannot be edited after sharing. Copy the codes above if you need to share them again.',
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set Room Code', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Enter the lobby room ID and password once. After saving, they will be shared with players and cannot be changed.',
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildRoomField(
            controller: _roomIdController,
            label: 'Room ID',
            hint: 'Enter lobby room ID',
            icon: Icons.videogame_asset_outlined,
          ),
          const SizedBox(height: 12),
          _buildRoomField(
            controller: _roomPassController,
            label: 'Room Password',
            hint: 'Enter lobby password',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSavingRoom ? null : _saveRoomCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSavingRoom
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Share Room Code', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.battlyBorder, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFF6B00), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saving room codes notifies all registered players immediately. You will not be able to edit them afterwards.',
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

  Widget _buildLockedRoomCodeCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.battlyBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B00), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(value, label),
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF4CAF50), size: 18),
            tooltip: 'Copy $label',
          ),
        ],
      ),
    );
  }

  Widget _buildRoomField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: const Color(0xFF4A4F5C), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF6B6F7A), size: 18),
            filled: true,
            fillColor: context.battlyCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF2B2F3A), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF2B2F3A), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFFF6B00), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMatchBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        border: Border(
          top: BorderSide(color: context.battlyBorder, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Match is Live',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFE53935),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isStopping ? null : _stopMatch,
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 20),
                label: Text(
                  'Stop Match & Record Result',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stopMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.battlyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Stop Live Match?',
          style: GoogleFonts.poppins(
            color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will stop the active match flow and redirect you to the score reporting screen.',
          style: GoogleFonts.poppins(color: context.battlyMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: context.battlyMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            child: Text(
              'Stop',
              style: GoogleFonts.poppins(
                color: context.battlyOnSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isStopping = true);
    try {
      final res = await ApiService.stopMatchFlow(_tournament.id!);
      if (!mounted) return;
      setState(() => _isStopping = false);

      if (res['success'] == true) {
        final flow = res['match_flow'] as MatchFlowState?;
        if (flow != null) {
          setState(() => _matchFlow = flow);
        }
        _showSnack(
          _tournament.isCustomMatchFlow
              ? (res['message'] as String? ?? 'Stop recorded.')
              : 'Match stopped! Please submit the scores.',
          isError: false,
        );
        widget.onRefresh();

        if (_tournament.isCustomMatchFlow) {
          return;
        }

        final cs = _tournament.customSettings;
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
        );
      } else {
        _showSnack(res['message'] ?? 'Failed to stop match.', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isStopping = false);
      _showSnack('An error occurred while stopping match.', isError: true);
    }
  }

}
