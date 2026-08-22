import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

final class SpaceParticipant {
  SpaceParticipant({
    required this.id,
    required this.name,
    required this.spaceUserRole,
    required List<TaskCategory> taskCategories,
    required this.score,
  }) : taskCategories = List<TaskCategory>.unmodifiable(taskCategories);

  factory SpaceParticipant.fromJson(Map<String, dynamic> json) {
    return SpaceParticipant(
      id: _requiredPositiveInt(json, 'id'),
      name: _requiredString(json, 'name'),
      spaceUserRole: SpaceUserRole.fromApiValue(json['spaceUserRole']),
      taskCategories: _taskCategories(json['taskCategories']),
      score: _requiredNonNegativeNumber(json, 'score'),
    );
  }

  final int id;
  final String name;
  final SpaceUserRole spaceUserRole;
  final List<TaskCategory> taskCategories;
  final num score;

  static int _requiredPositiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value <= 0) {
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

  static List<TaskCategory> _taskCategories(Object? value) {
    if (value == null) {
      return const <TaskCategory>[];
    }
    if (value is! List<dynamic>) {
      throw const FormatException('Campo taskCategories inválido.');
    }

    return <TaskCategory>[
      for (var index = 0; index < value.length; index += 1)
        _taskCategory(value[index], index),
    ];
  }

  static TaskCategory _taskCategory(Object? value, int index) {
    if (value is! String) {
      throw FormatException('Campo taskCategories[$index] inválido.');
    }

    final normalizedValue = value.trim();
    for (final category in TaskCategory.values) {
      if (category.apiValue == normalizedValue) {
        return category;
      }
    }
    throw FormatException('Campo taskCategories[$index] inválido.');
  }

  static num _requiredNonNegativeNumber(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || !value.isFinite || value < 0) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value;
  }
}
