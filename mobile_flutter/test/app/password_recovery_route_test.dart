import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app/password_recovery_route.dart';

void main() {
  group('PasswordRecoveryRoute.tryParse', () {
    final validCases = <({String location, String code})>[
      (location: '/new-password/304476', code: '304476'),
      (location: 'new-password/000001', code: '000001'),
      (location: 'https://app.example.com/new-password/304476', code: '304476'),
      (location: 'http://localhost:5173/new-password/304476', code: '304476'),
      (location: 'http://10.0.2.2/new-password/304476', code: '304476'),
      (location: 'taskifyspace://new-password/304476', code: '304476'),
      (location: 'taskifyspace:///new-password/304476', code: '304476'),
      (location: '/new-password/304476?source=email#form', code: '304476'),
      (location: '/new-password/%33%30%34%34%37%36', code: '304476'),
    ];

    for (final validCase in validCases) {
      test('aceita ${validCase.location}', () {
        final route = PasswordRecoveryRoute.tryParse(validCase.location);

        expect(route, isNotNull);
        expect(route!.token, validCase.code);
      });
    }

    for (final location in <String?>[
      null,
      '',
      '   ',
      '/',
      '/new-password',
      '/new-password/',
      '/new-password/30447',
      '/new-password/3044760',
      '/new-password/30447a',
      '/new-password/-30447',
      '/new-password/+30447',
      '/new-password/304 476',
      '/new-password/304%20476',
      '/new-password/304\t476',
      '/new-password/٣٠٤٤٧٦',
      '/new-password/３０４４７６',
      '/new-password/opaque-token',
      '/new-password/123e4567-e89b-42d3-a456-426614174000',
      '/new-password/304476/extra',
      '/other/304476',
      '//example.com/new-password/304476',
      'ftp://example.com/new-password/304476',
      'https:/new-password/304476',
      'https://user@example.com/new-password/304476',
      'taskifyspace://other/304476',
      'taskifyspace://new-password/304476/extra',
      '/new-password/304%2F476',
    ]) {
      test('rejeita ${location ?? 'null'} com seguranca', () {
        expect(PasswordRecoveryRoute.tryParse(location), isNull);
      });
    }
  });
}
