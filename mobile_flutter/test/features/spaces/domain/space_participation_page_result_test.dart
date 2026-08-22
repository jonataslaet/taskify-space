import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation_page_result.dart';

void main() {
  group('SpaceParticipationPageResult', () {
    test('interpreta conteúdo e metadados da página', () {
      final result = SpaceParticipationPageResult.fromJson(_validPageJson());

      expect(result.content, hasLength(1));
      expect(result.content.single.name, 'Joice Laet');
      expect(result.size, 10);
      expect(result.number, 1);
      expect(result.totalElements, 21);
      expect(result.totalPages, 3);
      expect(result.isEmpty, isFalse);
      expect(result.hasNextPage, isTrue);
    });

    test('mantém o conteúdo imutável', () {
      final result = SpaceParticipationPageResult.fromJson(_validPageJson());

      expect(() => result.content.clear(), throwsUnsupportedError);
    });

    test('reconhece página vazia e final', () {
      final json = _validPageJson()
        ..['content'] = <dynamic>[]
        ..['page'] = <String, dynamic>{
          'size': 10,
          'number': 0,
          'totalElements': 0,
          'totalPages': 0,
        };

      final result = SpaceParticipationPageResult.fromJson(json);

      expect(result.isEmpty, isTrue);
      expect(result.hasNextPage, isFalse);
    });

    test('rejeita content, item ou page incompatíveis', () {
      final invalidItem = _validPageJson()..['content'] = <dynamic>['user'];
      final invalidPage = _validPageJson();
      (invalidPage['page'] as Map<String, dynamic>)['totalElements'] = -1;

      expect(
        () => SpaceParticipationPageResult.fromJson(<String, dynamic>{
          'page': <String, dynamic>{},
        }),
        throwsFormatException,
      );
      expect(
        () => SpaceParticipationPageResult.fromJson(invalidItem),
        throwsFormatException,
      );
      expect(
        () => SpaceParticipationPageResult.fromJson(invalidPage),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _validPageJson() {
  return <String, dynamic>{
    'content': <dynamic>[
      <String, dynamic>{
        'id': 2,
        'name': 'Joice Laet',
        'spaceUserRole': 'ROLE_SPACE_ADMIN',
        'spaceMembershipStatus': 'PENDING',
      },
    ],
    'page': <String, dynamic>{
      'size': 10,
      'number': 1,
      'totalElements': 21,
      'totalPages': 3,
    },
  };
}
