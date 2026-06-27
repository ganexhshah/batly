import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_models.dart';
import '../../models/match_flow_state.dart';
import '../../services/api_service.dart';
import '../../core/cache_debug.dart';
import '../../widgets/battly_share_sheet.dart';
import '../profile/support_screen.dart';
import 'submit_result_screen.dart';
import 'verification_status_screen.dart';
import '../../core/theme/battly_theme.dart';

class MatchDetailsScreen extends StatefulWidget {
  final UpcomingTournament tournament;
  final String roundName;
  final String mapName;
  final String roundTime;

  const MatchDetailsScreen({
    super.key,
    required this.tournament,
    required this.roundName,
    required this.mapName,
    required this.roundTime,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  late Timer _timer;
  late int _secondsRemaining;
  String _roomId = '';
  String _roomPassword = '';
  MatchFlowState _matchFlow = const MatchFlowState();

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.tournament.timerDuration.inSeconds > 0
        ? widget.tournament.timerDuration.inSeconds
        : 2730;
    _startTimer();
    _loadRoomDetails();
    _loadMatchFlow();
  }

  Future<void> _loadMatchFlow() async {
    final id = widget.tournament.id;
    if (id == null) return;
    try {
      final flow = await ApiService.getMatchFlow(id);
      if (!mounted) return;
      setState(() => _matchFlow = flow);
      _syncTimerFromFlow(flow);
    } catch (e, st) {
      logCacheRefreshFailure('matchDetailsFlow', e, st);
    }
  }

  void _syncTimerFromFlow(MatchFlowState flow) {
    final endsAt = flow.matchEndsAt;
    if (endsAt != null) {
      final end = DateTime.tryParse(endsAt);
      if (end != null) {
        final remaining = end.difference(DateTime.now()).inSeconds;
        if (remaining > 0) {
          setState(() => _secondsRemaining = remaining);
        }
      }
    } else if (flow.secondsRemaining != null && flow.secondsRemaining! > 0) {
      setState(() => _secondsRemaining = flow.secondsRemaining!);
    }
  }

  String get _teamLeftName {
    if (_matchFlow.readyPlayers.isNotEmpty) {
      return _matchFlow.readyPlayers.first.name;
    }
    return widget.tournament.creatorName ?? 'Team 1';
  }

  String get _teamRightName {
    if (_matchFlow.readyPlayers.length > 1) {
      return _matchFlow.readyPlayers[1].name;
    }
    return 'Opponent';
  }

  void _applyRoomFromTournament(UpcomingTournament tournament) {
    final cs = tournament.customSettings;
    final roomId = cs?['room_id']?.toString().trim() ?? '';
    final roomPass = cs?['room_password']?.toString().trim() ?? '';
    if (roomId.isNotEmpty) _roomId = roomId;
    if (roomPass.isNotEmpty) _roomPassword = roomPass;
  }

  Future<void> _loadRoomDetails() async {
    _applyRoomFromTournament(widget.tournament);
    if (_roomId.isNotEmpty && _roomPassword.isNotEmpty) {
      if (mounted) setState(() {});
      return;
    }

    final id = widget.tournament.id;
    if (id == null) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final fresh = await ApiService.getTournament(id);
      if (!mounted) return;
      setState(() => _applyRoomFromTournament(fresh));
    } catch (e, st) {
      logCacheRefreshFailure('matchDetailsRoom', e, st);
      if (mounted) setState(() {});
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTimeSegment(int val) {
    return val.toString().padLeft(2, '0');
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              '$label copied to clipboard!',
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Breakdown remaining seconds
    final int hrs = _secondsRemaining ~/ 3600;
    final int mins = (_secondsRemaining % 3600) ~/ 60;
    final int secs = _secondsRemaining % 60;

    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08090C),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Match Details',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFFF6B00),
                  content: Text(
                    'Report issue form opened!',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.description_outlined, color: Color(0xFFFF6B00), size: 16),
            label: Text(
              'Report Issue',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF6B00),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // 1. MAIN CARD (Upcoming Match)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1C1F26), width: 1.0),
                gradient: const RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    Color(0xFF2C1910), // Low opacity dark reddish-orange glow
                    Color(0xFF0F1115),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Badge UPCOMING MATCH
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      'UPCOMING MATCH',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFF6B00),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Title
                  Text(
                    widget.tournament.title,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Subtitle Info
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${widget.roundName} ',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFF6B00),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '•  Match 5',
                          style: GoogleFonts.poppins(
                            color: context.battlyMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Teams VS Row
                  Row(
                    children: [
                      // Team Left (Night Squad)
                      Expanded(
                        child: Column(
                          children: [
                            // Glowing Team Logo container
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xFF08090C),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.battlyBorder, width: 1),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Image.asset(
                                widget.tournament.logoAsset ?? 'assets/logo/battly_cup.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.shield,
                                  color: Colors.purple,
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _teamLeftName,
                              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      // VS Text with orange-yellow gradient
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFFF9000),
                                  Color(0xFFFF5500),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: Text(
                                'VS',
                                style: GoogleFonts.poppins(color: context.battlyOnSurface,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Date row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined, color: Color(0xFFFF6B00), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  widget.tournament.dateText.contains('•') ? widget.tournament.dateText.split('•')[0].trim() : widget.tournament.dateText,
                                  style: GoogleFonts.poppins(
                                    color: context.battlyMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Time row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time, color: Color(0xFFFF6B00), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  widget.roundTime,
                                  style: GoogleFonts.poppins(
                                    color: context.battlyMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Team Right (Wolf Elite)
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xFF08090C),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.battlyBorder, width: 1),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Image.asset(
                                widget.tournament.logoAsset != null && widget.tournament.logoAsset!.contains('battly_cup')
                                    ? 'assets/logo/night_showdown.png'
                                    : 'assets/logo/battly_cup.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.shield,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _teamRightName,
                              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 2. COUNTDOWN BANNER (Match starts in)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1116),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.battly.elevatedSurface, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFFFF6B00), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Match starts in',
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_formatTimeSegment(hrs)} : ${_formatTimeSegment(mins)} : ${_formatTimeSegment(secs)}',
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'HRS',
                            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'MINS',
                            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'SECS',
                            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 3. MATCH INFORMATION
            Text(
              'Match Information',
              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E1116),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.battly.elevatedSurface, width: 1),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.sports_esports_outlined, 'Game', 'Free Fire MAX', isFirst: true),
                  _buildDivider(),
                  _buildInfoRow(Icons.groups_outlined, 'Mode', widget.tournament.mode),
                  _buildDivider(),
                  _buildInfoRow(Icons.map_outlined, 'Map', widget.mapName),
                  _buildDivider(),
                  _buildInfoRow(Icons.people_outline_rounded, 'Team Type', '${widget.tournament.type} (${widget.tournament.type == 'Solo' ? '1 Player' : widget.tournament.type == 'Duo' ? '2 Players' : '4 Players'})'),
                  _buildDivider(),
                  _buildInfoRow(Icons.info_outline, 'Room Type', 'Custom Room', isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 4. ROOM DETAILS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Room Details',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Color(0xFF4CAF50), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Share room details with your team',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4CAF50),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E1116),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.battly.elevatedSurface, width: 1),
              ),
              child: Column(
                children: [
                  _buildCopyRow('Room ID', _roomId.isNotEmpty ? _roomId : 'Not shared yet'),
                  _buildDivider(),
                  _buildCopyRow('Password', _roomPassword.isNotEmpty ? _roomPassword : 'Not shared yet'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // IMPORTANT BANNER
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1209),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4A2B0E), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF8C00), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFF8C00),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Join the room 5 minutes before match time. Failure to join may result in disqualification.',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFD4B198),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Submit Match Result & Verification Status Buttons Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubmitResultScreen(
                              tournament: widget.tournament,
                              roundName: widget.roundName,
                              mapName: widget.mapName,
                              roundTime: widget.roundTime,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 18),
                      label: Text(
                        'Submit Result',
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VerificationStatusScreen(
                              tournament: widget.tournament,
                              roundName: widget.roundName,
                              mapName: widget.mapName,
                              roundTime: widget.roundTime,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.verified_user_outlined, color: Color(0xFFFF6B00), size: 18),
                      label: Text(
                        'Check Status',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFF6B00),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 5. ACTIONS SECTION
            Text(
              'Actions',
              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SupportScreen()),
                      );
                    },
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF08090C),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1C1F26), width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.headset_mic_outlined, color: Colors.white, size: 18),
                          const SizedBox(height: 4),
                          Text(
                            'Contact Admin',
                            style: GoogleFonts.poppins(color: context.battlyOnSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () {
                      showBattlyShareSheet(
                        context,
                        title: 'Share Match Details',
                        shareText: '${widget.tournament.title} - ${widget.roundName} Details!\nRoom ID: ${_roomId.isNotEmpty ? _roomId : 'Pending'}\nPassword: ${_roomPassword.isNotEmpty ? _roomPassword : 'Pending'}',
                      );
                    },
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF08090C),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1C1F26), width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                          const SizedBox(height: 4),
                          Text(
                            'Share Details',
                            style: GoogleFonts.poppins(color: context.battlyOnSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: context.battlyCard,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: Text(
                              'Joining Custom Room',
                              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              _roomId.isNotEmpty
                                  ? 'You are being redirected to Free Fire MAX with Room ID: $_roomId'
                                  : 'Room details are not available yet. Please wait for the host to share them.',
                              style: GoogleFonts.poppins(color: context.battlyMuted),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Okay', style: GoogleFonts.poppins(color: const Color(0xFFFF6B00))),
                              )
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5500),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sports_esports_outlined, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Join Room',
                              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isFirst = false, bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFF6B00), size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: context.battlyMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.poppins(color: context.battlyOnSurface,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: context.battlyMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFF8C00),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _copyToClipboard(value, label),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF08090C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF1C1F26), width: 1),
                  ),
                  child: const Icon(
                    Icons.content_copy_outlined,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1.0,
      color: const Color(0xFF1C1F26),
    );
  }
}
