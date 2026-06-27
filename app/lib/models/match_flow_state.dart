import '../core/json_parse.dart';

class MatchFlowPlayer {
  final int userId;
  final String name;
  final String? avatarUrl;
  final bool isReady;
  final bool isOwner;
  final bool isRepresentative;

  const MatchFlowPlayer({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.isReady = false,
    this.isOwner = false,
    this.isRepresentative = false,
  });

  factory MatchFlowPlayer.fromJson(Map<String, dynamic> json) {
    return MatchFlowPlayer(
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Player',
      avatarUrl: json['avatar_url'] as String?,
      isReady: json['is_ready'] as bool? ?? false,
      isOwner: json['is_owner'] as bool? ?? false,
      isRepresentative: json['is_representative'] as bool? ?? false,
    );
  }
}

class MatchFlowState {
  static const phaseWaitingReady = 'waiting_ready';
  static const phaseSharingCodes = 'sharing_codes';
  static const phaseWaitingInGame = 'waiting_in_game';
  static const phaseLive = 'live';
  static const phaseAdminStopReview = 'admin_stop_review';
  static const phaseResultVote = 'result_vote';
  static const phaseProofReview = 'proof_review';
  static const phaseCompleted = 'completed';

  final bool applies;
  final String phase;
  final bool isOwner;
  final bool isRepresentative;
  final List<int> representatives;
  final bool allReady;
  final List<MatchFlowPlayer> readyPlayers;
  final int readyCount;
  final int totalPlayers;
  final int maxPlayers;
  final String? roomId;
  final String? roomPassword;
  final bool roomCodesShared;
  final List<int> inGameConfirmedBy;
  final List<int> stopClickedBy;
  final String? stopAdminDeadlineAt;
  final Map<String, dynamic> winnerVotes;
  final int? myVote;
  final bool myInGameConfirmed;
  final bool myStopClicked;
  final String? matchStartedAt;
  final String? matchEndsAt;
  final bool timerExpired;
  final int? secondsRemaining;
  final int? completedWinnerId;
  final List<String> proofsSubmitted;
  final bool myProofSubmitted;
  final String? tournamentStatus;

  const MatchFlowState({
    this.applies = false,
    this.phase = phaseWaitingReady,
    this.isOwner = false,
    this.isRepresentative = false,
    this.representatives = const [],
    this.allReady = false,
    this.readyPlayers = const [],
    this.readyCount = 0,
    this.totalPlayers = 0,
    this.maxPlayers = 2,
    this.roomId,
    this.roomPassword,
    this.roomCodesShared = false,
    this.inGameConfirmedBy = const [],
    this.stopClickedBy = const [],
    this.stopAdminDeadlineAt,
    this.winnerVotes = const {},
    this.myVote,
    this.myInGameConfirmed = false,
    this.myStopClicked = false,
    this.matchStartedAt,
    this.matchEndsAt,
    this.timerExpired = false,
    this.secondsRemaining,
    this.completedWinnerId,
    this.proofsSubmitted = const [],
    this.myProofSubmitted = false,
    this.tournamentStatus,
  });

  bool get shouldPoll => applies && phase != phaseCompleted;

  factory MatchFlowState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MatchFlowState();
    final rawPlayers = parseApiList(json['ready_players']);
    final rawReps = parseApiList(json['representatives']);
    final rawConfirmed = parseApiList(json['in_game_confirmed_by']);
    final rawStopped = parseApiList(json['stop_clicked_by']);
    final rawProofs = parseApiList(json['proofs_submitted']);
    return MatchFlowState(
      applies: json['applies'] as bool? ?? false,
      phase: json['phase'] as String? ?? phaseWaitingReady,
      isOwner: json['is_owner'] as bool? ?? false,
      isRepresentative: json['is_representative'] as bool? ?? false,
      representatives: rawReps.map((e) => (e as num).toInt()).toList(),
      allReady: json['all_ready'] as bool? ?? false,
      readyPlayers: rawPlayers
          .whereType<Map>()
          .map((p) => MatchFlowPlayer.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      readyCount: json['ready_count'] as int? ?? 0,
      totalPlayers: json['total_players'] as int? ?? 0,
      maxPlayers: json['max_players'] as int? ?? 2,
      roomId: json['room_id'] as String?,
      roomPassword: json['room_password'] as String?,
      roomCodesShared: json['room_codes_shared'] as bool? ?? false,
      inGameConfirmedBy: rawConfirmed.map((e) => (e as num).toInt()).toList(),
      stopClickedBy: rawStopped.map((e) => (e as num).toInt()).toList(),
      stopAdminDeadlineAt: json['stop_admin_deadline_at'] as String?,
      winnerVotes: parseApiMap(json['winner_votes']),
      myVote: json['my_vote'] as int?,
      myInGameConfirmed: json['my_in_game_confirmed'] as bool? ?? false,
      myStopClicked: json['my_stop_clicked'] as bool? ?? false,
      matchStartedAt: json['match_started_at'] as String?,
      matchEndsAt: json['match_ends_at'] as String?,
      timerExpired: json['timer_expired'] as bool? ?? false,
      secondsRemaining: (json['seconds_remaining'] as num?)?.toInt(),
      completedWinnerId: json['completed_winner_id'] as int?,
      proofsSubmitted: rawProofs.map((e) => e.toString()).toList(),
      myProofSubmitted: json['my_proof_submitted'] as bool? ?? false,
      tournamentStatus: json['tournament_status'] as String?,
    );
  }

  MatchFlowPlayer? playerById(int id) {
    for (final p in readyPlayers) {
      if (p.userId == id) return p;
    }
    return null;
  }
}
