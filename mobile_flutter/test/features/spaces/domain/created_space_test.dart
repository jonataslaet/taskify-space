import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/created_space.dart';

void main() {
  group('CreatedSpace', () {
    test('interpreta a resposta enxuta do POST /spaces', () {
      final space = CreatedSpace.fromJson(<String, dynamic>{
        'id': 7,
        'name': '  Casa da Praia  ',
        'spaceAdminName': '  Maria  ',
        'active': false,
      });

      expect(space.id, 7);
      expect(space.name, 'Casa da Praia');
      expect(space.spaceAdminName, 'Maria');
      expect(space.active, isFalse);
    });

    test('aceita administrador omitido pelo JsonInclude NON_NULL', () {
      final space = CreatedSpace.fromJson(<String, dynamic>{
        'id': 7,
        'name': 'Casa da Praia',
        'active': false,
      });

      expect(space.spaceAdminName, isNull);
    });

    test('rejeita campos essenciais ausentes ou inválidos', () {
      expect(
        () => CreatedSpace.fromJson(<String, dynamic>{
          'id': 0,
          'name': 'Casa da Praia',
          'active': false,
        }),
        throwsFormatException,
      );
      expect(
        () => CreatedSpace.fromJson(<String, dynamic>{
          'id': 7,
          'name': '   ',
          'active': false,
        }),
        throwsFormatException,
      );
      expect(
        () => CreatedSpace.fromJson(<String, dynamic>{
          'id': 7,
          'name': 'Casa da Praia',
        }),
        throwsFormatException,
      );
    });
  });
}
