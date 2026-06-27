import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../chat/chat_screen.dart';
import '../../core/theme/battly_theme.dart';

class PlayerProfileScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? initialParticipant;

  const PlayerProfileScreen({
    super.key,
    required this.userId,
    this.initialParticipant,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cached = await AuthService.getCachedUser();
      _currentUserId = cached?['id'] as int?;

      final profile = await UserService.getPublicProfile(widget.userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          if (widget.initialParticipant != null) {
            _profile = {
              'id': widget.userId,
              'name': widget.initialParticipant!['name'],
              'ign': widget.initialParticipant!['ign'],
              'game_uid': widget.initialParticipant!['game_uid'],
              'avatar_url': widget.initialParticipant!['avatar_url'],
              'is_self': _currentUserId == widget.userId,
            };
          }
        });
      }
    }
  }

  void _copyUid(String uid) {
    Clipboard.setData(ClipboardData(text: uid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFF6B00),
        content: Text('UID copied', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openChat() async {
    final profile = _profile;
    if (profile == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          recipientId: widget.userId,
          recipientName: (profile['ign'] as String? ?? profile['name'] as String? ?? 'Player').trim(),
          recipientAvatarUrl: profile['avatar_url'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final displayName = (profile?['ign'] as String? ?? profile?['name'] as String? ?? 'Player').trim();
    final uid = profile?['game_uid'] as String? ?? 'N/A';
    final avatarUrl = profile?['avatar_url'] as String?;
    final isSelf = profile?['is_self'] == true || _currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: context.battly.navBar,
      appBar: AppBar(
        backgroundColor: context.battly.navBar,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Player Profile',
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : profile == null
              ? Center(
                  child: Text(
                    _error ?? 'Could not load profile',
                    style: GoogleFonts.poppins(color: context.battlyMuted),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _avatarFallback(displayName),
                                )
                              : _avatarFallback(displayName),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Battly Player',
                        style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      _detailCard(Icons.sports_esports_outlined, 'In-Game Name (IGN)', displayName),
                      const SizedBox(height: 10),
                      _detailCard(Icons.fingerprint_rounded, 'Game UID', uid, onCopy: () => _copyUid(uid)),
                      if (profile['match_count'] != null) ...[
                        const SizedBox(height: 10),
                        _detailCard(Icons.emoji_events_outlined, 'Matches Played', '${profile['match_count']}'),
                      ],
                      if (profile['tournament_count'] != null) ...[
                        const SizedBox(height: 10),
                        _detailCard(Icons.groups_outlined, 'Tournaments Joined', '${profile['tournament_count']}'),
                      ],
                      const SizedBox(height: 28),
                      if (!isSelf)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _openChat,
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                            label: Text(
                              'Message Player',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: const Color(0xFF1E222A),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'P',
        style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 32),
      ),
    );
  }

  Widget _detailCard(IconData icon, String label, String value, {VoidCallback? onCopy}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B00), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: Color(0xFF6B6F7A), size: 18),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}
