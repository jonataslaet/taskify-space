import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

void main() {
  group('SpaceParticipant', () {
    test('interpreta participante completo e normaliza textos', () {
      final participant = SpaceParticipant.fromJson(<String, dynamic>{
        'id': 12,
        'name': ' Joice Laet ',
        'spaceUserRole': ' ROLE_SPACE_MANAGER ',
        'taskCategories': <dynamic>[' OPERATIONAL ', 'FINANCIAL'],
        'score': 49.1666666667,
        'contributionPercentual': 0.491666666667,
      });

      expect(participant.id, 12);
      expect(participant.name, 'Joice Laet');
      expect(participant.spaceUserRole, SpaceUserRole.manager);
      expect(participant.taskCategories, <TaskCategory>[
        TaskCategory.operational,
        TaskCategory.financial,
      ]);
      expect(participant.score, 49.1666666667);
      expect(participant.contributionPercentual, 0.491666666667);
    });

    test('aceita score e percentual zero e categorias ausentes ou nulas', () {
      for (final json in <Map<String, dynamic>>[
        _validJson()..remove('taskCategories'),
        _validJson()..['taskCategories'] = null,
      ]) {
        final participant = SpaceParticipant.fromJson(json);

        expect(participant.score, 0);
        expect(participant.contributionPercentual, 0);
        expect(participant.taskCategories, isEmpty);
      }
    });

    test('mantém taskCategories imutável e isolada da lista recebida', () {
      final categories = <TaskCategory>[TaskCategory.operational];
      final participant = SpaceParticipant(
        id: 1,
        name: 'Participante',
        spaceUserRole: SpaceUserRole.participant,
        taskCategories: categories,
        score: 0,
        contributionPercentual: 0,
      );

      categories.add(TaskCategory.financial);

      expect(participant.taskCategories, <TaskCategory>[
        TaskCategory.operational,
      ]);
      expect(
        () => participant.taskCategories.add(TaskCategory.financial),
        throwsUnsupportedError,
      );
    });

    test('rejeita id, nome, papel, score ou percentual inválidos', () {
      for (final invalidJson in <Map<String, dynamic>>[
        _validJson()..['id'] = 0,
        _validJson()..['id'] = 1.0,
        _validJson()..['name'] = '   ',
        _validJson()..['spaceUserRole'] = null,
        _validJson()..['spaceUserRole'] = 'ROLE_UNKNOWN',
        _validJson()..['score'] = -1,
        _validJson()..['score'] = double.nan,
        _validJson()..['score'] = double.infinity,
        _validJson()..['score'] = '10',
        _validJson()..remove('contributionPercentual'),
        _validJson()..['contributionPercentual'] = -1,
        _validJson()..['contributionPercentual'] = double.nan,
        _validJson()..['contributionPercentual'] = double.infinity,
        _validJson()..['contributionPercentual'] = '0.5',
      ]) {
        expect(
          () => SpaceParticipant.fromJson(invalidJson),
          throwsFormatException,
        );
      }
    });

    test(
      'rejeita taskCategories que não seja lista ou contenha valor desconhecido',
      () {
        for (final invalidJson in <Map<String, dynamic>>[
          _validJson()..['taskCategories'] = 'OPERATIONAL',
          _validJson()..['taskCategories'] = <dynamic>[null],
          _validJson()..['taskCategories'] = <dynamic>['UNKNOWN'],
        ]) {
          expect(
            () => SpaceParticipant.fromJson(invalidJson),
            throwsFormatException,
          );
        }
      },
    );
  });
}

Map<String, dynamic> _validJson() {
  return <String, dynamic>{
    'id': 1,
    'name': 'Participante',
    'spaceUserRole': 'ROLE_SPACE_PARTICIPANT',
    'taskCategories': <dynamic>[],
    'score': 0,
    'contributionPercentual': 0,
  };
}
