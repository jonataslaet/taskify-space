import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';

void main() {
  group('AuthSession', () {
    test('desserializa a resposta de login e tolera name nulo', () {
      final session = AuthSession.fromJson(<String, dynamic>{
        'id': 7,
        'username': 'user@example.com',
        'name': null,
        'accessToken': 'access-token-test-only',
        'refreshToken': 'refresh-token-test-only',
        'role': 'ROLE_FUTURE_VALUE',
      });

      expect(session.id, 7);
      expect(session.name, isNull);
      expect(session.role, 'ROLE_FUTURE_VALUE');
    });

    test('rejeita resposta sem refresh token', () {
      expect(
        () => AuthSession.fromJson(<String, dynamic>{
          'id': 7,
          'username': 'user@example.com',
          'name': 'User',
          'accessToken': 'access-token-test-only',
          'role': 'ROLE_USER',
        }),
        throwsFormatException,
      );
    });
  });
}
