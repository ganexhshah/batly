/// Shared auth/session error helpers for API responses.
class AuthErrors {
  AuthErrors._();

  static bool isAuthStatusCode(int? statusCode) =>
      statusCode == 401 || statusCode == 403;

  static bool isAuthException(Object error) {
    final message = error.toString();
    return message.contains('401') || message.contains('403');
  }
}
