import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';

abstract interface class TasksRepository {
  Future<TaskSummary> createTask({
    required String accessToken,
    required TaskCreation creation,
  });

  Future<TaskPageResult> fetchTasks({
    required String accessToken,
    TaskFilters filters = const TaskFilters(),
    int page = 0,
    int size = 10,
  });

  Future<TaskSummary> updateTask({
    required String accessToken,
    required int taskId,
    required TaskUpdate update,
  });

  Future<void> toggleTaskActive({
    required String accessToken,
    required int taskId,
  });
}
