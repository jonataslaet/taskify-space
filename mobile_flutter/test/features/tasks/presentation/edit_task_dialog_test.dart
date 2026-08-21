import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';
import 'package:mobile_flutter/features/tasks/presentation/edit_task_dialog.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets(
    'preenche os campos e preserva a agenda ao editar somente a descrição',
    (tester) async {
      final task = _task(
        category: TaskCategory.financial,
        schedule: TaskScheduleSummary(
          localDates: [DateTime.utc(2026, 8, 9), DateTime.utc(2026, 8, 2)],
          frequency: TaskFrequency.weekly,
        ),
      );
      final repository = FakeTasksRepository(
        updateHandler: (_, _, _, update) async => _applyUpdate(task, update),
      );

      await _pumpDialog(tester, repository: repository, task: task);

      expect(
        _fieldText(tester, 'edit-task-description-field'),
        task.description,
      );
      expect(_fieldText(tester, 'edit-task-score-field'), '12.5');
      expect(
        _fieldText(tester, 'edit-task-dates-field'),
        '2026-08-02, 2026-08-09',
      );
      expect(find.text('Financeira'), findsOneWidget);
      expect(find.text('Semanal'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('edit-task-description-field')),
        '  Descrição atualizada  ',
      );
      await _submitAndSettle(tester);

      expect(repository.updateTaskCalls, 1);
      expect(repository.receivedUpdateAccessTokens, [_accessToken]);
      expect(repository.receivedUpdateSpaceIds, [task.spaceId]);
      expect(repository.receivedTaskIds, [task.id]);
      final update = repository.receivedTaskUpdates.single;
      expect(update.description, 'Descrição atualizada');
      expect(update.score, 12.5);
      expect(update.category, TaskCategory.financial);
      expect(update.schedule?.frequency, TaskFrequency.weekly);
      expect(update.schedule?.localDates, [
        DateTime.utc(2026, 8, 2),
        DateTime.utc(2026, 8, 9),
      ]);
      expect(find.byType(EditTaskDialog), findsNothing);
    },
  );

  testWidgets('desligar agenda envia schedule nulo', (tester) async {
    final task = _task(
      schedule: TaskScheduleSummary(
        localDates: [DateTime.utc(2026, 8, 2)],
        frequency: TaskFrequency.once,
      ),
    );
    final repository = FakeTasksRepository(
      updateHandler: (_, _, _, update) async => _applyUpdate(task, update),
    );

    await _pumpDialog(tester, repository: repository, task: task);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-task-schedule-switch')),
    );

    expect(
      find.byKey(const ValueKey('edit-task-frequency-field')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('edit-task-dates-field')), findsNothing);

    await _submitAndSettle(tester);

    expect(repository.updateTaskCalls, 1);
    expect(repository.receivedTaskUpdates.single.schedule, isNull);
  });

  testWidgets('permite salvar agenda diária sem datas', (tester) async {
    final task = _task(
      schedule: TaskScheduleSummary(
        localDates: const <DateTime>[],
        frequency: TaskFrequency.daily,
      ),
    );
    final repository = FakeTasksRepository(
      updateHandler: (_, _, _, update) async => _applyUpdate(task, update),
    );

    await _pumpDialog(tester, repository: repository, task: task);

    expect(_fieldText(tester, 'edit-task-dates-field'), isEmpty);
    expect(find.text('Diária'), findsOneWidget);

    await _submitAndSettle(tester);

    expect(repository.updateTaskCalls, 1);
    final schedule = repository.receivedTaskUpdates.single.schedule!;
    expect(schedule.frequency, TaskFrequency.daily);
    expect(schedule.localDates, isEmpty);
  });

  testWidgets('exige datas ao trocar a frequência diária por semanal', (
    tester,
  ) async {
    final task = _task(
      schedule: TaskScheduleSummary(
        localDates: const <DateTime>[],
        frequency: TaskFrequency.daily,
      ),
    );
    final repository = FakeTasksRepository(
      updateHandler: (_, _, _, update) async => _applyUpdate(task, update),
    );

    await _pumpDialog(tester, repository: repository, task: task);
    await _selectFrequency(tester, 'Semanal');
    await _submitAndSettle(tester);

    expect(repository.updateTaskCalls, 0);
    expect(
      find.text('Informe ao menos uma data para a agenda.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'agenda habilitada exige frequência e datas e normaliza duplicatas',
    (tester) async {
      final task = _task();
      final repository = FakeTasksRepository(
        updateHandler: (_, _, _, update) async => _applyUpdate(task, update),
      );

      await _pumpDialog(tester, repository: repository, task: task);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('edit-task-schedule-switch')),
      );
      await _submitAndSettle(tester);

      expect(repository.updateTaskCalls, 0);
      expect(find.text('Informe a frequência da agenda.'), findsOneWidget);
      expect(
        find.text('Informe ao menos uma data para a agenda.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-task-dates-field')),
        '2026-08-09, 2026-08-02\n2026-08-09',
      );
      await _selectFrequency(tester, 'Semanal');
      await _submitAndSettle(tester);

      expect(repository.updateTaskCalls, 1);
      final schedule = repository.receivedTaskUpdates.single.schedule!;
      expect(schedule.frequency, TaskFrequency.weekly);
      expect(schedule.localDates, [
        DateTime.utc(2026, 8, 2),
        DateTime.utc(2026, 8, 9),
      ]);
    },
  );

  testWidgets('descrição e pontuação inválidas não chamam a rede', (
    tester,
  ) async {
    final task = _task();
    final repository = FakeTasksRepository(
      updateHandler: (_, _, _, update) async => _applyUpdate(task, update),
    );

    await _pumpDialog(tester, repository: repository, task: task);
    await tester.enterText(
      find.byKey(const ValueKey('edit-task-description-field')),
      '   ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-task-score-field')),
      '0',
    );
    await _submitAndSettle(tester);

    expect(repository.updateTaskCalls, 0);
    expect(find.text('Informe a descrição da tarefa.'), findsOneWidget);
    expect(find.textContaining('pontuação positiva'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit-task-description-field')),
      List<String>.filled(256, 'a').join(),
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-task-score-field')),
      '1.234',
    );
    await _submitAndSettle(tester);

    expect(repository.updateTaskCalls, 0);
    expect(find.textContaining('máximo 255 caracteres'), findsOneWidget);
    expect(find.textContaining('até duas casas decimais'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit-task-description-field')),
      'Descrição válida',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-task-score-field')),
      List<String>.filled(37, '9').join(),
    );
    await _submitAndSettle(tester);

    expect(repository.updateTaskCalls, 0);
    expect(find.textContaining('até 36 dígitos inteiros'), findsOneWidget);
  });

  testWidgets('bloqueia envio duplicado enquanto a atualização está pendente', (
    tester,
  ) async {
    final task = _task();
    final response = Completer<TaskSummary>();
    final repository = FakeTasksRepository(
      updateHandler: (_, _, _, _) => response.future,
    );

    await _pumpDialog(tester, repository: repository, task: task);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-task-submit-button')),
      settle: false,
    );

    expect(repository.updateTaskCalls, 1);
    expect(find.byKey(const ValueKey('edit-task-progress')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('edit-task-submit-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('edit-task-submit-button')));
    await tester.pump();
    expect(repository.updateTaskCalls, 1);

    response.complete(task);
    await tester.pumpAndSettle();
    expect(find.byType(EditTaskDialog), findsNothing);
  });

  testWidgets('401 chama onSessionExpired e libera novamente o formulário', (
    tester,
  ) async {
    final task = _task();
    var sessionExpiredCalls = 0;
    final repository = FakeTasksRepository(
      updateHandler: (_, _, _, _) async =>
          throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401),
    );

    await _pumpDialog(
      tester,
      repository: repository,
      task: task,
      onSessionExpired: () => sessionExpiredCalls += 1,
    );
    await _submitAndSettle(tester);

    expect(repository.updateTaskCalls, 1);
    expect(sessionExpiredCalls, 1);
    expect(find.byKey(const ValueKey('edit-task-error')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('edit-task-submit-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    '403 não expira a sessão, mostra erro e permite tentar novamente',
    (tester) async {
      final task = _task();
      var sessionExpiredCalls = 0;
      var attempts = 0;
      final repository = FakeTasksRepository(
        updateHandler: (_, _, _, update) async {
          attempts += 1;
          if (attempts == 1) {
            throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403);
          }
          return _applyUpdate(task, update);
        },
      );

      await _pumpDialog(
        tester,
        repository: repository,
        task: task,
        onSessionExpired: () => sessionExpiredCalls += 1,
      );
      await _submitAndSettle(tester);

      expect(repository.updateTaskCalls, 1);
      expect(sessionExpiredCalls, 0);
      expect(
        find.text('Você não tem mais permissão para editar esta tarefa.'),
        findsOneWidget,
      );

      await _submitAndSettle(tester);
      expect(repository.updateTaskCalls, 2);
      expect(sessionExpiredCalls, 0);
      expect(find.byType(EditTaskDialog), findsNothing);
    },
  );

  testWidgets('409 mostra conflito e permite tentar novamente', (tester) async {
    final task = _task();
    var attempts = 0;
    final repository = FakeTasksRepository(
      updateHandler: (_, _, _, update) async {
        attempts += 1;
        if (attempts == 1) {
          throw const ApiFailure(ApiFailureKind.validation, statusCode: 409);
        }
        return _applyUpdate(task, update);
      },
    );

    await _pumpDialog(tester, repository: repository, task: task);
    await _submitAndSettle(tester);

    expect(
      find.text('Já existe outra tarefa com esta descrição no espaço.'),
      findsOneWidget,
    );
    expect(repository.updateTaskCalls, 1);

    await _submitAndSettle(tester);
    expect(repository.updateTaskCalls, 2);
    expect(find.byType(EditTaskDialog), findsNothing);
  });
}

const _accessToken = 'access-token-edit-task-test-only';

Future<void> _pumpDialog(
  WidgetTester tester, {
  required FakeTasksRepository repository,
  required TaskSummary task,
  VoidCallback? onSessionExpired,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open-edit-task-dialog'),
            onPressed: () {
              unawaited(
                showDialog<TaskSummary>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => EditTaskDialog(
                    task: task,
                    accessToken: _accessToken,
                    tasksRepository: repository,
                    onSessionExpired: onSessionExpired,
                  ),
                ),
              );
            },
            child: const Text('Editar'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-edit-task-dialog')));
  await tester.pumpAndSettle();
  expect(find.byType(EditTaskDialog), findsOneWidget);
}

Future<void> _submitAndSettle(WidgetTester tester) {
  return _tapVisible(
    tester,
    find.byKey(const ValueKey('edit-task-submit-button')),
  );
}

Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _selectFrequency(WidgetTester tester, String label) async {
  final dropdown = find.byKey(const ValueKey('edit-task-frequency-field'));
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

TaskSummary _task({
  TaskCategory category = TaskCategory.operational,
  TaskScheduleSummary? schedule,
}) {
  return TaskSummary(
    id: 11,
    spaceId: 7,
    description: 'Pagar conta de água',
    score: 12.5,
    category: category,
    schedule: schedule,
    active: true,
    creatorName: 'Joice Laet',
  );
}

TaskSummary _applyUpdate(TaskSummary task, TaskUpdate update) {
  return TaskSummary(
    id: task.id,
    spaceId: task.spaceId,
    description: update.description,
    score: update.score,
    category: update.category,
    schedule: update.schedule,
    active: task.active,
    creatorName: task.creatorName,
  );
}
