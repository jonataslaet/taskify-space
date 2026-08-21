import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tasks/domain/task_execution_summary.dart';

void main() {
  group('TaskExecutionSummary', () {
    test('interpreta a execução e normaliza os nomes dos executores', () {
      final execution = TaskExecutionSummary.fromJson(
        _validExecutionJson()
          ..['executorNames'] = <dynamic>[
            '  Bella Laet ',
            'Joice Laet',
            'Jonatas Laet',
            'Ralph Laet',
          ],
      );

      expect(execution.id, 1);
      expect(execution.executionDate, DateTime.utc(2026, 8, 21, 18, 31));
      expect(execution.executionDate.isUtc, isTrue);
      expect(execution.score, 90.0);
      expect(execution.executorNames, <String>[
        'Bella Laet',
        'Joice Laet',
        'Jonatas Laet',
        'Ralph Laet',
      ]);
    });

    test('mantém executorNames imutável e aceita uma lista vazia', () {
      final execution = TaskExecutionSummary.fromJson(
        _validExecutionJson()..['executorNames'] = <dynamic>[],
      );

      expect(execution.executorNames, isEmpty);
      expect(
        () => execution.executorNames.add('Bella Laet'),
        throwsUnsupportedError,
      );
    });

    test('rejeita id ou score ausentes, incompatíveis ou não positivos', () {
      for (final value in <Object?>[null, 0, -1, 1.0]) {
        expect(
          () => TaskExecutionSummary.fromJson(
            _validExecutionJson()..['id'] = value,
          ),
          throwsFormatException,
        );
      }

      for (final value in <Object?>[
        null,
        0,
        -1,
        double.nan,
        double.infinity,
        '90.00',
      ]) {
        expect(
          () => TaskExecutionSummary.fromJson(
            _validExecutionJson()..['score'] = value,
          ),
          throwsFormatException,
        );
      }
    });

    test('rejeita formato ou componentes inválidos em executionDate', () {
      for (final value in <Object?>[
        null,
        '2026-08-21T18:31',
        '21/8/2026 18:31',
        '31/02/2026 18:31',
        '21/08/2026 24:00',
        '21/08/0000 18:31',
      ]) {
        expect(
          () => TaskExecutionSummary.fromJson(
            _validExecutionJson()..['executionDate'] = value,
          ),
          throwsFormatException,
        );
      }
    });

    test(
      'rejeita executorNames ausente, incompatível ou com nome inválido',
      () {
        for (final value in <Object?>[
          null,
          'Bella Laet',
          <dynamic>[null],
          <dynamic>['   '],
          <dynamic>['Bella Laet', 2],
        ]) {
          expect(
            () => TaskExecutionSummary.fromJson(
              _validExecutionJson()..['executorNames'] = value,
            ),
            throwsFormatException,
          );
        }
      },
    );
  });
}

Map<String, dynamic> _validExecutionJson() {
  return <String, dynamic>{
    'id': 1,
    'executionDate': '21/08/2026 18:31',
    'score': 90.0,
    'executorNames': <dynamic>['Bella Laet'],
  };
}
