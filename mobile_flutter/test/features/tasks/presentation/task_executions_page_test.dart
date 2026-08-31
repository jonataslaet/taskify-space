import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/task_execution_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_execution_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';
import 'package:mobile_flutter/features/tasks/presentation/task_executions_page.dart';

void main() {
  testWidgets('carrega e apresenta as execuções no contexto da tarefa', (
    tester,
  ) async {
    final response = Completer<TaskExecutionPageResult>();
    final repository = _FakeTasksRepository((_, _, _, _, _) => response.future);

    await tester.pumpWidget(_testApp(repository));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('task-executions-loading')),
      findsOneWidget,
    );
    expect(repository.fetchCalls, 1);
    expect(repository.accessTokens, [_session.accessToken]);
    expect(repository.spaceIds, [7]);
    expect(repository.taskIds, [23]);
    expect(repository.pages, [0]);
    expect(repository.sizes, [10]);

    response.complete(
      _page(
        content: [
          _execution(
            id: 1,
            score: 90,
            executorNames: const [
              'Bella Laet',
              'Joice Laet',
              'Jonatas Laet',
              'Ralph Laet',
            ],
          ),
        ],
        totalElements: 1,
        totalPages: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-executions-list')), findsOneWidget);
    expect(find.text('Residência do Casal'), findsOneWidget);
    expect(find.text('Lavar a louça'), findsOneWidget);
    expect(find.text('1 execução encontrada'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('task-executions-card-1')),
      findsOneWidget,
    );
    expect(find.text('21/08/2026 18:31'), findsOneWidget);
    expect(find.text('90 pontos'), findsOneWidget);
    expect(find.text('Bella Laet'), findsNothing);
    expect(find.text('Joice Laet'), findsNothing);
  });

  testWidgets('mostra os executores somente após o clique no ícone', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [
          _execution(id: 1, executorNames: const ['Bella Laet', 'Joice Laet']),
        ],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Bella Laet'), findsNothing);
    expect(find.text('Joice Laet'), findsNothing);

    final executorsButton = find.byKey(
      const ValueKey('task-executions-executors-button-1'),
    );
    expect(
      tester.getSemantics(executorsButton),
      matchesSemantics(
        label: 'Ver executores da execução de 21/08/2026 18:31',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(executorsButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('task-executions-executors-dialog-1')),
      findsOneWidget,
    );
    expect(find.text('Executores'), findsOneWidget);
    expect(find.text('Bella Laet'), findsOneWidget);
    expect(find.text('Joice Laet'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('task-executions-executors-close')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bella Laet'), findsNothing);
  });

  testWidgets('informa quando a execução não possui executores', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_execution(id: 2)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('task-executions-executors-button-2')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum executor informado.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('task-executions-executors-empty-2')),
      findsOneWidget,
    );
  });

  testWidgets('mostra a ação de sair em cada execução com semântica', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_execution(id: 1), _execution(id: 2)],
        number: page,
        size: size,
        totalElements: 2,
        totalPages: 1,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    final firstButton = find.byKey(
      const ValueKey('task-executions-remove-button-1'),
    );
    final secondButton = find.byKey(
      const ValueKey('task-executions-remove-button-2'),
    );
    expect(firstButton, findsOneWidget);
    expect(secondButton, findsOneWidget);
    expect(
      tester.getSemantics(firstButton),
      matchesSemantics(
        label: 'Sair da execução de 21/08/2026 18:31',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('mostra a confirmação exata e cancelar não chama a API', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_execution(id: 7)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('task-executions-remove-button-7')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('task-executions-remove-dialog-7')),
      findsOneWidget,
    );
    expect(
      find.text('Tem certeza disso que deseja se excluir dessa execução?'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('task-executions-remove-cancel-7')),
    );
    await tester.pumpAndSettle();

    expect(repository.removeCalls, 0);
    expect(
      find.byKey(const ValueKey('task-executions-remove-dialog-7')),
      findsNothing,
    );
  });

  testWidgets('confirma a saída, informa sucesso e recarrega a página', (
    tester,
  ) async {
    var removed = false;
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: removed ? const [] : [_execution(id: 9)],
        number: page,
        size: size,
        totalElements: removed ? 0 : 1,
        totalPages: removed ? 0 : 1,
      ),
      removeCurrentUserFromTaskExecutionHandler:
          (accessToken, spaceId, taskId, taskExecutionId) async {
            removed = true;
          },
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('task-executions-remove-button-9')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('task-executions-remove-confirm-9')),
    );
    await tester.pumpAndSettle();

    expect(repository.removeCalls, 1);
    expect(repository.removeAccessTokens, [_session.accessToken]);
    expect(repository.removeSpaceIds, [7]);
    expect(repository.removeTaskIds, [23]);
    expect(repository.removedExecutionIds, [9]);
    expect(repository.fetchCalls, 2);
    expect(repository.pages, [0, 0]);
    expect(repository.sizes, [10, 10]);
    expect(
      find.byKey(const ValueKey('task-execution-removed-message')),
      findsOneWidget,
    );
    expect(find.text('Você saiu desta execução.'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-executions-empty')), findsOneWidget);
  });

  testWidgets('encerra a sessão quando a remoção recebe 401', (tester) async {
    var sessionExpiredCalls = 0;
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_execution(id: 11)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
      removeCurrentUserFromTaskExecutionHandler: (_, _, _, _) async {
        throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401);
      },
    );

    await tester.pumpWidget(
      _testApp(repository, onSessionExpired: () => sessionExpiredCalls += 1),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('task-executions-remove-button-11')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('task-executions-remove-confirm-11')),
    );
    await tester.pumpAndSettle();

    expect(repository.removeCalls, 1);
    expect(sessionExpiredCalls, 1);
    expect(repository.fetchCalls, 1);
    expect(
      find.byKey(const ValueKey('task-execution-remove-error')),
      findsNothing,
    );
  });

  testWidgets('mantém a lista e informa erro quando a remoção recebe 403', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_execution(id: 12)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
      removeCurrentUserFromTaskExecutionHandler: (_, _, _, _) async {
        throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403);
      },
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('task-executions-remove-button-12')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('task-executions-remove-confirm-12')),
    );
    await tester.pumpAndSettle();

    expect(repository.removeCalls, 1);
    expect(repository.fetchCalls, 1);
    expect(
      find.byKey(const ValueKey('task-execution-remove-error')),
      findsOneWidget,
    );
    expect(
      find.text('Você não tem permissão para sair desta execução.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('task-executions-card-12')),
      findsOneWidget,
    );
  });

  testWidgets('apresenta estado vazio', (tester) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(number: page, size: size),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-executions-empty')), findsOneWidget);
    expect(
      find.text('Nenhuma execução foi encontrada para esta tarefa.'),
      findsOneWidget,
    );
  });

  testWidgets('permite navegar e alterar a quantidade por página', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_execution(id: page + 1)],
        number: page,
        size: size,
        totalElements: 21,
        totalPages: 3,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('task-executions-card-1')),
      findsOneWidget,
    );
    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('task-executions-page-1')),
    );
    await tester.pumpAndSettle();

    expect(repository.pages, [0, 1]);
    expect(repository.sizes, [10, 10]);
    expect(
      find.byKey(const ValueKey('task-executions-card-2')),
      findsOneWidget,
    );

    await _scrollTo(
      tester,
      find.byKey(const ValueKey('task-executions-page-size')),
    );
    await tester.tap(find.byKey(const ValueKey('task-executions-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();

    expect(repository.pages, [0, 1, 0]);
    expect(repository.sizes, [10, 10, 20]);
  });

  testWidgets('atualiza a página por pull-to-refresh', (tester) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_execution(id: 1)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 1);

    await tester.drag(
      find.byKey(const ValueKey('task-executions-list')),
      const Offset(0, 350),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
    expect(repository.pages, [0, 0]);
    expect(repository.sizes, [10, 10]);
  });

  testWidgets('permite tentar novamente depois de uma falha', (tester) async {
    var shouldFail = true;
    final repository = _FakeTasksRepository((_, _, _, page, size) async {
      if (shouldFail) {
        shouldFail = false;
        throw const ApiFailure(ApiFailureKind.network);
      }
      return _page(number: page, size: size);
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-executions-error')), findsOneWidget);
    expect(
      find.text('Não foi possível conectar à API. Confira sua conexão.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('task-executions-retry-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
    expect(find.byKey(const ValueKey('task-executions-error')), findsNothing);
    expect(find.byKey(const ValueKey('task-executions-empty')), findsOneWidget);
  });

  testWidgets('encerra a sessão em resposta não autorizada', (tester) async {
    var sessionExpiredCalls = 0;
    final repository = _FakeTasksRepository((_, _, _, _, _) async {
      throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401);
    });

    await tester.pumpWidget(
      _testApp(repository, onSessionExpired: () => sessionExpiredCalls += 1),
    );
    await tester.pumpAndSettle();

    expect(sessionExpiredCalls, 1);
    expect(find.byKey(const ValueKey('task-executions-error')), findsNothing);
  });

  testWidgets('mantém 403 como erro de permissão na tela', (tester) async {
    var sessionExpiredCalls = 0;
    final repository = _FakeTasksRepository((_, _, _, _, _) async {
      throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403);
    });

    await tester.pumpWidget(
      _testApp(repository, onSessionExpired: () => sessionExpiredCalls += 1),
    );
    await tester.pumpAndSettle();

    expect(sessionExpiredCalls, 0);
    expect(find.byKey(const ValueKey('task-executions-error')), findsOneWidget);
    expect(
      find.text('Seu acesso não permite consultar as execuções desta tarefa.'),
      findsOneWidget,
    );
  });

  testWidgets('rejeita resposta com número de página diferente', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, _, _, _, size) async => _page(number: 1, size: size),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-executions-error')), findsOneWidget);
    expect(
      find.text('A API retornou uma resposta inesperada.'),
      findsOneWidget,
    );
  });

  testWidgets('corrige página solicitada que deixou de existir', (
    tester,
  ) async {
    var secondPageWasRemoved = false;
    final repository = _FakeTasksRepository((_, _, _, page, size) async {
      if (page == 1) {
        secondPageWasRemoved = true;
        return _page(number: 1, size: size, totalElements: 1, totalPages: 1);
      }
      return _page(
        content: [_execution(id: secondPageWasRemoved ? 9 : 1)],
        number: 0,
        size: size,
        totalElements: secondPageWasRemoved ? 1 : 11,
        totalPages: secondPageWasRemoved ? 1 : 2,
      );
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('task-executions-page-1')),
    );
    await tester.pumpAndSettle();

    expect(repository.pages, [0, 1, 0]);
    expect(
      find.byKey(const ValueKey('task-executions-card-9')),
      findsOneWidget,
    );
  });
}

