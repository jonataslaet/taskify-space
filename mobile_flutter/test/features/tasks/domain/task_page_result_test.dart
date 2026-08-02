import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tasks/domain/task_page_result.dart';

void main() {
  group('TaskPageResult', () {
    test('interpreta content e metadados da página', () {
      final result = TaskPageResult.fromJson(_validPageJson());

      expect(result.content, hasLength(1));
      expect(result.content.single.description, 'Pagar conta de água');
      expect(result.size, 10);
      expect(result.number, 0);
      expect(result.totalElements, 11);
      expect(result.totalPages, 2);
      expect(result.isEmpty, isFalse);
      expect(result.hasNextPage, isTrue);
    });

    test('mantém o conteúdo imutável', () {
      final result = TaskPageResult.fromJson(_validPageJson());

      expect(() => result.content.clear(), throwsUnsupportedError);
    });

    test('rejeita content, item ou page incompatíveis', () {
      final invalidItem = _validPageJson();
      invalidItem['content'] = <dynamic>['task'];
      final invalidPage = _validPageJson();
      (invalidPage['page'] as Map<String, dynamic>)['number'] = -1;

      expect(
        () => TaskPageResult.fromJson(<String, dynamic>{
          'page': <String, dynamic>{},
        }),
        throwsFormatException,
      );
      expect(() => TaskPageResult.fromJson(invalidItem), throwsFormatException);
      expect(() => TaskPageResult.fromJson(invalidPage), throwsFormatException);
    });
  });
}

Map<String, dynamic> _validPageJson() {
  return <String, dynamic>{
    'content': <dynamic>[
      <String, dynamic>{
        'id': 2,
        'spaceId': 10,
        'description': 'Pagar conta de água',
        'score': 30,
        'category': 'FINANCIAL',
        'active': true,
      },
    ],
    'page': <String, dynamic>{
      'size': 10,
      'number': 0,
      'totalElements': 11,
      'totalPages': 2,
    },
  };
}
