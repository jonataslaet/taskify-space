import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/presentation/confirm_task_execution_dialog.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets(
    'inicia com data informada e usuário autenticado como executor fixo',
    (tester) async {
      final tasksRepository = FakeTasksRepository();
      final spacesRepository = _spacesRepository(
        searchHandler: (_, _, _) async => const <SpaceParticipantSummary>[
          SpaceParticipantSummary(id: 1, name: 'Usuário de Teste'),
        ],
      );

      await _pumpDialog(
        tester,
        tasksRepository: tasksRepository,
        spacesRepository: spacesRepository,
      );

      expect(
        find.byKey(const ValueKey('confirm-task-execution-dialog')),
        findsOneWidget,
      );
      expect(find.text('Lavar a louça'), findsOneWidget);
      expect(find.text('21/08/2026 18:31'), findsOneWidget);
      expect(find.text('Usuário de Teste (você)'), findsOneWidget);
      expect(find.text('1 executor selecionado'), findsOneWidget);
      expect(spacesRepository.searchSpaceParticipantsCalls, 0);

      final currentUserChip = find.byKey(
        const ValueKey('confirm-task-execution-selected-executor-1'),
      );
      expect(tester.widget<InputChip>(currentUserChip).onDeleted, isNull);

      await _openExecutorSelector(tester);
      final selectorCurrentUserChip = find.byKey(
        const ValueKey('confirm-task-execution-executor-selection-1'),
      );
      expect(
        tester.widget<InputChip>(selectorCurrentUserChip).onDeleted,
        isNull,
      );
      await tester.enterText(
        find.byKey(
          const ValueKey('confirm-task-execution-executor-search-field'),
        ),
        'Usuário',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      final currentUserOption = find.byKey(
        const ValueKey('confirm-task-execution-executor-option-1'),
      );
      expect(
        tester.widget<CheckboxListTile>(currentUserOption).onChanged,
        isNull,
      );
      expect(find.text('Usuário de Teste (você)'), findsWidgets);
    },
  );

  testWidgets('usa username quando a sessão não possui nome', (tester) async {
    await _pumpDialog(
      tester,
      tasksRepository: FakeTasksRepository(),
      spacesRepository: _spacesRepository(),
      session: const AuthSession(
        id: 1,
        username: 'user@example.com',
        name: null,
        accessToken: 'access-token-confirm-test-only',
        refreshToken: 'refresh-token-confirm-test-only',
        role: 'ROLE_USER',
      ),
    );

    expect(find.text('user@example.com (você)'), findsOneWidget);
  });

  testWidgets('abre os pickers de data e hora e mantém a data civil', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      tasksRepository: FakeTasksRepository(),
      spacesRepository: _spacesRepository(),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-task-execution-date-time-field')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('21/08/2026 18:31'), findsOneWidget);
  });

  testWidgets(
    'busca apenas nome não vazio após debounce e preserva seleção entre buscas',
    (tester) async {
      final spacesRepository = _spacesRepository(
        searchHandler: (_, _, name) async => switch (name) {
          'Bel' => const <SpaceParticipantSummary>[
            SpaceParticipantSummary(id: 2, name: 'Bella antiga'),
            SpaceParticipantSummary(id: 2, name: 'Bella Laet'),
          ],
          'Joi' => const <SpaceParticipantSummary>[
            SpaceParticipantSummary(id: 3, name: 'Joice Laet'),
          ],
          _ => const <SpaceParticipantSummary>[],
        },
      );
      await _pumpDialog(
        tester,
        tasksRepository: FakeTasksRepository(),
        spacesRepository: spacesRepository,
      );
      await _openExecutorSelector(tester);

      expect(spacesRepository.searchSpaceParticipantsCalls, 0);
      final searchField = find.byKey(
        const ValueKey('confirm-task-execution-executor-search-field'),
      );
      await tester.enterText(searchField, '   ');
      await tester.pump(const Duration(milliseconds: 400));
      expect(spacesRepository.searchSpaceParticipantsCalls, 0);

      await tester.enterText(searchField, '  Bel  ');
      await tester.pump(const Duration(milliseconds: 349));
      expect(spacesRepository.searchSpaceParticipantsCalls, 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(spacesRepository.searchSpaceParticipantsCalls, 1);
      expect(spacesRepository.receivedParticipantSearchNames, ['Bel']);
      final bellaOption = find.byKey(
        const ValueKey('confirm-task-execution-executor-option-2'),
      );
      expect(bellaOption, findsOneWidget);
      expect(find.text('Bella antiga'), findsNothing);
      expect(find.text('Bella Laet'), findsOneWidget);
      await tester.tap(bellaOption);
      await tester.pump();

      await tester.enterText(searchField, 'Joi');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey('confirm-task-execution-executor-selection-2'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-task-execution-executor-option-3')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey('confirm-task-execution-executor-apply-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 executores selecionados'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('confirm-task-execution-selected-executor-2'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('confirm-task-execution-selected-executor-3'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('ignora resposta antiga de busca', (tester) async {
    final bellaResponse = Completer<List<SpaceParticipantSummary>>();
    final joiceResponse = Completer<List<SpaceParticipantSummary>>();
    final spacesRepository = _spacesRepository(
      searchHandler: (_, _, name) => switch (name) {
        'Bella' => bellaResponse.future,
        'Joice' => joiceResponse.future,
        _ => Future<List<SpaceParticipantSummary>>.value(const []),
      },
    );
    await _pumpDialog(
      tester,
      tasksRepository: FakeTasksRepository(),
      spacesRepository: spacesRepository,
    );
    await _openExecutorSelector(tester);
    final searchField = find.byKey(
      const ValueKey('confirm-task-execution-executor-search-field'),
    );

    await tester.enterText(searchField, 'Bella');
    await tester.pump(const Duration(milliseconds: 350));
    expect(spacesRepository.searchSpaceParticipantsCalls, 1);
    await tester.enterText(searchField, 'Joice');
    await tester.pump(const Duration(milliseconds: 350));
    expect(spacesRepository.searchSpaceParticipantsCalls, 2);

    joiceResponse.complete(const [
      SpaceParticipantSummary(id: 3, name: 'Joice Laet'),
    ]);
    await tester.pump();
    bellaResponse.complete(const [
      SpaceParticipantSummary(id: 2, name: 'Bella Laet'),
    ]);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('confirm-task-execution-executor-option-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('confirm-task-execution-executor-option-2')),
      findsNothing,
    );
  });

  testWidgets('envia seleção deduplicada e fecha com true após sucesso', (
    tester,
  ) async {
    bool? dialogResult;
    final tasksRepository = FakeTasksRepository(
      confirmTaskExecutionHandler: (_, _, _, _, _) async {},
    );
    final spacesRepository = _spacesRepository(
      searchHandler: (_, _, _) async => const [
        SpaceParticipantSummary(id: 2, name: 'Bella Laet'),
      ],
    );
    await _pumpDialog(
      tester,
      tasksRepository: tasksRepository,
      spacesRepository: spacesRepository,
      onResult: (result) => dialogResult = result,
    );

    await _openExecutorSelector(tester);
    await tester.enterText(
      find.byKey(
        const ValueKey('confirm-task-execution-executor-search-field'),
      ),
      'Bella',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('confirm-task-execution-executor-option-2')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey('confirm-task-execution-executor-apply-button'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('confirm-task-execution-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(tasksRepository.confirmTaskExecutionCalls, 1);
    expect(tasksRepository.receivedConfirmTaskExecutionAccessTokens, [
      _session.accessToken,
    ]);
    expect(tasksRepository.receivedConfirmTaskExecutionSpaceIds, [7]);
    expect(tasksRepository.receivedConfirmTaskExecutionTaskIds, [23]);
    expect(tasksRepository.receivedConfirmTaskExecutionExecutorIds, [
      <int>{2},
    ]);
    expect(tasksRepository.receivedConfirmTaskExecutionDates, [
      DateTime.utc(2026, 8, 21, 18, 31),
    ]);
    expect(dialogResult, isTrue);
    expect(
      find.byKey(const ValueKey('confirm-task-execution-dialog')),
      findsNothing,
    );
  });

  testWidgets('omite usersIds quando não há executores adicionais', (
    tester,
  ) async {
    final tasksRepository = FakeTasksRepository(
      confirmTaskExecutionHandler: (_, _, _, _, _) async {},
    );
    await _pumpDialog(
      tester,
      tasksRepository: tasksRepository,
      spacesRepository: _spacesRepository(),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-task-execution-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(tasksRepository.receivedConfirmTaskExecutionExecutorIds, [<int>{}]);
  });

  testWidgets('401 aciona expiração da sessão', (tester) async {
    var sessionExpiredCalls = 0;
    final tasksRepository = FakeTasksRepository(
      confirmTaskExecutionHandler: (_, _, _, _, _) async {
        throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401);
      },
    );
    await _pumpDialog(
      tester,
      tasksRepository: tasksRepository,
      spacesRepository: _spacesRepository(),
      onSessionExpired: () => sessionExpiredCalls += 1,
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-task-execution-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(sessionExpiredCalls, 1);
    expect(
      find.byKey(const ValueKey('confirm-task-execution-error')),
      findsNothing,
    );
  });

  testWidgets('403 permanece inline e permite tentar novamente', (
    tester,
  ) async {
    final tasksRepository = FakeTasksRepository(
      confirmTaskExecutionHandler: (_, _, _, _, _) async {
        throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403);
      },
    );
    await _pumpDialog(
      tester,
      tasksRepository: tasksRepository,
      spacesRepository: _spacesRepository(),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-task-execution-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Esta tarefa está inativa ou seu acesso não permite registrar a execução.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-task-execution-submit-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'resultado incerto bloqueia reenvio e orienta conferir histórico',
    (tester) async {
      final tasksRepository = FakeTasksRepository(
        confirmTaskExecutionHandler: (_, _, _, _, _) async {
          throw const ApiFailure(ApiFailureKind.network);
        },
      );
      await _pumpDialog(
        tester,
        tasksRepository: tasksRepository,
        spacesRepository: _spacesRepository(),
      );

      await tester.tap(
        find.byKey(const ValueKey('confirm-task-execution-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(tasksRepository.confirmTaskExecutionCalls, 1);
      expect(
        find.textContaining('confira o histórico antes de tentar novamente'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(
                const ValueKey('confirm-task-execution-submit-button'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Fechar'), findsOneWidget);
      final dateDecorator = tester.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(
            const ValueKey('confirm-task-execution-date-time-field'),
          ),
          matching: find.byType(InputDecorator),
        ),
      );
      final executorsDecorator = tester.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(
            const ValueKey('confirm-task-execution-executors-field'),
          ),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(dateDecorator.decoration.enabled, isFalse);
      expect(dateDecorator.isEmpty, isFalse);
      expect(executorsDecorator.decoration.enabled, isFalse);
      expect(executorsDecorator.isEmpty, isFalse);
    },
  );

  testWidgets('5xx é incerto e bloqueia reenvio', (tester) async {
    final tasksRepository = FakeTasksRepository(
      confirmTaskExecutionHandler: (_, _, _, _, _) async {
        throw const ApiFailure(ApiFailureKind.server, statusCode: 503);
      },
    );
    await _pumpDialog(
      tester,
      tasksRepository: tasksRepository,
      spacesRepository: _spacesRepository(),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-task-execution-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('confira o histórico'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-task-execution-submit-button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('404 é determinístico e mantém reenvio habilitado', (
    tester,
  ) async {
    final tasksRepository = FakeTasksRepository(
      confirmTaskExecutionHandler: (_, _, _, _, _) async {
        throw const ApiFailure(ApiFailureKind.unknown, statusCode: 404);
      },
    );
    await _pumpDialog(
      tester,
      tasksRepository: tasksRepository,
      spacesRepository: _spacesRepository(),
    );

    await tester.tap(
      find.byKey(const ValueKey('confirm-task-execution-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('A tarefa ou o espaço não foi encontrado.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-task-execution-submit-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('Cancelar'), findsOneWidget);
  });
}

const _session = AuthSession(
  id: 1,
  username: 'user@example.com',
  name: 'Usuário de Teste',
  accessToken: 'access-token-confirm-test-only',
  refreshToken: 'refresh-token-confirm-test-only',
  role: 'ROLE_USER',
);

const _task = TaskSummary(
  id: 23,
  spaceId: 7,
  description: 'Lavar a louça',
  score: 10,
  category: TaskCategory.operational,
  schedule: null,
  active: true,
  creatorName: 'Joice Laet',
);

FakeSpacesRepository _spacesRepository({
  SearchSpaceParticipantsHandler? searchHandler,
}) {
  return FakeSpacesRepository(
    (_) async => makeSpacePage(),
    searchParticipantsHandler: searchHandler,
  );
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required FakeTasksRepository tasksRepository,
  required FakeSpacesRepository spacesRepository,
  AuthSession session = _session,
  VoidCallback? onSessionExpired,
  ValueChanged<bool?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open-confirm-task-execution-dialog'),
            onPressed: () {
              unawaited(
                showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => ConfirmTaskExecutionDialog(
                    task: _task,
                    session: session,
                    tasksRepository: tasksRepository,
                    spacesRepository: spacesRepository,
                    initialExecutionDate: DateTime.utc(2026, 8, 21, 18, 31),
                    onSessionExpired: onSessionExpired,
                  ),
                ).then((result) => onResult?.call(result)),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(
    find.byKey(const ValueKey('open-confirm-task-execution-dialog')),
  );
  await tester.pumpAndSettle();
  expect(find.byType(ConfirmTaskExecutionDialog), findsOneWidget);
}

Future<void> _openExecutorSelector(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('confirm-task-execution-executors-field')),
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('confirm-task-execution-executor-selector')),
    findsOneWidget,
  );
}
