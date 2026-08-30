import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';
import 'package:mobile_flutter/features/spaces/presentation/space_participations_page.dart';

void main() {
  testWidgets('carrega sem filtros e renderiza o contexto e os vínculos', (
    tester,
  ) async {
    final completer = Completer<SpaceParticipationPageResult>();
    final repository = _FakeSpacesRepository((_, _, _, _, _) {
      return completer.future;
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pump();

    expect(
      find.byKey(const Key('space-participations-loading')),
      findsOneWidget,
    );
    expect(repository.calls, 1);
    expect(repository.accessTokens, [_session.accessToken]);
    expect(repository.spaceIds, [7]);
    expect(repository.pages, [0]);
    expect(repository.pageSizes, [10]);
    expect(repository.filters.single.username, isNull);
    expect(repository.filters.single.statuses, isEmpty);

    completer.complete(
      _page(
        content: const [
          SpaceParticipation(
            id: 11,
            name: 'Joice Lima',
            spaceUserRole: SpaceUserRole.manager,
            spaceMembershipStatus: SpaceMembershipStatus.approved,
          ),
          SpaceParticipation(
            id: 12,
            name: 'Caio Souza',
            spaceUserRole: SpaceUserRole.participant,
            spaceMembershipStatus: SpaceMembershipStatus.pending,
          ),
        ],
        totalElements: 2,
        totalPages: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('space-participations-list')), findsOneWidget);
    expect(find.text('Espaço de testes'), findsOneWidget);
    expect(find.text('2 participações encontradas'), findsOneWidget);
    expect(
      find.byKey(const Key('space-participation-card-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('space-participation-card-12')),
      findsOneWidget,
    );
    expect(find.text('Joice Lima'), findsOneWidget);
    expect(find.text('Gerente'), findsOneWidget);
    expect(find.text('Aprovada'), findsOneWidget);
    expect(find.text('Caio Souza'), findsOneWidget);
    expect(find.text('Participante'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
  });

  testWidgets('aplica username e múltiplos status e limpa os filtros', (
    tester,
  ) async {
    final repository = _FakeSpacesRepository((_, _, _, page, size) async {
      return _page(number: page, size: size);
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('space-participations-toggle-filters')),
    );

    await tester.enterText(
      find.byKey(const Key('space-participations-username-filter')),
      '  joice  ',
    );
    for (final status in <SpaceMembershipStatus>[
      SpaceMembershipStatus.pending,
      SpaceMembershipStatus.approved,
    ]) {
      final chip = tester.widget<FilterChip>(
        find.byKey(ValueKey('space-participations-status-${status.apiValue}')),
      );
      chip.onSelected!(true);
      await tester.pump();
    }

    await _tapVisible(
      tester,
      find.byKey(const Key('space-participations-apply-filters')),
    );

    expect(repository.calls, 2);
    expect(repository.pages, [0, 0]);
    expect(repository.pageSizes, [10, 10]);
    final applied = repository.filters.last;
    expect(applied.username, '  joice  ');
    expect(applied.statuses, {
      SpaceMembershipStatus.pending,
      SpaceMembershipStatus.approved,
    });
    expect(
      find.byKey(const Key('space-participations-active-filters')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('space-participations-filter-empty')),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('space-participations-clear-filters')),
    );

    expect(repository.calls, 3);
    expect(repository.pages.last, 0);
    expect(repository.filters.last.username, isNull);
    expect(repository.filters.last.statuses, isEmpty);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('space-participations-username-filter')),
          )
          .controller!
          .text,
      isEmpty,
    );
    for (final status in SpaceMembershipStatus.values) {
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(
                ValueKey('space-participations-status-${status.apiValue}'),
              ),
            )
            .selected,
        isFalse,
      );
    }
    expect(
      find.byKey(const Key('space-participations-active-filters')),
      findsNothing,
    );
    expect(find.byKey(const Key('space-participations-empty')), findsOneWidget);
  });

  testWidgets('navega, altera o tamanho e preserva filtros no refresh', (
    tester,
  ) async {
    final repository = _FakeSpacesRepository((_, _, filters, page, size) async {
      return _page(
        content: [
          SpaceParticipation(
            id: 1000 + (page * 100) + size,
            name: 'Página $page tamanho $size',
            spaceUserRole: SpaceUserRole.admin,
            spaceMembershipStatus: SpaceMembershipStatus.approved,
          ),
        ],
        number: page,
        size: size,
        totalElements: 60,
        totalPages: (60 / size).ceil(),
      );
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('space-participations-toggle-filters')),
    );
    await tester.enterText(
      find.byKey(const Key('space-participations-username-filter')),
      'ana',
    );
    tester
        .widget<FilterChip>(
          find.byKey(const Key('space-participations-status-APPROVED')),
        )
        .onSelected!(true);
    await tester.pump();
    await _tapVisible(
      tester,
      find.byKey(const Key('space-participations-apply-filters')),
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('space-participations-toggle-filters')),
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('space-participations-page-1')),
    );
    expect(repository.pages, [0, 0, 1]);
    expect(repository.pageSizes, [10, 10, 10]);

    final pageSize = find.byKey(const Key('space-participations-page-size'));
    await tester.ensureVisible(pageSize);
    tester.widget<DropdownButton<int>>(pageSize).onChanged!(20);
    await tester.pumpAndSettle();

    expect(repository.pages, [0, 0, 1, 0]);
    expect(repository.pageSizes, [10, 10, 10, 20]);
    expect(repository.filters.last.username, 'ana');
    expect(repository.filters.last.statuses, {SpaceMembershipStatus.approved});

    await tester.drag(
      find.byKey(const Key('space-participations-list')),
      const Offset(0, 360),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 5);
    expect(repository.pages.last, 0);
    expect(repository.pageSizes.last, 20);
    expect(repository.filters.last.username, 'ana');
    expect(repository.filters.last.statuses, {SpaceMembershipStatus.approved});
  });

  testWidgets('ajusta uma página que deixou de existir', (tester) async {
    var pageOneCalls = 0;
    final repository = _FakeSpacesRepository((_, _, _, page, size) async {
      if (page == 1) {
        pageOneCalls += 1;
        return _page(number: 1, size: size, totalPages: 1);
      }
      return _page(
        content: const [
          SpaceParticipation(
            id: 30,
            name: 'Página válida',
            spaceUserRole: SpaceUserRole.participant,
            spaceMembershipStatus: SpaceMembershipStatus.approved,
          ),
        ],
        number: 0,
        size: size,
        totalElements: pageOneCalls == 0 ? 11 : 1,
        totalPages: pageOneCalls == 0 ? 2 : 1,
      );
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('space-participations-page-1')),
    );

    expect(repository.pages, [0, 1, 0]);
    expect(
      find.byKey(const Key('space-participation-card-30')),
      findsOneWidget,
    );
    expect(find.text('Página 1 de 1 · 1–1 de 1'), findsOneWidget);
  });

  testWidgets('permite tentar novamente e renderiza estado vazio', (
    tester,
  ) async {
    var shouldFail = true;
    final repository = _FakeSpacesRepository((_, _, _, page, size) async {
      if (shouldFail) {
        shouldFail = false;
        throw const ApiFailure(ApiFailureKind.network);
      }
      return _page(number: page, size: size);
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('space-participations-error')), findsOneWidget);
    expect(repository.calls, 1);

    await tester.tap(
      find.byKey(const Key('space-participations-retry-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.byKey(const Key('space-participations-empty')), findsOneWidget);
    expect(find.byKey(const Key('space-participations-error')), findsNothing);
  });

  testWidgets('encaminha 401 para expiração da sessão', (tester) async {
    var sessionExpiredCalls = 0;
    final repository = _FakeSpacesRepository((_, _, _, _, _) async {
      throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401);
    });

    await tester.pumpWidget(
      _testApp(repository, onSessionExpired: () => sessionExpiredCalls += 1),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(sessionExpiredCalls, 1);
    expect(find.byKey(const Key('space-participations-error')), findsNothing);
  });

  testWidgets('mantém 403 como erro de acesso na tela', (tester) async {
    var sessionExpiredCalls = 0;
    final repository = _FakeSpacesRepository((_, _, _, _, _) async {
      throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403);
    });

    await tester.pumpWidget(
      _testApp(repository, onSessionExpired: () => sessionExpiredCalls += 1),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(sessionExpiredCalls, 0);
    expect(find.byKey(const Key('space-participations-error')), findsOneWidget);
    expect(
      find.text(
        'Apenas administradores e gerentes do espaço podem consultar as '
        'participações.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('não mostra edição sem permissão para gerenciar vínculos', (
    tester,
  ) async {
    final repository = _FakeSpacesRepository((_, _, _, page, size) async {
      return _page(
        content: const [
          SpaceParticipation(
            id: 40,
            name: 'Participante sem edição',
            spaceUserRole: SpaceUserRole.participant,
            spaceMembershipStatus: SpaceMembershipStatus.approved,
          ),
        ],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      );
    });

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('space-participation-edit-button-40')),
      findsNothing,
    );
  });

  testWidgets('admin pode editar vínculos de todos os papéis', (tester) async {
    final repository = _FakeSpacesRepository((_, _, _, page, size) async {
      return _page(
        content: _participationsByRole,
        number: page,
        size: size,
        totalElements: _participationsByRole.length,
        totalPages: 1,
      );
    });

    await tester.pumpWidget(
      _testApp(
        repository,
        canEditParticipations: true,
        canEditParticipationRoles: true,
      ),
    );
    await tester.pumpAndSettle();

    for (final participation in _participationsByRole) {
      final editButton = find.byKey(
        ValueKey('space-participation-edit-button-${participation.id}'),
      );
      expect(editButton, findsOneWidget);
      expect(tester.widget<IconButton>(editButton).onPressed, isNotNull);
      expect(
        tester.getSemantics(editButton),
        matchesSemantics(
          label: 'Editar participação de ${participation.name}',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    }
  });

  testWidgets(
    'manager edita participante e vê vínculos privilegiados desabilitados',
    (tester) async {
      final repository = _FakeSpacesRepository((_, _, _, page, size) async {
        return _page(
          content: _participationsByRole,
          number: page,
          size: size,
          totalElements: _participationsByRole.length,
          totalPages: 1,
        );
      });

      await tester.pumpWidget(
        _testApp(
          repository,
          canEditParticipations: true,
          canEditParticipationRoles: false,
        ),
      );
      await tester.pumpAndSettle();

      final participantButton = find.byKey(
        const ValueKey('space-participation-edit-button-43'),
      );
      expect(tester.widget<IconButton>(participantButton).onPressed, isNotNull);

      for (final id in <int>[41, 42]) {
        final privilegedButton = find.byKey(
          ValueKey('space-participation-edit-button-$id'),
        );
        expect(privilegedButton, findsOneWidget);
        expect(tester.widget<IconButton>(privilegedButton).onPressed, isNull);
        expect(
          tester.getSemantics(privilegedButton),
          matchesSemantics(
            label:
                'Somente administradores podem editar vínculos de '
                'administradores ou gerentes',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
      }
    },
  );

  testWidgets('edição bem-sucedida retorna o item sem novo GET na página', (
    tester,
  ) async {
    SpaceParticipation? routeResult;
    final repository = _FakeSpacesRepository(
      (_, _, _, page, size) async => _page(
        content: [
          SpaceParticipation(
            id: 70 + page,
            name: 'Pessoa da página $page',
            spaceUserRole: SpaceUserRole.participant,
            spaceMembershipStatus: SpaceMembershipStatus.pending,
          ),
        ],
        number: page,
        size: size,
        totalElements: 20,
        totalPages: 2,
      ),
      updateHandler: (_, _, membershipId, status, role) async =>
          SpaceParticipation(
            id: membershipId,
            name: 'Pessoa da página 1',
            spaceUserRole: role ?? SpaceUserRole.participant,
            spaceMembershipStatus: status ?? SpaceMembershipStatus.pending,
          ),
    );

    await tester.pumpWidget(
      _routeTestApp(
        repository,
        canEditParticipations: true,
        canEditParticipationRoles: false,
        onResult: (result) => routeResult = result,
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('open-space-participations-page')),
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('space-participations-toggle-filters')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('space-participations-username-filter')),
      'joice',
    );
    tester
        .widget<TextField>(
          find.byKey(const ValueKey('space-participations-username-filter')),
        )
        .onSubmitted!('joice');
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('space-participations-toggle-filters')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('space-participations-page-1')),
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('space-participation-edit-button-71')),
    );
    expect(
      find.byKey(const ValueKey('edit-space-participation-dialog')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DropdownButton<SpaceUserRole>>(
            find.descendant(
              of: find.byKey(
                const ValueKey('edit-space-participation-role-field'),
              ),
              matching: find.byType(DropdownButton<SpaceUserRole>),
            ),
          )
          .onChanged,
      isNull,
    );
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-status-field'),
      'Aprovada',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-space-participation-submit-button')),
    );

    expect(repository.updateCalls, 1);
    expect(repository.updatedMembershipIds, [71]);
    expect(repository.updatedStatuses, [SpaceMembershipStatus.approved]);
    expect(repository.updatedRoles, [null]);
    expect(repository.pages, [0, 0, 1]);
    expect(repository.pageSizes, [10, 10, 10]);
    expect(repository.filters.last.username, 'joice');
    expect(routeResult?.id, 71);
    expect(routeResult?.spaceMembershipStatus, SpaceMembershipStatus.approved);
    expect(find.byType(SpaceParticipationsPage), findsNothing);
    expect(
      find.byKey(const ValueKey('space-participation-updated-message')),
      findsNothing,
    );
  });

  testWidgets('ignora a resposta antiga quando a fonte muda', (tester) async {
    final oldResponse = Completer<SpaceParticipationPageResult>();
    final oldRepository = _FakeSpacesRepository((_, _, _, _, _) {
      return oldResponse.future;
    });
    final newRepository = _FakeSpacesRepository((_, _, _, page, size) async {
      return _page(
        content: const [
          SpaceParticipation(
            id: 92,
            name: 'Fonte nova',
            spaceUserRole: SpaceUserRole.admin,
            spaceMembershipStatus: SpaceMembershipStatus.approved,
          ),
        ],
        number: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
      );
    });

    await tester.pumpWidget(_testApp(oldRepository));
    await tester.pump();
    await tester.pumpWidget(_testApp(newRepository));
    await tester.pumpAndSettle();

    expect(find.text('Fonte nova'), findsOneWidget);
    oldResponse.complete(
      _page(
        content: const [
          SpaceParticipation(
            id: 91,
            name: 'Fonte antiga',
            spaceUserRole: SpaceUserRole.participant,
            spaceMembershipStatus: SpaceMembershipStatus.pending,
          ),
        ],
        totalElements: 1,
        totalPages: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fonte nova'), findsOneWidget);
    expect(find.text('Fonte antiga'), findsNothing);
    expect(oldRepository.calls, 1);
    expect(newRepository.calls, 1);
  });
}

Widget _testApp(
  SpacesRepository repository, {
  VoidCallback? onSessionExpired,
  bool canEditParticipations = false,
  bool canEditParticipationRoles = false,
}) {
  return MaterialApp(
    home: SpaceParticipationsPage(
      session: _session,
      spaceId: 7,
      spaceName: 'Espaço de testes',
      spacesRepository: repository,
      canEditParticipations: canEditParticipations,
      canEditParticipationRoles: canEditParticipationRoles,
      onSessionExpired: onSessionExpired,
    ),
  );
}

Widget _routeTestApp(
  SpacesRepository repository, {
  required bool canEditParticipations,
  required bool canEditParticipationRoles,
  required ValueChanged<SpaceParticipation?> onResult,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          key: const ValueKey('open-space-participations-page'),
          onPressed: () async {
            final result = await Navigator.of(context).push<SpaceParticipation>(
              MaterialPageRoute<SpaceParticipation>(
                builder: (context) => SpaceParticipationsPage(
                  session: _session,
                  spaceId: 7,
                  spaceName: 'Espaço de testes',
                  spacesRepository: repository,
                  canEditParticipations: canEditParticipations,
                  canEditParticipationRoles: canEditParticipationRoles,
                ),
              ),
            );
            onResult(result);
          },
          child: const Text('Abrir participações'),
        ),
      ),
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _selectDropdown(
  WidgetTester tester,
  Key fieldKey,
  String optionLabel,
) async {
  final field = find.byKey(fieldKey);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionLabel).last);
  await tester.pumpAndSettle();
}

SpaceParticipationPageResult _page({
  List<SpaceParticipation> content = const <SpaceParticipation>[],
  int size = 10,
  int number = 0,
  int totalElements = 0,
  int totalPages = 0,
}) {
  return SpaceParticipationPageResult(
    content: content,
    size: size,
    number: number,
    totalElements: totalElements,
    totalPages: totalPages,
  );
}

typedef _FetchParticipationsHandler =
    Future<SpaceParticipationPageResult> Function(
      String accessToken,
      int spaceId,
      SpaceParticipationFilters filters,
      int page,
      int size,
    );

typedef _UpdateParticipationHandler =
    Future<SpaceParticipation> Function(
      String accessToken,
      int spaceId,
      int membershipId,
      SpaceMembershipStatus? status,
      SpaceUserRole? spaceUserRole,
    );

final class _FakeSpacesRepository implements SpacesRepository {
  _FakeSpacesRepository(this._handler, {this.updateHandler});

  final _FetchParticipationsHandler _handler;
  final _UpdateParticipationHandler? updateHandler;
  int calls = 0;
  int updateCalls = 0;
  final accessTokens = <String>[];
  final spaceIds = <int>[];
  final filters = <SpaceParticipationFilters>[];
  final pages = <int>[];
  final pageSizes = <int>[];
  final updatedMembershipIds = <int>[];
  final updatedStatuses = <SpaceMembershipStatus?>[];
  final updatedRoles = <SpaceUserRole?>[];

  @override
  Future<SpaceParticipationPageResult> fetchSpaceParticipations({
    required String accessToken,
    required int spaceId,
    SpaceParticipationFilters filters = const SpaceParticipationFilters(),
    int page = 0,
    int size = 10,
  }) {
    calls += 1;
    accessTokens.add(accessToken);
    spaceIds.add(spaceId);
    this.filters.add(filters);
    pages.add(page);
    pageSizes.add(size);
    return _handler(accessToken, spaceId, filters, page, size);
  }

  @override
  Future<SpaceParticipation> updateSpaceParticipation({
    required String accessToken,
    required int spaceId,
    required int membershipId,
    SpaceMembershipStatus? status,
    SpaceUserRole? spaceUserRole,
  }) {
    updateCalls += 1;
    updatedMembershipIds.add(membershipId);
    updatedStatuses.add(status);
    updatedRoles.add(spaceUserRole);
    final handler = updateHandler;
    if (handler == null) {
      return Future<SpaceParticipation>.error(
        StateError('Handler de atualização não configurado.'),
      );
    }
    return handler(accessToken, spaceId, membershipId, status, spaceUserRole);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _session = AuthSession(
  id: 3,
  username: 'user@example.com',
  name: 'Usuário de Teste',
  accessToken: 'access-token-test-only',
  refreshToken: 'refresh-token-test-only',
  role: 'ROLE_USER',
);

const _participationsByRole = <SpaceParticipation>[
  SpaceParticipation(
    id: 41,
    name: 'Ana Admin',
    spaceUserRole: SpaceUserRole.admin,
    spaceMembershipStatus: SpaceMembershipStatus.approved,
  ),
  SpaceParticipation(
    id: 42,
    name: 'Mauro Manager',
    spaceUserRole: SpaceUserRole.manager,
    spaceMembershipStatus: SpaceMembershipStatus.approved,
  ),
  SpaceParticipation(
    id: 43,
    name: 'Paula Participante',
    spaceUserRole: SpaceUserRole.participant,
    spaceMembershipStatus: SpaceMembershipStatus.pending,
  ),
];
