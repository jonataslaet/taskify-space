import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation.dart';

void main() {
  group('SpaceParticipation', () {
    test('interpreta participação completa e normaliza textos', () {
      final participation = SpaceParticipation.fromJson(<String, dynamic>{
        'id': 12,
        'name': ' Joice Laet ',
        'spaceUserRole': ' ROLE_SPACE_MANAGER ',
        'spaceMembershipStatus': ' PENDING ',
      });

      expect(participation.id, 12);
      expect(participation.name, 'Joice Laet');
      expect(participation.spaceUserRole, SpaceUserRole.manager);
      expect(
        participation.spaceMembershipStatus,
        SpaceMembershipStatus.pending,
      );
    });

    test('rejeita campos ausentes ou incompatíveis', () {
      for (final invalidJson in <Map<String, dynamic>>[
        _validJson()..remove('id'),
        _validJson()..['id'] = 0,
        _validJson()..['id'] = 1.0,
        _validJson()..remove('name'),
        _validJson()..['name'] = '   ',
        _validJson()..remove('spaceUserRole'),
        _validJson()..['spaceUserRole'] = 'ROLE_UNKNOWN',
        _validJson()..remove('spaceMembershipStatus'),
        _validJson()..['spaceMembershipStatus'] = 'UNKNOWN',
      ]) {
        expect(
          () => SpaceParticipation.fromJson(invalidJson),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, dynamic> _validJson() {
  return <String, dynamic>{
    'id': 1,
    'name': 'Participante',
    'spaceUserRole': 'ROLE_SPACE_PARTICIPANT',
    'spaceMembershipStatus': 'APPROVED',
  };
}
