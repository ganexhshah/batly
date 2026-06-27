import 'package:http/http.dart' as http;

/// Shared HTTP client — reuses connections for faster repeat API calls.
class AppHttpClient {
  AppHttpClient._();

  static final http.Client instance = http.Client();
}
