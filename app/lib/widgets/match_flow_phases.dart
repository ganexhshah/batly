import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/battly_theme.dart';
import '../../models/match_flow_state.dart';

class MatchFlowHeader extends StatelessWidget {
  const MatchFlowHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor = const Color(0xFFFF6B00),
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accentColor, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: context.battlyOnSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: context.battlyMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class MatchReadyPlayerList extends StatelessWidget {
  const MatchReadyPlayerList({super.key, required this.players});

  final List<MatchFlowPlayer> players;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.battlyCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.battlyBorder.withValues(alpha: 0.3)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: players.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: context.battlyBorder.withValues(alpha: 0.2)),
        itemBuilder: (context, index) {
          final p = players[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: context.battly.elevatedSurface,
              backgroundImage: p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                  ? NetworkImage(p.avatarUrl!)
                  : null,
              child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                  ? Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            title: Text(
              p.name,
              style: GoogleFonts.poppins(
                color: context.battlyOnSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: p.isRepresentative
                ? Text('Team rep', style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11))
                : null,
            trailing: Icon(
              p.isReady ? Icons.check_circle : Icons.radio_button_unchecked,
              color: p.isReady ? const Color(0xFF4CAF50) : context.battlyMuted,
            ),
          );
        },
      ),
    );
  }
}

class MatchReadyPhase extends StatelessWidget {
  const MatchReadyPhase({
    super.key,
    required this.flow,
    required this.isReady,
    required this.busy,
    required this.onToggleReady,
  });

  final MatchFlowState flow;
  final bool isReady;
  final bool busy;
  final ValueChanged<bool> onToggleReady;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MatchFlowHeader(
          title: 'Get Ready',
          subtitle: flow.allReady
              ? 'Everyone is ready. Host can share room codes next.'
              : 'Waiting for all ${flow.maxPlayers} players (${flow.readyCount}/${flow.maxPlayers} ready).',
          icon: Icons.sports_esports_rounded,
        ),
        const SizedBox(height: 24),
        MatchReadyPlayerList(players: flow.readyPlayers),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'I am ready',
            style: GoogleFonts.poppins(
              color: context.battlyOnSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          value: isReady,
          activeThumbColor: const Color(0xFF4CAF50),
          onChanged: busy ? null : onToggleReady,
        ),
      ],
    );
  }
}

class MatchShareCodesPhase extends StatelessWidget {
  const MatchShareCodesPhase({
    super.key,
    required this.flow,
    required this.roomIdController,
    required this.roomPassController,
    required this.saving,
    required this.onSave,
  });

  final MatchFlowState flow;
  final TextEditingController roomIdController;
  final TextEditingController roomPassController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    if (flow.isOwner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MatchFlowHeader(
            title: 'Share Room Codes',
            subtitle: 'Enter the in-game Room ID and Password once. Players cannot change these later.',
            icon: Icons.vpn_key_rounded,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: roomIdController,
            style: GoogleFonts.poppins(color: context.battlyOnSurface),
            decoration: InputDecoration(
              labelText: 'Room ID',
              labelStyle: GoogleFonts.poppins(color: context.battlyMuted),
              filled: true,
              fillColor: context.battly.elevatedSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: roomPassController,
            style: GoogleFonts.poppins(color: context.battlyOnSurface),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: GoogleFonts.poppins(color: context.battlyMuted),
              filled: true,
              fillColor: context.battly.elevatedSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Share with Players',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      );
    }

    return const MatchFlowHeader(
      title: 'Waiting for Host',
      subtitle: 'The host will share Room ID and Password once everyone is ready.',
      icon: Icons.hourglass_top_rounded,
      accentColor: Color(0xFF2196F3),
    );
  }
}

class MatchCredentialCard extends StatelessWidget {
  const MatchCredentialCard({
    super.key,
    required this.roomId,
    required this.roomPassword,
  });

  final String roomId;
  final String roomPassword;

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4CAF50),
        content: Text('$label copied', style: GoogleFonts.poppins(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.battlyCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF4CAF50), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(context, 'Room ID', roomId, () => _copy(context, 'Room ID', roomId)),
            const SizedBox(height: 12),
            _row(context, 'Password', roomPassword, () => _copy(context, 'Password', roomPassword)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, VoidCallback onCopy) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11)),
              Text(
                value.isEmpty ? '—' : value,
                style: GoogleFonts.poppins(
                  color: context.battlyOnSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: value.isEmpty ? null : onCopy,
          icon: const Icon(Icons.copy_rounded, color: Color(0xFF4CAF50)),
        ),
      ],
    );
  }
}

class MatchInGamePhase extends StatelessWidget {
  const MatchInGamePhase({
    super.key,
    required this.flow,
    required this.busy,
    required this.onConfirm,
  });

