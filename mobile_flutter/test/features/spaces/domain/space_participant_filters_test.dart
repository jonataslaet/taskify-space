import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

void main() {
  group('SpaceParticipantFilters', () {
    test('mantém todos os filtros suportados', () {
      const filters = SpaceParticipantFilters(
        name: 'Joice',
        role: SpaceUserRole.manager,
        taskCategories: <TaskCategory>{
          TaskCategory.operational,
          TaskCategory.financial,
        },
        sort: ParticipantSort.scoreDescending,
      );

      expect(filters.name, 'Joice');
      expect(filters.role, SpaceUserRole.manager);
      expect(filters.taskCategories, <TaskCategory>{
        TaskCategory.operational,
        TaskCategory.financial,
      });
      expect(filters.sort, ParticipantSort.scoreDescending);
    });

    test('oferece somente ordenações aceitas pelo backend', () {
      expect(ParticipantSort.values.map((sort) => sort.apiValue), <String>[
        'id,asc',
        'id,desc',
        'name,asc',
        'name,desc',
        'spaceUserRole,asc',
        'spaceUserRole,desc',
        'score,asc',
        'score,desc',
      ]);
    });

    test('usa filtros vazios por padrão', () {
      const filters = SpaceParticipantFilters();

      expect(filters.name, isNull);
      expect(filters.role, isNull);
      expect(filters.taskCategories, isEmpty);
      expect(filters.sort, isNull);
    });
  });
}
