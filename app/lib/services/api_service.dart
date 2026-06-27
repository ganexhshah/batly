import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'app_http_client.dart';
import 'local_cache.dart';
import '../core/cache_debug.dart';
import '../core/json_parse.dart';
import '../models/app_models.dart';
import '../models/match_flow_state.dart';

/// Cached home screen snapshot for instant paint.
class HomeDataSnapshot {
  const HomeDataSnapshot({
    required this.banners,
    required this.upcoming,
    required this.matches,
  });

  final List<FeaturedTournament> banners;
  final List<UpcomingTournament> upcoming;
  final List<RecentMatch> matches;

  bool get isEmpty => banners.isEmpty && upcoming.isEmpty && matches.isEmpty;
}

/// ApiService fetches real data from the Battly Laravel backend.
///
/// Uses a stale-while-revalidate cache via SharedPreferences:
///  - On first call, returns cached data instantly (if available)
///  - Simultaneously fetches fresh data in the background
///  - Next call gets the fresh data from cache
class ApiService {
  // ── Cache Keys ─────────────────────────────────────────────────────
  static const _kFeaturedKey  = 'cache_featured_tournaments';
  static const _kUpcomingKey  = 'cache_upcoming_tournaments';
  static const _kMatchesKey   = 'cache_recent_matches';
  static const _kBannersKey   = 'cache_home_banners';
  static const _kLobbyChatsKey = 'cache_lobby_chats';

  static bool _refreshingHome = false;

  /// Remove all user-scoped response caches (call on logout / account switch).
  static Future<void> clearUserCache() async {
    _refreshingHome = false;
    await Future.wait([
      LocalCache.remove(_kFeaturedKey),
      LocalCache.remove(_kUpcomingKey),
      LocalCache.remove(_kMatchesKey),
      LocalCache.remove(_kBannersKey),
      LocalCache.remove(_kLobbyChatsKey),
      LocalCache.remove('dismissed_popup_ids'),
    ]);
  }

  // ── Local Cache Helpers ────────────────────────────────────────────

  static Future<String?> _readCache(String key) => LocalCache.read(key);

  static Future<void> _writeCache(String key, String value) => LocalCache.write(key, value);

  /// Return cached home data instantly (memory/disk). No network.
  static Future<HomeDataSnapshot?> peekHomeData() async {
    final results = await Future.wait([
      _readCache(_kBannersKey),
      _readCache(_kUpcomingKey),
      _readCache(_kMatchesKey),
    ]);
    final bannersRaw = results[0];
    final upcomingRaw = results[1];
    final matchesRaw = results[2];
    if (bannersRaw == null && upcomingRaw == null && matchesRaw == null) {
      return null;
    }
    return HomeDataSnapshot(
      banners: bannersRaw != null ? _parseBanners(bannersRaw) : const [],
      upcoming: upcomingRaw != null ? _parseUpcoming(upcomingRaw) : const [],
      matches: matchesRaw != null ? _parseMatches(matchesRaw) : const [],
    );
  }

  /// Cached upcoming tournaments only — instant tournaments tab paint.
  static Future<List<UpcomingTournament>> peekUpcomingTournaments() async {
    final cached = await _readCache(_kUpcomingKey);
    if (cached == null) return const [];
    return _parseUpcoming(cached);
  }

  /// Prefetch core home feeds in parallel (call after login / on app open).
  static Future<void> warmHomeCache() async {
    if (_refreshingHome) return;
    _refreshingHome = true;
    try {
      await Future.wait([
        _fetchBanners(),
        _fetchUpcoming(),
        _fetchMatches(),
      ], eagerError: false);
    } catch (e, st) {
      logCacheRefreshFailure('warmHomeCache', e, st);
    } finally {
      _refreshingHome = false;
    }
  }

  // ── Banners ────────────────────────────────────────────────────────

  /// Fetch home screen banners — returns cached data instantly,
  /// refreshes cache in background.
  static Future<List<FeaturedTournament>> getBanners() async {
    final cached = await _readCache(_kBannersKey);
    if (cached != null) {
      // Return cache immediately, refresh in background
      _refreshBanners();
      return _parseBanners(cached);
    }
    // No cache — fetch fresh (first launch)
    return await _fetchBanners();
  }

