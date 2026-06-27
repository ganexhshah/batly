import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class UserService {
  static Future<Map<String, dynamic>> getPublicProfile(int userId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.apiUrl}/users/$userId'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }
    throw Exception(data['message'] ?? 'Failed to load profile');
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
