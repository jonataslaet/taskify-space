import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('normaliza a base e preserva um prefixo de API', () {
      final config = AppConfig(
        apiBaseUrl: ' https://api.example.com/api/v1/// ',
      );

      expect(
        config.endpoint('/auth/login').toString(),
        'https://api.example.com/api/v1/auth/login',
      );
    });

    test('rejeita URL inválida', () {
      expect(
        () => AppConfig(apiBaseUrl: 'api.example.com'),
        throwsFormatException,
      );
    });

    test('rejeita HTTP quando o transporte inseguro não é permitido', () {
      expect(
        () => AppConfig(
          apiBaseUrl: 'http://api.example.com',
          allowInsecureHttp: false,
        ),
        throwsFormatException,
      );
    });
  });
}
