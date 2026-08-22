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
            categories: const {
              TaskCategory.operational,
              TaskCategory.financial,
            },
            score: 42.5,
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
    expect(find.text('Operacional'), findsOneWidget);
    expect(find.text('Financeira'), findsOneWidget);
    expect(find.text('Caio Souza'), findsOneWidget);
    expect(find.text('Participante'), findsOneWidget);
    expect(find.text('0 pontos'), findsOneWidget);
  });

  testWidgets('aplica todos os filtros e limpa os critérios', (tester) async {
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      fetchParticipantsHandler: (_, _, _, page, size) async =>
          makeSpaceParticipantPage(number: page, size: size),
    );

    await tester.pumpWidget(_testApp(repository));
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

    final operationalFinder = find.byKey(
      const Key('space-participants-category-OPERATIONAL'),
    );
    tester.widget<FilterChip>(operationalFinder).onSelected!(true);
    await tester.pump();
    final financialFinder = find.byKey(
      const Key('space-participants-category-FINANCIAL'),
    );
    tester.widget<FilterChip>(financialFinder).onSelected!(true);
    await tester.pump();

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
    expect(tester.widget<FilterChip>(operationalFinder).selected, isFalse);
    expect(tester.widget<FilterChip>(financialFinder).selected, isFalse);
    expect(
      find.byKey(const Key('space-participants-active-filters')),
      findsNothing,
    );
    expect(find.byKey(const Key('space-participants-empty')), findsOneWidget);
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
  VoidCallback? onSessionExpired,
}) {
  return MaterialApp(
    home: SpaceParticipantsPage(
      session: testSession,
      spaceId: 7,
      spaceName: 'Espaço de testes',
      spacesRepository: repository,
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
}) {
  return SpaceParticipant(
    id: id,
    name: name,
    spaceUserRole: role,
    taskCategories: categories.toList(),
    score: score,
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

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
