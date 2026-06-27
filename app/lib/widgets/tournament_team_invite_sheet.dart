import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../core/theme/battly_theme.dart';

/// Team invite panel for 2v2 / 3v3 / 4v4 — send, accept, decline before registration.
class TournamentTeamInviteSheet extends StatefulWidget {
  final int tournamentId;
  final String tournamentTitle;
  final bool isOwner;
  final VoidCallback? onChanged;

  const TournamentTeamInviteSheet({
    super.key,
    required this.tournamentId,
    required this.tournamentTitle,
    this.isOwner = false,
    this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required int tournamentId,
    required String tournamentTitle,
    bool isOwner = false,
    VoidCallback? onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.battlyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: TournamentTeamInviteSheet(
          tournamentId: tournamentId,
          tournamentTitle: tournamentTitle,
          isOwner: isOwner,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  State<TournamentTeamInviteSheet> createState() => _TournamentTeamInviteSheetState();
}

class _TournamentTeamInviteSheetState extends State<TournamentTeamInviteSheet> {
  bool _loading = true;
  bool _searching = false;
  List<dynamic> _sent = [];
  List<dynamic> _received = [];
  int _teamSize = 2;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getTeamInvites(widget.tournamentId);
      if (mounted) {
        setState(() {
          _sent = data['sent'] as List<dynamic>? ?? [];
          _received = data['received'] as List<dynamic>? ?? [];
          _teamSize = data['teamSize'] as int? ?? 2;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.length < 2) return;
    setState(() => _searching = true);
    final results = await ApiService.searchPlayers(q);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  Future<void> _invite(int userId) async {
    final res = await ApiService.sendTeamInvite(widget.tournamentId, userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: res['success'] == true ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
        content: Text(res['message'] ?? 'Done', style: GoogleFonts.poppins(color: context.battlyOnSurface)),
      ),
    );
    if (res['success'] == true) {
      await _load();
      widget.onChanged?.call();
    }
  }

  Future<void> _respond(int inviteId, String action) async {
    final res = await ApiService.respondTeamInvite(widget.tournamentId, inviteId, action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: res['success'] == true ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
        content: Text(res['message'] ?? 'Done', style: GoogleFonts.poppins(color: context.battlyOnSurface)),
      ),
    );
    if (res['success'] == true) {
      await _load();
      widget.onChanged?.call();
    }
  }

  bool get _hasAcceptedInvite =>
      _received.any((i) => (i as Map)['status'] == 'accepted');

  @override
  Widget build(BuildContext context) {
    final acceptedSent = _sent.where((i) => (i as Map)['status'] == 'accepted').length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.battlyBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Team Invites',
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              widget.tournamentTitle,
              style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Team size: $_teamSize • Accepted: ${widget.isOwner ? acceptedSent : (_hasAcceptedInvite ? 1 : 0)}/${_teamSize - 1}',
              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
              ))
            else ...[
              if (_received.isNotEmpty) ...[
                Text('Invites for you', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ..._received.map((raw) => _buildReceivedInvite(raw as Map<String, dynamic>)),
                const SizedBox(height: 16),
              ],
              if (widget.isOwner) ...[
                Text('Invite teammates', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search IGN or Game UID',
                          hintStyle: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 12),
                          filled: true,
                          fillColor: context.battlyScaffold,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _searching ? null : _search,
                      icon: _searching
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B00)))
                          : const Icon(Icons.search, color: Color(0xFFFF6B00)),
                    ),
                  ],
                ),
                if (_searchResults.isNotEmpty)
                  ..._searchResults.map((u) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(u['ign'] ?? u['name'] ?? 'Player', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13)),
                    subtitle: Text('UID: ${u['game_uid'] ?? ''}', style: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 10)),
                    trailing: TextButton(
                      onPressed: () => _invite(u['id'] as int),
                      child: Text('Invite', style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
                    ),
                  )),
                if (_sent.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Sent invites', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11)),
                  ..._sent.map((raw) {
                    final i = raw as Map<String, dynamic>;
                    final invitee = i['invitee'] as Map<String, dynamic>?;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(invitee?['ign'] ?? invitee?['name'] ?? 'Player', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 12)),
                      trailing: _statusChip(i['status'] as String? ?? 'pending'),
                    );
                  }),
                ],
              ] else if (!_hasAcceptedInvite && _received.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Ask the room maker to invite you before registering.',
                    style: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 11, height: 1.4),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedInvite(Map<String, dynamic> invite) {
    final captain = invite['captain'] as Map<String, dynamic>?;
    final status = invite['status'] as String? ?? 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.battlyScaffold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(captain?['ign'] ?? captain?['name'] ?? 'Captain', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Invited you to their team', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10)),
              ],
            ),
          ),
          if (status == 'pending') ...[
            TextButton(onPressed: () => _respond(invite['id'] as int, 'decline'), child: Text('Decline', style: GoogleFonts.poppins(color: const Color(0xFFE53935), fontSize: 11))),
            TextButton(onPressed: () => _respond(invite['id'] as int, 'accept'), child: Text('Accept', style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 11))),
          ] else
            _statusChip(status),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'accepted'
        ? const Color(0xFF4CAF50)
        : status == 'declined'
            ? const Color(0xFFE53935)
            : const Color(0xFFFF6B00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status.toUpperCase(), style: GoogleFonts.poppins(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
