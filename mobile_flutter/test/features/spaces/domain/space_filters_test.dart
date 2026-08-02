import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';

void main() {
  group('SpaceFilters', () {
    test('mantém todos os filtros opcionais', () {
      const filters = SpaceFilters(
        name: 'Residência',
        role: SpaceUserRole.manager,
        status: SpaceMembershipStatus.approved,
      );

      expect(filters.name, 'Residência');
      expect(filters.role, SpaceUserRole.manager);
      expect(filters.status, SpaceMembershipStatus.approved);
    });

    test('possui valores de papéis compatíveis com a API', () {
      expect(SpaceUserRole.values.map((role) => role.apiValue), <String>[
        'ROLE_SPACE_ADMIN',
        'ROLE_SPACE_MANAGER',
        'ROLE_SPACE_PARTICIPANT',
      ]);
    });

    test('possui valores de situações compatíveis com a API', () {
      expect(
        SpaceMembershipStatus.values.map((status) => status.apiValue),
        <String>[
          'PENDING',
          'APPROVED',
          'BLOCKED',
          'CANCELLED',
          'DENIED',
          'SUSPENDED',
        ],
      );
    });
  });
}
