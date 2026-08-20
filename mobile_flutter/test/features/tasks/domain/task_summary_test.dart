import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';

void main() {
  group('TaskSummary', () {
    test('interpreta a tarefa completa e sua agenda', () {
      final task = TaskSummary.fromJson(_validTaskJson());

      expect(task.id, 1);
      expect(task.spaceId, 10);
      expect(task.description, 'Trocar o botijão');
      expect(task.score, 90.5);
      expect(task.category, TaskCategory.operational);
      expect(task.active, isTrue);
      expect(task.creatorName, 'Joice Laet');
      expect(task.schedule?.frequency, TaskFrequency.weekly);
      expect(task.schedule?.localDates, <DateTime>[
        DateTime.utc(2026, 8, 2),
        DateTime.utc(2026, 8, 9),
      ]);
    });

    test('aceita schedule e creatorName omitidos', () {
      final json = _validTaskJson()
        ..remove('schedule')
        ..remove('creatorName');

      final task = TaskSummary.fromJson(json);

      expect(task.schedule, isNull);
      expect(task.creatorName, isNull);
    });

    test('mantém as datas da agenda imutáveis', () {
      final task = TaskSummary.fromJson(_validTaskJson());

      expect(
        () => task.schedule!.localDates.add(DateTime.utc(2026, 8, 16)),
        throwsUnsupportedError,
      );
    });

    test('rejeita campos obrigatórios ausentes ou inválidos', () {
      for (final invalidJson in <Map<String, dynamic>>[
        _validTaskJson()..['id'] = 0,
        _validTaskJson()..remove('spaceId'),
        _validTaskJson()..['description'] = '   ',
        _validTaskJson()..['score'] = 0,
        _validTaskJson()..['active'] = 'true',
        _validTaskJson()..['category'] = 'OTHER',
      ]) {
        expect(() => TaskSummary.fromJson(invalidJson), throwsFormatException);
      }
    });

    test('rejeita frequência e LocalDate incompatíveis com o backend', () {
      final invalidFrequency = _validTaskJson();
      (invalidFrequency['schedule'] as Map<String, dynamic>)['frequence'] =
          'FORTNIGHTLY';
      final invalidDate = _validTaskJson();
      (invalidDate['schedule'] as Map<String, dynamic>)['localDates'] =
          <String>['2026-02-30'];

      expect(
        () => TaskSummary.fromJson(invalidFrequency),
        throwsFormatException,
      );
      expect(() => TaskSummary.fromJson(invalidDate), throwsFormatException);
    });

    test('aceita agenda diária com datas vazias, nulas ou omitidas', () {
      for (final scheduleJson in <Map<String, dynamic>>[
        <String, dynamic>{'localDates': <String>[], 'frequence': 'DAILY'},
        <String, dynamic>{'localDates': null, 'frequence': 'DAILY'},
        <String, dynamic>{'frequence': 'DAILY'},
      ]) {
        final task = TaskSummary.fromJson(
          _validTaskJson()..['schedule'] = scheduleJson,
        );

        expect(task.schedule?.frequency, TaskFrequency.daily);
        expect(task.schedule?.localDates, isEmpty);
      }
    });

    test('rejeita agenda não diária sem datas', () {
      final json = _validTaskJson();
      (json['schedule'] as Map<String, dynamic>)['localDates'] = <String>[];

      expect(() => TaskSummary.fromJson(json), throwsFormatException);
    });
  });
}

Map<String, dynamic> _validTaskJson() {
  return <String, dynamic>{
    'id': 1,
    'spaceId': 10,
    'description': ' Trocar o botijão ',
    'score': 90.5,
    'category': 'OPERATIONAL',
    'schedule': <String, dynamic>{
      'localDates': <String>['2026-08-02', '2026-08-09'],
      'frequence': 'WEEKLY',
    },
    'active': true,
    'creatorName': ' Joice Laet ',
  };
}
