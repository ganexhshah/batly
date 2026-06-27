import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/profile/player_profile_screen.dart';
import '../core/theme/battly_theme.dart';

enum TournamentPlayerRowStyle { preview, lobby, manage }

class TournamentPlayerRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> participant;
  final TournamentPlayerRowStyle style;
  final bool isMe;
  final Widget? trailing;
  final VoidCallback? onRemove;
  final VoidCallback? onCopyUid;

  const TournamentPlayerRow({
    super.key,
    required this.rank,
    required this.participant,
    this.style = TournamentPlayerRowStyle.preview,
    this.isMe = false,
    this.trailing,
    this.onRemove,
    this.onCopyUid,
  });

  String get _displayName =>
      (participant['ign'] as String? ?? participant['name'] as String? ?? 'Player').trim();

  String get _uid => participant['game_uid'] as String? ?? 'No UID';

  String? get _avatarUrl => participant['avatar_url'] as String?;

  bool get _isOwner => participant['is_owner'] == true;

  int? get _userId => participant['id'] as int?;

  void _openProfile(BuildContext context) {
    final id = _userId;
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfileScreen(
          userId: id,
          initialParticipant: participant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlightMe = style == TournamentPlayerRowStyle.lobby && isMe;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openProfile(context),
        borderRadius: BorderRadius.circular(style == TournamentPlayerRowStyle.preview ? 12 : 14),
        child: Container(
          margin: EdgeInsets.only(bottom: style == TournamentPlayerRowStyle.preview ? 8 : 10),
          padding: EdgeInsets.symmetric(
            horizontal: style == TournamentPlayerRowStyle.preview ? 10 : 14,
            vertical: style == TournamentPlayerRowStyle.preview ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: highlightMe ? const Color(0xFF1A2E1A) : context.battlyCard,
            borderRadius: BorderRadius.circular(style == TournamentPlayerRowStyle.preview ? 12 : 14),
            border: Border.all(
              color: highlightMe
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : context.battlyBorder,
            ),
          ),
          child: Row(
            children: [
              _RankBadge(rank: rank, compact: style == TournamentPlayerRowStyle.preview),
              const SizedBox(width: 12),
              _PlayerAvatar(name: _displayName, avatarUrl: _avatarUrl, radius: style == TournamentPlayerRowStyle.preview ? 16 : 18),
              const SizedBox(width: 12),
              Expanded(child: _PlayerInfo(
                displayName: _displayName,
                uid: _uid,
                isMe: isMe,
                isOwner: _isOwner,
                style: style,
                onCopyUid: onCopyUid,
              )),
              if (trailing != null) trailing!,
              if (style == TournamentPlayerRowStyle.preview)
                _RegisteredBadge(),
              if (style == TournamentPlayerRowStyle.manage && !_isOwner && onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Remove',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFE53935),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final bool compact;

  const _RankBadge({required this.rank, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 24 : 26,
      height: compact ? 24 : 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.battlyScaffold,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: compact ? null : Border.all(color: context.battlyBorder),
      ),
      child: Text(
        '$rank',
        style: GoogleFonts.poppins(
          color: compact ? Colors.white : const Color(0xFFFF6B00),
          fontWeight: FontWeight.bold,
          fontSize: compact ? 11 : 10,
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const _PlayerAvatar({
    required this.name,
    required this.avatarUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.battlyScaffold,
      backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty) ? NetworkImage(avatarUrl!) : null,
      child: (avatarUrl == null || avatarUrl!.isEmpty)
          ? (radius <= 16
              ? const Icon(Icons.person, color: Color(0xFFFF6B00), size: 16)
              : Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFF6B00),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ))
          : null,
    );
  }
}

class _PlayerInfo extends StatelessWidget {
  final String displayName;
  final String uid;
  final bool isMe;
  final bool isOwner;
  final TournamentPlayerRowStyle style;
  final VoidCallback? onCopyUid;

  const _PlayerInfo({
    required this.displayName,
    required this.uid,
    required this.isMe,
    required this.isOwner,
    required this.style,
    this.onCopyUid,
  });

  @override
  Widget build(BuildContext context) {
    final nameSize = style == TournamentPlayerRowStyle.preview ? 12.0 : 13.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                style: GoogleFonts.poppins(color: context.battlyOnSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: nameSize,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (style == TournamentPlayerRowStyle.lobby && isMe) ...[
              const SizedBox(width: 6),
              _Tag(label: 'You', color: const Color(0xFF4CAF50)),
            ],
            if (isOwner) ...[
              const SizedBox(width: 6),
              _Tag(
                label: style == TournamentPlayerRowStyle.manage ? 'Room Maker' : 'Host',
                color: const Color(0xFFFF6B00),
              ),
            ],
          ],
        ),
        Row(
          children: [
            Text(
              'UID: $uid',
              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
            ),
            if (onCopyUid != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onCopyUid,
                child: const Icon(Icons.copy_rounded, color: Color(0xFF6B6F7A), size: 12),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _RegisteredBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF4CAF50)),
      ),
      child: Text(
        'REGISTERED',
        style: GoogleFonts.poppins(
          color: const Color(0xFF4CAF50),
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
