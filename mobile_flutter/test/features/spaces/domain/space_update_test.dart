import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_update.dart';

void main() {
  group('SpaceUpdate', () {
    test('serializa nome normalizado e disponibilidade', () {
      const update = SpaceUpdate(
        name: '  Residência do Casal Laet  ',
        available: true,
      );

      expect(update.toJson(), <String, dynamic>{
        'name': 'Residência do Casal Laet',
        'available': true,
      });
    });

    test('omite campos ausentes para permitir atualização parcial', () {
      expect(const SpaceUpdate(name: ' Casa ').toJson(), <String, dynamic>{
        'name': 'Casa',
      });
      expect(const SpaceUpdate(available: false).toJson(), <String, dynamic>{
        'available': false,
      });
      expect(const SpaceUpdate().toJson(), isEmpty);
    });
  });
}
