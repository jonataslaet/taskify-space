import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';

final class TaskCreation {
  const TaskCreation({
    required this.spaceId,
    required this.description,
    required this.score,
    required this.category,
    required this.active,
    required this.creatorName,
    required this.schedule,
  });

  final int spaceId;
  final String description;
  final num score;
  final TaskCategory category;
  final bool active;
  final String creatorName;
  final TaskScheduleSummary? schedule;

  Map<String, dynamic> toJson() {
    final taskFields = TaskUpdate(
      description: description,
      score: score,
      category: category,
      schedule: schedule,
    ).toJson();

    return <String, dynamic>{
      'spaceId': spaceId,
      'description': taskFields['description'],
      'score': taskFields['score'],
      'category': taskFields['category'],
      'active': active,
      'creatorName': creatorName.trim(),
      'schedule': taskFields['schedule'],
    };
  }
}
