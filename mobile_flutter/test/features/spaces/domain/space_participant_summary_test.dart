import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_summary.dart';

void main() {
  group('SpaceParticipantSummary', () {
    test('interpreta id e normaliza o nome', () {
      final participant = SpaceParticipantSummary.fromJson(<String, dynamic>{
        'id': 7,
        'name': '  Joice Laet  ',
      });

      expect(participant.id, 7);
      expect(participant.name, 'Joice Laet');
    });

    test('rejeita id ausente, incompatível ou não positivo', () {
      for (final value in <Object?>[null, 0, -1, 1.0, '1']) {
        expect(
          () => SpaceParticipantSummary.fromJson(<String, dynamic>{
            'id': value,
            'name': 'Joice Laet',
          }),
          throwsFormatException,
        );
      }
    });

    test('rejeita nome ausente, incompatível ou vazio', () {
      for (final value in <Object?>[null, 1, '   ']) {
        expect(
          () => SpaceParticipantSummary.fromJson(<String, dynamic>{
            'id': 1,
            'name': value,
          }),
          throwsFormatException,
        );
      }
    });
  });
}
