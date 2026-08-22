import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation_filters.dart';

void main() {
  group('SpaceParticipationFilters', () {
    test('não aplica filtros por padrão', () {
      const filters = SpaceParticipationFilters();

      expect(filters.username, isNull);
      expect(filters.statuses, isEmpty);
    });

    test('mantém usuário e situações selecionadas', () {
      const filters = SpaceParticipationFilters(
        username: 'Joice',
        statuses: <SpaceMembershipStatus>{
          SpaceMembershipStatus.pending,
          SpaceMembershipStatus.approved,
        },
      );

      expect(filters.username, 'Joice');
      expect(filters.statuses, <SpaceMembershipStatus>{
        SpaceMembershipStatus.pending,
        SpaceMembershipStatus.approved,
      });
    });
  });
}
