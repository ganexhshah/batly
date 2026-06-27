import 'prize_distribution.dart';

class FeaturedTournament {
  final int? id;
  final String title;
  final String prizePool;
  final String dateText;
  final bool isLive;
  final String imagePath;

  FeaturedTournament({
    this.id,
    required this.title,
    required this.prizePool,
    required this.dateText,
    required this.isLive,
    required this.imagePath,
  });

  factory FeaturedTournament.fromJson(Map<String, dynamic> json) {
    return FeaturedTournament(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      prizePool: json['prizePool'] as String? ?? '',
      dateText: json['dateText'] as String? ?? '',
      isLive: json['isLive'] as bool? ?? false,
      imagePath: json['imagePath'] as String? ?? '',
    );
  }
}

class TournamentRegistrationMeta {
  final bool registrationOpen;
  final bool registrationClosed;
  final bool isFull;
  final bool roomCodesShared;
  final bool canLeave;
  final bool requiresTeam;
  final int teamSize;

  const TournamentRegistrationMeta({
    this.registrationOpen = true,
    this.registrationClosed = false,
    this.isFull = false,
    this.roomCodesShared = false,
    this.canLeave = true,
    this.requiresTeam = false,
    this.teamSize = 1,
  });

  factory TournamentRegistrationMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TournamentRegistrationMeta();
    return TournamentRegistrationMeta(
      registrationOpen: json['registrationOpen'] as bool? ?? true,
      registrationClosed: json['registrationClosed'] as bool? ?? false,
      isFull: json['isFull'] as bool? ?? false,
      roomCodesShared: json['roomCodesShared'] as bool? ?? false,
      canLeave: json['canLeave'] as bool? ?? true,
      requiresTeam: json['requiresTeam'] as bool? ?? false,
      teamSize: json['teamSize'] as int? ?? 1,
    );
  }
}

class UpcomingTournament {
  static const String defaultLogoAsset = 'assets/logo/freefire.jpg';

  final int? id;
  final String title;
  final String type;
  final String mode;
  final String dateText;
  final int currentPlayers;
  final int maxPlayers;
  final String prizePool;
  final String entryFee;
  final String statusText;
  final Duration timerDuration;
  final DateTime? startsAt;
  final DateTime? createdAt;
  final List<Map<String, dynamic>>? rounds;
  final PrizeDistributionInfo? prizeDistribution;
  final String? stage;
  final String? logoAsset;
  final Map<String, dynamic>? customSettings;
  final int? createdBy;
  final String? creatorName;
  final String? creatorAvatar;
  final bool resultsPendingReview;
  final bool resultsLocked;
  final bool chatOpen;

  UpcomingTournament({
    this.id,
    required this.title,
    required this.type,
    required this.mode,
    required this.dateText,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.prizePool,
    required this.entryFee,
    required this.statusText,
    required this.timerDuration,
    this.startsAt,
    this.createdAt,
    this.rounds,
    this.prizeDistribution,
    this.stage,
    this.logoAsset,
    this.customSettings,
    this.createdBy,
    this.creatorName,
    this.creatorAvatar,
    this.resultsPendingReview = false,
    this.resultsLocked = false,
    this.chatOpen = true,
  });

  /// Minimal tournament for embedded lobby chat (floating overlay, etc.).
  factory UpcomingTournament.lobbyChat({
    required int id,
    required String title,
    bool chatOpen = true,
  }) {
    return UpcomingTournament(
      id: id,
      title: title,
      type: 'Squad',
      mode: 'Battle Royale',
      dateText: '',
      currentPlayers: 0,
      maxPlayers: 64,
      prizePool: '',
      entryFee: 'Free',
      statusText: 'UPCOMING',
      timerDuration: Duration.zero,
      chatOpen: chatOpen,
    );
  }

  bool get isTeamFormat {
    final size = customSettings?['team_size'] as String?;
    return size == '2v2' || size == '3v3' || size == '4v4';
  }

  bool get isCustomMatchFlow =>
      mode == 'Custom Room' || mode == 'Lone Wolf';

  String? get teamSizeLabel => customSettings?['team_size'] as String?;

  factory UpcomingTournament.fromJson(Map<String, dynamic> json) {
    final timerSeconds = json['timerSeconds'] as num? ?? 0;
    final rawRounds = json['rounds'];
    List<Map<String, dynamic>>? parsedRounds;
    if (rawRounds is List) {
      parsedRounds = rawRounds
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }

    final customSettings = json['customSettings'] as Map<String, dynamic>?;

    PrizeDistributionInfo? prizeDistribution;
    if (json['prizeDistribution'] is Map) {
      prizeDistribution = PrizeDistributionInfo.fromJson(
        Map<String, dynamic>.from(json['prizeDistribution'] as Map),
      );
    } else {
      prizeDistribution = PrizeDistributionInfo.fallback(
        prizePoolText: json['prizePool'] as String? ?? '',
        entryFeeText: json['entryFee'] as String? ?? 'Free',
        maxPlayers: json['maxPlayers'] as int? ?? 64,
        customSettings: customSettings,
        stage: json['stage'] as String?,
      );
    }

    return UpcomingTournament(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'Squad',
      mode: json['mode'] as String? ?? 'Battle Royale',
      dateText: json['dateText'] as String? ?? '',
      currentPlayers: json['currentPlayers'] as int? ?? 0,
      maxPlayers: json['maxPlayers'] as int? ?? 64,
      prizePool: json['prizePool'] as String? ?? '',
      entryFee: json['entryFee'] as String? ?? 'Free',
      statusText: json['statusText'] as String? ?? 'UPCOMING',
      timerDuration: Duration(seconds: timerSeconds.toInt()),
      startsAt: _parseDateTime(json['starts_at']),
      createdAt: _parseDateTime(json['created_at']),
      rounds: parsedRounds,
      prizeDistribution: prizeDistribution,
      stage: json['stage'] as String?,
      logoAsset: json['logoAsset'] as String?,
      customSettings: customSettings,
      createdBy: json['createdBy'] as int?,
      creatorName: json['creatorName'] as String?,
      creatorAvatar: json['creatorAvatar'] as String?,
      resultsPendingReview: json['resultsPendingReview'] as bool? ?? false,
      resultsLocked: json['resultsLocked'] as bool? ?? false,
      chatOpen: json['chatOpen'] as bool? ?? true,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) return null;
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }
}

class RecentMatch {
  final int? id;
  final String title;
  final String type;
  final String dateText;
  final String rankString;
  final String killsText;
  final String? logoAsset;

  RecentMatch({
    this.id,
    required this.title,
    required this.type,
    required this.dateText,
    required this.rankString,
    required this.killsText,
    this.logoAsset,
  });

  factory RecentMatch.fromJson(Map<String, dynamic> json) {
    return RecentMatch(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'Squad',
      dateText: json['dateText'] as String? ?? '',
      rankString: json['rankString'] as String? ?? '-',
      killsText: json['killsText'] as String? ?? '0',
      logoAsset: json['logoAsset'] as String?,
    );
  }
}
