import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/prize_distribution.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../core/cache_debug.dart';
import '../../services/auth_service.dart';
import 'manage_tournament_screen.dart';
import 'joined_tournament_screen.dart';
import '../../core/json_parse.dart';
import '../../widgets/battly_share_sheet.dart';
import '../../widgets/tournament_player_row.dart';
import '../../widgets/tournament_team_invite_sheet.dart';
import '../../widgets/wallet_deduction_confirmation.dart';
import '../../widgets/query_error_view.dart';
import '../../core/theme/battly_theme.dart';

class TournamentScreen extends StatefulWidget {
  final UpcomingTournament tournament;

  const TournamentScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UpcomingTournament _tournament;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isRegistered = false;
  bool _isOwner = false;
  List<Map<String, dynamic>> _participants = [];
  TournamentRegistrationMeta _registrationMeta = const TournamentRegistrationMeta();
  bool _hasAcceptedTeamInvite = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tournament = widget.tournament;
    _fetchDetails();
  }

  Future<void> _fetchDetails({bool silent = false}) async {
    if (_tournament.id == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
      return;
    }
    if (!silent) {
      setState(() => _isRefreshing = true);
    }
    try {
      final cachedUser = await AuthService.getCachedUser();
      final userId = AuthService.parseUserId(cachedUser);
      final details = await ApiService.getTournamentDetails(_tournament.id!);
      if (mounted) {
        final tournament = details['tournament'] as UpcomingTournament;
        final participants = parseParticipantList(details['participants']);
        var isRegistered = _readBool(details['is_registered']);
        var isOwner = _readBool(details['is_owner']);

        if (userId != null) {
          if (tournament.createdBy == userId) {
            isOwner = true;
          }
          if (!isRegistered) {
            isRegistered = _isUserInParticipants(participants, userId);
          }
        }

        setState(() {
          _tournament = tournament;
          _participants = participants;
          _isRegistered = isRegistered;
          _isOwner = isOwner;
          _registrationMeta = details['registration'] as TournamentRegistrationMeta? ?? const TournamentRegistrationMeta();
          _isLoading = false;
          _isRefreshing = false;
          _loadError = null;
        });
        if (_tournament.isTeamFormat && !_isRegistered && !_isOwner && _tournament.id != null) {
          _loadTeamInviteStatus();
        }
      }
    } catch (e) {
      debugPrint('Error fetching tournament details: $e');
      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  bool _isUserInParticipants(List<Map<String, dynamic>> participants, int userId) {
    for (final participant in participants) {
      final participantId = AuthService.parseUserId(participant) ??
          AuthService.parseUserId({'id': participant['user_id']});
      if (participantId == userId) return true;
    }
    return false;
  }

  Future<void> _loadTeamInviteStatus() async {
    if (_tournament.id == null) return;
    try {
      final data = await ApiService.getTeamInvites(_tournament.id!);
      final received = data['received'] as List<dynamic>? ?? [];
      final accepted = received.any((i) => (i as Map)['status'] == 'accepted');
      if (mounted) setState(() => _hasAcceptedTeamInvite = accepted);
    } catch (e, st) {
      logCacheRefreshFailure('tournamentTeamInvites', e, st);
    }
  }

  int get _playerCount => _participants.isNotEmpty ? _participants.length : _tournament.currentPlayers;

  bool get _canRegister {
    if (_isRegistered || _isOwner) return false;
    if (!_registrationMeta.registrationOpen) return false;
    if (_tournament.isTeamFormat && !_hasAcceptedTeamInvite) return false;
    return true;
  }

  String get _registerButtonLabel {
    if (_isOwner) return 'Manage Match';
    if (_isRegistered) return '✓ Registered';
    if (_registrationMeta.isFull || _registrationMeta.registrationClosed) {
      return 'Registration Closed';
    }
    if (_tournament.isTeamFormat && !_hasAcceptedTeamInvite) return 'Need Team Invite';
    return 'Register Now';
  }

  Future<void> _openTeamInvites() async {
    if (_tournament.id == null) return;
    await TournamentTeamInviteSheet.show(
      context,
      tournamentId: _tournament.id!,
      tournamentTitle: _tournament.title,
      isOwner: _isOwner,
      onChanged: () {
        _fetchDetails(silent: true);
        _loadTeamInviteStatus();
      },
    );
  }

  Future<void> _attemptRegister(UpcomingTournament t) async {
    if (t.isTeamFormat && !_hasAcceptedTeamInvite && !_isOwner) {
      _showSnack('Accept a team invite before registering.', isError: true);
      await _openTeamInvites();
      return;
    }
    if (!mounted) return;

    final entryFeeRaw = double.tryParse(t.entryFee.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    // Show the premium confirmation sheet
    final confirmed = await showWalletDeductionConfirmSheet(
      context,
      title: 'Confirm Registration',
      subtitle: t.isTeamFormat
          ? 'Register for ${t.title}? You will be charged the entry fee.'
          : 'Do you wish to register in the ${t.title}? You will be charged the entry fee.',
      deductionAmount: entryFeeRaw,
      actionButtonLabel: 'Confirm & Register',
    );

    if (confirmed != true) return;

    // Show a loading dialog spinner while registering
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
      ),
    );

    try {
      final res = await ApiService.registerForTournament(t.id!);
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading spinner

      if (res['success'] == true) {
        final alreadyRegistered = res['alreadyRegistered'] == true;
        _showSnack(
          res['message'] ?? (alreadyRegistered ? 'Already registered' : 'Registered!'),
          isError: false,
        );
        setState(() => _isRegistered = true);
        await _fetchDetails();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JoinedTournamentScreen(
              tournament: _tournament,
              participants: _participants,
              onRefresh: _fetchDetails,
            ),
          ),
        );
      } else {
        _showSnack(res['message'] ?? 'Registration failed', isError: true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading spinner
        _showSnack('An error occurred: $e', isError: true);
      }
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'live':
        return const Color(0xFF4CAF50);
      case 'upcoming':
        return const Color(0xFF2196F3);
      case 'completed':
        return context.battlyMuted;
      case 'cancelled':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFFFF6B00);
    }
  }

  Widget _buildStatusBadge(UpcomingTournament t) {
    final color = _statusColor(t.statusText);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.0),
      ),
      child: Text(
        t.statusText,
        style: GoogleFonts.poppins(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _shareTournament(UpcomingTournament t) {
    showBattlyShareSheet(
      context,
      title: 'Share Tournament',
      shareText: 'Join the ${t.title} Tournament on Battly!\n'
          'Entry Fee: ${t.entryFee}\n'
          'Prize Pool: ${t.prizePool}\n'
          'Players: $_playerCount/${t.maxPlayers}',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        title: Text(
          'Tournament Details',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
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
            onPressed: _isRefreshing ? null : () => _fetchDetails(),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
            onPressed: () => _shareTournament(t),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main Card Section (Top Banner / Info)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder, width: 1),
              ),
              child: Row(
                children: [
                  // Logo Badge with glowing radial background
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: context.battlyScaffold,
                      borderRadius: BorderRadius.circular(12),
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFF6B00).withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                        radius: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      t.logoAsset ?? 'assets/logo/battly_cup.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFF6B00),
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Middle Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        _buildStatusBadge(t),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          t.title,
                          style: GoogleFonts.poppins(color: context.battlyOnSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Subtitle
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: t.type,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFF6B00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: ' • ${t.mode}',
                                style: GoogleFonts.poppins(
                                  color: context.battlyMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Metadata Icons Row
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, color: Color(0xFFFF6B00), size: 10),
                              const SizedBox(width: 4),
                              Text(
                                t.dateText.contains('•') ? t.dateText.split('•')[0].trim() : t.dateText,
                                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.access_time_rounded, color: Color(0xFFFF6B00), size: 10),
                              const SizedBox(width: 4),
                              Text(
                                t.dateText.contains('•') ? t.dateText.split('•')[1].trim() : '',
                                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.people_outline_rounded, color: Color(0xFFFF6B00), size: 10),
                              const SizedBox(width: 4),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$_playerCount/${t.maxPlayers} ',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFF6B00),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Teams',
                                      style: GoogleFonts.poppins(
                                        color: context.battlyMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (t.creatorName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 7,
                                backgroundColor: context.battlyBorder,
                                backgroundImage: t.creatorAvatar != null &&
                                        t.creatorAvatar!.isNotEmpty
                                    ? NetworkImage(t.creatorAvatar!)
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
                                t.creatorName!,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFF6B00),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Vertical separator
                  Container(
                    width: 1,
                    height: 76,
                    color: context.battlyBorder,
                  ),
                  const SizedBox(width: 10),
                  // Right Section (Prize Pool & Entry Fee)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            t.prizePool,
                            style: GoogleFonts.poppins(color: context.battlyOnSurface,
                              fontSize: 12,
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
                        t.entryFee,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF4CAF50),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Scrollable Tabs Header
          PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: const Color(0xFFFF6B00),
                labelColor: const Color(0xFFFF6B00),
                unselectedLabelColor: context.battlyMuted,
                dividerColor: const Color(0xFF1E2129),
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  const Tab(text: 'OVERVIEW'),
                  const Tab(text: 'PRIZE POOL'),
                  const Tab(text: 'RULES'),
                  Tab(text: t.type == 'Solo' ? 'PLAYERS' : 'TEAMS'),
                ],
              ),
            ),
          ),
          // Tab views
          Expanded(
            child: _loadError != null
                ? QueryErrorView(
                    message: _loadError,
                    onRetry: () {
                      setState(() {
                        _loadError = null;
                        _isLoading = true;
                      });
                      _fetchDetails();
                    },
                  )
                : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(t),
                _buildPrizePoolTab(t),
                _buildRulesTab(),
                _buildTeamsTab(t),
              ],
            ),
          ),
          // Sticky Bottom Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Color(0xFF0F1115),
              border: Border(
                top: BorderSide(color: Color(0xFF2B2F3A), width: 1.0),
              ),
            ),
            child: SafeArea(
              top: false,
              child: _isOwner
                  ? _buildOwnerActions(t)
                  : _isRegistered
                      ? _buildRegisteredActions(t)
                      : Row(
                      children: [
                        // Invite Team button (Outlined)
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: t.isTeamFormat
                                  ? _openTeamInvites
                                  : () => _shareTournament(t),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Color(0xFF2B2F3A), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFFFF6B00), size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      t.isTeamFormat ? 'Team' : 'Invite',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFF6B00),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Register Now / Registered button (Solid Orange / Muted Green)
                        Expanded(
                          flex: 5,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: !_canRegister && !_isRegistered
                                  ? (t.isTeamFormat && !_hasAcceptedTeamInvite ? _openTeamInvites : null)
                                  : () => _attemptRegister(t),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _canRegister ? const Color(0xFFFF6B00) : const Color(0xFF1E2129),
                                disabledBackgroundColor: const Color(0xFF1E2129),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: _isRegistered
                                      ? BorderSide(color: Color(0xFF4CAF50), width: 1.0)
                                      : BorderSide.none,
                                ),
                                elevation: 0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _registerButtonLabel,
                                    style: GoogleFonts.poppins(
                                      color: _isRegistered ? const Color(0xFF4CAF50) : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (!_isRegistered && _canRegister)
                                    Text(
                                      'Entry Fee: ${t.entryFee}',
                                      style: GoogleFonts.poppins(color: context.battlyOnSurface.withValues(alpha: 0.7), fontSize: 9),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredActions(UpcomingTournament t) {
    return _buildMyLobbyButton(t);
  }

  Widget _buildOwnerActions(UpcomingTournament t) {
    return _buildManageButton(t);
  }

  Widget _buildMyLobbyButton(UpcomingTournament t) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JoinedTournamentScreen(
                tournament: t,
                participants: _participants,
                onRefresh: _fetchDetails,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A2E1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Color(0xFF4CAF50), width: 1.5),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_esports_rounded, color: Color(0xFF4CAF50), size: 18),
            const SizedBox(width: 8),
            Text(
              'My Lobby',
              style: GoogleFonts.poppins(
                color: const Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageButton(UpcomingTournament t) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManageTournamentScreen(
                tournament: t,
                participants: _participants,
                onRefresh: _fetchDetails,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2A1A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Color(0xFFFF6B00), width: 1.5),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_rounded, color: Color(0xFFFF6B00), size: 18),
            const SizedBox(width: 8),
            Text(
              'Manage',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF6B00),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(UpcomingTournament t) {
    final Map<String, dynamic>? custom = t.customSettings;
    final mapName = custom?['map'] as String? ??
        (t.rounds?.isNotEmpty == true ? t.rounds!.first['map'] as String? : null) ??
        'Bermuda';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About Tournament Section Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.battlyBorder, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Tournament',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join ${t.title} and compete with top teams. Show your skills, dominate the battlefield and win exciting prizes!',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                // Horizontal details divider block grid
                Row(
                  children: [
                    _buildOverviewSubBlock('GAME MODE', t.mode, Icons.sports_esports_outlined),
                    _buildSubDivider(),
                    _buildOverviewSubBlock('TEAM TYPE', '${t.type}\n(${t.type == 'Solo' ? '1 Player' : t.type == 'Duo' ? '2 Players' : '4 Players'})', Icons.people_outline_rounded),
                    _buildSubDivider(),
                    _buildOverviewSubBlock('MAP', mapName, Icons.map_outlined),
                    _buildSubDivider(),
                    _buildOverviewSubBlock('VERSION', 'Latest', Icons.verified_user_outlined),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPrizeSummaryCard(t),
          const SizedBox(height: 16),
          // Custom Match Rules Summary Card (only if customSettings exist)
          if (custom != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Match Details',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildOverviewDetailRow('Throwable Limit', custom['throwable_limit'] ?? 'Yes'),
                  _buildOverviewDivider(),
                  _buildOverviewDetailRow('Character Skills', custom['character_skill'] ?? 'Yes'),
                  if (custom['character_skill'] == 'Yes' && custom['skill_allowance_mode'] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 4),
                      child: Text(
                        custom['skill_allowance_mode'] == 'Except Dmitri, Ryden, Orion'
                            ? 'Dmitri, Ryden, Orion blocked'
                            : 'Allowed: ${(custom['allowed_characters'] as List? ?? []).join(", ")}',
                        style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  _buildOverviewDivider(),
                  _buildOverviewDetailRow('Gun Attributes', custom['gun_attributes'] ?? 'Yes'),
                  _buildOverviewDivider(),
                  _buildOverviewDetailRow('Rounds / Coins', '${custom['rounds'] ?? 7} Rounds / ${custom['default_coin'] ?? 'Default'}'),
                  _buildOverviewDivider(),
                  _buildOverviewDetailRow('Host Mode', custom['host_mode'] ?? 'No'),
                  _buildOverviewDivider(),
                  _buildOverviewDetailRow('Lobby Creator', custom['room_maker'] ?? 'Room Maker'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 16),
          // Registered Teams Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.type == 'Solo'
                    ? 'Registered Players (${t.currentPlayers}/${t.maxPlayers})'
                    : 'Registered Teams (${t.currentPlayers}/${t.maxPlayers})',
                style: GoogleFonts.poppins(color: context.battlyOnSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () {
                  _tabController.animateTo(3);
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFF6B00),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            _buildParticipantSkeleton()
          else if (_participants.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  t.type == 'Solo' ? 'No players registered yet.' : 'No teams registered yet.',
                  style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
                ),
              ),
            )
          else ...[
            ..._participants.take(3).toList().asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final p = entry.value;
              return TournamentPlayerRow(
                rank: idx,
                participant: p,
                style: TournamentPlayerRowStyle.preview,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPrizeSummaryCard(UpcomingTournament t) {
    final prize = t.prizeDistribution ??
        PrizeDistributionInfo.fallback(
          prizePoolText: t.prizePool,
          entryFeeText: t.entryFee,
          maxPlayers: t.maxPlayers,
          customSettings: t.customSettings,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prize Pool System',
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildOverviewDetailRow('Format', prize.matchFormat ?? 'Classic Squad'),
          _buildOverviewDivider(),
          _buildOverviewDetailRow('Distribution', prize.label),
          _buildOverviewDivider(),
          _buildOverviewDetailRow('Total Pool', PrizeDistributionInfo.formatAmount(prize.totalPool)),
          if (prize.slots.isNotEmpty) ...[
            _buildOverviewDivider(),
            _buildOverviewDetailRow(
              prize.isWinnerTakesAll ? 'Winner Prize' : '1st Place',
              PrizeDistributionInfo.formatAmount(prize.slots.first.amount),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewSubBlock(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFF6B00), size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 8, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubDivider() {
    return Container(
      width: 1,
      height: 36,
      color: context.battlyBorder,
    );
  }



  Widget _buildParticipantSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E222A),
      highlightColor: const Color(0xFF2B3040),
      child: Column(
        children: List.generate(3, (index) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        )),
      ),
    );
  }

  Widget _buildPrizePoolTab(UpcomingTournament t) {
    final prize = t.prizeDistribution ??
        PrizeDistributionInfo.fallback(
          prizePoolText: t.prizePool,
          entryFeeText: t.entryFee,
          maxPlayers: t.maxPlayers,
          customSettings: t.customSettings,
        );

    Color slotColor(String hex) {
      final value = hex.replaceAll('#', '');
      if (value.length == 6) {
        return Color(int.parse('FF$value', radix: 16));
      }
      return const Color(0xFFFFD700);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.battlyBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        prize.label,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFF6B00),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (prize.matchFormat != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        prize.matchFormat!,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  prize.description,
                  style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 12),
                _buildOverviewDetailRow('Total Prize Pool', PrizeDistributionInfo.formatAmount(prize.totalPool)),
                _buildOverviewDivider(),
                _buildOverviewDetailRow('Entry Fee', t.entryFee),
                _buildOverviewDivider(),
                _buildOverviewDetailRow('Max Players', '${t.maxPlayers}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Prize Distribution Breakdown',
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.battlyBorder, width: 1.0),
            ),
            child: Column(
              children: [
                for (var i = 0; i < prize.slots.length; i++) ...[
                  if (i > 0) _buildDividerLine(),
                  _buildPrizeRow(
                    prize.slots[i].label,
                    prize.slots[i].share,
                    PrizeDistributionInfo.formatAmount(prize.slots[i].amount),
                    slotColor(prize.slots[i].color),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeRow(String label, String share, String prizeValue, Color rankColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: rankColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  share,
                  style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            prizeValue,
            style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 14),
          )
        ],
      ),
    );
  }

  Widget _buildDividerLine() {
    return Container(height: 1, color: context.battlyBorder);
  }

  Widget _buildRulesTab() {
    final t = _tournament;
    final Map<String, dynamic>? custom = t.customSettings;

    final List<String> standardRules = [
      'Emulators, triggers, iPad views, and third-party cheats are strictly prohibited.',
      'Roster changes are not allowed once registration closes.',
      'Lobby passwords will be shared via notifications and profile 15 minutes before the start time.',
      if (custom == null) 'Teams must have at least 3 players check-in to be qualified for the lobby.',
      'Referees decision is final and absolute.',
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (custom != null) ...[
            Text(
              'Custom Match Settings',
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder, width: 1.0),
              ),
              child: Column(
                children: [
                  _buildCustomRuleRow('Room Type', custom['room_type'] ?? t.mode, Icons.sports_esports),
                  _buildCustomRuleDivider(),
                  _buildCustomRuleRow('Team Mode', custom['team_size'] ?? t.type, Icons.people),
                  _buildCustomRuleDivider(),
                  _buildCustomRuleRow('Throwable Limit', custom['throwable_limit'] ?? 'Yes', Icons.timer_outlined),
                  _buildCustomRuleDivider(),
                  _buildCustomRuleRow('Character Skill', custom['character_skill'] ?? 'Yes', Icons.person_outline),
                  if (custom['character_skill'] == 'Yes' && custom['skill_allowance_mode'] != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          custom['skill_allowance_mode'] == 'Except Dmitri, Ryden, Orion'
                              ? '• Dmitri, Ryden, Orion blocked'
                              : '• Allowed skills: ${(custom['allowed_characters'] as List? ?? []).join(", ")}',
                          style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  _buildCustomRuleDivider(),
                  _buildCustomRuleRow('Host Mode', custom['host_mode'] ?? 'No', Icons.videocam),
                  _buildCustomRuleDivider(),
                  _buildCustomRuleRow('Gun Attributes', custom['gun_attributes'] ?? 'Yes', Icons.shield),
                  _buildCustomRuleDivider(),
                  _buildCustomRuleRow('Rounds', '${custom['rounds'] ?? 7} Rounds', Icons.replay),
                  _buildCustomRuleDivider(),
                  _buildCustomRuleRow('Default Coin', custom['default_coin'] ?? 'Default Coin', Icons.monetization_on),
                  if (custom['room_maker'] != null) ...[
                    _buildCustomRuleDivider(),
                    _buildCustomRuleRow('Room Creator', custom['room_maker'], Icons.person),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'General Rules and Guidelines',
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Column(
            children: standardRules.map((r) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right_rounded, color: Color(0xFFFF6B00), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r,
                        style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomRuleRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B00), size: 16),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomRuleDivider() {
    return Divider(color: Color(0xFF2B2F3A), height: 12);
  }

  Widget _buildOverviewDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewDivider() {
    return Divider(color: Color(0xFF2B2F3A), height: 10);
  }


  Widget _buildTeamsTab(UpcomingTournament t) {
    final titleText = t.type == 'Solo' ? 'All Registered Players' : 'All Registered Teams';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            _buildParticipantSkeleton()
          else if (_participants.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 32.0),
                child: Text(
                  t.type == 'Solo' ? 'No players registered yet.' : 'No teams registered yet.',
                  style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _participants.length,
              itemBuilder: (context, index) {
                final p = _participants[index];
                return TournamentPlayerRow(
                  rank: index + 1,
                  participant: p,
                  style: TournamentPlayerRowStyle.preview,
                );
              },
            ),
        ],
      ),
    );
  }
}
