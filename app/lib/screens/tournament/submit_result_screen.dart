import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import 'verification_status_screen.dart';
import '../../core/theme/battly_theme.dart';

class SubmitResultScreen extends StatefulWidget {
  final UpcomingTournament tournament;
  final String roundName;
  final String mapName;
  final String roundTime;

  const SubmitResultScreen({
    super.key,
    required this.tournament,
    required this.roundName,
    required this.mapName,
    required this.roundTime,
  });

  @override
  State<SubmitResultScreen> createState() => _SubmitResultScreenState();
}

class _SubmitResultScreenState extends State<SubmitResultScreen> {
  String _finalPosition = '1';
  String _totalKills = '0';
  String _totalPoints = '0';
  bool _isConfirmed = true;
  bool _loadingResults = true;

  final List<String> _positionOptions = List.generate(32, (i) => (i + 1).toString());
  final List<String> _killsOptions = List.generate(40, (i) => i.toString());
  final List<String> _pointsOptions = List.generate(100, (i) => i.toString());

  bool _hasScreenshot1 = false;
  bool _hasScreenshot2 = false;
  XFile? _screenshot1;
  XFile? _screenshot2;
  Uint8List? _screenshot1Bytes;
  Uint8List? _screenshot2Bytes;

  @override
  void initState() {
    super.initState();
    _loadExistingResult();
  }

