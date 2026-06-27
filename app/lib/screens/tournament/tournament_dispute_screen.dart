import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../core/theme/battly_theme.dart';

class TournamentDisputeScreen extends StatefulWidget {
  final int tournamentId;
  final String tournamentTitle;
  final int? gameMatchId;
  final int? reportedUserId;
  final String? reportedUserName;
  final bool isReport;

  const TournamentDisputeScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentTitle,
    this.gameMatchId,
    this.reportedUserId,
    this.reportedUserName,
    this.isReport = false,
  });

  @override
  State<TournamentDisputeScreen> createState() => _TournamentDisputeScreenState();
}

class _TournamentDisputeScreenState extends State<TournamentDisputeScreen> {
  final _reasonController = TextEditingController();
  String _disputeType = 'wrong_result';
  bool _submitting = false;

  static const _disputeTypes = [
    ('wrong_result', 'Wrong Result'),
    ('wrong_rank', 'Wrong Rank'),
    ('wrong_kills', 'Wrong Kill Count'),
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 10) {
      _showSnack('Please describe the issue (at least 10 characters).', isError: true);
      return;
    }

    setState(() => _submitting = true);

    final Map<String, dynamic> res;
    if (widget.isReport && widget.reportedUserId != null) {
      res = await ApiService.reportPlayer(
        widget.tournamentId,
        reportedUserId: widget.reportedUserId!,
        reason: reason,
      );
    } else {
      res = await ApiService.raiseDispute(
        widget.tournamentId,
        type: _disputeType,
        reason: reason,
        gameMatchId: widget.gameMatchId,
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true) {
      _showSnack(res['message'] ?? 'Submitted for admin review.', isError: false);
      Navigator.pop(context, true);
    } else {
      _showSnack(res['message'] ?? 'Failed to submit.', isError: true);
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

  @override
  Widget build(BuildContext context) {
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
          widget.isReport ? 'Report Player' : 'Raise Dispute',
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                  Text(widget.tournamentTitle, style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    widget.isReport
                        ? 'Reporting: ${widget.reportedUserName ?? 'Player'}'
                        : 'Admin will review your dispute before any prize changes.',
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!widget.isReport) ...[
              Text('Issue type', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._disputeTypes.map((t) {
                final selected = _disputeType == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _disputeType = t.$1),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFF6B00).withValues(alpha: 0.12) : context.battlyCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? const Color(0xFFFF6B00) : context.battlyBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: selected ? const Color(0xFFFF6B00) : const Color(0xFF6B6F7A),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(t.$2, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            Text('Description', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 5,
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Explain what went wrong. Include expected vs actual rank/kills if relevant.',
                hintStyle: GoogleFonts.poppins(color: const Color(0xFF4A4F5C), fontSize: 12),
                filled: true,
                fillColor: context.battlyCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF2B2F3A))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF2B2F3A))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFFF6B00))),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        widget.isReport ? 'Submit Report' : 'Submit Dispute',
                        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
