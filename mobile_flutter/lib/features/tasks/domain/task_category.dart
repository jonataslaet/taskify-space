enum TaskCategory {
  operational('OPERATIONAL'),
  financial('FINANCIAL');

  const TaskCategory(this.apiValue);

  final String apiValue;

  static TaskCategory fromApiValue(Object? value) {
    if (value is! String) {
      throw const FormatException('Campo category ausente ou inválido.');
    }

    final normalizedValue = value.trim();
    for (final category in values) {
      if (category.apiValue == normalizedValue) {
        return category;
      }
    }
    throw const FormatException('Campo category inválido.');
  }
}
