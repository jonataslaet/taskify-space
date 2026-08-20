import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';
import 'package:mobile_flutter/features/tasks/presentation/create_task_dialog.dart';
import 'package:mobile_flutter/features/tasks/presentation/edit_task_dialog.dart';
import 'package:mobile_flutter/features/tasks/presentation/tasks_page.dart';

void main() {
  testWidgets('faz o GET inicial e apresenta tarefa e contexto do espaço', (
    tester,
  ) async {
    final response = Completer<TaskPageResult>();
    final repository = _FakeTasksRepository((_, _, _, _) => response.future);

    await tester.pumpWidget(_testApp(repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('tasks-loading')), findsOneWidget);
    expect(repository.fetchCalls, 1);
    expect(repository.accessTokens, [_session.accessToken]);
    expect(repository.filters.single.spaceId, 7);
    expect(repository.pages, [0]);
    expect(repository.sizes, [10]);

    response.complete(
      _page(
        content: [
          _task(
            id: 1,
            score: 10.5,
            creatorName: 'Joice Laet',
            schedule: TaskScheduleSummary(
              localDates: [DateTime.utc(2026, 8, 3)],
              frequency: TaskFrequency.weekly,
            ),
          ),
        ],
        totalElements: 1,
        totalPages: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tasks-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('tasks-space-name')), findsOneWidget);
    expect(find.text('Residência do Casal'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-card-1')), findsOneWidget);
    expect(find.text('Tarefa 1'), findsOneWidget);
    expect(find.text('10.5 pontos'), findsOneWidget);
    expect(find.text('Operacional'), findsOneWidget);
    expect(find.text('Ativa'), findsOneWidget);
    expect(find.text('Criada por: Joice Laet'), findsOneWidget);
    expect(find.text('Semanal · 03/08/2026'), findsOneWidget);
  });

  testWidgets(
    'aplica todos os filtros com vírgula, reseta a página e permite limpar',
    (tester) async {
      final repository = _FakeTasksRepository(
        (_, _, page, size) async => _page(number: page, size: size),
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await _openFilters(tester);

      await tester.enterText(
        find.byKey(const ValueKey('tasks-description-filter')),
        '  conta de água  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tasks-score-filter')),
        '10,5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tasks-min-score-filter')),
        '5,25',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tasks-max-score-filter')),
        '20,75',
      );

      tester
          .widget<DropdownButton<bool>>(
            find.byKey(const ValueKey('tasks-active-filter')),
          )
          .onChanged!(true);
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('tasks-category-operational')),
          )
          .onSelected!(true);
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('tasks-category-financial')),
          )
          .onSelected!(true);
      await tester.pump();

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('tasks-apply-filters')),
      );

      expect(repository.fetchCalls, 2);
      expect(repository.pages, [0, 0]);
      expect(repository.sizes, [10, 10]);
      final filters = repository.filters.last;
      expect(filters.spaceId, 7);
      expect(filters.description, '  conta de água  ');
      expect(filters.score, 10.5);
      expect(filters.active, isTrue);
      expect(filters.categories, {
        TaskCategory.operational,
        TaskCategory.financial,
      });
      expect(filters.minScore, 5.25);
      expect(filters.maxScore, 20.75);
      await _scrollTo(tester, find.byKey(const ValueKey('tasks-filter-empty')));
      expect(find.byKey(const ValueKey('tasks-filter-empty')), findsOneWidget);

      await _scrollToAndTap(
        tester,
        find.byKey(const ValueKey('tasks-clear-filters')),
      );

      expect(repository.fetchCalls, 3);
      expect(repository.pages, [0, 0, 0]);
      final cleared = repository.filters.last;
      expect(cleared.spaceId, 7);
      expect(cleared.description, isNull);
      expect(cleared.score, isNull);
      expect(cleared.active, isNull);
      expect(cleared.categories, isEmpty);
      expect(cleared.minScore, isNull);
      expect(cleared.maxScore, isNull);
      await _scrollTo(tester, find.byKey(const ValueKey('tasks-empty')));
      expect(find.byKey(const ValueKey('tasks-empty')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('tasks-description-filter')),
            )
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('rejeita pontuação inválida e intervalo invertido localmente', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, _, page, size) async => _page(number: page, size: size),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await _openFilters(tester);

    await tester.enterText(
      find.byKey(const ValueKey('tasks-score-filter')),
      'inválida',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('tasks-apply-filters')),
    );

    expect(repository.fetchCalls, 1);
    expect(find.byKey(const ValueKey('tasks-filter-error')), findsOneWidget);
    expect(find.textContaining('números não negativos'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('tasks-score-filter')),
      '',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tasks-min-score-filter')),
      '20',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tasks-max-score-filter')),
      '10',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('tasks-apply-filters')),
    );

    expect(repository.fetchCalls, 1);
    expect(find.textContaining('mínima não pode ser maior'), findsOneWidget);
  });

  testWidgets('pagina substituindo conteúdo e mudar tamanho volta para zero', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, filters, page, size) async => _page(
        content: [_task(id: page + size, spaceId: filters.spaceId!)],
        number: page,
        size: size,
        totalElements: 60,
        totalPages: 3,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-card-10')), findsOneWidget);
    await _scrollToAndTap(tester, find.byKey(const ValueKey('tasks-page-1')));

    expect(repository.pages, [0, 1]);
    expect(repository.sizes, [10, 10]);
    expect(find.byKey(const ValueKey('task-card-10')), findsNothing);
    expect(find.byKey(const ValueKey('task-card-11')), findsOneWidget);

    final sizeDropdown = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('tasks-page-size')),
    );
    expect(sizeDropdown.items!.map((item) => item.value), [5, 10, 20, 50]);
    sizeDropdown.onChanged!(20);
    await tester.pumpAndSettle();

    expect(repository.pages, [0, 1, 0]);
    expect(repository.sizes, [10, 10, 20]);
    expect(find.byKey(const ValueKey('task-card-11')), findsNothing);
    expect(find.byKey(const ValueKey('task-card-20')), findsOneWidget);
  });

  testWidgets('pull-to-refresh preserva filtros, página e tamanho', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, filters, page, size) async => _page(
        content: [_task(id: 1000 + page + size, spaceId: filters.spaceId!)],
        number: page,
        size: size,
        totalElements: 60,
        totalPages: 3,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButton<int>>(
          find.byKey(const ValueKey('tasks-page-size')),
        )
        .onChanged!(20);
    await tester.pumpAndSettle();
    await _openFilters(tester);
    await tester.enterText(
      find.byKey(const ValueKey('tasks-description-filter')),
      'mensal',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('tasks-apply-filters')),
    );
    await _scrollToAndTap(tester, find.byKey(const ValueKey('tasks-page-1')));

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();
    await tester.pumpAndSettle();

    expect(repository.pages, [0, 0, 0, 1, 1]);
    expect(repository.sizes, [10, 20, 20, 20, 20]);
    expect(repository.filters.last.description, 'mensal');
    expect(repository.filters.last.spaceId, 7);
  });

  testWidgets('erro inicial mantém retry e estado vazio distingue filtros', (
    tester,
  ) async {
    var shouldFail = true;
    final repository = _FakeTasksRepository((_, _, page, size) async {
      if (shouldFail) {
        shouldFail = false;
        throw const ApiFailure(ApiFailureKind.network);
      }
      return _page(number: page, size: size);
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tasks-error')), findsOneWidget);
    expect(repository.fetchCalls, 1);

    await tester.tap(find.byKey(const ValueKey('tasks-retry-button')));
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
    expect(find.byKey(const ValueKey('tasks-error')), findsNothing);
    expect(find.byKey(const ValueKey('tasks-empty')), findsOneWidget);

    await _openFilters(tester);
    await tester.enterText(
      find.byKey(const ValueKey('tasks-description-filter')),
      'inexistente',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('tasks-apply-filters')),
    );

    await _scrollTo(tester, find.byKey(const ValueKey('tasks-filter-empty')));
    expect(find.byKey(const ValueKey('tasks-filter-empty')), findsOneWidget);
  });

  testWidgets('ignora resposta antiga ao trocar o espaço', (tester) async {
    final oldResponse = Completer<TaskPageResult>();
    final repository = _FakeTasksRepository((_, filters, page, size) {
      if (filters.spaceId == 1) {
        return oldResponse.future;
      }
      return Future<TaskPageResult>.value(
        _page(
          content: [_task(id: 2, spaceId: 2)],
          number: page,
          size: size,
          totalElements: 1,
          totalPages: 1,
        ),
      );
    });
    var selectedSpaceId = 1;
    var selectedSpaceName = 'Espaço antigo';
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return TasksPage(
              session: _session,
              spaceId: selectedSpaceId,
              spaceName: selectedSpaceName,
              tasksRepository: repository,
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(repository.fetchCalls, 1);

    rebuild(() {
      selectedSpaceId = 2;
      selectedSpaceName = 'Espaço novo';
    });
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
    expect(find.text('Espaço novo'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-card-2')), findsOneWidget);

    oldResponse.complete(
      _page(
        content: [_task(id: 1, spaceId: 1)],
        totalElements: 1,
        totalPages: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-card-1')), findsNothing);
    expect(find.byKey(const ValueKey('task-card-2')), findsOneWidget);
  });

  testWidgets('rejeita número de página divergente', (tester) async {
    final repository = _FakeTasksRepository(
      (_, _, _, _) async => _page(number: 1, totalPages: 2),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tasks-error')), findsOneWidget);
    expect(find.textContaining('resposta inesperada'), findsOneWidget);
  });

  testWidgets('rejeita tarefa pertencente a outro espaço', (tester) async {
    final repository = _FakeTasksRepository(
      (_, _, page, size) async => _page(
        content: [_task(id: 99, spaceId: 99)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-card-99')), findsNothing);
    expect(find.byKey(const ValueKey('tasks-error')), findsOneWidget);
    expect(find.textContaining('resposta inesperada'), findsOneWidget);
  });

  for (final createCase in <({bool canEdit, Matcher matcher, String label})>[
    (canEdit: true, matcher: findsOneWidget, label: 'permitida'),
    (canEdit: false, matcher: findsNothing, label: 'não permitida'),
  ]) {
    testWidgets(
      'renderiza a ação de criar quando a permissão é ${createCase.label}',
      (tester) async {
        final repository = _FakeTasksRepository(
          (_, _, page, size) async => _page(number: page, size: size),
        );

        await tester.pumpWidget(
          _testApp(repository, canEditTasks: createCase.canEdit),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('create-task-button')),
          createCase.matcher,
        );
      },
    );
  }

  testWidgets('cria uma tarefa e recarrega a lista do espaço', (tester) async {
    TaskSummary? createdTask;
    final repository = _FakeTasksRepository(
      (_, _, page, size) async => _page(
        content: createdTask == null ? const [] : [createdTask!],
        number: page,
        size: size,
      ),
      createHandler: (_, creation) async {
        createdTask = _task(
          id: 15,
          description: creation.description,
          score: creation.score,
          category: creation.category,
          schedule: creation.schedule,
          active: creation.active,
          creatorName: creation.creatorName,
        );
        return createdTask!;
      },
    );

    await tester.pumpWidget(_testApp(repository, canEditTasks: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-task-button')));
    await tester.pumpAndSettle();
    expect(find.byType(CreateTaskDialog), findsOneWidget);
    expect(find.text('Ativa · Criada por Usuário de Teste'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('create-task-description-field')),
      '  Pagar conta de água  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-task-score-field')),
      '80,00',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('create-task-schedule-switch')),
    );
    await _selectDropdownOption(
      tester,
      find.byKey(const ValueKey('create-task-frequency-field')),
      'Semanal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-task-dates-field')),
      '2024-02-29, 2024-02-28, 2024-02-27',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('create-task-submit-button')),
    );

    expect(repository.createCalls, 1);
    expect(repository.createAccessTokens, [_session.accessToken]);
    final creation = repository.creations.single;
    expect(creation.spaceId, 7);
    expect(creation.description, 'Pagar conta de água');
    expect(creation.score, 80);
    expect(creation.category, TaskCategory.operational);
    expect(creation.active, isTrue);
    expect(creation.creatorName, 'Usuário de Teste');
    expect(creation.schedule?.frequency, TaskFrequency.weekly);
    expect(creation.schedule?.localDates, [
      DateTime.utc(2024, 2, 27),
      DateTime.utc(2024, 2, 28),
      DateTime.utc(2024, 2, 29),
    ]);
    expect(repository.fetchCalls, 2);
    expect(find.byKey(const ValueKey('task-created-message')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-card-15')), findsOneWidget);
  });

  for (final editCase in <({bool canEdit, Matcher matcher, String label})>[
    (canEdit: true, matcher: findsOneWidget, label: 'permitida'),
    (canEdit: false, matcher: findsNothing, label: 'não permitida'),
  ]) {
    testWidgets(
      'renderiza a ação de editar quando a permissão é ${editCase.label}',
      (tester) async {
        final repository = _FakeTasksRepository(
          (_, _, page, size) async => _page(
            content: [_task(id: 1)],
            number: page,
            size: size,
            totalElements: 1,
            totalPages: 1,
          ),
        );

        await tester.pumpWidget(
          _testApp(repository, canEditTasks: editCase.canEdit),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('task-edit-button-1')),
          editCase.matcher,
        );
      },
    );
  }

  testWidgets(
    'recarrega filtros, página e tamanho atuais após editar e preserva a agenda',
    (tester) async {
      final schedule = TaskScheduleSummary(
        localDates: [DateTime.utc(2026, 8, 4), DateTime.utc(2026, 8, 11)],
        frequency: TaskFrequency.weekly,
      );
      final originalTask = _task(
        id: 1,
        description: 'Tarefa antiga',
        schedule: schedule,
      );
      final updatedTask = _task(
        id: 1,
        description: 'Tarefa revisada',
        schedule: schedule,
      );
      var fetchSequence = 0;
      final repository = _FakeTasksRepository((_, _, page, size) async {
        fetchSequence += 1;
        return _page(
          content: [fetchSequence >= 4 ? updatedTask : originalTask],
          number: page,
          size: size,
          totalElements: 20,
          totalPages: 2,
        );
      }, updateHandler: (_, _, _) async => updatedTask);

      await tester.pumpWidget(_testApp(repository, canEditTasks: true));
      await tester.pumpAndSettle();

      await _openFilters(tester);
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('tasks-category-operational')),
          )
          .onSelected!(true);
      await tester.pump();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('tasks-apply-filters')),
      );
      await _scrollToAndTap(tester, find.byKey(const ValueKey('tasks-page-1')));

      await _scrollToAndTap(
        tester,
        find.byKey(const ValueKey('task-edit-button-1')),
      );
      expect(find.byType(EditTaskDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('edit-task-description-field')),
        '  Tarefa revisada  ',
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('edit-task-submit-button')),
      );

      expect(
        find.byKey(const ValueKey('task-updated-message')),
        findsOneWidget,
      );
      expect(repository.updateCalls, 1);
      expect(repository.updateAccessTokens, [_session.accessToken]);
      expect(repository.taskIds, [originalTask.id]);
      final update = repository.updates.single;
      expect(update.description, 'Tarefa revisada');
      expect(update.score, originalTask.score);
      expect(update.category, originalTask.category);
      expect(update.schedule?.frequency, schedule.frequency);
      expect(update.schedule?.localDates, schedule.localDates);

      expect(repository.fetchCalls, 4);
      expect(repository.pages, [0, 0, 1, 1]);
      expect(repository.sizes, [10, 10, 10, 10]);
      expect(repository.filters.last.spaceId, 7);
      expect(repository.filters.last.categories, {TaskCategory.operational});
      await _scrollTo(tester, find.byKey(const ValueKey('task-card-1')));
      expect(find.text('Tarefa antiga'), findsNothing);
      expect(find.text('Tarefa revisada'), findsOneWidget);
    },
  );
}

