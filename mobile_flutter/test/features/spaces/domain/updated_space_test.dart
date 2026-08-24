import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/updated_space.dart';

void main() {
  group('UpdatedSpace', () {
    test('interpreta a resposta do PUT /spaces/{id}', () {
      final space = UpdatedSpace.fromJson(<String, dynamic>{
        'id': 1,
        'name': ' Residência do Casal Laet atualizado ',
        'spaceAdminName': ' Jonatas Laet ',
        'active': true,
        'available': false,
      });

      expect(space.id, 1);
      expect(space.name, 'Residência do Casal Laet atualizado');
      expect(space.spaceAdminName, 'Jonatas Laet');
      expect(space.active, isTrue);
      expect(space.available, isFalse);
    });

    test('aceita administrador ausente', () {
      final space = UpdatedSpace.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Casa',
        'active': false,
        'available': true,
      });

      expect(space.spaceAdminName, isNull);
    });

    for (final invalidBody in <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 0,
        'name': 'Casa',
        'active': true,
        'available': true,
      },
      <String, dynamic>{
        'id': 1,
        'name': '   ',
        'active': true,
        'available': true,
      },
      <String, dynamic>{
        'id': 1,
        'name': 'Casa',
        'active': 'true',
        'available': true,
      },
      <String, dynamic>{'id': 1, 'name': 'Casa', 'active': true},
      <String, dynamic>{
        'id': 1,
        'name': 'Casa',
        'spaceAdminName': '   ',
        'active': true,
        'available': true,
      },
    ]) {
      test(
        'rejeita resposta obrigatória ausente ou inválida: $invalidBody',
        () {
          expect(
            () => UpdatedSpace.fromJson(invalidBody),
            throwsFormatException,
          );
        },
      );
    }
  });
}
