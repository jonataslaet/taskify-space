final class TaskCategory {
  const TaskCategory._(this.apiValue);

  static const operational = TaskCategory._('OPERATIONAL');
  static const financial = TaskCategory._('FINANCIAL');
  static const personal = TaskCategory._('PERSONAL');

  static const values = <TaskCategory>[operational, financial, personal];

  final String apiValue;

  static TaskCategory fromApiValue(Object? value) {
    if (value is! String) {
      throw const FormatException('Campo category ausente ou inválido.');
    }

    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw const FormatException('Campo category ausente ou inválido.');
    }

    for (final category in values) {
      if (category.apiValue == normalizedValue) {
        return category;
      }
    }
    return TaskCategory._(normalizedValue);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskCategory && other.apiValue == apiValue;
  }

  @override
  int get hashCode => apiValue.hashCode;

  @override
  String toString() => 'TaskCategory($apiValue)';
}
