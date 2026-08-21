final class TaskExecutionSummary {
  TaskExecutionSummary({
    required this.id,
    required this.executionDate,
    required this.score,
    required List<String> executorNames,
  }) : executorNames = List<String>.unmodifiable(executorNames);

  factory TaskExecutionSummary.fromJson(Map<String, dynamic> json) {
    return TaskExecutionSummary(
      id: _requiredPositiveInt(json, 'id'),
      executionDate: _requiredExecutionDate(json, 'executionDate'),
      score: _requiredPositiveNumber(json, 'score'),
      executorNames: _requiredExecutorNames(json['executorNames']),
    );
  }

  final int id;
  final DateTime executionDate;
  final num score;
  final List<String> executorNames;

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

  static DateTime _requiredExecutionDate(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('Campo $key ausente ou inválido.');
    }

    final match = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$',
    ).firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Campo $key ausente ou inválido.');
    }

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final parsed = DateTime.utc(year, month, day, hour, minute);
    if (year == 0 ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute) {
      throw FormatException('Campo $key inválido.');
    }
    return parsed;
  }

  static List<String> _requiredExecutorNames(Object? value) {
    if (value is! List<dynamic>) {
      throw const FormatException('Campo executorNames ausente ou inválido.');
    }

    return <String>[
      for (var index = 0; index < value.length; index += 1)
        _requiredExecutorName(value[index], index),
    ];
  }

  static String _requiredExecutorName(Object? value, int index) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo executorNames[$index] inválido.');
    }
    return value.trim();
  }
}
