import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';
import 'package:mobile_flutter/features/spaces/domain/updated_space.dart';
import 'package:mobile_flutter/features/spaces/presentation/edit_space_dialog.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('preenche os campos e exige uma alteração para confirmar', (
    tester,
  ) async {
    final repository = _repository();

    await _pumpDialog(tester, repository: repository);

    expect(
      tester.widget<TextFormField>(_nameField).controller?.text,
      _adminSpace.name,
    );
    final availableField = tester.widget<SwitchListTile>(_availableField);
    expect(availableField.value, isTrue);
    expect(availableField.onChanged, isNotNull);
    expect(tester.widget<FilledButton>(_submitButton).onPressed, isNull);
  });

  testWidgets('administrador envia nome normalizado e available', (
    tester,
  ) async {
    UpdatedSpace? dialogResult;
    final repository = _repository(
      updateHandler: (_, _, update) async => UpdatedSpace(
        id: _adminSpace.id,
        name: update.name!,
        spaceAdminName: _adminSpace.spaceAdminName,
        active: true,
        available: update.available!,
      ),
    );

    await _pumpDialog(
      tester,
      repository: repository,
      onResult: (result) => dialogResult = result,
    );
    await tester.enterText(_nameField, '  Residência atualizada  ');
    tester.widget<SwitchListTile>(_availableField).onChanged!(false);
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pumpAndSettle();

    expect(repository.updateSpaceCalls, 1);
    expect(repository.receivedUpdateSpaceAccessTokens, [_accessToken]);
    expect(repository.receivedUpdateSpaceIds, [_adminSpace.id]);
    expect(
      repository.receivedSpaceUpdates.single.name,
      'Residência atualizada',
    );
    expect(repository.receivedSpaceUpdates.single.available, isFalse);
    expect(dialogResult?.name, 'Residência atualizada');
    expect(dialogResult?.available, isFalse);
    expect(find.byType(EditSpaceDialog), findsNothing);
  });

  testWidgets('gerente visualiza available bloqueado e envia somente name', (
    tester,
  ) async {
    final repository = _repository(
      updateHandler: (_, _, update) async => UpdatedSpace(
        id: _managerSpace.id,
        name: update.name!,
        spaceAdminName: _managerSpace.spaceAdminName,
        active: true,
        available: _managerSpace.available,
      ),
    );

    await _pumpDialog(tester, repository: repository, space: _managerSpace);

    final availableField = tester.widget<SwitchListTile>(_availableField);
    expect(availableField.value, isFalse);
    expect(availableField.onChanged, isNull);
    expect(
      find.text('Somente administradores podem alterar a disponibilidade.'),
      findsOneWidget,
    );

    await tester.enterText(_nameField, 'Espaço do gerente atualizado');
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pumpAndSettle();

    expect(
      repository.receivedSpaceUpdates.single.name,
      'Espaço do gerente atualizado',
    );
    expect(repository.receivedSpaceUpdates.single.available, isNull);
  });

  testWidgets('valida nome vazio e maior que 255 caracteres', (tester) async {
    final repository = _repository();
    await _pumpDialog(tester, repository: repository);

    await tester.enterText(_nameField, '   ');
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pump();
    expect(find.text('Informe o nome do espaço.'), findsOneWidget);

    await tester.enterText(_nameField, 'a' * 256);
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pump();
    expect(
      find.text('O nome deve ter no máximo 255 caracteres.'),
      findsOneWidget,
    );
    expect(repository.updateSpaceCalls, 0);
  });

  testWidgets('bloqueia o formulário e exibe progresso durante o PUT', (
    tester,
  ) async {
    final response = Completer<UpdatedSpace>();
    final repository = _repository(updateHandler: (_, _, _) => response.future);
    await _pumpDialog(tester, repository: repository);

    await tester.enterText(_nameField, 'Nome em atualização');
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pump();

    expect(repository.updateSpaceCalls, 1);
    expect(tester.widget<TextFormField>(_nameField).enabled, isFalse);
    expect(tester.widget<SwitchListTile>(_availableField).onChanged, isNull);
    expect(tester.widget<TextButton>(_cancelButton).onPressed, isNull);
    expect(tester.widget<FilledButton>(_submitButton).onPressed, isNull);
    expect(find.byKey(const ValueKey('edit-space-progress')), findsOneWidget);

    response.complete(_updatedSpace(name: 'Nome em atualização'));
    await tester.pumpAndSettle();
    expect(find.byType(EditSpaceDialog), findsNothing);
  });

  testWidgets('401 encerra a sessão sem exibir erro inline', (tester) async {
    var sessionExpiredCalls = 0;
    final repository = _repository(
      updateHandler: (_, _, _) async =>
          throw const ApiFailure(ApiFailureKind.unauthorized),
    );
    await _pumpDialog(
      tester,
      repository: repository,
      onSessionExpired: () => sessionExpiredCalls += 1,
    );

    await tester.enterText(_nameField, 'Outro nome');
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pumpAndSettle();

    expect(sessionExpiredCalls, 1);
    expect(find.byKey(const ValueKey('edit-space-error')), findsNothing);
    expect(tester.widget<TextFormField>(_nameField).enabled, isTrue);
  });

  testWidgets('403 permanece no diálogo como erro anunciado', (tester) async {
    var sessionExpiredCalls = 0;
    final repository = _repository(
      updateHandler: (_, _, _) async =>
          throw const ApiFailure(ApiFailureKind.forbidden),
    );
    await _pumpDialog(
      tester,
      repository: repository,
      onSessionExpired: () => sessionExpiredCalls += 1,
    );

    await tester.enterText(_nameField, 'Outro nome');
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pumpAndSettle();

    expect(sessionExpiredCalls, 0);
    expect(find.byType(EditSpaceDialog), findsOneWidget);
    expect(
      find.text('Você não tem mais permissão para editar este espaço.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    expect(tester.widget<TextFormField>(_nameField).enabled, isTrue);
  });

  testWidgets('não fecha quando a API devolve outro id', (tester) async {
    final repository = _repository(
      updateHandler: (_, _, _) async => const UpdatedSpace(
        id: 999,
        name: 'Outro espaço',
        spaceAdminName: 'Outra pessoa',
        active: true,
        available: true,
      ),
    );
    await _pumpDialog(tester, repository: repository);

    await tester.enterText(_nameField, 'Outro nome');
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pumpAndSettle();

    expect(find.byType(EditSpaceDialog), findsOneWidget);
    expect(
      find.text('A API retornou um espaço diferente do atualizado.'),
      findsOneWidget,
    );
  });

  test('rejeita espaço com id inválido', () {
    expect(
      () => EditSpaceDialog(
        space: _space(id: 0),
        accessToken: _accessToken,
        spacesRepository: _repository(),
      ),
      throwsAssertionError,
    );
  });
}

const _accessToken = 'access-token-test-only';

const _adminSpace = SpaceSummary(
  id: 7,
  name: 'Residência do Casal Laet',
  spaceAdminName: 'Jonatas Laet',
  active: true,
  available: true,
  spaceUserRole: 'ROLE_SPACE_ADMIN',
  spaceMembershipStatus: 'APPROVED',
  activeParticipationsCount: 3,
);

const _managerSpace = SpaceSummary(
  id: 8,
  name: 'Espaço do gerente',
  spaceAdminName: 'Jonatas Laet',
  active: true,
  available: false,
  spaceUserRole: 'ROLE_SPACE_MANAGER',
  spaceMembershipStatus: 'APPROVED',
  activeParticipationsCount: 2,
);

final _nameField = find.byKey(const ValueKey('edit-space-name-field'));
final _availableField = find.byKey(
  const ValueKey('edit-space-available-field'),
);
final _cancelButton = find.byKey(const ValueKey('edit-space-cancel-button'));
final _submitButton = find.byKey(const ValueKey('edit-space-submit-button'));

FakeSpacesRepository _repository({UpdateSpaceHandler? updateHandler}) {
  return FakeSpacesRepository(
    (_) async => makeSpacePage(),
    updateSpaceHandler: updateHandler,
  );
}

UpdatedSpace _updatedSpace({required String name}) {
  return UpdatedSpace(
    id: _adminSpace.id,
    name: name,
    spaceAdminName: _adminSpace.spaceAdminName,
    active: _adminSpace.active,
    available: _adminSpace.available,
  );
}

SpaceSummary _space({required int id}) {
  return SpaceSummary(
    id: id,
    name: _adminSpace.name,
    spaceAdminName: _adminSpace.spaceAdminName,
    active: _adminSpace.active,
    available: _adminSpace.available,
    spaceUserRole: _adminSpace.spaceUserRole,
    spaceMembershipStatus: _adminSpace.spaceMembershipStatus,
    activeParticipationsCount: _adminSpace.activeParticipationsCount,
  );
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required FakeSpacesRepository repository,
  SpaceSummary space = _adminSpace,
  VoidCallback? onSessionExpired,
  ValueChanged<UpdatedSpace?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final result = await showDialog<UpdatedSpace>(
                context: context,
                barrierDismissible: false,
                builder: (context) => EditSpaceDialog(
                  space: space,
                  accessToken: _accessToken,
                  spacesRepository: repository,
                  onSessionExpired: onSessionExpired,
                ),
              );
              onResult?.call(result);
            },
            child: const Text('Editar'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Editar'));
  await tester.pumpAndSettle();
  expect(find.byType(EditSpaceDialog), findsOneWidget);
}
