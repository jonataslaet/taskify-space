import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('usa o alias do host como padrão no Android Emulator', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final config = AppConfig.fromEnvironment();

      expect(config.apiBaseUri.toString(), 'http://10.0.2.2:8080/');
    });

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
