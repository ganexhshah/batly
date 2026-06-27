import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../widgets/query_error_view.dart';
import '../../core/theme/battly_theme.dart';

class VerificationStatusScreen extends StatefulWidget {
  final UpcomingTournament tournament;
  final String roundName;
  final String mapName;
  final String roundTime;
  final Map<String, dynamic>? myResult;

  const VerificationStatusScreen({
    super.key,
    required this.tournament,
    required this.roundName,
    required this.mapName,
    required this.roundTime,
    this.myResult,
  });

  @override
  State<VerificationStatusScreen> createState() => _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  bool _loading = true;
  String? _error;
  String _verificationStatus = 'pending_verification';
  String? _rejectedReason;
  double _prizeAmount = 0;
  String _rank = '1';
  String _kills = '0';
  String _points = '0';

  @override
  void initState() {
    super.initState();
    if (widget.myResult != null) {
      _applyMyResult(widget.myResult!);
      _loading = false;
      _loadStatus();
    } else {
      _loadStatus();
    }
  }

  void _applyMyResult(Map<String, dynamic> myResult) {
    _verificationStatus = myResult['status'] as String? ?? _verificationStatus;
    _rejectedReason = myResult['rejected_reason'] as String?;
    _prizeAmount = (myResult['prize_amount'] as num?)?.toDouble() ?? 0;
    _rank = myResult['rank']?.toString() ?? '1';
    _kills = myResult['kills']?.toString() ?? '0';
    _points = myResult['points']?.toString() ?? '0';
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.tournament.id == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final data = await ApiService.getTournamentResults(widget.tournament.id!);
      final myResult = data['my_result'] as Map<String, dynamic>?;
      if (myResult == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No result found for this tournament.';
        });
        return;
      }

      final matchId = myResult['match_id'] as int?;
      if (matchId != null) {
        final statusData = await ApiService.getMatchVerificationStatus(matchId);
        if (!mounted) return;
        setState(() {
          _verificationStatus = statusData['status'] as String? ?? _verificationStatus;
          _rejectedReason = statusData['rejected_reason'] as String?;
          _prizeAmount = (statusData['prize_amount'] as num?)?.toDouble() ?? 0;
        });
      }

      if (!mounted) return;
      setState(() {
        _rank = myResult['rank']?.toString() ?? _rank;
        _kills = myResult['kills']?.toString() ?? _kills;
        _points = myResult['points']?.toString() ?? _points;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _statusTitle {
    return switch (_verificationStatus) {
      'verified' => 'Result Verified',
      'rejected' => 'Result Rejected',
      _ => 'Under Verification',
    };
  }

  String get _statusMessage {
    return switch (_verificationStatus) {
      'verified' => _prizeAmount > 0
          ? 'Your result is approved and NPR ${_prizeAmount.toStringAsFixed(0)} has been credited to your wallet.'
          : 'Your result is approved and published.',
      'rejected' => _rejectedReason ?? 'Your result was rejected by the admin team. Please contact support if this looks wrong.',
      _ => 'Your result has been submitted successfully and is currently under review by our admin team.',
    };
  }

  IconData get _statusIcon {
    return switch (_verificationStatus) {
      'verified' => Icons.verified_rounded,
      'rejected' => Icons.cancel_rounded,
      _ => Icons.access_time_filled_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.battly.navBar,
        appBar: AppBar(
          backgroundColor: context.battly.navBar,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Verification Status',
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: context.battly.navBar,
        appBar: AppBar(
          backgroundColor: context.battly.navBar,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Verification Status',
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: QueryErrorView(message: _error, onRetry: _loadStatus),
      );
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
          'Verification Status',
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
                          'Verification Process',
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your submitted results are cross-checked with the host match logs and screenshot data. Once confirmed by our gaming administrators, the tournament points will be distributed and results will be published.',
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
            // 1. MATCH DETAILS CARD
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
                              widget.tournament.dateText.contains('•') ? widget.tournament.dateText.split('•')[0].trim() : widget.tournament.dateText,
                              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9.5),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.access_time_rounded, color: Color(0xFFFF9800), size: 10),
                            const SizedBox(width: 4),
                            Text(
                              widget.roundTime,
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
                      const SizedBox(height: 4),
                      Text(
                        'Completed On',
                        style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.tournament.dateText.contains('•') ? widget.tournament.dateText.split('•')[0].trim() : widget.tournament.dateText} • ${widget.roundTime}',
                        style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. UNDER VERIFICATION CARD (Large Status Banner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Orange circular clock graphic
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_statusIcon, color: const Color(0xFFFF6B00), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusTitle,
                              style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _statusMessage,
                              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      // Gold glow clipboard graphics placeholder on right
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 20, height: 2, color: const Color(0xFFFF9800), margin: const EdgeInsets.only(bottom: 4)),
                                Container(width: 25, height: 2, color: const Color(0xFFFF9800), margin: const EdgeInsets.only(bottom: 4)),
                                Container(width: 15, height: 2, color: const Color(0xFFFF9800)),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Icon(Icons.search, color: const Color(0xFFFF9800), size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Container(height: 1, color: const Color(0xFF222630)),
                  const SizedBox(height: 20),

                  // Step progress timeline tracker
                  _buildProgressTimeline(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. YOUR SUBMITTED RESULT SECTION
            _buildSectionHeader('Your Submitted Result'),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStandingCard(Icons.emoji_events_outlined, 'Final Position', _rank),
                const SizedBox(width: 8),
                _buildStandingCard(Icons.gps_fixed_rounded, 'Total Kills', _kills),
                const SizedBox(width: 8),
                _buildStandingCard(Icons.stars_rounded, 'Total Points', _points),
              ],
            ),
            const SizedBox(height: 24),

            // 4. SUBMITTED PROOF SCREENSHOTS
            _buildSectionHeader('Submitted Proof Screenshots'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildProofCard('BOOYAH!', Colors.orangeAccent.withValues(alpha: 0.1))),
                const SizedBox(width: 12),
                Expanded(child: _buildProofCard('Scoreboard', Colors.blueGrey.withValues(alpha: 0.15))),
              ],
            ),
            const SizedBox(height: 24),

            // 5. TEAM INFORMATION
            _buildSectionHeader('Team Information'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Column(
                children: [
                  _buildTeamRow('NS•Rexx (You)', 'UID: 123456789', isCaptain: true, isFirst: true),
                  _buildDivider(),
                  _buildTeamRow('NS•Samir', 'UID: 234567890'),
                  _buildDivider(),
                  _buildTeamRow('NS•Rizen', 'UID: 345678901'),
                  _buildDivider(),
                  _buildTeamRow('NS•LEGEND', 'UID: 456789012', isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. WHAT HAPPENS NEXT?
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF110E1C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF221F4C)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5865F2).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF5865F2), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What happens next?',
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Our admin team will verify your result and screenshots. You will be notified once the verification is complete.',
                          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Estimated Time Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.access_time_rounded, color: Color(0xFF5865F2), size: 20),
                      const SizedBox(height: 6),
                      Text(
                        'Estimated Time',
                        style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '2 - 6 Hours',
                        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bottom footnote alert
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, color: Color(0x40A0A0A0), size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'You will receive a notification once the verification is complete.',
                    style: GoogleFonts.poppins(color: const Color(0x40A0A0A0), fontSize: 9, fontWeight: FontWeight.w500),
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

  Widget _buildSectionHeader(String title) {
    return Row(
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTimeline() {
    final String cleanDate = widget.tournament.dateText.contains('•')
        ? widget.tournament.dateText.split('•')[0].trim()
        : widget.tournament.dateText;
    final String stepTime = '${cleanDate.length > 6 ? cleanDate.substring(0, 6) : cleanDate}, ${widget.roundTime}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepItem('Result Submitted', stepTime, isCompleted: true),
        _buildLineConnector(isCompleted: true),
        _buildStepItem('Under Verification', stepTime, isActive: true),
        _buildLineConnector(isCompleted: false),
        _buildStepItem('Verification Complete', 'Pending', isPending: true),
        _buildLineConnector(isCompleted: false),
        _buildStepItem('Result Published', 'Pending', isPending: true),
      ],
    );
  }

  Widget _buildStepItem(String title, String subtitle, {bool isCompleted = false, bool isActive = false, bool isPending = false}) {
    IconData icon;
    Color color;
    Color circleBg;

    if (isCompleted) {
      icon = Icons.check_circle_rounded;
      color = const Color(0xFFFF6B00);
      circleBg = Colors.transparent;
    } else if (isActive) {
      icon = Icons.access_time_filled_rounded;
      color = const Color(0xFFFF6B00);
      circleBg = Colors.transparent;
    } else {
      icon = Icons.circle_outlined;
      color = const Color(0x30A0A0A0);
      circleBg = const Color(0xFF101216);
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: circleBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: isPending ? const Color(0x60A0A0A0) : Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: isPending ? const Color(0x30A0A0A0) : const Color(0x60A0A0A0),
              fontSize: 6.5,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLineConnector({required bool isCompleted}) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(top: 10),
      color: isCompleted ? const Color(0xFFFF6B00) : const Color(0xFF222630),
    );
  }

  Widget _buildStandingCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF101216),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF222630)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFF6B00), size: 18),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofCard(String text, Color overlayColor) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101216),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF222630)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: overlayColor),
              Center(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow(String name, String uid, {bool isCaptain = false, bool isFirst = false, bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isCaptain ? const Color(0xFF4CAF50) : context.battlyBorder,
                width: 1.5,
              ),
            ),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF1E222A),
              child: Icon(Icons.person, color: Colors.white54, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 1),
                Text(
                  uid,
                  style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCaptain ? const Color(0xFF4CAF50).withValues(alpha: 0.4) : const Color(0x30A0A0A0),
              ),
              color: isCaptain ? const Color(0xFF4CAF50).withValues(alpha: 0.08) : Colors.transparent,
            ),
            child: Text(
              isCaptain ? 'CAPTAIN' : 'MEMBER',
              style: GoogleFonts.poppins(
                color: isCaptain ? const Color(0xFF4CAF50) : context.battlyMuted,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1.0,
      color: const Color(0xFF222630),
    );
  }
}