typedef _FetchExecutionsHandler =
    Future<TaskExecutionPageResult> Function(
      String accessToken,
      int spaceId,
      int taskId,
      int page,
      int size,
    );
typedef _RemoveCurrentUserFromTaskExecutionHandler =
    Future<void> Function(
      String accessToken,
      int spaceId,
      int taskId,
      int taskExecutionId,
    );

final class _FakeTasksRepository implements TasksRepository {
  _FakeTasksRepository(
    this._handler, {
    this.removeCurrentUserFromTaskExecutionHandler,
  });

  final _FetchExecutionsHandler _handler;
  final _RemoveCurrentUserFromTaskExecutionHandler?
  removeCurrentUserFromTaskExecutionHandler;
  int fetchCalls = 0;
  int removeCalls = 0;
  final accessTokens = <String>[];
  final spaceIds = <int>[];
  final taskIds = <int>[];
  final pages = <int>[];
  final sizes = <int>[];
  final removeAccessTokens = <String>[];
  final removeSpaceIds = <int>[];
  final removeTaskIds = <int>[];
  final removedExecutionIds = <int>[];

  @override
  Future<void> confirmTaskExecution({
    required String accessToken,
    required int spaceId,
    required int taskId,
    Set<int> executorIds = const <int>{},
    DateTime? executionDate,
  }) {
    return Future<void>.error(
      StateError('Confirmacao de tarefa nao esperada neste teste.'),
    );
  }

