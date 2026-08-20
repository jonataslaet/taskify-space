import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';

void main() {
  group('TaskCreation', () {
    test('serializa todos os campos e a agenda no formato da API', () {
      final creation = TaskCreation(
        spaceId: 1,
        description: 'Pagar conta de água',
        score: 80.0,
        category: TaskCategory.financial,
        active: true,
        creatorName: 'Joice Laet',
        schedule: TaskScheduleSummary(
          localDates: <DateTime>[
            DateTime.utc(2024, 2, 29),
            DateTime.utc(2024, 2, 28),
            DateTime.utc(2024, 2, 27),
          ],
          frequency: TaskFrequency.weekly,
        ),
      );

      expect(creation.toJson(), <String, dynamic>{
        'spaceId': 1,
        'description': 'Pagar conta de água',
        'score': 80.0,
        'category': 'FINANCIAL',
        'active': true,
        'creatorName': 'Joice Laet',
        'schedule': <String, dynamic>{
          'localDates': <String>['2024-02-29', '2024-02-28', '2024-02-27'],
          'frequence': 'WEEKLY',
        },
      });
    });

    test('serializa schedule nulo quando a tarefa não possui agenda', () {
      const creation = TaskCreation(
        spaceId: 7,
        description: 'Trocar o botijão',
        score: 90.5,
        category: TaskCategory.operational,
        schedule: null,
        active: true,
        creatorName: 'Joice Laet',
      );

      expect(creation.toJson(), <String, dynamic>{
        'spaceId': 7,
        'description': 'Trocar o botijão',
        'score': 90.5,
        'category': 'OPERATIONAL',
        'active': true,
        'creatorName': 'Joice Laet',
        'schedule': null,
      });
    });
  });
}
