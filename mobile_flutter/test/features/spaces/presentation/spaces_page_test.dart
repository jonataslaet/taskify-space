import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';
import 'package:mobile_flutter/features/spaces/presentation/spaces_page.dart';

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
}

Widget _testApp(FakeSpacesRepository repository) {
  return MaterialApp(
    home: SpacesPage(session: testSession, spacesRepository: repository),
  );
}