  @override
  Future<TaskExecutionPageResult> fetchTaskExecutions({
    required String accessToken,
    required int spaceId,
    required int taskId,
    int page = 0,
    int size = 10,
  }) {
    fetchCalls += 1;
    accessTokens.add(accessToken);
    spaceIds.add(spaceId);
    taskIds.add(taskId);
    pages.add(page);
    sizes.add(size);
    return _handler(accessToken, spaceId, taskId, page, size);
  }

  @override
  Future<void> removeCurrentUserFromTaskExecution({
    required String accessToken,
    required int spaceId,
    required int taskId,
    required int taskExecutionId,
  }) {
    removeCalls += 1;
    removeAccessTokens.add(accessToken);
    removeSpaceIds.add(spaceId);
    removeTaskIds.add(taskId);
    removedExecutionIds.add(taskExecutionId);
    final handler = removeCurrentUserFromTaskExecutionHandler;
    if (handler == null) {
      return Future<void>.error(
        StateError('Remoção de execução não esperada neste teste.'),
      );
    }
    return handler(accessToken, spaceId, taskId, taskExecutionId);
  }

  @override
  Future<TaskSummary> createTask({
    required String accessToken,
    required int spaceId,
    required TaskCreation creation,
  }) {
    return Future<TaskSummary>.error(
      StateError('Criação de tarefa não esperada neste teste.'),
    );
  }

