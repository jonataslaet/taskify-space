import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

enum ParticipantSort {
  idAscending('id,asc'),
  idDescending('id,desc'),
  nameAscending('name,asc'),
  nameDescending('name,desc'),
  spaceUserRoleAscending('spaceUserRole,asc'),
  spaceUserRoleDescending('spaceUserRole,desc'),
  scoreAscending('score,asc'),
  scoreDescending('score,desc');

  const ParticipantSort(this.apiValue);

  final String apiValue;
}

final class SpaceParticipantFilters {
  const SpaceParticipantFilters({
    this.name,
    this.role,
    this.taskCategories = const <TaskCategory>{},
    this.sort,
  });

  final String? name;
  final SpaceUserRole? role;
  final Set<TaskCategory> taskCategories;
  final ParticipantSort? sort;
}
