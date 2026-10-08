import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

final class TaskCategorySummary {
  const TaskCategorySummary({required this.id, required this.category});

  factory TaskCategorySummary.fromJson(Map<String, dynamic> json) {
    return TaskCategorySummary(
      id: _requiredPositiveInt(json, 'id'),
      category: TaskCategory.fromApiValue(json['name']),
    );
  }

  final int id;
  final TaskCategory category;

  String get name => category.apiValue;

  static int _requiredPositiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value <= 0) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value;
  }
}
