import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation.dart';
import 'package:mobile_flutter/features/spaces/presentation/edit_space_participation_dialog.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('preenche os campos e mantém submit desabilitado sem mudanças', (
    tester,
  ) async {
    final repository = _repository();

    await _pumpDialog(tester, repository: repository, canEditRole: true);

    expect(find.text(_participation.name), findsOneWidget);
    expect(_roleDropdown(tester).value, SpaceUserRole.participant);
    expect(_statusDropdown(tester).value, SpaceMembershipStatus.pending);
    expect(
      _roleDropdown(tester).items!.map((item) => item.value),
      SpaceUserRole.values,
    );
    expect(
      _statusDropdown(tester).items!.map((item) => item.value),
      SpaceMembershipStatus.values,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(
              const ValueKey('edit-space-participation-submit-button'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(repository.updateSpaceParticipationCalls, 0);
  });

  testWidgets('admin envia somente papel e situação alterados', (tester) async {
    final repository = _repository(
      handler: (_, _, _, status, role) async => SpaceParticipation(
        id: _participation.id,
        name: _participation.name,
        spaceUserRole: role ?? _participation.spaceUserRole,
        spaceMembershipStatus: status ?? _participation.spaceMembershipStatus,
      ),
    );

    await _pumpDialog(tester, repository: repository, canEditRole: true);
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-role-field'),
      'Gerente',
    );
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-status-field'),
      'Suspensa',
    );
    await _submit(tester);

    expect(repository.updateSpaceParticipationCalls, 1);
    expect(repository.receivedUpdateSpaceParticipationAccessTokens, [
      _accessToken,
    ]);
    expect(repository.receivedUpdateSpaceParticipationSpaceIds, [_spaceId]);
    expect(repository.receivedUpdateSpaceParticipationMembershipIds, [
      _participation.id,
    ]);
    expect(repository.receivedUpdateSpaceParticipationStatuses, [
      SpaceMembershipStatus.suspended,
    ]);
    expect(repository.receivedUpdateSpaceParticipationSpaceUserRoles, [
      SpaceUserRole.manager,
    ]);
    expect(find.byType(EditSpaceParticipationDialog), findsNothing);
  });

  testWidgets('admin omite o papel quando altera somente a situação', (
    tester,
  ) async {
    final repository = _repository();

    await _pumpDialog(tester, repository: repository, canEditRole: true);
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-status-field'),
      'Aprovada',
    );
    await _submit(tester);

    expect(repository.receivedUpdateSpaceParticipationStatuses, [
      SpaceMembershipStatus.approved,
    ]);
    expect(repository.receivedUpdateSpaceParticipationSpaceUserRoles, [null]);
  });

  testWidgets('manager vê papel desabilitado e envia somente status', (
    tester,
  ) async {
    final repository = _repository();

    await _pumpDialog(tester, repository: repository, canEditRole: false);

    expect(_roleDropdown(tester).onChanged, isNull);
    expect(
      find.text('Somente administradores podem alterar o papel.'),
      findsOneWidget,
    );
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-status-field'),
      'Negada',
    );
    await _submit(tester);

    expect(repository.receivedUpdateSpaceParticipationStatuses, [
      SpaceMembershipStatus.denied,
    ]);
    expect(repository.receivedUpdateSpaceParticipationSpaceUserRoles, [null]);
  });

  testWidgets('bloqueia campos, fechamento e reenvio durante a atualização', (
    tester,
  ) async {
    final response = Completer<SpaceParticipation>();
    final repository = _repository(handler: (_, _, _, _, _) => response.future);

    await _pumpDialog(tester, repository: repository, canEditRole: true);
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-status-field'),
      'Bloqueada',
    );
    await _submit(tester, settle: false);

    expect(repository.updateSpaceParticipationCalls, 1);
    expect(
      find.byKey(const ValueKey('edit-space-participation-progress')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(
              const ValueKey('edit-space-participation-submit-button'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(
              const ValueKey('edit-space-participation-cancel-button'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(_roleDropdown(tester).onChanged, isNull);
    expect(_statusDropdown(tester).onChanged, isNull);

    await tester.tap(
      find.byKey(const ValueKey('edit-space-participation-submit-button')),
    );
    await tester.pump();
    expect(repository.updateSpaceParticipationCalls, 1);

    response.complete(
      const SpaceParticipation(
        id: 20,
        name: 'Joice Lima',
        spaceUserRole: SpaceUserRole.participant,
        spaceMembershipStatus: SpaceMembershipStatus.blocked,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditSpaceParticipationDialog), findsNothing);
  });

  testWidgets('401 chama expiração da sessão e libera o formulário', (
    tester,
  ) async {
    var sessionExpiredCalls = 0;
    final repository = _repository(
      handler: (_, _, _, _, _) async =>
          throw const ApiFailure(ApiFailureKind.unauthorized, statusCode: 401),
    );

    await _pumpDialog(
      tester,
      repository: repository,
      canEditRole: false,
      onSessionExpired: () => sessionExpiredCalls += 1,
    );
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-status-field'),
      'Cancelada',
    );
    await _submit(tester);

    expect(repository.updateSpaceParticipationCalls, 1);
    expect(sessionExpiredCalls, 1);
    expect(
      find.byKey(const ValueKey('edit-space-participation-error')),
      findsNothing,
    );
    expect(_statusDropdown(tester).onChanged, isNotNull);
  });

  testWidgets('403 mostra a mensagem da API', (tester) async {
    final repository = _repository(
      handler: (_, _, _, _, _) async => throw const ApiFailure(
        ApiFailureKind.forbidden,
        statusCode: 403,
        apiMessage:
            'O espaço precisa manter pelo menos um administrador aprovado.',
      ),
    );

    await _pumpDialog(tester, repository: repository, canEditRole: false);
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-status-field'),
      'Suspensa',
    );
    await _submit(tester);

    expect(
      find.text(
        'O espaço precisa manter pelo menos um administrador aprovado.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('A alteração não é permitida.'), findsNothing);
  });

  testWidgets('403 sem mensagem usa fallback e permite tentar novamente', (
    tester,
  ) async {
    var attempts = 0;
    final repository = _repository(
      handler: (_, _, _, status, role) async {
        attempts += 1;
        if (attempts == 1) {
          throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403);
        }
        return SpaceParticipation(
          id: _participation.id,
          name: _participation.name,
          spaceUserRole: role ?? _participation.spaceUserRole,
          spaceMembershipStatus: status ?? _participation.spaceMembershipStatus,
        );
      },
    );

    await _pumpDialog(tester, repository: repository, canEditRole: false);
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-status-field'),
      'Suspensa',
    );
    await _submit(tester);

    expect(repository.updateSpaceParticipationCalls, 1);
    expect(find.textContaining('A alteração não é permitida.'), findsOneWidget);
    expect(_statusDropdown(tester).onChanged, isNotNull);

    await _submit(tester);
    expect(repository.updateSpaceParticipationCalls, 2);
    expect(find.byType(EditSpaceParticipationDialog), findsNothing);
  });

  testWidgets('resposta com outro membership id é tratada como inesperada', (
    tester,
  ) async {
    final repository = _repository(
      handler: (_, _, _, _, _) async => const SpaceParticipation(
        id: 999,
        name: 'Outro vínculo',
        spaceUserRole: SpaceUserRole.participant,
        spaceMembershipStatus: SpaceMembershipStatus.approved,
      ),
    );

    await _pumpDialog(tester, repository: repository, canEditRole: true);
    await _selectDropdown(
      tester,
      const ValueKey('edit-space-participation-status-field'),
      'Aprovada',
    );
    await _submit(tester);

    expect(repository.updateSpaceParticipationCalls, 1);
    expect(
      find.text('A API retornou uma participação diferente da esperada.'),
      findsOneWidget,
    );
    expect(find.byType(EditSpaceParticipationDialog), findsOneWidget);
  });
}

FakeSpacesRepository _repository({UpdateSpaceParticipationHandler? handler}) {
  return FakeSpacesRepository(
    (_) async => makeSpacePage(),
    updateSpaceParticipationHandler:
        handler ??
        (_, _, _, status, role) async => SpaceParticipation(
          id: _participation.id,
          name: _participation.name,
          spaceUserRole: role ?? _participation.spaceUserRole,
          spaceMembershipStatus: status ?? _participation.spaceMembershipStatus,
        ),
  );
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required FakeSpacesRepository repository,
  required bool canEditRole,
  VoidCallback? onSessionExpired,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open-edit-space-participation-dialog'),
            onPressed: () {
              unawaited(
                showDialog<SpaceParticipation>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => EditSpaceParticipationDialog(
                    participation: _participation,
                    accessToken: _accessToken,
                    spaceId: _spaceId,
                    spacesRepository: repository,
                    canEditRole: canEditRole,
                    onSessionExpired: onSessionExpired,
                  ),
                ),
              );
            },
            child: const Text('Editar'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(
    find.byKey(const ValueKey('open-edit-space-participation-dialog')),
  );
  await tester.pumpAndSettle();
  expect(find.byType(EditSpaceParticipationDialog), findsOneWidget);
}

DropdownButton<SpaceUserRole> _roleDropdown(WidgetTester tester) {
  return tester.widget<DropdownButton<SpaceUserRole>>(
    find.descendant(
      of: find.byKey(const ValueKey('edit-space-participation-role-field')),
      matching: find.byType(DropdownButton<SpaceUserRole>),
    ),
  );
}

DropdownButton<SpaceMembershipStatus> _statusDropdown(WidgetTester tester) {
  return tester.widget<DropdownButton<SpaceMembershipStatus>>(
    find.descendant(
      of: find.byKey(const ValueKey('edit-space-participation-status-field')),
      matching: find.byType(DropdownButton<SpaceMembershipStatus>),
    ),
  );
}

Future<void> _selectDropdown(WidgetTester tester, Key key, String label) async {
  final dropdown = find.byKey(key);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, {bool settle = true}) async {
  final submit = find.byKey(
    const ValueKey('edit-space-participation-submit-button'),
  );
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

const _accessToken = 'access-token-edit-participation-test-only';
const _spaceId = 7;
const _participation = SpaceParticipation(
  id: 20,
  name: 'Joice Lima',
  spaceUserRole: SpaceUserRole.participant,
  spaceMembershipStatus: SpaceMembershipStatus.pending,
);