  Future<void> _loadExistingResult() async {
    if (widget.tournament.id == null) {
      if (mounted) setState(() => _loadingResults = false);
      return;
    }
    try {
      final data = await ApiService.getTournamentResults(widget.tournament.id!);
      final my = data['my_result'] as Map<String, dynamic>?;
      if (my != null && mounted) {
        setState(() {
          if (my['rank'] != null) _finalPosition = my['rank'].toString();
          if (my['kills'] != null) _totalKills = my['kills'].toString();
          if (my['points'] != null) _totalPoints = my['points'].toString();
          _loadingResults = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingResults = false);
  }

  Future<void> _handleSubmit() async {
    if (!_isConfirmed) {
      _showSnackBar('Please confirm the information is correct', const Color(0xFFE53935));
      return;
    }

    if (widget.tournament.id == null) {
      _showSnackBar('Tournament ID is missing. Please reopen the tournament and try again.', const Color(0xFFE53935));
      return;
    }

    if (!_hasScreenshot1 && !_hasScreenshot2) {
      _showSnackBar('Please upload at least one screenshot proof', const Color(0xFFE53935));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.battlyBorder, width: 1.5),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                ),
                SizedBox(height: 16),
                Text(
                  'Uploading match proof & statistics...',
                  style: TextStyle(color: Colors.white70, fontSize: 13, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final proofFiles = <Map<String, dynamic>>[];
      if (_screenshot1 != null) {
        proofFiles.add({
          'bytes': await _screenshot1!.readAsBytes(),
          'filename': _screenshot1!.name,
        });
      }
      if (_screenshot2 != null) {
        proofFiles.add({
          'bytes': await _screenshot2!.readAsBytes(),
          'filename': _screenshot2!.name,
        });
      }

      await ApiService.submitMatchResult(
        tournamentId: widget.tournament.id!,
        rank: int.parse(_finalPosition),
        kills: int.parse(_totalKills),
        points: int.parse(_totalPoints),
        roundName: widget.roundName,
        mapName: widget.mapName,
        roundTime: widget.roundTime,
        proofFiles: proofFiles,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: context.battlyCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Color(0xFF2B2F3A), width: 1.5),
            ),
            title: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF4CAF50),
              size: 48,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Result Submitted!',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your team stats (Rank #$_finalPosition, $_totalKills Kills, $_totalPoints Points) have been sent for verification. Admin approval may take up to 30 minutes.',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 11.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pushReplacement(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), const Color(0xFFE53935));
    }
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(
          text,
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickScreenshot(int slot) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      if (slot == 1) {
        _screenshot1 = picked;
        _screenshot1Bytes = bytes;
        _hasScreenshot1 = true;
      } else {
        _screenshot2 = picked;
        _screenshot2Bytes = bytes;
        _hasScreenshot2 = true;
      }
    });
  }

  Widget _screenshotPreview(Uint8List bytes, VoidCallback onRemove) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101216),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF222630)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Submit Result',
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
                          'How it works',
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '1. Enter your final standings (Position, Kills, Points).\n2. Upload proof screenshots showing the final placement scoreboard.\n3. Make sure to only submit valid, clean images. Fraudulent uploads lead to permanent account bans.',
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
      body: _loadingResults
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 100), // padding to offset absolute footer
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. MATCH INFO CARD
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Row(
                children: [
                  // Logo thumbnail
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
                  // Details
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
                  // Status block on right
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'MATCH STARTED',
                        style: GoogleFonts.poppins(color: const Color(0xFFFF9800), fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'Completed',
                            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 12),
                        ],
                      ),
                      const SizedBox(height: 4),
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

            // 2. WARNING ALERT BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF23150C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4A2B0E)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF8C00), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submit your result carefully',
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Incorrect result submission may lead to disqualification.',
                          style: GoogleFonts.poppins(color: const Color(0xFFD4B198), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. YOUR FINAL STANDING SECTION
            _buildSectionHeader('Your Final Standing'),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStandingDropdown(
                  icon: Icons.emoji_events_outlined,
                  label: 'Final Position',
                  value: _finalPosition,
                  options: _positionOptions,
                  onChanged: (val) => setState(() => _finalPosition = val),
                ),
                const SizedBox(width: 8),
                _buildStandingDropdown(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Total Kills',
                  value: _totalKills,
                  options: _killsOptions,
                  onChanged: (val) => setState(() => _totalKills = val),
                ),
                const SizedBox(width: 8),
                _buildStandingDropdown(
                  icon: Icons.stars_rounded,
                  label: 'Total Points',
                  value: _totalPoints,
                  options: _pointsOptions,
                  onChanged: (val) => setState(() => _totalPoints = val),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4. UPLOAD PROOF SCREENSHOTS
            _buildSectionHeader('Upload Proof Screenshots'),
            const SizedBox(height: 2),
            Text(
              'Upload clear screenshots from match end screen',
              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_hasScreenshot1 && _screenshot1Bytes != null)
                  Expanded(child: _screenshotPreview(_screenshot1Bytes!, () => setState(() {
                    _hasScreenshot1 = false;
                    _screenshot1 = null;
                    _screenshot1Bytes = null;
                  })))
                else
                  Expanded(child: _buildUploadTriggerCard('Slot 1', () => _pickScreenshot(1))),
                
                const SizedBox(width: 10),
                if (_hasScreenshot2 && _screenshot2Bytes != null)
                  Expanded(child: _screenshotPreview(_screenshot2Bytes!, () => setState(() {
                    _hasScreenshot2 = false;
                    _screenshot2 = null;
                    _screenshot2Bytes = null;
                  })))
                else
                  Expanded(child: _buildUploadTriggerCard('Slot 2', () => _pickScreenshot(2))),
                
                const SizedBox(width: 10),
                Expanded(child: _buildUploadTriggerCard('Optional', () {})),
              ],
            ),
            const SizedBox(height: 28),

            // 5. TEAM INFORMATION
            _buildSectionHeader('Team Information'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222630)),
              ),
              child: Column(
                children: [
                  _buildTeamRow('NS•Rexx (You)', 'UID: 123456789', true, isCaptain: true, isFirst: true),
                  _buildDivider(),
                  _buildTeamRow('NS•Samir', 'UID: 234567890', false),
                  _buildDivider(),
                  _buildTeamRow('NS•Rizen', 'UID: 345678901', false),
                  _buildDivider(),
                  _buildTeamRow('NS•LEGEND', 'UID: 456789012', false, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomSheet: Container(
        color: context.battly.navBar,
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Checkbox Confirm Tile
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _isConfirmed,
                    onChanged: (val) {
                      if (val != null) setState(() => _isConfirmed = val);
                    },
                    activeColor: const Color(0xFFFF6B00),
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'I confirm that the above information is correct and screenshots are valid. False submission may lead to disqualification or ban.',
                    style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 10.5, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // CTA Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _handleSubmit,
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                label: Text(
                  'Submit Result',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Lock details
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, color: Color(0x60A0A0A0), size: 12),
                const SizedBox(width: 6),
                Text(
                  'You can only submit once. Make sure everything is correct.',
                  style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 9, fontWeight: FontWeight.w500),
                ),
              ],
            ),
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

  Widget _buildStandingDropdown({
    required IconData icon,
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF101216),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF222630)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: const Color(0xFFFF6B00), size: 16),
                const Icon(Icons.help_outline_rounded, color: Color(0x40A0A0A0), size: 12),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8.5, fontWeight: FontWeight.bold),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: const Color(0xFF101216),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 18),
                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 18, fontWeight: FontWeight.bold),
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
                items: options.map<DropdownMenuItem<String>>((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTriggerCard(String label, VoidCallback onAdd) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: GestureDetector(
        onTap: onAdd,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF222630), style: BorderStyle.solid, width: 1.0), // clean dotted visual
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_outlined, color: Colors.white54, size: 24),
              const SizedBox(height: 6),
              Text(
                'Additional Screenshot',
                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 8.5, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                '($label)',
                style: GoogleFonts.poppins(color: const Color(0x50A0A0A0), fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow(String name, String uid, bool hasGlowBorder, {bool isCaptain = false, bool isFirst = false, bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        children: [
          // Avatar
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
          // Info
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
          // Badge
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
