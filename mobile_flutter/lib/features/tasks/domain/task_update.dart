import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';

final class TaskUpdate {
  const TaskUpdate({
    required this.description,
    required this.score,
    required this.category,
    required this.schedule,
  });

  final String description;
  final num score;
  final TaskCategory category;
  final TaskScheduleSummary? schedule;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'description': description.trim(),
      'score': score,
      'category': category.apiValue,
      'schedule': switch (schedule) {
        final schedule? => <String, dynamic>{
          'localDates': schedule.localDates.map(_formatLocalDate).toList(),
          'frequence': schedule.frequency.apiValue,
        },
        null => null,
      },
    };
  }

  static String _formatLocalDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
