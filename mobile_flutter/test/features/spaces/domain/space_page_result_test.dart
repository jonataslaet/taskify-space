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
            'spaceUserRole': ' ROLE_SPACE_PARTICIPANT ',
            'spaceMembershipStatus': ' APPROVED ',
            'activeParticipationsCount': 4,
          },
          <String, dynamic>{
            'id': 2,
            'name': 'Residência do Marido da Bella',
            'active': true,
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
