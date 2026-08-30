import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_page_result.dart';

void main() {
  group('SpaceParticipantPageResult', () {
    test('interpreta conteúdo e metadados da página', () {
      final result = SpaceParticipantPageResult.fromJson(_validPageJson());

      expect(result.content, hasLength(1));
      expect(result.content.single.name, 'Joice Laet');
      expect(result.content.single.contributionPercentual, 0.75);
      expect(result.size, 10);
      expect(result.number, 1);
      expect(result.totalElements, 21);
      expect(result.totalPages, 3);
      expect(result.isEmpty, isFalse);
      expect(result.hasNextPage, isTrue);
    });

    test('mantém o conteúdo imutável', () {
      final result = SpaceParticipantPageResult.fromJson(_validPageJson());

      expect(() => result.content.clear(), throwsUnsupportedError);
    });

    test('rejeita content, item ou page incompatíveis', () {
      final invalidItem = _validPageJson()..['content'] = <dynamic>['user'];
      final invalidPage = _validPageJson();
      (invalidPage['page'] as Map<String, dynamic>)['totalElements'] = -1;

      expect(
        () => SpaceParticipantPageResult.fromJson(<String, dynamic>{
          'page': <String, dynamic>{},
        }),
        throwsFormatException,
      );
      expect(
        () => SpaceParticipantPageResult.fromJson(invalidItem),
        throwsFormatException,
      );
      expect(
        () => SpaceParticipantPageResult.fromJson(invalidPage),
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
        'taskCategories': <dynamic>['OPERATIONAL'],
        'score': 90.5,
        'contributionPercentual': 0.75,
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
