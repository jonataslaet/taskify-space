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
    final repository = _FakeTasksRepository((_, _, _, _, _) => response.future);

    await tester.pumpWidget(_testApp(repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('tasks-loading')), findsOneWidget);
    expect(repository.fetchCalls, 1);
    expect(repository.accessTokens, [_session.accessToken]);
    expect(repository.spaceIds, [7]);
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
        (_, _, _, page, size) async => _page(number: page, size: size),
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
      expect(repository.spaceIds, [7, 7]);
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
      expect(repository.spaceIds, [7, 7, 7]);
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
      (_, _, _, page, size) async => _page(number: page, size: size),
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
      (_, spaceId, _, page, size) async => _page(
        content: [_task(id: page + size, spaceId: spaceId)],
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
      (_, spaceId, _, page, size) async => _page(
        content: [_task(id: 1000 + page + size, spaceId: spaceId)],
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
    expect(repository.spaceIds.last, 7);
  });

  testWidgets('erro inicial mantém retry e estado vazio distingue filtros', (
    tester,
  ) async {
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
    final repository = _FakeTasksRepository((_, spaceId, _, page, size) {
      if (spaceId == 1) {
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
      (_, _, _, _, _) async => _page(number: 1, totalPages: 2),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tasks-error')), findsOneWidget);
    expect(find.textContaining('resposta inesperada'), findsOneWidget);
  });

  testWidgets('rejeita tarefa pertencente a outro espaço', (tester) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
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

  testWidgets('mantém o status visível, mas sem ação para participante', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_task(id: 1)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    final statusChip = find.byKey(const ValueKey('task-active-toggle-1'));
    expect(statusChip, findsOneWidget);
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: statusChip, matching: find.byType(InkWell)),
          )
          .onTap,
      isNull,
    );
    expect(repository.toggleTaskActiveCalls, 0);
  });

  for (final toggleCase
      in <({bool initialActive, IconData initialIcon, IconData nextIcon})>[
        (
          initialActive: true,
          initialIcon: Icons.visibility_outlined,
          nextIcon: Icons.visibility_off_outlined,
        ),
        (
          initialActive: false,
          initialIcon: Icons.visibility_off_outlined,
          nextIcon: Icons.visibility_outlined,
        ),
      ]) {
    testWidgets(
      'alterna tarefa ${toggleCase.initialActive ? 'ativa' : 'inativa'} e recarrega a lista',
      (tester) async {
        var active = toggleCase.initialActive;
        final repository = _FakeTasksRepository(
          (_, _, _, page, size) async => _page(
            content: [_task(id: 1, active: active)],
            number: page,
            size: size,
            totalElements: 1,
            totalPages: 1,
          ),
          toggleTaskActiveHandler: (_, spaceId, taskId) async {
            expect(spaceId, 7);
            expect(taskId, 1);
            active = !active;
          },
        );

        await tester.pumpWidget(_testApp(repository, canEditTasks: true));
        await tester.pumpAndSettle();

        final statusChip = find.byKey(const ValueKey('task-active-toggle-1'));
        expect(tester.getSize(statusChip).height, greaterThanOrEqualTo(48));
        expect(
          find.descendant(
            of: statusChip,
            matching: find.byIcon(toggleCase.initialIcon),
          ),
          findsOneWidget,
        );

        await _tapVisible(tester, statusChip);

        expect(repository.toggleTaskActiveCalls, 1);
        expect(repository.toggleTaskActiveAccessTokens, [_session.accessToken]);
        expect(repository.toggleTaskActiveSpaceIds, [7]);
        expect(repository.toggledTaskIds, [1]);
        expect(repository.fetchCalls, 2);
        expect(repository.pages, [0, 0]);
        expect(repository.sizes, [10, 10]);
        expect(
          find.descendant(
            of: statusChip,
            matching: find.byIcon(toggleCase.nextIcon),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('task-status-updated-message')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('bloqueia clique duplicado enquanto altera o status', (
    tester,
  ) async {
    final response = Completer<void>();
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_task(id: 1)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
      toggleTaskActiveHandler: (_, _, _) => response.future,
    );

    await tester.pumpWidget(_testApp(repository, canEditTasks: true));
    await tester.pumpAndSettle();

    final statusChip = find.byKey(const ValueKey('task-active-toggle-1'));
    await tester.tap(statusChip);
    await tester.pump();

    expect(repository.toggleTaskActiveCalls, 1);
    expect(find.byKey(const ValueKey('task-status-progress')), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: statusChip, matching: find.byType(InkWell)),
          )
          .onTap,
      isNull,
    );

    await tester.tap(statusChip);
    await tester.pump();
    expect(repository.toggleTaskActiveCalls, 1);

    response.complete();
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 2);
  });

  testWidgets('toggle preserva filtros, página e tamanho atuais', (
    tester,
  ) async {
    var active = true;
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_task(id: 1, active: active)],
        number: page,
        size: size,
        totalElements: 60,
        totalPages: 3,
      ),
      toggleTaskActiveHandler: (_, _, _) async => active = false,
    );

    await tester.pumpWidget(_testApp(repository, canEditTasks: true));
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
    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('task-active-toggle-1')),
    );

    expect(repository.toggleTaskActiveCalls, 1);
    expect(repository.pages, [0, 0, 0, 1, 1]);
    expect(repository.sizes, [10, 20, 20, 20, 20]);
    expect(repository.spaceIds.last, 7);
    expect(repository.filters.last.description, 'mensal');
  });

  testWidgets('401 ao alterar status expira a sessão sem recarregar', (
    tester,
  ) async {
    var sessionExpiredCalls = 0;
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_task(id: 1)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
      toggleTaskActiveHandler: (_, _, _) async =>
          throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401),
    );

    await tester.pumpWidget(
      _testApp(
        repository,
        canEditTasks: true,
        onSessionExpired: () => sessionExpiredCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('task-active-toggle-1')),
    );

    expect(repository.toggleTaskActiveCalls, 1);
    expect(repository.fetchCalls, 1);
    expect(sessionExpiredCalls, 1);
    expect(find.byKey(const ValueKey('task-status-error')), findsNothing);
  });

  testWidgets('403 ao alterar status mantém a sessão e informa o erro', (
    tester,
  ) async {
    var sessionExpiredCalls = 0;
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_task(id: 1)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
      toggleTaskActiveHandler: (_, _, _) async =>
          throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403),
    );

    await tester.pumpWidget(
      _testApp(
        repository,
        canEditTasks: true,
        onSessionExpired: () => sessionExpiredCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('task-active-toggle-1')),
    );

    expect(repository.toggleTaskActiveCalls, 1);
    expect(repository.fetchCalls, 1);
    expect(sessionExpiredCalls, 0);
    expect(find.byKey(const ValueKey('task-status-error')), findsOneWidget);
    expect(find.textContaining('não tem permissão'), findsOneWidget);
  });

  testWidgets('recarrega a lista quando o resultado do PATCH é incerto', (
    tester,
  ) async {
    var active = true;
    final repository = _FakeTasksRepository(
      (_, _, _, page, size) async => _page(
        content: [_task(id: 1, active: active)],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      ),
      toggleTaskActiveHandler: (_, _, _) async {
        active = false;
        throw const ApiFailure(ApiFailureKind.network);
      },
    );

    await tester.pumpWidget(_testApp(repository, canEditTasks: true));
    await tester.pumpAndSettle();

    final statusChip = find.byKey(const ValueKey('task-active-toggle-1'));
    await _tapVisible(tester, statusChip);

    expect(repository.toggleTaskActiveCalls, 1);
    expect(repository.fetchCalls, 2);
    expect(
      find.descendant(
        of: statusChip,
        matching: find.byIcon(Icons.visibility_off_outlined),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('task-status-error')), findsOneWidget);
    expect(find.textContaining('lista será atualizada'), findsOneWidget);
  });

  for (final createCase in <({bool canEdit, Matcher matcher, String label})>[
    (canEdit: true, matcher: findsOneWidget, label: 'permitida'),
    (canEdit: false, matcher: findsNothing, label: 'não permitida'),
  ]) {
    testWidgets(
      'renderiza a ação de criar quando a permissão é ${createCase.label}',
      (tester) async {
        final repository = _FakeTasksRepository(
          (_, _, _, page, size) async => _page(number: page, size: size),
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
      (_, _, _, page, size) async => _page(
        content: createdTask == null ? const [] : [createdTask!],
        number: page,
        size: size,
      ),
      createHandler: (_, spaceId, creation) async {
        expect(spaceId, 7);
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
    expect(repository.createSpaceIds, [7]);
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
          (_, _, _, page, size) async => _page(
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
      final repository = _FakeTasksRepository((_, _, _, page, size) async {
        fetchSequence += 1;
        return _page(
          content: [fetchSequence >= 4 ? updatedTask : originalTask],
          number: page,
          size: size,
          totalElements: 20,
          totalPages: 2,
        );
      }, updateHandler: (_, _, _, _) async => updatedTask);

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
      expect(repository.updateSpaceIds, [7]);
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
      expect(repository.spaceIds.last, 7);
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
      int spaceId,
      TaskFilters filters,
      int page,
      int size,
    );
typedef _UpdateHandler =
    Future<TaskSummary> Function(
      String accessToken,
      int spaceId,
      int taskId,
      TaskUpdate update,
    );
typedef _CreateHandler =
    Future<TaskSummary> Function(
      String accessToken,
      int spaceId,
      TaskCreation creation,
    );
typedef _ToggleTaskActiveHandler =
    Future<void> Function(String accessToken, int spaceId, int taskId);

final class _FakeTasksRepository implements TasksRepository {
  _FakeTasksRepository(
    this._handler, {
    this.createHandler,
    this.updateHandler,
    this.toggleTaskActiveHandler,
  });

  final _FetchHandler _handler;
  final _CreateHandler? createHandler;
  final _UpdateHandler? updateHandler;
  final _ToggleTaskActiveHandler? toggleTaskActiveHandler;
  int fetchCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int toggleTaskActiveCalls = 0;
  final accessTokens = <String>[];
  final spaceIds = <int>[];
  final filters = <TaskFilters>[];
  final pages = <int>[];
  final sizes = <int>[];
  final createAccessTokens = <String>[];
  final createSpaceIds = <int>[];
  final creations = <TaskCreation>[];
  final updateAccessTokens = <String>[];
  final updateSpaceIds = <int>[];
  final taskIds = <int>[];
  final updates = <TaskUpdate>[];
  final toggleTaskActiveAccessTokens = <String>[];
  final toggleTaskActiveSpaceIds = <int>[];
  final toggledTaskIds = <int>[];

  @override
  Future<TaskPageResult> fetchTasks({
    required String accessToken,
    required int spaceId,
    TaskFilters filters = const TaskFilters(),
    int page = 0,
    int size = 10,
  }) {
    fetchCalls += 1;
    accessTokens.add(accessToken);
    spaceIds.add(spaceId);
    this.filters.add(filters);
    pages.add(page);
    sizes.add(size);
    return _handler(accessToken, spaceId, filters, page, size);
  }

  @override
  Future<TaskSummary> createTask({
    required String accessToken,
    required int spaceId,
    required TaskCreation creation,
  }) {
    createCalls += 1;
    createAccessTokens.add(accessToken);
    createSpaceIds.add(spaceId);
    creations.add(creation);
    final handler = createHandler;
    if (handler == null) {
      return Future<TaskSummary>.error(
        StateError('Handler de criação de tarefa não configurado.'),
      );
    }
    return handler(accessToken, spaceId, creation);
  }

  @override
  Future<TaskSummary> updateTask({
    required String accessToken,
    required int spaceId,
    required int taskId,
    required TaskUpdate update,
  }) {
    updateCalls += 1;
    updateAccessTokens.add(accessToken);
    updateSpaceIds.add(spaceId);
    taskIds.add(taskId);
    updates.add(update);
    final handler = updateHandler;
    if (handler == null) {
      return Future<TaskSummary>.error(
        StateError('Handler de atualização de tarefa não configurado.'),
      );
    }
    return handler(accessToken, spaceId, taskId, update);
  }

  @override
  Future<void> toggleTaskActive({
    required String accessToken,
    required int spaceId,
    required int taskId,
  }) {
    toggleTaskActiveCalls += 1;
    toggleTaskActiveAccessTokens.add(accessToken);
    toggleTaskActiveSpaceIds.add(spaceId);
    toggledTaskIds.add(taskId);
    final handler = toggleTaskActiveHandler;
    if (handler == null) {
      return Future<void>.error(
        StateError('Handler de status de tarefa não configurado.'),
      );
    }
    return handler(accessToken, spaceId, taskId);
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

Widget _testApp(
  _FakeTasksRepository repository, {
  bool canEditTasks = false,
  VoidCallback? onSessionExpired,
}) {
  return MaterialApp(
    home: TasksPage(
      session: _session,
      spaceId: 7,
      spaceName: 'Residência do Casal',
      tasksRepository: repository,
      canEditTasks: canEditTasks,
      onSessionExpired: onSessionExpired,
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