  final MatchFlowState flow;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final reps = flow.representatives;
    final confirmed = flow.inGameConfirmedBy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MatchFlowHeader(
          title: 'Join In-Game',
          subtitle: 'Use the room codes below, join the match, then confirm when you are in the lobby.',
          icon: Icons.login_rounded,
          accentColor: Color(0xFF2196F3),
        ),
        if (flow.roomId != null || flow.roomPassword != null) ...[
          const SizedBox(height: 20),
          MatchCredentialCard(
            roomId: flow.roomId ?? '',
            roomPassword: flow.roomPassword ?? '',
          ),
        ],
        const SizedBox(height: 20),
        Card(
          color: context.battlyCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In-game status',
                  style: GoogleFonts.poppins(
                    color: context.battlyOnSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                for (final repId in reps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          confirmed.contains(repId) ? Icons.check_circle : Icons.pending,
                          color: confirmed.contains(repId)
                              ? const Color(0xFF4CAF50)
                              : context.battlyMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            flow.playerById(repId)?.name ?? 'Player $repId',
                            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13),
                          ),
                        ),
                        Text(
                          confirmed.contains(repId) ? 'Joined' : 'Waiting',
                          style: GoogleFonts.poppins(
                            color: confirmed.contains(repId)
                                ? const Color(0xFF4CAF50)
                                : context.battlyMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (flow.isRepresentative && !flow.myInGameConfirmed) ...[
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: busy ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'I Joined the Game',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ] else if (flow.myInGameConfirmed) ...[
          const SizedBox(height: 16),
          Text(
            'You confirmed. Waiting for other side(s)...',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class MatchLivePhase extends StatefulWidget {
  const MatchLivePhase({
    super.key,
    required this.flow,
    required this.busy,
    required this.onStop,
  });

  final MatchFlowState flow;
  final bool busy;
  final VoidCallback onStop;

  @override
  State<MatchLivePhase> createState() => _MatchLivePhaseState();
}

class _MatchLivePhaseState extends State<MatchLivePhase> {
  Timer? _timer;
  int? _secondsRemaining;
  bool _timerExpired = false;

  @override
  void initState() {
    super.initState();
    _syncFromFlow(widget.flow);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(MatchLivePhase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flow.matchEndsAt != widget.flow.matchEndsAt ||
        oldWidget.flow.secondsRemaining != widget.flow.secondsRemaining) {
      _syncFromFlow(widget.flow);
    }
  }

  void _syncFromFlow(MatchFlowState flow) {
    _secondsRemaining = flow.secondsRemaining;
    _timerExpired = flow.timerExpired;
    if (flow.matchEndsAt != null) {
      final ends = DateTime.tryParse(flow.matchEndsAt!);
      if (ends != null) {
        final diff = ends.difference(DateTime.now()).inSeconds;
        _secondsRemaining = diff > 0 ? diff : 0;
        _timerExpired = diff <= 0;
      }
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      if (_secondsRemaining != null && _secondsRemaining! > 0) {
        _secondsRemaining = _secondsRemaining! - 1;
      } else {
        _timerExpired = true;
        _secondsRemaining = 0;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _secondsRemaining ?? 0;
    final canStopSolo = _timerExpired;
    final stopHint = widget.flow.myStopClicked
        ? 'Waiting for opponent to tap Stop.'
        : canStopSolo
            ? 'Timer ended. Tap Stop when the match is over.'
            : 'Both sides must tap Stop early, or wait for the timer.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MatchFlowHeader(
          title: 'Match Live',
          subtitle: 'Play your match. The server timer tracks the 25-minute window.',
          icon: Icons.fiber_manual_record,
          accentColor: Color(0xFF4CAF50),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Text(
                _timerExpired ? 'TIMER ENDED' : 'TIME REMAINING',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF4CAF50),
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _timerExpired ? '00:00' : _formatTime(remaining),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          stopHint,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12, height: 1.4),
        ),
        if (widget.flow.isRepresentative && !widget.flow.myStopClicked) ...[
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: widget.busy ? null : widget.onStop,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: widget.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Stop Match',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class MatchStopNoticePhase extends StatelessWidget {
  const MatchStopNoticePhase({
    super.key,
    required this.flow,
    required this.busy,
    required this.onAcknowledge,
  });

  final MatchFlowState flow;
  final bool busy;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final stopperId = flow.stopClickedBy.isNotEmpty ? flow.stopClickedBy.first : null;
    final stopperName = stopperId != null
        ? flow.playerById(stopperId)?.name ?? 'Opponent'
        : 'Opponent';
    final isStopper = flow.myStopClicked;
    final canAck = flow.isRepresentative && !isStopper;
    String? opponentRep;
    for (final id in flow.representatives) {
      if (id != stopperId) {
        opponentRep = flow.playerById(id)?.name ?? 'Opponent';
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MatchFlowHeader(
          title: 'Match End Review',
          subtitle: 'One player ended the match. The opponent has a limited time to respond.',
          icon: Icons.gavel_rounded,
          accentColor: Color(0xFFFF9800),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1F0A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
          ),
          child: Text(
            isStopper
                ? 'You tapped Stop. Waiting for ${opponentRep ?? 'your opponent'} to acknowledge or for the review window to end.'
                : '$stopperName tapped Stop. Acknowledge that the match ended, or the stopper may receive the prize automatically.',
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, height: 1.5),
          ),
        ),
        if (flow.stopAdminDeadlineAt != null) ...[
          const SizedBox(height: 12),
          Text(
            'Review deadline: ${flow.stopAdminDeadlineAt}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
          ),
        ],
        if (canAck) ...[
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: busy ? null : onAcknowledge,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Acknowledge Match Ended',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class MatchResultVotePhase extends StatelessWidget {
  const MatchResultVotePhase({
    super.key,
    required this.flow,
    required this.busy,
    required this.onVote,
  });

  final MatchFlowState flow;
  final bool busy;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final voted = flow.myVote != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MatchFlowHeader(
          title: 'Vote Winner',
          subtitle: 'Each side picks who won. Matching votes trigger automatic payout.',
          icon: Icons.emoji_events_outlined,
          accentColor: Color(0xFFFFD700),
        ),
        const SizedBox(height: 24),
        if (voted)
          Text(
            'Your vote is locked. Waiting for the other side...',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
          )
        else if (flow.isRepresentative) ...[
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: busy ? null : () => onVote('self'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'I Won',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: busy ? null : () => onVote('opponent'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.battlyBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Opponent Won',
                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else
          Text(
            'Only team representatives can vote.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
          ),
      ],
    );
  }
}

class MatchProofPhase extends StatelessWidget {
  const MatchProofPhase({
    super.key,
    required this.flow,
    required this.busy,
    required this.hasScreenshot,
    required this.onPickScreenshot,
    required this.onClearScreenshot,
    required this.onSubmit,
  });

  final MatchFlowState flow;
  final bool busy;
  final bool hasScreenshot;
  final VoidCallback onPickScreenshot;
  final VoidCallback onClearScreenshot;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MatchFlowHeader(
          title: 'Submit Proof',
          subtitle: 'Players disagreed on the winner. Upload a screenshot for admin review.',
          icon: Icons.image_outlined,
          accentColor: Color(0xFFE53935),
        ),
        const SizedBox(height: 24),
        if (flow.myProofSubmitted)
          Text(
            'Proof submitted. An admin will review and approve the winner.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13, height: 1.4),
          )
        else if (flow.isRepresentative) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Match result screenshot',
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              hasScreenshot ? 'Screenshot selected' : 'Pick a screenshot from your gallery',
              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
            ),
            trailing: hasScreenshot
                ? IconButton(
                    onPressed: busy ? null : onClearScreenshot,
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  )
                : null,
          ),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onPickScreenshot,
              icon: Icon(hasScreenshot ? Icons.check_circle_outline : Icons.photo_library_outlined,
                  color: hasScreenshot ? const Color(0xFF4CAF50) : const Color(0xFFFF6B00)),
              label: Text(
                hasScreenshot ? 'Change screenshot' : 'Pick screenshot',
                style: GoogleFonts.poppins(
                  color: context.battlyOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: hasScreenshot ? const Color(0xFF4CAF50) : context.battlyBorder,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: busy || !hasScreenshot ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Submit for Review',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ] else
          Text(
            'Waiting for team representative to submit proof.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
          ),
      ],
    );
  }
}

class MatchCompletedPhase extends StatelessWidget {
  const MatchCompletedPhase({super.key, required this.flow});

  final MatchFlowState flow;

  @override
  Widget build(BuildContext context) {
    final winner = flow.completedWinnerId != null
        ? flow.playerById(flow.completedWinnerId!)?.name ?? 'Winner'
        : 'Winner';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MatchFlowHeader(
          title: 'Match Complete',
          subtitle: 'Results are final. Prize has been distributed when votes agreed or admin approved.',
          icon: Icons.check_circle_outline,
          accentColor: Color(0xFF4CAF50),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF6B00).withValues(alpha: 0.2),
                const Color(0xFFFFD700).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 48),
              const SizedBox(height: 12),
              Text(
                winner,
                style: GoogleFonts.poppins(
                  color: context.battlyOnSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Winner',
                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
