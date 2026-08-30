import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';

void main() {
  group('SpacePageResult', () {
    test('interpreta a página e os campos opcionais do espaço', () {
      final result = SpacePageResult.fromJson(<String, dynamic>{
        'content': <dynamic>[
          <String, dynamic>{
            'id': 1,
            'name': ' Residência do Casal Laet ',
            'spaceAdminName': ' Joice Laet ',
            'active': true,
            'available': false,
            'spaceUserRole': ' ROLE_SPACE_PARTICIPANT ',
            'spaceMembershipStatus': ' APPROVED ',
            'activeParticipationsCount': 4,
          },
          <String, dynamic>{
            'id': 2,
            'name': 'Residência do Marido da Bella',
            'active': true,
            'available': true,
            'activeParticipationsCount': 2,
          },
        ],
        'page': <String, dynamic>{
          'size': 10,
          'number': 0,
          'totalElements': 2,
          'totalPages': 1,
        },
      });

      expect(result.content, hasLength(2));
      expect(result.content.first.name, 'Residência do Casal Laet');
      expect(result.content.first.spaceUserRole, 'ROLE_SPACE_PARTICIPANT');
      expect(result.content.first.spaceMembershipStatus, 'APPROVED');
      expect(result.content.first.available, isFalse);
      expect(result.content.first.canEditTasks, isFalse);
      expect(result.content.last.spaceUserRole, isNull);
      expect(result.content.last.spaceMembershipStatus, isNull);
      expect(result.content.last.spaceAdminName, isNull);
      expect(result.size, 10);
      expect(result.number, 0);
      expect(result.totalElements, 2);
      expect(result.totalPages, 1);
      expect(result.isEmpty, isFalse);
      expect(result.hasNextPage, isFalse);
    });

    test('libera edição somente para admin ou gerente aprovados', () {
      SpaceSummary space({required String? role, String? status = 'APPROVED'}) {
        return SpaceSummary(
          id: 1,
          name: 'Casa',
          spaceAdminName: null,
          active: true,
          available: true,
          spaceUserRole: role,
          spaceMembershipStatus: status,
          activeParticipationsCount: 1,
        );
      }

      expect(space(role: 'ROLE_SPACE_ADMIN').canEditTasks, isTrue);
      expect(space(role: 'ROLE_SPACE_MANAGER').canEditTasks, isTrue);
      expect(space(role: 'ROLE_SPACE_PARTICIPANT').canEditTasks, isFalse);
      expect(space(role: null).canEditTasks, isFalse);
      expect(
        space(role: 'ROLE_SPACE_ADMIN', status: 'PENDING').canEditTasks,
        isFalse,
      );

      expect(space(role: 'ROLE_SPACE_ADMIN').canEditParticipations, isTrue);
      expect(space(role: 'ROLE_SPACE_MANAGER').canEditParticipations, isTrue);
      expect(space(role: 'ROLE_SPACE_ADMIN').canViewParticipations, isTrue);
      expect(space(role: 'ROLE_SPACE_MANAGER').canViewParticipations, isTrue);
      expect(
        space(role: 'ROLE_SPACE_PARTICIPANT').canEditParticipations,
        isFalse,
      );
      expect(
        space(role: 'ROLE_SPACE_PARTICIPANT').canViewParticipations,
        isFalse,
      );
      expect(space(role: null).canViewParticipations, isFalse);
      expect(space(role: 'ROLE_UNKNOWN').canViewParticipations, isFalse);
      expect(space(role: 'ROLE_SPACE_ADMIN').canEditParticipationRoles, isTrue);
      expect(space(role: 'ROLE_SPACE_ADMIN').canEditSpace, isTrue);
      expect(space(role: 'ROLE_SPACE_MANAGER').canEditSpace, isTrue);
      expect(space(role: 'ROLE_SPACE_ADMIN').canEditAvailability, isTrue);
      expect(space(role: 'ROLE_SPACE_MANAGER').canEditAvailability, isFalse);
      expect(
        space(role: 'ROLE_SPACE_MANAGER').canEditParticipationRoles,
        isFalse,
      );
      expect(
        space(
          role: 'ROLE_SPACE_ADMIN',
          status: 'PENDING',
        ).canEditParticipations,
        isFalse,
      );
      expect(
        space(
          role: 'ROLE_SPACE_ADMIN',
          status: 'PENDING',
        ).canViewParticipations,
        isFalse,
      );
      expect(
        space(
          role: 'ROLE_SPACE_MANAGER',
          status: 'PENDING',
        ).canViewParticipations,
        isFalse,
      );
      expect(
        space(role: 'ROLE_SPACE_MANAGER', status: null).canViewParticipations,
        isFalse,
      );
      expect(
        space(
          role: 'ROLE_SPACE_ADMIN',
          status: 'PENDING',
        ).canEditParticipationRoles,
        isFalse,
      );
    });

    test('mantém a lista de resultados imutável', () {
      final result = SpacePageResult.fromJson(<String, dynamic>{
        'content': <dynamic>[],
        'page': <String, dynamic>{
          'size': 10,
          'number': 0,
          'totalElements': 0,
          'totalPages': 0,
        },
      });

      expect(result.isEmpty, isTrue);
      expect(
        () => result.content.add(
          const SpaceSummary(
            id: 1,
            name: 'Casa',
            spaceAdminName: 'Admin',
            active: true,
            available: true,
            spaceUserRole: null,
            spaceMembershipStatus: null,
            activeParticipationsCount: 0,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('informa se existe uma próxima página', () {
      final result = SpacePageResult.fromJson(<String, dynamic>{
        'content': <dynamic>[],
        'page': <String, dynamic>{
          'size': 10,
          'number': 1,
          'totalElements': 35,
          'totalPages': 4,
        },
      });

      expect(result.hasNextPage, isTrue);
    });

    test('rejeita item que não seja objeto JSON', () {
      expect(
        () => SpacePageResult.fromJson(<String, dynamic>{
          'content': <dynamic>['inválido'],
          'page': <String, dynamic>{
            'size': 10,
            'number': 0,
            'totalElements': 1,
            'totalPages': 1,
          },
        }),
        throwsFormatException,
      );
    });

    test('rejeita campos obrigatórios ausentes ou com tipo inválido', () {
      expect(
        () => SpacePageResult.fromJson(<String, dynamic>{
          'content': <dynamic>[
            <String, dynamic>{
              'id': 1,
              'name': 'Casa',
              'spaceAdminName': 'Admin',
              'active': 'true',
              'available': true,
              'activeParticipationsCount': 1,
            },
          ],
          'page': <String, dynamic>{
            'size': 10,
            'number': 0,
            'totalElements': 1,
            'totalPages': 1,
          },
        }),
        throwsFormatException,
      );

      expect(
        () => SpacePageResult.fromJson(<String, dynamic>{
          'content': <dynamic>[
            <String, dynamic>{
              'id': 1,
              'name': 'Casa',
              'spaceAdminName': 'Admin',
              'active': true,
              'activeParticipationsCount': 1,
            },
          ],
          'page': <String, dynamic>{
            'size': 10,
            'number': 0,
            'totalElements': 1,
            'totalPages': 1,
          },
        }),
        throwsFormatException,
      );

      expect(
        () => SpacePageResult.fromJson(<String, dynamic>{
          'content': <dynamic>[],
          'page': <String, dynamic>{
            'size': -1,
            'number': 0,
            'totalElements': 0,
            'totalPages': 0,
          },
        }),
        throwsFormatException,
      );
    });
  });
}
