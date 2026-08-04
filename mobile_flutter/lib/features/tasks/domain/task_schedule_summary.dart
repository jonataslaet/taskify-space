enum TaskFrequency {
  once('ONCE'),
  daily('DAILY'),
  monthly('MONTHLY'),
  weekly('WEEKLY'),
  yearly('YEARLY');

  const TaskFrequency(this.apiValue);

  final String apiValue;

  static TaskFrequency fromApiValue(Object? value) {
    if (value is! String) {
      throw const FormatException(
        'Campo schedule.frequence ausente ou inválido.',
      );
    }

    final normalizedValue = value.trim();
    for (final frequency in values) {
      if (frequency.apiValue == normalizedValue) {
        return frequency;
      }
    }
    throw const FormatException('Campo schedule.frequence inválido.');
  }
}

final class TaskScheduleSummary {
  TaskScheduleSummary({
    required List<DateTime> localDates,
    required this.frequency,
  }) : localDates = List<DateTime>.unmodifiable(localDates);

  factory TaskScheduleSummary.fromJson(Map<String, dynamic> json) {
    final rawLocalDates = json['localDates'];
    if (rawLocalDates is! List<dynamic>) {
      throw const FormatException(
        'Campo schedule.localDates ausente ou inválido.',
      );
    }
    if (rawLocalDates.isEmpty) {
      throw const FormatException(
        'Campo schedule.localDates deve conter ao menos uma data.',
      );
    }

    return TaskScheduleSummary(
      localDates: <DateTime>[
        for (var index = 0; index < rawLocalDates.length; index += 1)
          _parseLocalDate(rawLocalDates[index], index),
      ],
      frequency: TaskFrequency.fromApiValue(json['frequence']),
    );
  }

  final List<DateTime> localDates;
  final TaskFrequency frequency;

  static DateTime _parseLocalDate(Object? value, int index) {
    if (value is! String) {
      throw FormatException('Campo schedule.localDates[$index] inválido.');
    }

    final normalizedValue = value.trim();
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(normalizedValue);
    if (match == null) {
      throw FormatException('Campo schedule.localDates[$index] inválido.');
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw FormatException('Campo schedule.localDates[$index] inválido.');
    }
    return parsed;
  }
}
