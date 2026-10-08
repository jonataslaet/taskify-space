import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

void main() {
  group('TaskCategory', () {
    test('preserva categorias conhecidas e aceita nomes dinâmicos', () {
      expect(
        TaskCategory.fromApiValue(' OPERATIONAL '),
        same(TaskCategory.operational),
      );

      final custom = TaskCategory.fromApiValue('  HOUSEHOLD  ');

      expect(custom.apiValue, 'HOUSEHOLD');
      expect(custom, TaskCategory.fromApiValue('HOUSEHOLD'));
      expect(custom.hashCode, TaskCategory.fromApiValue('HOUSEHOLD').hashCode);
      expect(custom, isNot(TaskCategory.operational));
    });

    test('mantém a lista fixa usada pelos filtros existentes', () {
      expect(TaskCategory.values, <TaskCategory>[
        TaskCategory.operational,
        TaskCategory.financial,
        TaskCategory.personal,
      ]);
    });

    test('rejeita valores ausentes, não textuais ou em branco', () {
      for (final value in <Object?>[null, 1, true, '', '   ']) {
        expect(() => TaskCategory.fromApiValue(value), throwsFormatException);
      }
    });
  });
}
