import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_page_result.dart';
import 'package:mobile_flutter/features/spaces/presentation/space_participants_page.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category_summary.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('carrega e renderiza participantes e o contexto do espaço', (
    tester,
  ) async {
    final completer = Completer<SpaceParticipantPageResult>();
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      fetchParticipantsHandler: (_, _, _, _, _) => completer.future,
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pump();

    expect(find.byKey(const Key('space-participants-loading')), findsOneWidget);
    expect(repository.fetchSpaceParticipantsCalls, 1);
    expect(repository.receivedParticipantAccessTokens, [
      testSession.accessToken,
    ]);
    expect(repository.receivedParticipantSpaceIds, [7]);
    expect(repository.receivedParticipantPages, [0]);
    expect(repository.receivedParticipantPageSizes, [10]);
    expect(repository.receivedParticipantFilters.single.name, isNull);
    expect(repository.receivedParticipantFilters.single.role, isNull);
    expect(
      repository.receivedParticipantFilters.single.taskCategories,
      isEmpty,
    );
    expect(
      repository.receivedParticipantFilters.single.sort,
      ParticipantSort.scoreDescending,
    );

    completer.complete(
      makeSpaceParticipantPage(
        content: [
          _participant(
            11,
            name: 'Joice Lima',
            role: SpaceUserRole.manager,
            categories: {TaskCategory.operational, TaskCategory.financial},
            score: 42.5,
            contributionPercentual: 0.425,
          ),
          _participant(12, name: 'Caio Souza'),
        ],
        totalElements: 2,
        totalPages: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('space-participants-list')), findsOneWidget);
    expect(find.text('Espaço de testes'), findsOneWidget);
    expect(find.text('2 participantes ativos encontrados'), findsOneWidget);
    expect(find.byKey(const Key('space-participant-card-11')), findsOneWidget);
    expect(find.byKey(const Key('space-participant-card-12')), findsOneWidget);
    expect(find.text('Joice Lima'), findsOneWidget);
    expect(find.text('Gerente'), findsOneWidget);
    expect(find.text('42.5 pontos'), findsOneWidget);
    expect(find.text('42.5% de contribuição'), findsOneWidget);
    expect(find.text('Operacional'), findsOneWidget);
    expect(find.text('Financeira'), findsOneWidget);
    expect(find.text('Caio Souza'), findsOneWidget);
    expect(find.text('Participante'), findsOneWidget);
    expect(find.text('0 pontos'), findsOneWidget);
    expect(find.text('0% de contribuição'), findsOneWidget);
  });

  testWidgets('aplica todos os filtros e limpa os critérios', (tester) async {
    final maintenance = TaskCategory.fromApiValue('MAINTENANCE');
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      fetchParticipantsHandler: (_, _, _, page, size) async =>
          makeSpaceParticipantPage(number: page, size: size),
    );
    final tasksRepository = FakeTasksRepository(
      searchTaskCategoriesHandler: (_, _, name) async {
        if (name == 'maint') {
          return <TaskCategorySummary>[
            TaskCategorySummary(id: 17, category: maintenance),
          ];
        }
        return const <TaskCategorySummary>[
          TaskCategorySummary(id: 1, category: TaskCategory.operational),
          TaskCategorySummary(id: 2, category: TaskCategory.financial),
        ];
      },
    );

    await tester.pumpWidget(
      _testApp(repository, tasksRepository: tasksRepository),
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('space-participants-toggle-filters')),
    );

    await tester.enterText(
      find.byKey(const Key('space-participants-name-filter')),
      '  joice  ',
    );
    _roleDropdown(tester).onChanged!(SpaceUserRole.manager);
    await tester.pump();
    final sortDropdown = _sortDropdown(tester);
    expect(sortDropdown.value, ParticipantSort.scoreDescending);
    expect(
      sortDropdown.items!.map((item) => item.value),
      ParticipantSort.values,
    );
    sortDropdown.onChanged!(ParticipantSort.nameDescending);
    await tester.pump();

    await _tapVisible(
      tester,
      find.byKey(const Key('space-participants-category-field')),
    );
    expect(
      find.byKey(const Key('space-participants-category-search-dialog')),
      findsOneWidget,
    );
    expect(tasksRepository.searchTaskCategoriesCalls, 0);

    await tester.enterText(
      find.byKey(const Key('space-participants-category-search-field')),
      '   ',
    );
    await tester.tap(
      find.byKey(const Key('space-participants-category-search-button')),
    );
    await tester.pumpAndSettle();

    expect(tasksRepository.searchTaskCategoriesCalls, 1);
    expect(tasksRepository.receivedTaskCategorySearchAccessTokens, [
      testSession.accessToken,
    ]);
    expect(tasksRepository.receivedTaskCategorySearchSpaceIds, [7]);
    expect(tasksRepository.receivedTaskCategorySearchNames, <String?>[null]);
    await tester.tap(
      find.byKey(const Key('space-participants-category-option-1')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('space-participants-category-option-2')),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('space-participants-category-search-field')),
      '  maint  ',
    );
    await tester.tap(
      find.byKey(const Key('space-participants-category-search-button')),
    );
    await tester.pumpAndSettle();

    expect(tasksRepository.searchTaskCategoriesCalls, 2);
    expect(tasksRepository.receivedTaskCategorySearchAccessTokens, [
      testSession.accessToken,
      testSession.accessToken,
    ]);
    expect(tasksRepository.receivedTaskCategorySearchSpaceIds, [7, 7]);
    expect(tasksRepository.receivedTaskCategorySearchNames, <String?>[
      null,
      'maint',
    ]);
    await tester.tap(
      find.byKey(const Key('space-participants-category-option-17')),
    );
    await tester.pump();
    expect(
      find.byKey(
        const Key('space-participants-category-selection-OPERATIONAL'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('space-participants-category-selection-FINANCIAL')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('space-participants-category-selection-MAINTENANCE'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('space-participants-category-search-apply-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('space-participants-selected-category-OPERATIONAL')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('space-participants-selected-category-FINANCIAL')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('space-participants-selected-category-MAINTENANCE')),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('space-participants-apply-filters')),
    );

    expect(repository.fetchSpaceParticipantsCalls, 2);
    expect(repository.receivedParticipantPages, [0, 0]);
    expect(repository.receivedParticipantPageSizes, [10, 10]);
    final applied = repository.receivedParticipantFilters.last;
    expect(applied.name, '  joice  ');
    expect(applied.role, SpaceUserRole.manager);
    expect(applied.taskCategories, {
      TaskCategory.operational,
      TaskCategory.financial,
      maintenance,
    });
    expect(applied.sort, ParticipantSort.nameDescending);
    expect(
      find.byKey(const Key('space-participants-active-filters')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('space-participants-filter-empty')),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('space-participants-clear-filters')),
    );

    expect(repository.fetchSpaceParticipantsCalls, 3);
    expect(repository.receivedParticipantPages.last, 0);
    final cleared = repository.receivedParticipantFilters.last;
    expect(cleared.name, isNull);
    expect(cleared.role, isNull);
    expect(cleared.taskCategories, isEmpty);
    expect(cleared.sort, ParticipantSort.scoreDescending);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('space-participants-name-filter')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(_roleDropdown(tester).value, isNull);
    expect(_sortDropdown(tester).value, ParticipantSort.scoreDescending);
    expect(
      find.byKey(const Key('space-participants-selected-category-OPERATIONAL')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('space-participants-selected-category-FINANCIAL')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('space-participants-selected-category-MAINTENANCE')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('space-participants-active-filters')),
      findsNothing,
    );
    expect(find.byKey(const Key('space-participants-empty')), findsOneWidget);
  });

  testWidgets(
    'preserva seleção entre buscas, descarta cancelamento e permite remover',
    (tester) async {
      final repository = FakeSpacesRepository(
        (_) async => makeSpacePage(),
        fetchParticipantsHandler: (_, _, _, page, size) async =>
            makeSpaceParticipantPage(number: page, size: size),
      );
      final tasksRepository = FakeTasksRepository();

      await tester.pumpWidget(
        _testApp(repository, tasksRepository: tasksRepository),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const Key('space-participants-toggle-filters')),
      );
      await _openCategorySearch(tester);
      await _searchCategories(tester, '');
      await _toggleCategoryOption(tester, 1);
      await _toggleCategoryOption(tester, 2);
      await _applyCategorySelection(tester);

      expect(
        find.byKey(
          const Key('space-participants-selected-category-OPERATIONAL'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('space-participants-selected-category-FINANCIAL')),
        findsOneWidget,
      );

      await _openCategorySearch(tester);
      expect(
        find.byKey(
          const Key('space-participants-category-selection-OPERATIONAL'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('space-participants-category-selection-FINANCIAL'),
        ),
        findsOneWidget,
      );
      await _searchCategories(tester, '');
      await _toggleCategoryOption(tester, 2);
      await tester.tap(
        find.byKey(
          const Key('space-participants-category-search-cancel-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('space-participants-selected-category-OPERATIONAL'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('space-participants-selected-category-FINANCIAL')),
        findsOneWidget,
      );

      await _openCategorySearch(tester);
      await _searchCategories(tester, '');
      await _toggleCategoryOption(tester, 2);
      await _applyCategorySelection(tester);

      expect(
        find.byKey(
          const Key('space-participants-selected-category-OPERATIONAL'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('space-participants-selected-category-FINANCIAL')),
        findsNothing,
      );
      final operationalChip = tester.widget<InputChip>(
        find.byKey(
          const Key('space-participants-selected-category-OPERATIONAL'),
        ),
      );
      operationalChip.onDeleted!();
      await tester.pump();

      expect(
        find.byKey(
          const Key('space-participants-selected-category-OPERATIONAL'),
        ),
        findsNothing,
      );
      expect(tasksRepository.receivedTaskCategorySearchNames, <String?>[
        null,
        null,
        null,
      ]);
    },
  );

  testWidgets('mostra busca vazia e permite tentar novamente após falha', (
    tester,
  ) async {
    var retryAttempts = 0;
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      fetchParticipantsHandler: (_, _, _, page, size) async =>
          makeSpaceParticipantPage(number: page, size: size),
    );
    final tasksRepository = FakeTasksRepository(
      searchTaskCategoriesHandler: (_, _, name) async {
        if (name == 'empty') {
          return const <TaskCategorySummary>[];
        }
        retryAttempts += 1;
        if (retryAttempts == 1) {
          throw const ApiFailure(ApiFailureKind.network);
        }
        return const <TaskCategorySummary>[
          TaskCategorySummary(id: 3, category: TaskCategory.personal),
        ];
      },
    );

    await tester.pumpWidget(
      _testApp(repository, tasksRepository: tasksRepository),
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('space-participants-toggle-filters')),
    );
    await _openCategorySearch(tester);

    await _searchCategories(tester, 'empty');
    expect(
      find.byKey(const Key('space-participants-category-search-empty')),
      findsOneWidget,
    );

    await _searchCategories(tester, 'retry');
    expect(
      find.byKey(const Key('space-participants-category-search-error')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('space-participants-category-search-button')),
    );
    await tester.pumpAndSettle();

    expect(retryAttempts, 2);
    expect(tasksRepository.receivedTaskCategorySearchNames, <String?>[
      'empty',
      'retry',
      'retry',
    ]);
    expect(
      find.byKey(const Key('space-participants-category-search-error')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('space-participants-category-option-3')),
      findsOneWidget,
    );
  });

  testWidgets('encaminha 401 da busca de categorias para expiração', (
    tester,
  ) async {
    var sessionExpiredCalls = 0;
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      fetchParticipantsHandler: (_, _, _, page, size) async =>
          makeSpaceParticipantPage(number: page, size: size),
    );
    final tasksRepository = FakeTasksRepository(
      searchTaskCategoriesHandler: (_, _, _) async =>
          throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401),
    );

    await tester.pumpWidget(
      _testApp(
        repository,
        tasksRepository: tasksRepository,
        onSessionExpired: () => sessionExpiredCalls += 1,
      ),
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('space-participants-toggle-filters')),
    );
    await _openCategorySearch(tester);
    await _searchCategories(tester, '');

    expect(tasksRepository.searchTaskCategoriesCalls, 1);
    expect(sessionExpiredCalls, 1);
    expect(
      find.byKey(const Key('space-participants-category-search-error')),
      findsNothing,
    );
  });

  testWidgets(
    'navega entre páginas e altera o tamanho reiniciando na primeira',
    (tester) async {
      final repository = FakeSpacesRepository(
        (_) async => makeSpacePage(),
        fetchParticipantsHandler: (_, _, _, page, size) async {
          return makeSpaceParticipantPage(
            content: [
              _participant(
                1000 + (page * 100) + size,
                name: 'Página $page tamanho $size',
              ),
            ],
            number: page,
            size: size,
            totalElements: 60,
            totalPages: (60 / size).ceil(),
          );
        },
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('space-participant-card-1010')),
        findsOneWidget,
      );

      await _tapVisible(
        tester,
        find.byKey(const Key('space-participants-page-1')),
      );

      expect(repository.receivedParticipantPages, [0, 1]);
      expect(repository.receivedParticipantPageSizes, [10, 10]);
      expect(
        find.byKey(const Key('space-participant-card-1110')),
        findsOneWidget,
      );

      final sizeFinder = find.byKey(const Key('space-participants-page-size'));
      await tester.ensureVisible(sizeFinder);
      tester.widget<DropdownButton<int>>(sizeFinder).onChanged!(20);
      await tester.pumpAndSettle();

      expect(repository.receivedParticipantPages, [0, 1, 0]);
      expect(repository.receivedParticipantPageSizes, [10, 10, 20]);
      expect(
        find.byKey(const Key('space-participant-card-1020')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('space-participant-card-1110')),
        findsNothing,
      );
    },
  );

  testWidgets('permite tentar novamente e renderiza estado vazio', (
    tester,
  ) async {
    var shouldFail = true;
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      fetchParticipantsHandler: (_, _, _, page, size) async {
        if (shouldFail) {
          shouldFail = false;
          throw const ApiFailure(ApiFailureKind.network);
        }
        return makeSpaceParticipantPage(number: page, size: size);
      },
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('space-participants-error')), findsOneWidget);
    expect(repository.fetchSpaceParticipantsCalls, 1);

    await tester.tap(find.byKey(const Key('space-participants-retry-button')));
    await tester.pumpAndSettle();

    expect(repository.fetchSpaceParticipantsCalls, 2);
    expect(find.byKey(const Key('space-participants-empty')), findsOneWidget);
    expect(find.byKey(const Key('space-participants-error')), findsNothing);
  });

  testWidgets('encaminha 401 para expiração da sessão', (tester) async {
    var sessionExpiredCalls = 0;
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      fetchParticipantsHandler: (_, _, _, _, _) async {
        throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401);
      },
    );

    await tester.pumpWidget(
      _testApp(repository, onSessionExpired: () => sessionExpiredCalls += 1),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchSpaceParticipantsCalls, 1);
    expect(sessionExpiredCalls, 1);
    expect(find.byKey(const Key('space-participants-error')), findsNothing);
  });

  testWidgets('mostra estado de acesso negado em 403 sem expirar a sessão', (
    tester,
  ) async {
    var sessionExpiredCalls = 0;
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      fetchParticipantsHandler: (_, _, _, _, _) async {
        throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403);
      },
    );

    await tester.pumpWidget(
      _testApp(repository, onSessionExpired: () => sessionExpiredCalls += 1),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchSpaceParticipantsCalls, 1);
    expect(sessionExpiredCalls, 0);
    expect(find.byKey(const Key('space-participants-error')), findsOneWidget);
    expect(
      find.text(
        'É necessária uma participação aprovada para consultar este espaço.',
      ),
      findsOneWidget,
    );
  });
}