typedef _FetchHandler =
    Future<TaskPageResult> Function(
      String accessToken,
      TaskFilters filters,
      int page,
      int size,
    );
typedef _UpdateHandler =
    Future<TaskSummary> Function(
      String accessToken,
      int taskId,
      TaskUpdate update,
    );
typedef _CreateHandler =
    Future<TaskSummary> Function(String accessToken, TaskCreation creation);

final class _FakeTasksRepository implements TasksRepository {
  _FakeTasksRepository(this._handler, {this.createHandler, this.updateHandler});

  final _FetchHandler _handler;
  final _CreateHandler? createHandler;
  final _UpdateHandler? updateHandler;
  int fetchCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  final accessTokens = <String>[];
  final filters = <TaskFilters>[];
  final pages = <int>[];
  final sizes = <int>[];
  final createAccessTokens = <String>[];
  final creations = <TaskCreation>[];
  final updateAccessTokens = <String>[];
  final taskIds = <int>[];
  final updates = <TaskUpdate>[];

  @override
  Future<TaskPageResult> fetchTasks({
    required String accessToken,
    TaskFilters filters = const TaskFilters(),
    int page = 0,
    int size = 10,
  }) {
    fetchCalls += 1;
    accessTokens.add(accessToken);
    this.filters.add(filters);
    pages.add(page);
    sizes.add(size);
    return _handler(accessToken, filters, page, size);
  }

