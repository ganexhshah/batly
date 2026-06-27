class PrizeDistributionSlot {
  final int rank;
  final String label;
  final String share;
  final double amount;
  final String color;

  const PrizeDistributionSlot({
    required this.rank,
    required this.label,
    required this.share,
    required this.amount,
    required this.color,
  });

  factory PrizeDistributionSlot.fromJson(Map<String, dynamic> json) {
    return PrizeDistributionSlot(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      share: json['share'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      color: json['color'] as String? ?? '#FFD700',
    );
  }
}

class PrizeDistributionInfo {
  final String type;
  final String label;
  final String description;
  final String? matchFormat;
  final String? roomType;
  final double totalPool;
  final double entryFee;
  final int maxPlayers;
  final List<PrizeDistributionSlot> slots;

  const PrizeDistributionInfo({
    required this.type,
    required this.label,
    required this.description,
    this.matchFormat,
    this.roomType,
    required this.totalPool,
    required this.entryFee,
    required this.maxPlayers,
    required this.slots,
  });

  bool get isWinnerTakesAll => type == 'winner_takes_all';

  bool get isClassicTop3 => type == 'classic_top3';

  factory PrizeDistributionInfo.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    final slots = rawSlots is List
        ? rawSlots
            .whereType<Map>()
            .map((s) => PrizeDistributionSlot.fromJson(Map<String, dynamic>.from(s)))
            .toList()
        : <PrizeDistributionSlot>[];

    return PrizeDistributionInfo(
      type: json['type'] as String? ?? 'classic_top3',
      label: json['label'] as String? ?? 'Classic Top 3',
      description: json['description'] as String? ?? '',
      matchFormat: json['matchFormat'] as String?,
      roomType: json['roomType'] as String?,
      totalPool: (json['totalPool'] as num?)?.toDouble() ?? 0,
      entryFee: (json['entryFee'] as num?)?.toDouble() ?? 0,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 0,
      slots: slots,
    );
  }

  /// Client-side fallback when API has not refreshed yet.
  factory PrizeDistributionInfo.fallback({
    required String prizePoolText,
    required String entryFeeText,
    required int maxPlayers,
    Map<String, dynamic>? customSettings,
    String? stage,
  }) {
    String? matchFormat = customSettings?['team_size'] as String?;
    if (matchFormat == null && stage != null) {
      final match = RegExp(r'\[(1v1|2v2|3v3|4v4|1v2)\]').firstMatch(stage);
      matchFormat = match?.group(1);
    }

    final type = customSettings?['prize_distribution'] as String? ??
        (matchFormat != null ? 'winner_takes_all' : 'classic_top3');

    final pool = double.tryParse(prizePoolText.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final entry = double.tryParse(entryFeeText.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    List<PrizeDistributionSlot> slots;
    String label;
    String description;

    if (type == 'winner_takes_all') {
      label = 'Winner Takes All';
      description = matchFormat != null
          ? 'Custom $matchFormat match — the winner receives the full prize pool.'
          : 'Custom match — the winner receives the full prize pool.';
      slots = [
        PrizeDistributionSlot(
          rank: 1,
          label: 'Match Winner',
          share: '100% Pool',
          amount: pool,
          color: '#FFD700',
        ),
      ];
    } else {
      label = 'Classic Top 3';
      description = 'Classic squad tournament — prizes split among top 3 (50% / 30% / 20%).';
      slots = [
        PrizeDistributionSlot(rank: 1, label: '1st Place Champion', share: '50% Pool', amount: pool * 0.5, color: '#FFD700'),
        PrizeDistributionSlot(rank: 2, label: '2nd Place Runner-up', share: '30% Pool', amount: pool * 0.3, color: '#C0C0C0'),
        PrizeDistributionSlot(rank: 3, label: '3rd Place Finalist', share: '20% Pool', amount: pool * 0.2, color: '#CD7F32'),
      ];
    }

    return PrizeDistributionInfo(
      type: type,
      label: label,
      description: description,
      matchFormat: matchFormat,
      roomType: customSettings?['room_type'] as String?,
      totalPool: pool,
      entryFee: entry,
      maxPlayers: maxPlayers,
      slots: slots,
    );
  }

  static String formatAmount(double amount) {
    if (amount <= 0) return 'TBD';
    final whole = amount.round().toString();
    return 'NPR ${whole.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}
