import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';

final class TaskSummary {
  const TaskSummary({
    required this.id,
    required this.spaceId,
    required this.description,
    required this.score,
    required this.category,
    required this.schedule,
    required this.active,
    required this.creatorName,
  });

  factory TaskSummary.fromJson(Map<String, dynamic> json) {
    final rawSchedule = json['schedule'];
    return TaskSummary(
      id: _requiredPositiveInt(json, 'id'),
      spaceId: _requiredPositiveInt(json, 'spaceId'),
      description: _requiredString(json, 'description'),
      score: _requiredPositiveNumber(json, 'score'),
      category: TaskCategory.fromApiValue(json['category']),
      schedule: rawSchedule == null
          ? null
          : TaskScheduleSummary.fromJson(
              _stringKeyedMap(rawSchedule, field: 'schedule'),
            ),
      active: _requiredBool(json, 'active'),
      creatorName: _optionalString(json, 'creatorName'),
    );
  }

  final int id;
  final int spaceId;
  final String description;
  final num score;
  final TaskCategory category;
  final TaskScheduleSummary? schedule;
  final bool active;
  final String? creatorName;

  static int _requiredPositiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value <= 0) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value;
  }

  static num _requiredPositiveNumber(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || !value.isFinite || value <= 0) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo $key inválido.');
    }
    return value.trim();
  }

  static Map<String, dynamic> _stringKeyedMap(
    Object? value, {
    required String field,
  }) {
    if (value is! Map) {
      throw FormatException('Campo $field inválido.');
    }

    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('Campo $field inválido.');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }
}