  @override
  Future<TaskSummary> createTask({
    required String accessToken,
    required TaskCreation creation,
  }) {
    createCalls += 1;
    createAccessTokens.add(accessToken);
    creations.add(creation);
    final handler = createHandler;
    if (handler == null) {
      return Future<TaskSummary>.error(
        StateError('Handler de criação de tarefa não configurado.'),
      );
    }
    return handler(accessToken, creation);
  }

  @override
  Future<TaskSummary> updateTask({
    required String accessToken,
    required int taskId,
    required TaskUpdate update,
  }) {
    updateCalls += 1;
    updateAccessTokens.add(accessToken);
    taskIds.add(taskId);
    updates.add(update);
    final handler = updateHandler;
    if (handler == null) {
      return Future<TaskSummary>.error(
        StateError('Handler de atualização de tarefa não configurado.'),
      );
    }
    return handler(accessToken, taskId, update);
  }
}

const _session = AuthSession(
  id: 1,
  username: 'user@example.com',
  name: 'Usuário de Teste',
  accessToken: 'access-token-tasks-test-only',
  refreshToken: 'refresh-token-tasks-test-only',
  role: 'ROLE_USER',
);

Widget _testApp(_FakeTasksRepository repository, {bool canEditTasks = false}) {
  return MaterialApp(
    home: TasksPage(
      session: _session,
      spaceId: 7,
      spaceName: 'Residência do Casal',
      tasksRepository: repository,
      canEditTasks: canEditTasks,
    ),
  );
}

TaskSummary _task({
  required int id,
  int spaceId = 7,
  String? description,
  num score = 10,
  TaskCategory category = TaskCategory.operational,
  TaskScheduleSummary? schedule,
  bool active = true,
  String? creatorName,
}) {
  return TaskSummary(
    id: id,
    spaceId: spaceId,
    description: description ?? 'Tarefa $id',
    score: score,
    category: category,
    schedule: schedule,
    active: active,
    creatorName: creatorName,
  );
}

TaskPageResult _page({
  List<TaskSummary> content = const [],
  int size = 10,
  int number = 0,
  int? totalElements,
  int? totalPages,
}) {
  return TaskPageResult(
    content: content,
    size: size,
    number: number,
    totalElements: totalElements ?? content.length,
    totalPages: totalPages ?? (content.isEmpty ? 0 : 1),
  );
}

Future<void> _openFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tasks-toggle-filters')));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 400, scrollable: _tasksScrollable());
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownOption(
  WidgetTester tester,
  Finder dropdown,
  String label,
) async {
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Finder _tasksScrollable() {
  return find.descendant(
    of: find.byKey(const ValueKey('tasks-list')),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
}