  static Future<List<FeaturedTournament>> _fetchBanners() async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/banners'),
      headers: await _headers(),
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      await _writeCache(_kBannersKey, response.body);
      return _parseBanners(response.body);
    }
    throw Exception('Failed to load banners: ${response.statusCode}');
  }

  static Future<void> _refreshBanners() async {
    try {
      await _fetchBanners();
    } catch (e, st) {
      logCacheRefreshFailure('banners', e, st);
    }
  }

  static List<FeaturedTournament> _parseBanners(String body) {
    try {
      final data = jsonDecode(body);
      final rawList = data['banners'];
      final list = rawList is List ? rawList : [];
      return list.map((json) => FeaturedTournament.fromJson(json)).toList();
    } catch (e, st) {
      logCacheRefreshFailure('parseBanners', e, st);
      return [];
    }
  }

  // ── Tournaments ────────────────────────────────────────────────────

  /// Fetch featured tournaments — returns cached data instantly,
  /// refreshes cache in background.
  static Future<List<FeaturedTournament>> getFeaturedTournaments() async {
    final cached = await _readCache(_kFeaturedKey);
    if (cached != null) {
      // Return cache immediately, refresh in background
      _refreshFeatured();
      return _parseFeatured(cached);
    }
    // No cache — fetch fresh (first launch)
    return await _fetchFeatured();
  }

  static Future<List<FeaturedTournament>> _fetchFeatured() async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments/featured'),
      headers: await _headers(),
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      await _writeCache(_kFeaturedKey, response.body);
      return _parseFeatured(response.body);
    }
    throw Exception('Failed to load featured tournaments: ${response.statusCode}');
  }

  static Future<void> _refreshFeatured() async {
    try {
      await _fetchFeatured();
    } catch (e, st) {
      logCacheRefreshFailure('featured', e, st);
    }
  }

  static List<FeaturedTournament> _parseFeatured(String body) {
    try {
      final data = jsonDecode(body);
      final rawList = data['tournaments'];
      final list = rawList is List ? rawList : [];
      return list.map((json) => FeaturedTournament.fromJson(json)).toList();
    } catch (e, st) {
      logCacheRefreshFailure('parseFeatured', e, st);
      return [];
    }
  }

  /// Fetch upcoming tournaments with stale-while-revalidate.
  static Future<List<UpcomingTournament>> getUpcomingTournaments() async {
    final cached = await _readCache(_kUpcomingKey);
    if (cached != null) {
      _refreshUpcoming();
      return _parseUpcoming(cached);
    }
    return await _fetchUpcoming();
  }

  static Future<List<UpcomingTournament>> _fetchUpcoming() async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments'),
      headers: await _headers(),
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      await _writeCache(_kUpcomingKey, response.body);
      return _parseUpcoming(response.body);
    }
    throw Exception('Failed to load tournaments: ${response.statusCode}');
  }

  static Future<List<UpcomingTournament>> getTournamentsByStatus(String status) async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments').replace(queryParameters: {'status': status}),
      headers: await _headers(),
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      return _parseUpcoming(response.body);
    }
    throw Exception('Failed to load $status tournaments: ${response.statusCode}');
  }

  static Future<void> _refreshUpcoming() async {
    try {
      await _fetchUpcoming();
    } catch (e, st) {
      logCacheRefreshFailure('upcoming', e, st);
    }
  }

  static List<UpcomingTournament> _parseUpcoming(String body) {
    try {
      final data = jsonDecode(body);
      final rawList = data['tournaments'];
      final list = rawList is List ? rawList : [];
      return list.map((json) => UpcomingTournament.fromJson(json)).toList();
    } catch (e, st) {
      logCacheRefreshFailure('parseUpcoming', e, st);
      return [];
    }
  }

  /// Fetch a single tournament details by ID.
  static Future<UpcomingTournament> getTournament(int id) async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments/$id'),
      headers: await _headers(),
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UpcomingTournament.fromJson(data['tournament']);
    }
    throw Exception('Failed to load tournament: ${response.statusCode}');
  }

  /// Fetch tournament details including participants and user registration status.
  static Future<Map<String, dynamic>> getTournamentDetails(int id) async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments/$id'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final matchFlow = MatchFlowState.fromJson(
        data['match_flow'] as Map<String, dynamic>?,
      );
      return {
        'tournament': UpcomingTournament.fromJson(data['tournament']),
        'participants': parseParticipantList(data['participants']),
        'is_registered': _readApiBool(data['is_registered']),
        'is_owner': _readApiBool(data['is_owner']),
        'registration': TournamentRegistrationMeta.fromJson(
          data['registration'] as Map<String, dynamic>?,
        ),
        'match_flow': matchFlow,
      };
    }
    throw Exception('Failed to load tournament details: ${response.statusCode}');
  }

  /// Create a tournament/match with custom settings on the backend.
  static Future<UpcomingTournament> createTournament(Map<String, dynamic> tournamentData) async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/tournaments'),
      headers: headers,
      body: jsonEncode(tournamentData),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return UpcomingTournament.fromJson(data['tournament']);
    }
    throw Exception(data['message'] ?? 'Failed to create match: ${response.statusCode}');
  }

  // ── Tournament Management (owner only) ────────────────────────────

  /// Remove a participant from the tournament.
  static Future<Map<String, dynamic>> removeParticipant(int tournamentId, int userId) async {
    try {
      final headers = await _authHeaders();
      final response = await AppHttpClient.instance.delete(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/participants/$userId'),
        headers: headers,
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update the room ID and password for a tournament.
  static Future<Map<String, dynamic>> updateRoomCode(
    int tournamentId, {
    String? roomId,
    String? roomPassword,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{};
      if (roomId != null) body['room_id'] = roomId;
      if (roomPassword != null) body['room_password'] = roomPassword;
      final response = await AppHttpClient.instance.patch(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/room-code'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'tournament': data['tournament'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update the status of a tournament.
  static Future<Map<String, dynamic>> updateTournamentStatus(
    int tournamentId,
    String status,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await AppHttpClient.instance.patch(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/status'),
        headers: headers,
        body: jsonEncode({'status': status}),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'tournament': data['tournament'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ── Matches ────────────────────────────────────────────────────────

  /// Fetch the authenticated user's recent match history.
  static Future<List<RecentMatch>> getRecentMatches() async {
    final cached = await _readCache(_kMatchesKey);
    if (cached != null) {
      _refreshMatches();
      return _parseMatches(cached);
    }
    return await _fetchMatches();
  }

  static Future<List<RecentMatch>> _fetchMatches() async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/matches'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      await _writeCache(_kMatchesKey, response.body);
      return _parseMatches(response.body);
    }
    throw Exception('Failed to load recent matches: ${response.statusCode}');
  }

  static Future<void> _refreshMatches() async {
    try {
      await _fetchMatches();
    } catch (e, st) {
      logCacheRefreshFailure('matches', e, st);
    }
  }

  static List<RecentMatch> _parseMatches(String body) {
    try {
      final data = jsonDecode(body);
      final rawList = data['matches'];
      final list = rawList is List ? rawList : [];
      return list.map((json) => RecentMatch.fromJson(json)).toList();
    } catch (e, st) {
      logCacheRefreshFailure('parseMatches', e, st);
      return [];
    }
  }

  static Future<Map<String, dynamic>> getTournamentResults(int tournamentId) async {
    try {
      final response = await AppHttpClient.instance.get(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/results'),
        headers: await _authHeaders(),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data as Map<String, dynamic>;
      }
      throw Exception(data['message'] ?? 'Failed to load results');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> publishTournamentResults(
    int tournamentId,
    List<Map<String, dynamic>> results,
  ) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/publish-results'),
        headers: await _authHeaders(),
        body: jsonEncode({'results': results}),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'tournament': data['tournament'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> submitMatchResult({
    required int tournamentId,
    required int rank,
    required int kills,
    required int points,
    required String roundName,
    required String mapName,
    required String roundTime,
    List<String> proofImages = const [],
    List<Map<String, dynamic>> proofFiles = const [],
    String? notes,
  }) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/submit-result');
    final token = await AuthService.getToken();

    if (proofFiles.isNotEmpty) {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields['rank'] = rank.toString();
      request.fields['kills'] = kills.toString();
      request.fields['points'] = points.toString();
      request.fields['round_name'] = roundName;
      request.fields['map_name'] = mapName;
      request.fields['round_time'] = roundTime;
      if (notes != null) request.fields['notes'] = notes;

      for (var i = 0; i < proofFiles.length; i++) {
        final file = proofFiles[i];
        final bytes = file['bytes'] as List<int>?;
        if (bytes == null || bytes.isEmpty) continue;
        request.files.add(http.MultipartFile.fromBytes(
          'proof_files[]',
          bytes,
          filename: file['filename'] as String? ?? 'proof-$i.jpg',
        ));
      }

      final streamed = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data as Map<String, dynamic>;
      }
      throw Exception(data['message'] ?? 'Failed to submit result');
    }

    final response = await AppHttpClient.instance.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({
        'rank': rank,
        'kills': kills,
        'points': points,
        'round_name': roundName,
        'map_name': mapName,
        'round_time': roundTime,
        'proof_images': proofImages,
        if (notes != null) 'notes': notes,
      }),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to submit result');
  }

  static Future<Map<String, dynamic>> getMatchVerificationStatus(int matchId) async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/matches/$matchId/verification-status'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to load verification status');
  }

  static Future<void> registerFcmToken(String token) async {
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/user/fcm-token'),
      headers: await _authHeaders(),
      body: jsonEncode({'token': token}),
    ).timeout(ApiConfig.timeout);

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to register FCM token');
    }
  }

  static Future<List<Map<String, dynamic>>> getSupportTickets() async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/support/tickets'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final tickets = data['tickets'];
      if (tickets is List) {
        return tickets.map((t) => Map<String, dynamic>.from(t as Map)).toList();
      }
      return const [];
    }
    throw Exception(data['message'] ?? 'Failed to load support tickets');
  }

  static Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String message,
    String category = 'general',
  }) async {
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/support/tickets'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'subject': subject,
        'message': message,
        'category': category,
      }),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to submit support ticket');
  }

  // ── Force Refresh (called on pull-to-refresh) ──────────────────────

  /// Bypass cache and fetch fresh data from the server.
  static Future<List<FeaturedTournament>> forceBanners() => _fetchBanners();

  static Future<List<FeaturedTournament>> forceFeaturedTournaments() =>
      _fetchFeatured();

  static Future<List<UpcomingTournament>> forceUpcomingTournaments() =>
      _fetchUpcoming();

  static Future<List<RecentMatch>> forceRecentMatches() => _fetchMatches();

  // ── Tournament Registration & Integrity ──────────────────────────

  static Future<Map<String, dynamic>> leaveTournament(int tournamentId) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/leave'),
        headers: await _authHeaders(),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> setTournamentReady(int tournamentId, {required bool ready}) async {
    try {
      final response = await AppHttpClient.instance.patch(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/ready'),
        headers: await _authHeaders(),
        body: jsonEncode({'ready': ready}),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'is_ready': data['is_ready'] as bool? ?? ready,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getReadyStatus(int tournamentId) async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/ready-status'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }
    throw Exception(data['message'] ?? 'Failed to load ready status');
  }

  // ── Custom match flow ───────────────────────────────────────────────

  static Future<MatchFlowState> getMatchFlow(int tournamentId) async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/match-flow'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return MatchFlowState.fromJson(data['match_flow'] as Map<String, dynamic>?);
    }
    throw Exception(data['message'] ?? 'Failed to load match flow');
  }

  static Future<Map<String, dynamic>> _matchFlowPost(
    int tournamentId,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/match-flow/$action'),
        headers: await _authHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'match_flow': MatchFlowState.fromJson(data['match_flow'] as Map<String, dynamic>?),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
        'match_flow': const MatchFlowState(),
      };
    }
  }

  static Future<Map<String, dynamic>> confirmInGame(int tournamentId) =>
      _matchFlowPost(tournamentId, 'confirm-in-game');

  static Future<Map<String, dynamic>> stopMatchFlow(int tournamentId) =>
      _matchFlowPost(tournamentId, 'stop');

  static Future<Map<String, dynamic>> acknowledgeMatchStop(int tournamentId) =>
      _matchFlowPost(tournamentId, 'acknowledge-stop');

  static Future<Map<String, dynamic>> voteMatchWinner(
    int tournamentId, {
    required String claim,
  }) =>
      _matchFlowPost(tournamentId, 'vote-winner', body: {'claim': claim});

  static Future<Map<String, dynamic>> submitMatchFlowProof(
    int tournamentId,
    List<String> proofUrls,
  ) =>
      _matchFlowPost(tournamentId, 'submit-proof', body: {'proof_urls': proofUrls});

  static Future<Map<String, dynamic>> getTeamInvites(int tournamentId) async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/team-invites'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }
    throw Exception(data['message'] ?? 'Failed to load team invites');
  }

  static Future<Map<String, dynamic>> sendTeamInvite(int tournamentId, int inviteeId) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/team-invites'),
        headers: await _authHeaders(),
        body: jsonEncode({'invitee_id': inviteeId}),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> respondTeamInvite(
    int tournamentId,
    int inviteId,
    String action,
  ) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/team-invites/$inviteId/respond'),
        headers: await _authHeaders(),
        body: jsonEncode({'action': action}),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> searchPlayers(String query) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}/wallet/search-recipient')
        .replace(queryParameters: {'query': query});
    final response = await AppHttpClient.instance.get(uri, headers: await _authHeaders()).timeout(ApiConfig.timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['users'] ?? []);
    }
    return [];
  }

  static Future<Map<String, dynamic>> raiseDispute(
    int tournamentId, {
    required String type,
    required String reason,
    int? gameMatchId,
    List<String> proofImages = const [],
  }) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/disputes'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'type': type,
          'reason': reason,
          if (gameMatchId != null) 'game_match_id': gameMatchId,
          'proof_images': proofImages,
        }),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> reportPlayer(
    int tournamentId, {
    required int reportedUserId,
    required String reason,
    List<String> proofImages = const [],
  }) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/reports'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'reported_user_id': reportedUserId,
          'reason': reason,
          'proof_images': proofImages,
        }),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> cancelUnderfilled(
    int tournamentId, {
    int minPlayers = 2,
  }) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/cancel-underfilled'),
        headers: await _authHeaders(),
        body: jsonEncode({'min_players': minPlayers}),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'tournament': data['tournament'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Register the current user for a tournament.
  static Future<Map<String, dynamic>> registerForTournament(int tournamentId) async {
    try {
      final headers = await _authHeaders();
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/register'),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);
      final message = data['message'] as String? ?? 'Unknown error';
      final alreadyRegistered = response.statusCode == 409 ||
          message.toLowerCase().contains('already registered');
      return {
        'success': response.statusCode == 200 || alreadyRegistered,
        'alreadyRegistered': alreadyRegistered,
        'message': message,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ── Tournament Chat ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMyLobbyChats() async {
    final cached = await _readCache(_kLobbyChatsKey);
    if (cached != null) {
      _refreshLobbyChats();
      return _parseLobbyChats(cached);
    }
    return _fetchLobbyChats();
  }

  static Future<List<Map<String, dynamic>>> _fetchLobbyChats() async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments/my/lobby-chats'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await _writeCache(_kLobbyChatsKey, response.body);
      return List<Map<String, dynamic>>.from(data['lobby_chats'] ?? []);
    }
    throw Exception(data['message'] ?? 'Failed to load lobby chats');
  }

  static Future<void> _refreshLobbyChats() async {
    try {
      await _fetchLobbyChats();
    } catch (e, st) {
      logCacheRefreshFailure('lobbyChats', e, st);
    }
  }

  static List<Map<String, dynamic>> _parseLobbyChats(String body) {
    try {
      final data = jsonDecode(body);
      return List<Map<String, dynamic>>.from(data['lobby_chats'] ?? []);
    } catch (e, st) {
      logCacheRefreshFailure('parseLobbyChats', e, st);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> peekLobbyChats() async {
    final cached = await _readCache(_kLobbyChatsKey);
    if (cached == null) return const [];
    return _parseLobbyChats(cached);
  }

  static Future<Map<String, dynamic>> getTournamentChatStatus(int tournamentId) async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/chat/status'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }
    throw Exception(data['message'] ?? 'Failed to load chat status');
  }

  static Future<Map<String, dynamic>> getTournamentChatMessages(int tournamentId) async {
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/chat/messages'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }
    throw Exception(data['message'] ?? 'Failed to load chat messages');
  }

  static Future<Map<String, dynamic>> sendTournamentChatMessage(
    int tournamentId, {
    String? body,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/tournaments/$tournamentId/chat/messages');
      final token = await AuthService.getToken();

      if (imageBytes != null && imageBytes.isNotEmpty) {
        final request = http.MultipartRequest('POST', uri);
        request.headers['Accept'] = 'application/json';
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        final trimmedBody = body?.trim();
        if (trimmedBody != null && trimmedBody.isNotEmpty) {
          request.fields['body'] = trimmedBody;
        }
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageFilename ?? 'chat-image.jpg',
        ));

        final streamed = await request.send().timeout(ApiConfig.timeout);
        final response = await http.Response.fromStream(streamed);
        final data = jsonDecode(response.body);
        return {
          'success': response.statusCode == 201,
          'message': data['message'] is Map ? data['message'] : data,
          'error': data['message'] is String ? data['message'] : null,
        };
      }

      final text = body?.trim() ?? '';
      final response = await AppHttpClient.instance.post(
        uri,
        headers: await _authHeaders(),
        body: jsonEncode({'body': text}),
      ).timeout(ApiConfig.timeout);
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] is Map ? data['message'] : data,
        'error': data['message'] is String ? data['message'] : null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ── Notifications ──────────────────────────────────────────────────

  /// Fetch notifications from the backend.
  static Future<List<dynamic>> getNotifications() async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/notifications'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rawNotifications = data['notifications'];
      return rawNotifications is List ? rawNotifications : [];
    }
    throw Exception('Failed to load notifications: ${response.statusCode}');
  }

  /// Mark all notifications as read.
  static Future<void> markNotificationsRead() async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/notifications/mark-read'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notifications as read: ${response.statusCode}');
    }
  }

  /// Mark a single notification as read.
  static Future<void> markNotificationRead(int notificationId) async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/notifications/$notificationId/mark-read'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification read: ${response.statusCode}');
    }
  }

  // ── Headers ────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers() async {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static bool _readApiBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }
}