  @override
  Future<TaskPageResult> fetchTasks({
    required String accessToken,
    required int spaceId,
    TaskFilters filters = const TaskFilters(),
    int page = 0,
    int size = 10,
  }) {
    return Future<TaskPageResult>.error(
      StateError('Listagem de tarefas não esperada neste teste.'),
    );
  }

  @override
  Future<TaskSummary> updateTask({
    required String accessToken,
    required int spaceId,
    required int taskId,
    required TaskUpdate update,
  }) {
    return Future<TaskSummary>.error(
      StateError('Atualização de tarefa não esperada neste teste.'),
    );
  }

  @override
  Future<void> toggleTaskActive({
    required String accessToken,
    required int spaceId,
    required int taskId,
  }) {
    return Future<void>.error(
      StateError('Alteração de status não esperada neste teste.'),
    );
  }
}

const _session = AuthSession(
  id: 1,
  username: 'user@example.com',
  name: 'Usuário de Teste',
  accessToken: 'access-token-executions-test-only',
  refreshToken: 'refresh-token-executions-test-only',
  role: 'ROLE_USER',
);

Widget _testApp(
  _FakeTasksRepository repository, {
  VoidCallback? onSessionExpired,
}) {
  return MaterialApp(
    home: TaskExecutionsPage(
      session: _session,
      spaceId: 7,
      spaceName: 'Residência do Casal',
      taskId: 23,
      taskDescription: 'Lavar a louça',
      tasksRepository: repository,
      onSessionExpired: onSessionExpired,
    ),
  );
}

TaskExecutionSummary _execution({
  required int id,
  num score = 10.5,
  List<String> executorNames = const [],
}) {
  return TaskExecutionSummary(
    id: id,
    executionDate: DateTime.utc(2026, 8, 21, 18, 31),
    score: score,
    executorNames: executorNames,
  );
}

TaskExecutionPageResult _page({
  List<TaskExecutionSummary> content = const [],
  int size = 10,
  int number = 0,
  int? totalElements,
  int? totalPages,
}) {
  return TaskExecutionPageResult(
    content: content,
    size: size,
    number: number,
    totalElements: totalElements ?? content.length,
    totalPages: totalPages ?? (content.isEmpty ? 0 : 1),
  );
}

Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('task-executions-list')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
