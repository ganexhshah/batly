import 'package:flutter/foundation.dart';

/// Battly API Configuration
///
/// Central configuration for connecting the Flutter app to the Laravel backend.
/// Automatically selects the correct host based on the platform:
///   - Android USB device → 127.0.0.1 with `adb reverse tcp:8888 tcp:8888`
///   - Android emulator → pass `--dart-define=BATTLY_ANDROID_EMULATOR=true` (uses 10.0.2.2)
///   - iOS Simulator / macOS / Windows → 127.0.0.1
///   - Physical Device → pass `--dart-define=BATTLY_PHYSICAL_DEVICE_IP=YOUR_LAN_IP`
class ApiConfig {
  /// Optional full backend URL override, for example:
  /// `flutter run --dart-define=BATTLY_API_BASE_URL=https://api.battly.zone`
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'BATTLY_API_BASE_URL',
    defaultValue: '',
  );

  /// Optional LAN IP for physical device testing.
  ///
  /// Example:
  /// `flutter run --dart-define=BATTLY_PHYSICAL_DEVICE_IP=192.168.1.100`
  static const String _physicalDeviceIp = String.fromEnvironment(
    'BATTLY_PHYSICAL_DEVICE_IP',
    defaultValue: '',
  );

  /// Use the Android emulator host alias (10.0.2.2) instead of USB adb reverse.
  ///
  /// Example:
  /// `flutter run --dart-define=BATTLY_ANDROID_EMULATOR=true`
  static const bool _androidEmulator = bool.fromEnvironment(
    'BATTLY_ANDROID_EMULATOR',
    defaultValue: false,
  );

  /// Backend port (nginx exposes port 8888 on the host)
  static const int backendPort = int.fromEnvironment(
    'BATTLY_BACKEND_PORT',
    defaultValue: 8888,
  );

  /// Resolve the correct base URL at runtime based on platform.
  static String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _validatedUrl(_apiBaseUrlOverride);
    }
    if (_physicalDeviceIp.isNotEmpty) {
      return _validatedUrl('http://$_physicalDeviceIp:$backendPort');
    }
    if (kIsWeb) {
      // Use localhost (not 127.0.0.1) so Chrome allows browser → API calls.
      return _validatedUrl('http://localhost:$backendPort');
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (_androidEmulator) {
        return _validatedUrl('http://10.0.2.2:$backendPort');
      }
      // Real USB devices use adb reverse to map device localhost to the laptop.
      return _validatedUrl('http://127.0.0.1:$backendPort');
    }
    return _validatedUrl('http://127.0.0.1:$backendPort');
  }

  static String _validatedUrl(String url) {
    final uri = Uri.parse(url);
    final isLoopback = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
    if (kReleaseMode && uri.scheme != 'https' && !isLoopback) {
      throw StateError(
        'Release builds require an HTTPS BATTLY_API_BASE_URL.',
      );
    }
    return url;
  }

  /// Full API base path
  static String get apiUrl => '$baseUrl/api';

  /// Web needs a longer timeout for local Docker-backed API calls.
  static Duration get timeout =>
      kIsWeb ? const Duration(seconds: 30) : const Duration(seconds: 8);
}
