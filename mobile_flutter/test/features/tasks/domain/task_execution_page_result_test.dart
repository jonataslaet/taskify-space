import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tasks/domain/task_execution_page_result.dart';

void main() {
  group('TaskExecutionPageResult', () {
    test('interpreta conteúdo e metadados da página', () {
      final result = TaskExecutionPageResult.fromJson(_validPageJson());

      expect(result.content, hasLength(1));
      expect(result.content.single.id, 1);
      expect(
        result.content.single.executionDate,
        DateTime.utc(2026, 8, 21, 18, 31),
      );
      expect(result.size, 10);
      expect(result.number, 0);
      expect(result.totalElements, 11);
      expect(result.totalPages, 2);
      expect(result.isEmpty, isFalse);
      expect(result.hasNextPage, isTrue);
    });

    test('mantém o conteúdo imutável', () {
      final result = TaskExecutionPageResult.fromJson(_validPageJson());

      expect(() => result.content.clear(), throwsUnsupportedError);
    });

    test('rejeita content, item ou page incompatíveis', () {
      final invalidItem = _validPageJson()
        ..['content'] = <dynamic>['execution'];
      final invalidPage = _validPageJson();
      (invalidPage['page'] as Map<String, dynamic>)['totalElements'] = -1;

      expect(
        () => TaskExecutionPageResult.fromJson(<String, dynamic>{
          'page': <String, dynamic>{},
        }),
        throwsFormatException,
      );
      expect(
        () => TaskExecutionPageResult.fromJson(invalidItem),
        throwsFormatException,
      );
      expect(
        () => TaskExecutionPageResult.fromJson(invalidPage),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _validPageJson() {
  return <String, dynamic>{
    'content': <dynamic>[
      <String, dynamic>{
        'id': 1,
        'executionDate': '21/08/2026 18:31',
        'score': 90.0,
        'executorNames': <dynamic>['Bella Laet'],
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
