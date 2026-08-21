import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/created_space.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';
import 'package:mobile_flutter/features/spaces/presentation/space_participants_page.dart';
import 'package:mobile_flutter/features/spaces/presentation/spaces_page.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/presentation/tasks_page.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('carrega uma vez e apresenta os espaços', (tester) async {
    final completer = Completer<SpacePageResult>();
    final repository = FakeSpacesRepository((_) => completer.future);

    await tester.pumpWidget(_testApp(repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('spaces-loading')), findsOneWidget);
    expect(repository.fetchSpacesCalls, 1);
    expect(repository.receivedAccessTokens, [testSession.accessToken]);
    expect(repository.receivedPages, [0]);
    expect(repository.receivedPageSizes, [10]);
    expect(repository.receivedFilters.single.name, isNull);
    expect(repository.receivedFilters.single.role, isNull);
    expect(repository.receivedFilters.single.status, isNull);

    completer.complete(makeSpacePage(content: const [testSpace]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('spaces-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('space-card-1')), findsOneWidget);
    expect(find.text('Residência do Casal Laet'), findsOneWidget);
    expect(find.text('Participante'), findsOneWidget);

    await tester.pump();
    expect(repository.fetchSpacesCalls, 1);
  });

  testWidgets('ignora resposta antiga quando o repositório da sessão muda', (
    tester,
  ) async {
    final oldResponse = Completer<SpacePageResult>();
    final oldRepository = FakeSpacesRepository((_) => oldResponse.future);
    final newRepository = FakeSpacesRepository(
      (_) async => makeSpacePage(content: [_makeSpace(2)]),
    );
    var activeRepository = oldRepository;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SpacesPage(
              session: testSession,
              spacesRepository: activeRepository,
              tasksRepository: FakeTasksRepository(),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(oldRepository.fetchSpacesCalls, 1);

    rebuild(() => activeRepository = newRepository);
    await tester.pumpAndSettle();

    expect(newRepository.fetchSpacesCalls, 1);
    expect(find.byKey(const ValueKey('space-card-2')), findsOneWidget);

    oldResponse.complete(makeSpacePage(content: [_makeSpace(1)]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-card-1')), findsNothing);
    expect(find.byKey(const ValueKey('space-card-2')), findsOneWidget);
  });

  testWidgets('exibe barra com páginas visuais e reticências', (tester) async {
    final repository = FakeSpacesRepository(
      (_) async => throw StateError('Handler paginado esperado.'),
      fetchPageHandler: (_, page, size) async {
        expect(page, 0);
        expect(size, 10);
        return _makePagedSpacePage(
          content: [_makeSpace(1)],
          number: 0,
          totalElements: 200,
          totalPages: 20,
        );
      },
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(repository.receivedPages, [0]);
    expect(repository.receivedPageSizes, [10]);
    expect(find.byKey(const ValueKey('spaces-pagination-bar')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('spaces-page-0')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('spaces-page-1')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data == '…' || widget.data == '...'),
      ),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('spaces-page-previous')), findsOneWidget);
    expect(find.byKey(const ValueKey('spaces-page-next')), findsOneWidget);
  });

  testWidgets('troca de página substitui o conteúdo e respeita os limites', (
    tester,
  ) async {
    final repository = FakeSpacesRepository(
      (_) async => throw StateError('Handler paginado esperado.'),
      fetchPageHandler: (_, page, size) async => _makePagedSpacePage(
        content: [_makeSpace(page + 1)],
        number: page,
        size: size,
        totalElements: 3,
        totalPages: 3,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-card-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('spaces-page-1')));
    await tester.pumpAndSettle();

    expect(repository.receivedPages, [0, 1]);
    expect(repository.receivedPageSizes, [10, 10]);
    expect(find.byKey(const ValueKey('space-card-1')), findsNothing);
    expect(find.byKey(const ValueKey('space-card-2')), findsOneWidget);

    final nextPageButton = find.byKey(const ValueKey('spaces-page-next'));
    await tester.ensureVisible(nextPageButton);
    await tester.pumpAndSettle();
    await tester.tap(nextPageButton);
    await tester.pumpAndSettle();

    expect(repository.receivedPages, [0, 1, 2]);
    expect(find.byKey(const ValueKey('space-card-2')), findsNothing);
    expect(find.byKey(const ValueKey('space-card-3')), findsOneWidget);

    expect(tester.widget<IconButton>(nextPageButton).onPressed, isNull);

    expect(repository.receivedPages, [0, 1, 2]);

    final previousPageButton = find.byKey(
      const ValueKey('spaces-page-previous'),
    );
    await tester.ensureVisible(previousPageButton);
    await tester.pumpAndSettle();
    await tester.tap(previousPageButton);
    await tester.pumpAndSettle();

    expect(repository.receivedPages, [0, 1, 2, 1]);
    expect(find.byKey(const ValueKey('space-card-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('space-card-3')), findsNothing);
  });

  testWidgets('oferece tamanhos permitidos e mudar tamanho reinicia na zero', (
    tester,
  ) async {
    final repository = FakeSpacesRepository(
      (_) async => throw StateError('Handler paginado esperado.'),
      fetchPageHandler: (_, page, size) async => _makePagedSpacePage(
        content: [_makeSpace(size)],
        number: page,
        size: size,
        totalElements: 100,
        totalPages: (100 / size).ceil(),
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    final pageSizeDropdown = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('spaces-page-size')),
    );
    expect(pageSizeDropdown.value, 10);
    expect(pageSizeDropdown.items!.map((item) => item.value), [5, 10, 20, 50]);

    await tester.tap(find.byKey(const ValueKey('spaces-page-1')));
    await tester.pumpAndSettle();
    expect(repository.receivedPages, [0, 1]);

    pageSizeDropdown.onChanged!(20);
    await tester.pumpAndSettle();

    expect(repository.receivedPages, [0, 1, 0]);
    expect(repository.receivedPageSizes, [10, 10, 20]);
    expect(find.byKey(const ValueKey('space-card-10')), findsNothing);
    expect(find.byKey(const ValueKey('space-card-20')), findsOneWidget);
  });

  testWidgets('aplicar filtros reinicia na página zero e preserva o tamanho', (
    tester,
  ) async {
    final repository = FakeSpacesRepository(
      (_) async => throw StateError('Handler paginado esperado.'),
      fetchPageHandler: (_, page, size) async => _makePagedSpacePage(
        content: [_makeSpace(1000 + (page * 100) + size)],
        number: page,
        size: size,
        totalElements: 100,
        totalPages: (100 / size).ceil(),
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    final pageSizeDropdown = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('spaces-page-size')),
    );
    pageSizeDropdown.onChanged!(20);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spaces-page-1')));
    await tester.pumpAndSettle();

    await _toggleFilters(tester);
    await tester.enterText(
      find.byKey(const ValueKey('spaces-name-filter')),
      '  praia  ',
    );
    await tester.tap(find.byKey(const ValueKey('spaces-apply-filters')));
    await tester.pumpAndSettle();

    expect(repository.receivedPages, [0, 0, 1, 0]);
    expect(repository.receivedPageSizes, [10, 20, 20, 20]);
    final appliedFilters = repository.receivedFilters.last;
    expect(appliedFilters.name, '  praia  ');
    expect(appliedFilters.role, isNull);
    expect(appliedFilters.status, isNull);
  });

  testWidgets('aceita espaço sem vínculo e sem responsável', (tester) async {
    const availableSpace = SpaceSummary(
      id: 2,
      name: 'Espaço disponível',
      spaceAdminName: null,
      active: true,
      spaceUserRole: null,
      spaceMembershipStatus: null,
      activeParticipationsCount: 2,
    );
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(content: const [availableSpace]),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Espaço disponível'), findsOneWidget);
    expect(find.text('Disponível'), findsOneWidget);
    expect(find.textContaining('Responsável:'), findsNothing);
  });

  testWidgets(
    'abre tarefas do espaço aprovado e faz uma única busca contextual',
    (tester) async {
      final spacesRepository = FakeSpacesRepository(
        (_) async => makeSpacePage(content: const [testSpace]),
      );
      final tasksRepository = FakeTasksRepository();

      await tester.pumpWidget(
        _testApp(spacesRepository, tasksRepository: tasksRepository),
      );
      await tester.pumpAndSettle();

      final tasksButton = find.byKey(const ValueKey('space-tasks-button-1'));
      expect(tasksButton, findsOneWidget);
      expect(tester.widget<OutlinedButton>(tasksButton).onPressed, isNotNull);
      expect(tasksRepository.fetchTasksCalls, 0);

      await tester.tap(tasksButton);
      await tester.pumpAndSettle();

      expect(find.byType(TasksPage), findsOneWidget);
      final tasksPage = tester.widget<TasksPage>(find.byType(TasksPage));
      expect(identical(tasksPage.spacesRepository, spacesRepository), isTrue);
      expect(tasksRepository.fetchTasksCalls, 1);
      expect(tasksRepository.receivedAccessTokens, [testSession.accessToken]);
      expect(tasksRepository.receivedSpaceIds, [testSpace.id]);
      expect(tasksRepository.receivedPages, [0]);
      expect(tasksRepository.receivedPageSizes, [10]);
    },
  );

  testWidgets(
    'abre participantes do espaço aprovado e faz uma busca contextual',
    (tester) async {
      final repository = FakeSpacesRepository(
        (_) async => makeSpacePage(content: const [testSpace]),
        fetchParticipantsHandler: (_, _, _, page, size) async =>
            makeSpaceParticipantPage(number: page, size: size),
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      final participantsChip = find.byKey(
        const ValueKey('space-participants-button-1'),
      );
      expect(participantsChip, findsOneWidget);
      final inkWell = tester.widget<InkWell>(
        find.descendant(of: participantsChip, matching: find.byType(InkWell)),
      );
      expect(inkWell.onTap, isNotNull);
      final targetSize = tester.getSize(
        find.descendant(
          of: participantsChip,
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(targetSize.width, greaterThanOrEqualTo(48));
      expect(targetSize.height, greaterThanOrEqualTo(48));
      expect(repository.fetchSpaceParticipantsCalls, 0);

      await tester.tap(participantsChip);
      await tester.pumpAndSettle();

      expect(find.byType(SpaceParticipantsPage), findsOneWidget);
      expect(repository.fetchSpaceParticipantsCalls, 1);
      expect(repository.receivedParticipantAccessTokens, [
        testSession.accessToken,
      ]);
      expect(repository.receivedParticipantSpaceIds, [testSpace.id]);
      expect(repository.receivedParticipantPages, [0]);
      expect(repository.receivedParticipantPageSizes, [10]);
      expect(repository.receivedParticipantFilters.single.name, isNull);
      expect(repository.receivedParticipantFilters.single.role, isNull);
      expect(
        repository.receivedParticipantFilters.single.taskCategories,
        isEmpty,
      );
      expect(repository.receivedParticipantFilters.single.sort, isNull);
    },
  );

  testWidgets(
    'desabilita participantes sem vínculo ou com participação pendente',
    (tester) async {
      const availableSpace = SpaceSummary(
        id: 20,
        name: 'Espaço sem vínculo',
        spaceAdminName: 'Responsável',
        active: true,
        spaceUserRole: null,
        spaceMembershipStatus: null,
        activeParticipationsCount: 1,
      );
      const pendingSpace = SpaceSummary(
        id: 21,
        name: 'Espaço pendente',
        spaceAdminName: 'Responsável',
        active: true,
        spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
        spaceMembershipStatus: 'PENDING',
        activeParticipationsCount: 2,
      );
      final repository = FakeSpacesRepository(
        (_) async =>
            makeSpacePage(content: const [availableSpace, pendingSpace]),
        fetchParticipantsHandler: (_, _, _, page, size) async =>
            makeSpaceParticipantPage(number: page, size: size),
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      for (final id in <int>[availableSpace.id, pendingSpace.id]) {
        final participantsChip = find.byKey(
          ValueKey('space-participants-button-$id'),
        );
        expect(participantsChip, findsOneWidget);
        await tester.ensureVisible(participantsChip);
        await tester.pump();
        final inkWell = tester.widget<InkWell>(
          find.descendant(of: participantsChip, matching: find.byType(InkWell)),
        );
        expect(inkWell.onTap, isNull);
        final targetSize = tester.getSize(
          find.descendant(
            of: participantsChip,
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(targetSize.width, greaterThanOrEqualTo(48));
        expect(targetSize.height, greaterThanOrEqualTo(48));
      }
      expect(repository.fetchSpaceParticipantsCalls, 0);
      expect(find.byType(SpaceParticipantsPage), findsNothing);
    },
  );

  for (final roleCase in <({String label, String? role, bool canEditTasks})>[
    (label: 'administrador', role: 'ROLE_SPACE_ADMIN', canEditTasks: true),
    (label: 'gerente', role: 'ROLE_SPACE_MANAGER', canEditTasks: true),
    (
      label: 'participante',
      role: 'ROLE_SPACE_PARTICIPANT',
      canEditTasks: false,
    ),
    (label: 'ausente', role: null, canEditTasks: false),
  ]) {
    testWidgets(
      'propaga papel ${roleCase.label} e controla a visibilidade da edição',
      (tester) async {
        final space = SpaceSummary(
          id: _roleTestTask.spaceId,
          name: 'Espaço por papel',
          spaceAdminName: 'Responsável',
          active: true,
          spaceUserRole: roleCase.role,
          spaceMembershipStatus: 'APPROVED',
          activeParticipationsCount: 1,
        );
        final spacesRepository = FakeSpacesRepository(
          (_) async => makeSpacePage(content: [space]),
        );
        final tasksRepository = FakeTasksRepository(
          handler: (_, _, filters, page, size) async => TaskPageResult(
            content: const [_roleTestTask],
            size: size,
            number: page,
            totalElements: 1,
            totalPages: 1,
          ),
        );

        await tester.pumpWidget(
          _testApp(spacesRepository, tasksRepository: tasksRepository),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('space-tasks-button-${space.id}')),
        );
        await tester.pumpAndSettle();

        final tasksPage = tester.widget<TasksPage>(find.byType(TasksPage));
        expect(tasksPage.canEditTasks, roleCase.canEditTasks);
        expect(
          find.byKey(ValueKey('task-edit-button-${_roleTestTask.id}')),
          roleCase.canEditTasks ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  testWidgets(
    'desabilita tarefas para espaços sem vínculo ou com participação pendente',
    (tester) async {
      const availableSpace = SpaceSummary(
        id: 2,
        name: 'Espaço sem vínculo',
        spaceAdminName: 'Responsável',
        active: true,
        spaceUserRole: null,
        spaceMembershipStatus: null,
        activeParticipationsCount: 1,
      );
      const pendingSpace = SpaceSummary(
        id: 3,
        name: 'Espaço pendente',
        spaceAdminName: 'Responsável',
        active: true,
        spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
        spaceMembershipStatus: 'PENDING',
        activeParticipationsCount: 1,
      );
      final spacesRepository = FakeSpacesRepository(
        (_) async =>
            makeSpacePage(content: const [availableSpace, pendingSpace]),
      );
      final tasksRepository = FakeTasksRepository();

      await tester.pumpWidget(
        _testApp(spacesRepository, tasksRepository: tasksRepository),
      );
      await tester.pumpAndSettle();

      for (final id in <int>[availableSpace.id, pendingSpace.id]) {
        final tasksButton = find.byKey(ValueKey('space-tasks-button-$id'));
        expect(tasksButton, findsOneWidget);
        expect(tester.widget<OutlinedButton>(tasksButton).onPressed, isNull);
      }
      expect(tasksRepository.fetchTasksCalls, 0);
      expect(find.byType(TasksPage), findsNothing);
    },
  );

  testWidgets('apresenta estado vazio', (tester) async {
    final repository = FakeSpacesRepository((_) async => makeSpacePage());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('spaces-empty')), findsOneWidget);
    expect(
      find.text('Nenhum espaço está disponível no momento.'),
      findsOneWidget,
    );
  });

  testWidgets('permite tentar novamente depois de uma falha', (tester) async {
    var shouldFail = true;
    final repository = FakeSpacesRepository((_) async {
      if (shouldFail) {
        shouldFail = false;
        throw const ApiFailure(ApiFailureKind.network);
      }
      return makeSpacePage(content: const [testSpace]);
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('spaces-error')), findsOneWidget);
    expect(repository.fetchSpacesCalls, 1);

    await tester.tap(find.byKey(const ValueKey('spaces-retry-button')));
    await tester.pumpAndSettle();

    expect(repository.fetchSpacesCalls, 2);
    expect(find.byKey(const ValueKey('space-card-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('spaces-error')), findsNothing);
  });

  testWidgets('mantém os filtros recolhidos e alterna sem novo GET', (
    tester,
  ) async {
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(content: const [testSpace]),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('spaces-toggle-filters')), findsOneWidget);
    expect(find.byKey(const ValueKey('spaces-filter-panel')), findsNothing);
    expect(find.byKey(const ValueKey('spaces-name-filter')), findsNothing);
    expect(find.text('Expandir'), findsOneWidget);
    expect(find.text('Contrair'), findsNothing);
    expect(find.text('Filtros ativos'), findsNothing);
    expect(repository.fetchSpacesCalls, 1);

    await _toggleFilters(tester);

    expect(find.byKey(const ValueKey('spaces-filter-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('spaces-name-filter')), findsOneWidget);
    expect(find.text('Contrair'), findsOneWidget);
    expect(find.text('Expandir'), findsNothing);
    expect(repository.fetchSpacesCalls, 1);

    await _toggleFilters(tester);

    expect(find.byKey(const ValueKey('spaces-filter-panel')), findsNothing);
    expect(find.byKey(const ValueKey('spaces-name-filter')), findsNothing);
    expect(find.text('Expandir'), findsOneWidget);
    expect(find.text('Contrair'), findsNothing);
    expect(repository.fetchSpacesCalls, 1);
  });

  testWidgets('aplica e limpa nome, papel e situação', (tester) async {
    var responseNumber = 0;
    final repository = FakeSpacesRepository((_) async {
      responseNumber += 1;
      return responseNumber == 1
          ? makeSpacePage(content: const [testSpace])
          : makeSpacePage();
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await _toggleFilters(tester);

    await tester.enterText(
      find.byKey(const ValueKey('spaces-name-filter')),
      '  casal laet  ',
    );

    final roleDropdown = tester.widget<DropdownButton<SpaceUserRole>>(
      find.descendant(
        of: find.byKey(const ValueKey('spaces-role-filter')),
        matching: find.byType(DropdownButton<SpaceUserRole>),
      ),
    );
    roleDropdown.onChanged!(SpaceUserRole.participant);
    await tester.pump();

    final statusDropdown = tester.widget<DropdownButton<SpaceMembershipStatus>>(
      find.descendant(
        of: find.byKey(const ValueKey('spaces-status-filter')),
        matching: find.byType(DropdownButton<SpaceMembershipStatus>),
      ),
    );
    statusDropdown.onChanged!(SpaceMembershipStatus.approved);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('spaces-apply-filters')));
    await tester.pumpAndSettle();

    expect(repository.fetchSpacesCalls, 2);
    final appliedFilters = repository.receivedFilters.last;
    expect(appliedFilters.name, '  casal laet  ');
    expect(appliedFilters.role, SpaceUserRole.participant);
    expect(appliedFilters.status, SpaceMembershipStatus.approved);
    expect(find.byKey(const ValueKey('spaces-filter-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('spaces-name-filter')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('spaces-clear-filters')));
    await tester.pumpAndSettle();

    expect(repository.fetchSpacesCalls, 3);
    final clearedFilters = repository.receivedFilters.last;
    expect(clearedFilters.name, isNull);
    expect(clearedFilters.role, isNull);
    expect(clearedFilters.status, isNull);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('spaces-name-filter')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('oferece somente situações úteis para este endpoint', (
    tester,
  ) async {
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(content: const [testSpace]),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await _toggleFilters(tester);

    final statusDropdown = tester.widget<DropdownButton<SpaceMembershipStatus>>(
      find.descendant(
        of: find.byKey(const ValueKey('spaces-status-filter')),
        matching: find.byType(DropdownButton<SpaceMembershipStatus>),
      ),
    );
    expect(statusDropdown.items!.map((item) => item.value), [
      null,
      SpaceMembershipStatus.pending,
      SpaceMembershipStatus.approved,
    ]);
  });

  testWidgets('preserva os filtros aplicados ao recolher e reabrir', (
    tester,
  ) async {
    final repository = FakeSpacesRepository((_) async => makeSpacePage());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await _toggleFilters(tester);

    await tester.enterText(
      find.byKey(const ValueKey('spaces-name-filter')),
      '  casal laet  ',
    );
    final roleDropdown = tester.widget<DropdownButton<SpaceUserRole>>(
      find.descendant(
        of: find.byKey(const ValueKey('spaces-role-filter')),
        matching: find.byType(DropdownButton<SpaceUserRole>),
      ),
    );
    roleDropdown.onChanged!(SpaceUserRole.participant);
    await tester.pump();

    final statusDropdown = tester.widget<DropdownButton<SpaceMembershipStatus>>(
      find.descendant(
        of: find.byKey(const ValueKey('spaces-status-filter')),
        matching: find.byType(DropdownButton<SpaceMembershipStatus>),
      ),
    );
    statusDropdown.onChanged!(SpaceMembershipStatus.approved);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('spaces-apply-filters')));
    await tester.pumpAndSettle();

    expect(repository.fetchSpacesCalls, 2);
    expect(repository.receivedFilters.last.name, '  casal laet  ');
    expect(repository.receivedFilters.last.role, SpaceUserRole.participant);
    expect(
      repository.receivedFilters.last.status,
      SpaceMembershipStatus.approved,
    );

    await _toggleFilters(tester);

    expect(find.byKey(const ValueKey('spaces-filter-panel')), findsNothing);
    expect(find.text('Filtros ativos'), findsOneWidget);
    expect(repository.fetchSpacesCalls, 2);

    await _toggleFilters(tester);

    expect(repository.fetchSpacesCalls, 2);
    expect(find.text('Filtros ativos'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('spaces-name-filter')))
          .controller!
          .text,
      '  casal laet  ',
    );
    expect(
      tester
          .widget<DropdownButton<SpaceUserRole>>(
            find.descendant(
              of: find.byKey(const ValueKey('spaces-role-filter')),
              matching: find.byType(DropdownButton<SpaceUserRole>),
            ),
          )
          .value,
      SpaceUserRole.participant,
    );
    expect(
      tester
          .widget<DropdownButton<SpaceMembershipStatus>>(
            find.descendant(
              of: find.byKey(const ValueKey('spaces-status-filter')),
              matching: find.byType(DropdownButton<SpaceMembershipStatus>),
            ),
          )
          .value,
      SpaceMembershipStatus.approved,
    );
  });

  testWidgets(
    'cria espaço inativo, avisa o usuário e mantém a lista ativa sem novo GET',
    (tester) async {
      final repository = FakeSpacesRepository(
        (_) async => makeSpacePage(),
        createHandler: (_, name) async => CreatedSpace(
          id: 9,
          name: name,
          spaceAdminName: 'Usuário de Teste',
          active: false,
        ),
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      expect(repository.fetchSpacesCalls, 1);
      await tester.tap(find.byKey(const ValueKey('create-space-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('create-space-name-field')),
        '  Casa de Praia  ',
      );
      await tester.tap(
        find.byKey(const ValueKey('create-space-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(repository.createSpaceCalls, 1);
      expect(repository.receivedCreateAccessTokens, [testSession.accessToken]);
      expect(repository.receivedSpaceNames, ['Casa de Praia']);
      expect(repository.fetchSpacesCalls, 1);
      expect(
        find.textContaining(
          'Ele está inativo e ainda não aparece nesta lista.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('spaces-empty')), findsOneWidget);
    },
  );
}

Widget _testApp(
  FakeSpacesRepository repository, {
  FakeTasksRepository? tasksRepository,
}) {
  return MaterialApp(
    home: SpacesPage(
      session: testSession,
      spacesRepository: repository,
      tasksRepository: tasksRepository ?? FakeTasksRepository(),
    ),
  );
}

Future<void> _toggleFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('spaces-toggle-filters')));
  await tester.pumpAndSettle();
}

SpaceSummary _makeSpace(int id) {
  return SpaceSummary(
    id: id,
    name: 'Espaço $id',
    spaceAdminName: 'Responsável $id',
    active: true,
    spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
    spaceMembershipStatus: 'APPROVED',
    activeParticipationsCount: 1,
  );
}

const _roleTestTask = TaskSummary(
  id: 91,
  spaceId: 71,
  description: 'Tarefa por papel',
  score: 10,
  category: TaskCategory.operational,
  schedule: null,
  active: true,
  creatorName: 'Responsável',
);

SpacePageResult _makePagedSpacePage({
  required List<SpaceSummary> content,
  required int number,
  required int totalElements,
  required int totalPages,
  int size = 10,
}) {
  return SpacePageResult(
    content: content,
    size: size,
    number: number,
    totalElements: totalElements,
    totalPages: totalPages,
  );
}
