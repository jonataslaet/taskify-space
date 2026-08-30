import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/created_space.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation.dart';
import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';
import 'package:mobile_flutter/features/spaces/domain/updated_space.dart';
import 'package:mobile_flutter/features/spaces/presentation/edit_space_dialog.dart';
import 'package:mobile_flutter/features/spaces/presentation/space_participations_page.dart';
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

  testWidgets(
    'exibe ações gerenciais somente para administrador ou gerente aprovados',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const spaces = <SpaceSummary>[
        SpaceSummary(
          id: 51,
          name: 'Espaço administrado',
          spaceAdminName: 'Administrador',
          active: true,
          available: true,
          spaceUserRole: 'ROLE_SPACE_ADMIN',
          spaceMembershipStatus: 'APPROVED',
          activeParticipationsCount: 1,
        ),
        SpaceSummary(
          id: 52,
          name: 'Espaço gerenciado',
          spaceAdminName: 'Administrador',
          active: true,
          available: true,
          spaceUserRole: 'ROLE_SPACE_MANAGER',
          spaceMembershipStatus: 'APPROVED',
          activeParticipationsCount: 1,
        ),
        SpaceSummary(
          id: 53,
          name: 'Espaço participado',
          spaceAdminName: 'Administrador',
          active: true,
          available: true,
          spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
          spaceMembershipStatus: 'APPROVED',
          activeParticipationsCount: 1,
        ),
        SpaceSummary(
          id: 54,
          name: 'Espaço pendente',
          spaceAdminName: 'Administrador',
          active: true,
          available: true,
          spaceUserRole: 'ROLE_SPACE_ADMIN',
          spaceMembershipStatus: 'PENDING',
          activeParticipationsCount: 1,
        ),
        SpaceSummary(
          id: 55,
          name: 'Espaço sem vínculo',
          spaceAdminName: 'Administrador',
          active: true,
          available: true,
          spaceUserRole: null,
          spaceMembershipStatus: null,
          activeParticipationsCount: 1,
        ),
      ];
      final repository = FakeSpacesRepository(
        (_) async => makeSpacePage(content: spaces),
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      for (final id in <int>[51, 52]) {
        expect(find.byKey(ValueKey('space-edit-button-$id')), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(ValueKey('space-participations-button-$id')),
              )
              .onPressed,
          isNotNull,
        );
      }
      for (final id in <int>[53, 54, 55]) {
        expect(find.byKey(ValueKey('space-edit-button-$id')), findsNothing);
        expect(
          find.byKey(ValueKey('space-participations-button-$id')),
          findsNothing,
        );
      }
    },
  );

  testWidgets('abre edição e recarrega a página atual após confirmar', (
    tester,
  ) async {
    const originalSpace = SpaceSummary(
      id: 81,
      name: 'Espaço original',
      spaceAdminName: 'Usuário de Teste',
      active: true,
      available: true,
      spaceUserRole: 'ROLE_SPACE_ADMIN',
      spaceMembershipStatus: 'APPROVED',
      activeParticipationsCount: 3,
    );
    const refreshedSpace = SpaceSummary(
      id: 81,
      name: 'Espaço revisado',
      spaceAdminName: 'Usuário de Teste',
      active: true,
      available: false,
      spaceUserRole: 'ROLE_SPACE_ADMIN',
      spaceMembershipStatus: 'APPROVED',
      activeParticipationsCount: 3,
    );
    var fetchCalls = 0;
    final repository = FakeSpacesRepository(
      (_) async => throw StateError('Handler paginado esperado.'),
      fetchPageHandler: (_, page, size) async {
        fetchCalls += 1;
        return _makePagedSpacePage(
          content: [fetchCalls >= 3 ? refreshedSpace : originalSpace],
          number: page,
          size: size,
          totalElements: 20,
          totalPages: 2,
        );
      },
      updateSpaceHandler: (_, spaceId, update) async => UpdatedSpace(
        id: spaceId,
        name: update.name ?? originalSpace.name,
        spaceAdminName: originalSpace.spaceAdminName,
        active: originalSpace.active,
        available: update.available ?? originalSpace.available,
      ),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    final secondPageButton = find.byKey(const ValueKey('spaces-page-1'));
    await tester.ensureVisible(secondPageButton);
    await tester.tap(secondPageButton);
    await tester.pumpAndSettle();

    final editButton = find.byKey(const ValueKey('space-edit-button-81'));
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.byType(EditSpaceDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('edit-space-name-field')),
      '  Espaço revisado  ',
    );
    await tester.tap(find.byKey(const ValueKey('edit-space-available-field')));
    await tester.pump();
    final submitButton = find.byKey(const ValueKey('edit-space-submit-button'));
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(repository.updateSpaceCalls, 1);
    expect(repository.receivedUpdateSpaceAccessTokens, [
      testSession.accessToken,
    ]);
    expect(repository.receivedUpdateSpaceIds, [originalSpace.id]);
    final update = repository.receivedSpaceUpdates.single;
    expect(update.name, 'Espaço revisado');
    expect(update.available, isFalse);
    expect(repository.fetchSpacesCalls, 3);
    expect(repository.receivedPages, [0, 1, 1]);
    expect(repository.receivedPageSizes, [10, 10, 10]);
    expect(find.byKey(const ValueKey('space-updated-message')), findsOneWidget);
    expect(find.text('Espaço original'), findsNothing);
    expect(find.text('Espaço revisado'), findsOneWidget);
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

  testWidgets(
    'solicita participação pelo espaço disponível e atualiza para pendente',
    (tester) async {
      const availableSpace = SpaceSummary(
        id: 2,
        name: 'Espaço disponível',
        spaceAdminName: null,
        active: true,
        available: true,
        spaceUserRole: null,
        spaceMembershipStatus: null,
        activeParticipationsCount: 2,
      );
      const pendingSpace = SpaceSummary(
        id: 2,
        name: 'Espaço disponível',
        spaceAdminName: null,
        active: true,
        available: true,
        spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
        spaceMembershipStatus: 'PENDING',
        activeParticipationsCount: 2,
      );
      final requestCompleter = Completer<void>();
      var fetchCalls = 0;
      final repository = FakeSpacesRepository((_) async {
        fetchCalls += 1;
        return makeSpacePage(
          content: [fetchCalls == 1 ? availableSpace : pendingSpace],
        );
      }, requestSpaceParticipationHandler: (_, _) => requestCompleter.future);

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('Espaço disponível'), findsOneWidget);
      expect(find.text('Solicitar participação'), findsOneWidget);
      expect(find.textContaining('Responsável:'), findsNothing);
      final requestButton = find.byKey(
        const ValueKey('space-participation-request-button-2'),
      );
      expect(requestButton, findsOneWidget);
      expect(
        tester.getSemantics(requestButton),
        matchesSemantics(
          label: 'Solicitar participação em Espaço disponível',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      final requestTarget = find.descendant(
        of: requestButton,
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(requestTarget).height, greaterThanOrEqualTo(48));

      await tester.tap(requestButton);
      await tester.pump();

      expect(repository.requestSpaceParticipationCalls, 1);
      expect(repository.receivedRequestSpaceParticipationAccessTokens, [
        testSession.accessToken,
      ]);
      expect(repository.receivedRequestSpaceParticipationSpaceIds, [2]);
      expect(
        find.byKey(const ValueKey('space-participation-request-progress')),
        findsOneWidget,
      );
      expect(find.text('Solicitando participação...'), findsOneWidget);

      await tester.tap(requestButton);
      await tester.pump();
      expect(repository.requestSpaceParticipationCalls, 1);

      requestCompleter.complete();
      await tester.pumpAndSettle();

      expect(repository.fetchSpacesCalls, 2);
      expect(repository.receivedPages, [0, 0]);
      expect(repository.receivedPageSizes, [10, 10]);
      expect(requestButton, findsNothing);
      expect(find.text('Participação pendente'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('space-participation-requested-message')),
        findsOneWidget,
      );
      expect(
        find.text('Solicitação enviada para "Espaço disponível".'),
        findsOneWidget,
      );
    },
  );

  testWidgets('401 ao solicitar participação expira a sessão', (tester) async {
    var sessionExpiredCalls = 0;
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(content: [_availableSpace(3)]),
      requestSpaceParticipationHandler: (_, _) async =>
          throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401),
    );

    await tester.pumpWidget(
      _testApp(repository, onSessionExpired: () => sessionExpiredCalls += 1),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('space-participation-request-button-3')),
    );
    await tester.pumpAndSettle();

    expect(repository.requestSpaceParticipationCalls, 1);
    expect(sessionExpiredCalls, 1);
    expect(
      find.byKey(const ValueKey('space-participation-request-error')),
      findsNothing,
    );
  });

  testWidgets(
    'erro ao solicitar participação informa e permite tentar de novo',
    (tester) async {
      final repository = FakeSpacesRepository(
        (_) async => makeSpacePage(content: [_availableSpace(4)]),
        requestSpaceParticipationHandler: (_, _) async =>
            throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403),
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      final requestButton = find.byKey(
        const ValueKey('space-participation-request-button-4'),
      );

      await tester.tap(requestButton);
      await tester.pumpAndSettle();

      expect(repository.requestSpaceParticipationCalls, 1);
      expect(
        find.byKey(const ValueKey('space-participation-request-error')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Seu acesso não permite solicitar participação neste espaço.',
        ),
        findsOneWidget,
      );

      await tester.tap(requestButton);
      await tester.pumpAndSettle();
      expect(repository.requestSpaceParticipationCalls, 2);
    },
  );

  testWidgets('409 recarrega a lista sem repetir a solicitação', (
    tester,
  ) async {
    var fetchCalls = 0;
    final repository = FakeSpacesRepository(
      (_) async {
        fetchCalls += 1;
        return makeSpacePage(
          content: fetchCalls == 1
              ? [_availableSpace(5)]
              : [
                  const SpaceSummary(
                    id: 5,
                    name: 'Espaço 5',
                    spaceAdminName: null,
                    active: true,
                    available: true,
                    spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
                    spaceMembershipStatus: 'PENDING',
                    activeParticipationsCount: 0,
                  ),
                ],
        );
      },
      requestSpaceParticipationHandler: (_, _) async =>
          throw const ApiFailure(ApiFailureKind.unknown, statusCode: 409),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('space-participation-request-button-5')),
    );
    await tester.pumpAndSettle();

    expect(repository.requestSpaceParticipationCalls, 1);
    expect(repository.fetchSpacesCalls, 2);
    expect(
      find.byKey(const ValueKey('space-participation-request-button-5')),
      findsNothing,
    );
    expect(find.text('Participação pendente'), findsOneWidget);
    expect(
      find.text('A solicitação já existe. Atualizando a lista.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'posiciona participacoes imediatamente antes das tarefas no mesmo Wrap',
    (tester) async {
      final repository = FakeSpacesRepository(
        (_) async => makeSpacePage(content: const [_approvedAdminSpace]),
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      const participationsKey = ValueKey('space-participations-button-1');
      const tasksKey = ValueKey('space-tasks-button-1');
      final participationsButton = find.byKey(participationsKey);
      expect(participationsButton, findsOneWidget);
      expect(find.byKey(tasksKey), findsOneWidget);

      final actionsWrap = tester
          .element(participationsButton)
          .findAncestorWidgetOfExactType<Wrap>();
      expect(actionsWrap, isNotNull);
      final actionKeys = actionsWrap!.children
          .map((child) => child is Tooltip ? child.child?.key : child.key)
          .toList();
      final participationsIndex = actionKeys.indexOf(participationsKey);
      final tasksIndex = actionKeys.indexOf(tasksKey);
      expect(participationsIndex, isNonNegative);
      expect(tasksIndex, participationsIndex + 1);
    },
  );

  testWidgets(
    'abre participações e não recarrega espaços ao voltar sem edição',
    (tester) async {
      final repository = FakeSpacesRepository(
        (_) async => makeSpacePage(content: const [_approvedAdminSpace]),
        fetchParticipationsHandler: (_, _, _, page, size) async =>
            makeSpaceParticipationPage(number: page, size: size),
      );

      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      final participationsButton = find.byKey(
        const ValueKey('space-participations-button-1'),
      );
      expect(participationsButton, findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(participationsButton).onPressed,
        isNotNull,
      );
      expect(repository.fetchSpaceParticipationsCalls, 0);

      await tester.tap(participationsButton);
      await tester.pumpAndSettle();

      expect(find.byType(SpaceParticipationsPage), findsOneWidget);
      final participationsPage = tester.widget<SpaceParticipationsPage>(
        find.byType(SpaceParticipationsPage),
      );
      expect(participationsPage.session, testSession);
      expect(participationsPage.spaceId, _approvedAdminSpace.id);
      expect(participationsPage.spaceName, _approvedAdminSpace.name);
      expect(participationsPage.canEditParticipations, isTrue);
      expect(participationsPage.canEditParticipationRoles, isTrue);
      expect(
        identical(participationsPage.spacesRepository, repository),
        isTrue,
      );
      expect(repository.fetchSpaceParticipationsCalls, 1);
      expect(repository.receivedParticipationAccessTokens, [
        testSession.accessToken,
      ]);
      expect(repository.receivedParticipationSpaceIds, [
        _approvedAdminSpace.id,
      ]);
      expect(repository.receivedParticipationPages, [0]);
      expect(repository.receivedParticipationPageSizes, [10]);
      expect(repository.receivedParticipationFilters, hasLength(1));
      expect(repository.receivedParticipationFilters.single.username, isNull);
      expect(repository.receivedParticipationFilters.single.statuses, isEmpty);

      Navigator.of(tester.element(find.byType(SpaceParticipationsPage))).pop();
      await tester.pumpAndSettle();

      expect(repository.fetchSpacesCalls, 1);
      expect(
        find.byKey(const ValueKey('space-participation-updated-message')),
        findsNothing,
      );
    },
  );

  testWidgets('recarrega o contexto e revoga o acesso após rebaixamento', (
    tester,
  ) async {
    const adminSpace = SpaceSummary(
      id: 81,
      name: 'Espaço gerenciado',
      spaceAdminName: 'Usuário de Teste',
      active: true,
      available: true,
      spaceUserRole: 'ROLE_SPACE_ADMIN',
      spaceMembershipStatus: 'APPROVED',
      activeParticipationsCount: 3,
    );
    const demotedSpace = SpaceSummary(
      id: 81,
      name: 'Espaço gerenciado',
      spaceAdminName: 'Outra administradora',
      active: true,
      available: true,
      spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
      spaceMembershipStatus: 'APPROVED',
      activeParticipationsCount: 3,
    );
    var returnDemotedSpace = false;
    final repository = FakeSpacesRepository(
      (_) async => throw StateError('Handler paginado esperado.'),
      fetchPageHandler: (_, page, size) async => _makePagedSpacePage(
        content: [returnDemotedSpace ? demotedSpace : adminSpace],
        number: page,
        size: size,
        totalElements: 40,
        totalPages: 2,
      ),
      fetchParticipationsHandler: (_, _, _, page, size) async =>
          makeSpaceParticipationPage(number: page, size: size),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButton<int>>(
          find.byKey(const ValueKey('spaces-page-size')),
        )
        .onChanged!(20);
    await tester.pumpAndSettle();
    await _toggleFilters(tester);
    await tester.enterText(
      find.byKey(const ValueKey('spaces-name-filter')),
      'gerenciado',
    );
    await tester.tap(find.byKey(const ValueKey('spaces-apply-filters')));
    await tester.pumpAndSettle();
    await _toggleFilters(tester);
    await tester.tap(find.byKey(const ValueKey('spaces-page-1')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('space-participations-button-81')),
    );
    await tester.pumpAndSettle();
    final pageBeforeUpdate = tester.widget<SpaceParticipationsPage>(
      find.byType(SpaceParticipationsPage),
    );
    expect(pageBeforeUpdate.canEditParticipations, isTrue);
    expect(pageBeforeUpdate.canEditParticipationRoles, isTrue);

    returnDemotedSpace = true;
    Navigator.of(tester.element(find.byType(SpaceParticipationsPage))).pop(
      const SpaceParticipation(
        id: 91,
        name: 'Usuário de Teste',
        spaceUserRole: SpaceUserRole.participant,
        spaceMembershipStatus: SpaceMembershipStatus.approved,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchSpacesCalls, 5);
    expect(repository.receivedPages, [0, 0, 0, 1, 1]);
    expect(repository.receivedPageSizes, [10, 20, 20, 20, 20]);
    expect(repository.receivedFilters.last.name, 'gerenciado');
    expect(
      find.byKey(const ValueKey('space-participation-updated-message')),
      findsOneWidget,
    );
    expect(
      find.text('Participação de "Usuário de Teste" atualizada.'),
      findsOneWidget,
    );

    expect(
      find.byKey(const ValueKey('space-participations-button-81')),
      findsNothing,
    );
    expect(find.byType(SpaceParticipationsPage), findsNothing);
    expect(repository.fetchSpaceParticipationsCalls, 1);
  });

  testWidgets('propaga permissao de gerente sem liberar alteracao de papel', (
    tester,
  ) async {
    const managerSpace = SpaceSummary(
      id: 18,
      name: 'Espaco gerenciado',
      spaceAdminName: 'Administradora',
      active: true,
      available: true,
      spaceUserRole: 'ROLE_SPACE_MANAGER',
      spaceMembershipStatus: 'APPROVED',
      activeParticipationsCount: 3,
    );
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(content: const [managerSpace]),
      fetchParticipationsHandler: (_, _, _, page, size) async =>
          makeSpaceParticipationPage(number: page, size: size),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('space-participations-button-18')),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<SpaceParticipationsPage>(
      find.byType(SpaceParticipationsPage),
    );
    expect(page.canEditParticipations, isTrue);
    expect(page.canEditParticipationRoles, isFalse);
  });

  testWidgets('oculta participações sem papel gerencial aprovado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const availableSpace = SpaceSummary(
      id: 22,
      name: 'Espaco disponivel',
      spaceAdminName: 'Responsavel',
      active: true,
      available: true,
      spaceUserRole: null,
      spaceMembershipStatus: null,
      activeParticipationsCount: 1,
    );
    const pendingSpace = SpaceSummary(
      id: 23,
      name: 'Espaco pendente',
      spaceAdminName: 'Responsavel',
      active: true,
      available: true,
      spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
      spaceMembershipStatus: 'PENDING',
      activeParticipationsCount: 2,
    );
    const approvedParticipantSpace = SpaceSummary(
      id: 24,
      name: 'Espaço participado',
      spaceAdminName: 'Responsável',
      active: true,
      available: true,
      spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
      spaceMembershipStatus: 'APPROVED',
      activeParticipationsCount: 2,
    );
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(
        content: const [availableSpace, pendingSpace, approvedParticipantSpace],
      ),
      fetchParticipationsHandler: (_, _, _, page, size) async =>
          makeSpaceParticipationPage(number: page, size: size),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    for (final id in <int>[
      availableSpace.id,
      pendingSpace.id,
      approvedParticipantSpace.id,
    ]) {
      final participationsButton = find.byKey(
        ValueKey('space-participations-button-$id'),
      );
      expect(participationsButton, findsNothing);
    }
    expect(repository.fetchSpaceParticipationsCalls, 0);
    expect(find.byType(SpaceParticipationsPage), findsNothing);
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
      expect(
        repository.receivedParticipantFilters.single.sort,
        ParticipantSort.scoreDescending,
      );
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
        available: true,
        spaceUserRole: null,
        spaceMembershipStatus: null,
        activeParticipationsCount: 1,
      );
      const pendingSpace = SpaceSummary(
        id: 21,
        name: 'Espaço pendente',
        spaceAdminName: 'Responsável',
        active: true,
        available: true,
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
          available: true,
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
        available: true,
        spaceUserRole: null,
        spaceMembershipStatus: null,
        activeParticipationsCount: 1,
      );
      const pendingSpace = SpaceSummary(
        id: 3,
        name: 'Espaço pendente',
        spaceAdminName: 'Responsável',
        active: true,
        available: true,
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
  VoidCallback? onSessionExpired,
}) {
  return MaterialApp(
    home: SpacesPage(
      session: testSession,
      spacesRepository: repository,
      tasksRepository: tasksRepository ?? FakeTasksRepository(),
      onSessionExpired: onSessionExpired,
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
    available: true,
    spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
    spaceMembershipStatus: 'APPROVED',
    activeParticipationsCount: 1,
  );
}

SpaceSummary _availableSpace(int id) {
  return SpaceSummary(
    id: id,
    name: 'Espaço $id',
    spaceAdminName: null,
    active: true,
    available: true,
    spaceUserRole: null,
    spaceMembershipStatus: null,
    activeParticipationsCount: 0,
  );
}

const _approvedAdminSpace = SpaceSummary(
  id: 1,
  name: 'Residência do Casal Laet',
  spaceAdminName: 'Joice Laet',
  active: true,
  available: true,
  spaceUserRole: 'ROLE_SPACE_ADMIN',
  spaceMembershipStatus: 'APPROVED',
  activeParticipationsCount: 4,
);

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
