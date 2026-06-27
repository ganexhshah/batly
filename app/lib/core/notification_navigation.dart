import 'package:flutter/material.dart';

import '../screens/tournament/tournament_screen.dart';
import '../services/api_service.dart';

/// Parses `tournament:{id}` deep links from push/in-app notifications.
int? parseTournamentDeepLink(String? deepLink) {
  if (deepLink == null || deepLink.isEmpty) return null;
  const prefix = 'tournament:';
  if (!deepLink.startsWith(prefix)) return null;
  return int.tryParse(deepLink.substring(prefix.length).trim());
}

/// Opens a tournament screen from a notification deep link.
Future<void> openTournamentDeepLink(BuildContext context, String? deepLink) async {
  final tournamentId = parseTournamentDeepLink(deepLink);
  if (tournamentId == null || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
      ),
    ),
  );

  try {
    final tournament = await ApiService.getTournament(tournamentId);
    if (!context.mounted) return;
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentScreen(tournament: tournament),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE53935),
        content: Text('Could not open tournament: $e'),
      ),
    );
  }
}

bool isNotificationImageUrl(String? deepLink) {
  if (deepLink == null) return false;
  return deepLink.startsWith('http://') || deepLink.startsWith('https://');
}
