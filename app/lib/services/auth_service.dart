import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_http_client.dart';
import 'local_cache.dart';
import 'wallet_service.dart';
import '../core/auth_errors.dart';
import '../firebase_options.dart';

/// AuthService handles user authentication against the Battly Laravel backend.
///
/// Stores the API token in SharedPreferences for persistence across app restarts.
class AuthService {
  static const String _tokenKey = 'battly_auth_token';
  static const String _userKey = 'battly_user_data';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? DefaultFirebaseOptions.googleWebClientId : null,
  );

  static String? _cachedToken;
  static Map<String, dynamic>? _cachedUser;

  // ── Token Management ─────────────────────────────────────────────

  /// Get the stored auth token, or null if not logged in.
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final stored = await LocalCache.readSecure(_tokenKey);
    _cachedToken = stored;
    return stored;
  }

  /// Check if the user is currently logged in (has a stored token).
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Store the auth token after login/register.
  static Future<void> _saveToken(String token) async {
    _cachedToken = token;
    await LocalCache.writeSecure(_tokenKey, token);
  }

  /// Store user data locally for quick access.
  static Future<void> _saveUserData(Map<String, dynamic> user) async {
    _cachedUser = user;
    await LocalCache.write(_userKey, jsonEncode(user));
  }

  /// Parse user id from API maps or raw id values (int, num, or string).
  static int? parseUserId(dynamic value) {
    if (value is Map<String, dynamic>) {
      value = value['id'];
    }
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Get cached user data without making an API call.
  static Future<Map<String, dynamic>?> getCachedUser() async {
    if (_cachedUser != null) return _cachedUser;
    final data = await LocalCache.read(_userKey);
    if (data == null) return null;
    _cachedUser = jsonDecode(data) as Map<String, dynamic>;
    return _cachedUser;
  }

  /// Clear all auth data (logout) and user-scoped disk caches.
  static Future<void> _clearAuth() async {
    _cachedToken = null;
    _cachedUser = null;
    await LocalCache.removeSecure(_tokenKey);
    await LocalCache.remove(_userKey);
    await ApiService.clearUserCache();
    await WalletService.invalidateCache();
    LocalCache.clearMemory();
  }

  /// True when an API response indicates the session is no longer valid.
  static bool isAuthFailure(int? statusCode, [Object? error]) {
    if (AuthErrors.isAuthStatusCode(statusCode)) return true;
    if (error != null && AuthErrors.isAuthException(error)) return true;
    return false;
  }

  static Future<void> _onAuthSuccess() async {
    unawaited(ApiService.warmHomeCache());
  }

  // ── Auth Headers ──────────────────────────────────────────────────

  /// Build headers with auth token for authenticated requests.
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── API Calls ─────────────────────────────────────────────────────

  /// Register a new user account.
  ///
  /// Returns a map with 'success' (bool), 'user' (map), and optionally 'error' (string).
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? ign,
    String? gameUid,
    String? avatarUrl,
  }) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'ign': ign,
          'game_uid': gameUid,
          'avatar_url': avatarUrl,
        }),
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await _saveToken(data['token']);
        await _saveUserData(data['user']);
        await _onAuthSuccess();
        return {'success': true, 'user': data['user']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Registration failed',
          'errors': data['errors'],
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Login with email and password.
  ///
  /// Returns a map with 'success' (bool), 'user' (map), and optionally 'error' (string).
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveToken(data['token']);
        await _saveUserData(data['user']);
        await _onAuthSuccess();
        return {'success': true, 'user': data['user']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get the authenticated user's profile from the API.
  static Future<Map<String, dynamic>?> getUser() async {
    try {
      final headers = await _authHeaders();
      final response = await AppHttpClient.instance.get(
        Uri.parse('${ApiConfig.apiUrl}/user'),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveUserData(data['user']);
        return data['user'];
      }
      if (AuthErrors.isAuthStatusCode(response.statusCode)) {
        await _clearAuth();
        return null;
      }
      return null;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('network') ||
          message.contains('timeout') ||
          message.contains('connection') ||
          message.contains('socket')) {
        return getCachedUser();
      }
      return null;
    }
  }

  /// Update the user's profile.
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? ign,
    String? gameUid,
    String? avatarUrl,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (ign != null) body['ign'] = ign;
      if (gameUid != null) body['game_uid'] = gameUid;
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;

      final response = await AppHttpClient.instance.put(
        Uri.parse('${ApiConfig.apiUrl}/user'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveUserData(data['user']);
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'error': data['message'] ?? 'Update failed'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Sign in with Google and authenticate with the Battly backend.
  ///
  /// This handles both sign-up and sign-in — the backend will create a new
  /// account if the Google user does not already exist, or return the existing
  /// user if they do.
  ///
  /// Returns a map with 'success' (bool), 'user' (map), and optionally 'error' (string).
  static Future<Map<String, dynamic>> loginWithGoogle() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      return {
        'success': false,
        'error': 'Google Sign-In is not configured for this platform. '
            'Run flutterfire configure or use email login.',
      };
    }
    try {
      if (kIsWeb) {
        return _loginWithGoogleWeb();
      }
      return _loginWithGoogleMobile();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user') {
        return {'success': false, 'error': 'Google Sign-In was cancelled'};
      }
      return {'success': false, 'error': 'Firebase error: ${e.message}'};
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Backend not reachable at ${ApiConfig.baseUrl}. If you are using a real phone, run with --dart-define=BATTLY_API_BASE_URL=http://YOUR_PC_IP:8888',
      };
    } catch (e) {
      return {'success': false, 'error': 'Google Sign-In error: $e'};
    }
  }

  /// Web uses Firebase popup auth so localhost does not need to be added to
  /// the Google OAuth client's authorized origins (only Firebase authorized domains).
  static Future<Map<String, dynamic>> _loginWithGoogleWeb() async {
    final userCredential = await FirebaseAuth.instance.signInWithPopup(
      GoogleAuthProvider(),
    );
    final user = userCredential.user;

    if (user == null) {
      return {'success': false, 'error': 'Google Sign-In was cancelled'};
    }

    final firebaseIdToken = await user.getIdToken();
    if (firebaseIdToken == null) {
      return {'success': false, 'error': 'Failed to get Firebase ID token'};
    }

    final googleId = user.providerData
        .where((profile) => profile.providerId == 'google.com')
        .map((profile) => profile.uid)
        .firstWhere(
          (uid) => uid != null && uid.isNotEmpty,
          orElse: () => user.uid,
        )!;

    return _completeGoogleBackendLogin(
      firebaseToken: firebaseIdToken,
      name: user.displayName ??
          user.email?.split('@').first ??
          'BattlyWarrior',
      email: user.email ?? '',
      googleId: googleId,
      avatarUrl: user.photoURL,
    );
  }

  static Future<Map<String, dynamic>> _loginWithGoogleMobile() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      return {'success': false, 'error': 'Google Sign-In was cancelled'};
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential firebaseResult =
        await FirebaseAuth.instance.signInWithCredential(credential);

    final String? firebaseIdToken = await firebaseResult.user?.getIdToken();

    if (firebaseIdToken == null) {
      return {'success': false, 'error': 'Failed to get Firebase ID token'};
    }

    return _completeGoogleBackendLogin(
      firebaseToken: firebaseIdToken,
      name: googleUser.displayName ?? googleUser.email.split('@').first,
      email: googleUser.email,
      googleId: googleUser.id,
      avatarUrl: googleUser.photoUrl,
    );
  }

  static Future<Map<String, dynamic>> _completeGoogleBackendLogin({
    required String firebaseToken,
    required String name,
    required String email,
    required String googleId,
    String? avatarUrl,
  }) async {
    try {
      final response = await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/auth/google'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'firebase_token': firebaseToken,
          'name': name,
          'email': email,
          'google_id': googleId,
          'avatar_url': avatarUrl,
        }),
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _saveToken(data['token']);
        await _saveUserData(data['user']);
        await _onAuthSuccess();
        return {'success': true, 'user': data['user']};
      }

      return {
        'success': false,
        'error': data['message'] ?? 'Google authentication failed',
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': kIsWeb
            ? 'Backend timeout at ${ApiConfig.baseUrl}. Start the API with: cd backend && docker compose up -d'
            : 'Backend timeout at ${ApiConfig.baseUrl}. Check phone and PC are on the same Wi-Fi and allow Windows Firewall port 8888.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Backend auth error: $e'};
    }
  }

  /// Logout: revoke the token on the server and clear local storage.
  /// Also signs out of Google if the user signed in via Google.
  static Future<void> logout() async {
    try {
      final headers = await _authHeaders();
      await AppHttpClient.instance.post(
        Uri.parse('${ApiConfig.apiUrl}/logout'),
        headers: headers,
      ).timeout(ApiConfig.timeout);
    } catch (_) {
      // Even if the server call fails, clear local auth
    }
    // Sign out of Google and Firebase if applicable
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      if (DefaultFirebaseOptions.isConfigured) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {
      // Ignore if not signed in with Google
    }
    await _clearAuth();
  }

  /// Delete Account: call delete endpoint on the server, clear local storage and sign out.
  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final headers = await _authHeaders();
      final response = await AppHttpClient.instance.delete(
        Uri.parse('${ApiConfig.apiUrl}/user'),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Sign out of Google and Firebase if applicable
        try {
          if (!kIsWeb) {
            await _googleSignIn.signOut();
          }
          if (DefaultFirebaseOptions.isConfigured) {
            await FirebaseAuth.instance.signOut();
          }
        } catch (_) {}
        await _clearAuth();
        return {'success': true, 'message': data['message'] ?? 'Account deleted'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'error': data['message'] ?? 'Failed to delete account'};
      }
    } catch (e) {
      // Offline/fallback delete behavior if network is down but we need to reset
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
