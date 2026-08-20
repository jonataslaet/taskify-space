import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/presentation/create_task_dialog.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('inicia com campos vazios e valores padrão', (tester) async {
    final repository = FakeTasksRepository();

    await _pumpDialog(tester, repository: repository);

    expect(find.text('Nova tarefa'), findsOneWidget);
    expect(find.text('Ativa · Criada por $_creatorName'), findsOneWidget);
    expect(_fieldText(tester, 'create-task-description-field'), isEmpty);
    expect(_fieldText(tester, 'create-task-score-field'), isEmpty);
    expect(
      tester
          .widget<DropdownButtonFormField<TaskCategory>>(
            find.byKey(const ValueKey('create-task-category-field')),
          )
          .initialValue,
      TaskCategory.operational,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('create-task-schedule-switch')),
          )
          .value,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('create-task-frequency-field')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('create-task-dates-field')), findsNothing);
    expect(repository.createTaskCalls, 0);
  });

  testWidgets(
    'envia agenda normalizada e todos os campos obrigatórios da criação',
    (tester) async {
      final repository = FakeTasksRepository(
        createHandler: (_, creation) async => _createdTask(creation),
      );

      await _pumpDialog(tester, repository: repository);
      await tester.enterText(
        find.byKey(const ValueKey('create-task-description-field')),
        '  Pagar conta de água  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-task-score-field')),
        '80,00',
      );
      await _selectDropdownOption(
        tester,
        fieldKey: 'create-task-category-field',
        optionLabel: 'Financeira',
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('create-task-schedule-switch')),
      );
      await _selectDropdownOption(
        tester,
        fieldKey: 'create-task-frequency-field',
        optionLabel: 'Semanal',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-task-dates-field')),
        '2024-02-29, 2024-02-27\n2024-02-28; 2024-02-29',
      );

      await _submitAndSettle(tester);

      expect(repository.createTaskCalls, 1);
      expect(repository.receivedCreateAccessTokens, [_accessToken]);
      final creation = repository.receivedTaskCreations.single;
      expect(creation.spaceId, _spaceId);
      expect(creation.description, 'Pagar conta de água');
      expect(creation.score, 80);
      expect(creation.category, TaskCategory.financial);
      expect(creation.active, isTrue);
      expect(creation.creatorName, _creatorName);
      expect(creation.schedule?.frequency, TaskFrequency.weekly);
      expect(creation.schedule?.localDates, [
        DateTime.utc(2024, 2, 27),
        DateTime.utc(2024, 2, 28),
        DateTime.utc(2024, 2, 29),
      ]);
      expect(creation.toJson(), <String, dynamic>{
        'spaceId': _spaceId,
        'description': 'Pagar conta de água',
        'score': 80,
        'category': 'FINANCIAL',
        'active': true,
        'creatorName': _creatorName,
        'schedule': <String, dynamic>{
          'localDates': <String>['2024-02-27', '2024-02-28', '2024-02-29'],
          'frequence': 'WEEKLY',
        },
      });
      expect(find.byType(CreateTaskDialog), findsNothing);
    },
  );

  testWidgets('dados inválidos não chamam o repositório', (tester) async {
    final repository = FakeTasksRepository(
      createHandler: (_, creation) async => _createdTask(creation),
    );

    await _pumpDialog(tester, repository: repository);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('create-task-schedule-switch')),
    );
    await _submitAndSettle(tester);

    expect(repository.createTaskCalls, 0);
    expect(find.text('Informe a descrição da tarefa.'), findsOneWidget);
    expect(find.textContaining('pontuação positiva'), findsOneWidget);
    expect(find.text('Informe a frequência da agenda.'), findsOneWidget);
    expect(
      find.text('Informe ao menos uma data para a agenda.'),
      findsOneWidget,
    );
  });

  for (final failureCase in <({String label, ApiFailure failure})>[
    (label: 'timeout', failure: const ApiFailure(ApiFailureKind.timeout)),
    (label: 'network', failure: const ApiFailure(ApiFailureKind.network)),
    (
      label: 'malformedResponse',
      failure: const ApiFailure(ApiFailureKind.malformedResponse),
    ),
    (label: 'unknown', failure: const ApiFailure(ApiFailureKind.unknown)),
  ]) {
    testWidgets(
      '${failureCase.label} bloqueia reenvio e troca Cancelar por Fechar',
      (tester) async {
        final repository = FakeTasksRepository(
          createHandler: (_, _) async => throw failureCase.failure,
        );

        await _pumpDialog(tester, repository: repository);
        await _fillMinimumValidForm(tester);
        await _submitAndSettle(tester);

        expect(repository.createTaskCalls, 1);
        expect(find.byKey(const ValueKey('create-task-error')), findsOneWidget);
        expect(find.text('Cancelar'), findsNothing);
        expect(find.text('Fechar'), findsOneWidget);
        final submitButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey('create-task-submit-button')),
        );
        expect(submitButton.onPressed, isNull);

        await tester.tap(
          find.byKey(const ValueKey('create-task-submit-button')),
        );
        await tester.pump();
        expect(repository.createTaskCalls, 1);
      },
    );
  }

  testWidgets('401 chama onSessionExpired e libera novamente o formulário', (
    tester,
  ) async {
    var sessionExpiredCalls = 0;
    final repository = FakeTasksRepository(
      createHandler: (_, _) async =>
          throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401),
    );

    await _pumpDialog(
      tester,
      repository: repository,
      onSessionExpired: () => sessionExpiredCalls += 1,
    );
    await _fillMinimumValidForm(tester);
    await _submitAndSettle(tester);

    expect(repository.createTaskCalls, 1);
    expect(sessionExpiredCalls, 1);
    expect(find.byKey(const ValueKey('create-task-error')), findsNothing);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Fechar'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('create-task-submit-button')),
          )
          .onPressed,
      isNotNull,
    );
  });
}

const _spaceId = 7;
const _creatorName = 'Joice Laet';
const _accessToken = 'access-token-create-task-test-only';

Future<void> _pumpDialog(
  WidgetTester tester, {
  required FakeTasksRepository repository,
  VoidCallback? onSessionExpired,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open-create-task-dialog'),
            onPressed: () {
              unawaited(
                showDialog<TaskSummary>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => CreateTaskDialog(
                    spaceId: _spaceId,
                    creatorName: _creatorName,
                    accessToken: _accessToken,
                    tasksRepository: repository,
                    onSessionExpired: onSessionExpired,
                  ),
                ),
              );
            },
            child: const Text('Criar'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-create-task-dialog')));
  await tester.pumpAndSettle();
  expect(find.byType(CreateTaskDialog), findsOneWidget);
}

Future<void> _fillMinimumValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('create-task-description-field')),
    'Tarefa válida',
  );
  await tester.enterText(
    find.byKey(const ValueKey('create-task-score-field')),
    '10',
  );
}

Future<void> _submitAndSettle(WidgetTester tester) {
  return _tapVisible(
    tester,
    find.byKey(const ValueKey('create-task-submit-button')),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownOption(
  WidgetTester tester, {
  required String fieldKey,
  required String optionLabel,
}) async {
  final dropdown = find.byKey(ValueKey(fieldKey));
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionLabel).last);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

TaskSummary _createdTask(TaskCreation creation) {
  return TaskSummary(
    id: 11,
    spaceId: creation.spaceId,
    description: creation.description,
    score: creation.score,
    category: creation.category,
    schedule: creation.schedule,
    active: creation.active,
    creatorName: creation.creatorName,
  );
}
