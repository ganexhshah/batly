import 'package:app/core/auth_errors.dart';
import 'package:app/core/notification_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthErrors', () {
    test('detects 401 and 403', () {
      expect(AuthErrors.isAuthStatusCode(401), isTrue);
      expect(AuthErrors.isAuthStatusCode(403), isTrue);
      expect(AuthErrors.isAuthStatusCode(200), isFalse);
    });

    test('detects auth failures in exception text', () {
      expect(AuthErrors.isAuthException(Exception('Failed: 403')), isTrue);
      expect(AuthErrors.isAuthException(Exception('timeout')), isFalse);
    });
  });

  group('parseTournamentDeepLink', () {
    test('parses tournament id', () {
      expect(parseTournamentDeepLink('tournament:42'), 42);
      expect(parseTournamentDeepLink('https://x.com'), isNull);
      expect(parseTournamentDeepLink(null), isNull);
    });

    test('image url helper', () {
      expect(isNotificationImageUrl('https://cdn.example.com/a.png'), isTrue);
      expect(isNotificationImageUrl('tournament:1'), isFalse);
    });
  });
}
