import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';

void main() {
  group('TaskFilters', () {
    test('mantém todos os filtros aceitos pela specification', () {
      const filters = TaskFilters(
        spaceId: 7,
        description: 'Conta',
        score: 20.5,
        active: true,
        categories: <TaskCategory>{TaskCategory.financial},
        minScore: 10,
        maxScore: 30,
      );

      expect(filters.spaceId, 7);
      expect(filters.description, 'Conta');
      expect(filters.score, 20.5);
      expect(filters.active, isTrue);
      expect(filters.categories, <TaskCategory>{TaskCategory.financial});
      expect(filters.minScore, 10);
      expect(filters.maxScore, 30);
    });

    test('expõe categorias e frequências compatíveis com a API', () {
      expect(TaskCategory.values.map((category) => category.apiValue), <String>[
        'OPERATIONAL',
        'FINANCIAL',
      ]);
      expect(
        TaskFrequency.values.map((frequency) => frequency.apiValue),
        <String>['ONCE', 'DAILY', 'MONTHLY', 'WEEKLY', 'YEARLY'],
      );
    });
  });
}
