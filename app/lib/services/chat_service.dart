import 'dart:convert';
import 'api_config.dart';
import 'auth_service.dart';
import 'app_http_client.dart';
import 'local_cache.dart';
import '../core/cache_debug.dart';

class ChatService {
  static const _kConversationsKey = 'cache_conversations';

  static Future<List<Map<String, dynamic>>> getConversations() async {
    final cached = await LocalCache.read(_kConversationsKey);
    if (cached != null) {
      _refreshConversations();
      return _parseConversations(cached);
    }
    return _fetchConversations();
  }

  static Future<List<Map<String, dynamic>>> _fetchConversations() async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/conversations'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      await LocalCache.write(_kConversationsKey, response.body);
      return _parseConversations(response.body);
    }
    throw Exception('Failed to load conversations');
  }

  static Future<void> _refreshConversations() async {
    try {
      await _fetchConversations();
    } catch (e, st) {
      logCacheRefreshFailure('conversations', e, st);
    }
  }

  static List<Map<String, dynamic>> _parseConversations(String body) {
    try {
      final data = jsonDecode(body);
      return List<Map<String, dynamic>>.from(data['conversations'] ?? []);
    } catch (e, st) {
      logCacheRefreshFailure('parseConversations', e, st);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> peekConversations() async {
    final cached = await LocalCache.read(_kConversationsKey);
    if (cached == null) return const [];
    return _parseConversations(cached);
  }

  static Future<Map<String, dynamic>> startConversation(int recipientId) async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/conversations'),
      headers: headers,
      body: jsonEncode({'recipient_id': recipientId}),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data['conversation'] as Map);
    }
    throw Exception(data['message'] ?? 'Failed to start conversation');
  }

  static Future<List<Map<String, dynamic>>> getMessages(int conversationId) async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/conversations/$conversationId/messages'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['messages'] ?? []);
    }
    throw Exception('Failed to load messages');
  }

  static Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required String body,
  }) async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/conversations/$conversationId/messages'),
      headers: headers,
      body: jsonEncode({'body': body}),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(data['message'] as Map);
    }
    throw Exception(data['message'] ?? 'Failed to send message');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
