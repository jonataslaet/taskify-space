import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category_summary.dart';

void main() {
  group('TaskCategorySummary', () {
    test('interpreta id e nome dinâmico normalizado', () {
      final summary = TaskCategorySummary.fromJson(<String, dynamic>{
        'id': 4,
        'name': '  HOUSEHOLD  ',
      });

      expect(summary.id, 4);
      expect(summary.category, TaskCategory.fromApiValue('HOUSEHOLD'));
      expect(summary.name, 'HOUSEHOLD');
    });

    test('rejeita id ou nome inválidos', () {
      for (final json in <Map<String, dynamic>>[
        <String, dynamic>{'id': 0, 'name': 'HOUSEHOLD'},
        <String, dynamic>{'id': 1.0, 'name': 'HOUSEHOLD'},
        <String, dynamic>{'id': 1, 'name': null},
        <String, dynamic>{'id': 1, 'name': '   '},
      ]) {
        expect(() => TaskCategorySummary.fromJson(json), throwsFormatException);
      }
    });
  });
}
