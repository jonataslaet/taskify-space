import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

final class TaskFilters {
  const TaskFilters({
    this.description,
    this.score,
    this.active,
    this.categories = const <TaskCategory>{},
    this.minScore,
    this.maxScore,
  });

  final String? description;
  final num? score;
  final bool? active;
  final Set<TaskCategory> categories;
  final num? minScore;
  final num? maxScore;
}