Widget _testApp(
  FakeSpacesRepository repository, {
  FakeTasksRepository? tasksRepository,
  VoidCallback? onSessionExpired,
}) {
  return MaterialApp(
    home: SpaceParticipantsPage(
      session: testSession,
      spaceId: 7,
      spaceName: 'Espaço de testes',
      spacesRepository: repository,
      tasksRepository: tasksRepository ?? FakeTasksRepository(),
      onSessionExpired: onSessionExpired,
    ),
  );
}

SpaceParticipant _participant(
  int id, {
  required String name,
  SpaceUserRole role = SpaceUserRole.participant,
  Set<TaskCategory> categories = const {},
  num score = 0,
  num contributionPercentual = 0,
}) {
  return SpaceParticipant(
    id: id,
    name: name,
    spaceUserRole: role,
    taskCategories: categories.toList(),
    score: score,
    contributionPercentual: contributionPercentual,
  );
}

DropdownButton<SpaceUserRole> _roleDropdown(WidgetTester tester) {
  return tester.widget<DropdownButton<SpaceUserRole>>(
    find.descendant(
      of: find.byKey(const Key('space-participants-role-filter')),
      matching: find.byType(DropdownButton<SpaceUserRole>),
    ),
  );
}

DropdownButton<ParticipantSort> _sortDropdown(WidgetTester tester) {
  return tester.widget<DropdownButton<ParticipantSort>>(
    find.descendant(
      of: find.byKey(const Key('space-participants-sort-filter')),
      matching: find.byType(DropdownButton<ParticipantSort>),
    ),
  );
}

Future<void> _openCategorySearch(WidgetTester tester) async {
  await _tapVisible(
    tester,
    find.byKey(const Key('space-participants-category-field')),
  );
  expect(
    find.byKey(const Key('space-participants-category-search-dialog')),
    findsOneWidget,
  );
}

Future<void> _searchCategories(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const Key('space-participants-category-search-field')),
    query,
  );
  await tester.tap(
    find.byKey(const Key('space-participants-category-search-button')),
  );
  await tester.pumpAndSettle();
}

Future<void> _toggleCategoryOption(WidgetTester tester, int id) async {
  await tester.tap(
    find.byKey(ValueKey('space-participants-category-option-$id')),
  );
  await tester.pump();
}

Future<void> _applyCategorySelection(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('space-participants-category-search-apply-button')),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
