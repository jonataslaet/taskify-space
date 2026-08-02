import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/created_space.dart';
import 'package:mobile_flutter/features/spaces/presentation/create_space_dialog.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('valida nome vazio e limite de 255 caracteres sem chamar a API', (
    tester,
  ) async {
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      createHandler: (_, _) async => _createdSpace,
    );

    await tester.pumpWidget(_dialogTestApp(repository));
    await tester.tap(find.byKey(const ValueKey('open-create-space-dialog')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('create-space-name-field')),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey('create-space-submit-button')));
    await tester.pump();

    expect(find.textContaining('Informe o nome'), findsOneWidget);
    expect(repository.createSpaceCalls, 0);

    await tester.enterText(
      find.byKey(const ValueKey('create-space-name-field')),
      'a' * 256,
    );
    await tester.tap(find.byKey(const ValueKey('create-space-submit-button')));
    await tester.pump();

    expect(
      find.text('O nome deve ter no máximo 255 caracteres.'),
      findsOneWidget,
    );
    expect(repository.createSpaceCalls, 0);
  });

  testWidgets('remove espaços do nome antes de criar', (tester) async {
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      createHandler: (_, _) async => _createdSpace,
    );

    await tester.pumpWidget(_dialogTestApp(repository));
    await tester.tap(find.byKey(const ValueKey('open-create-space-dialog')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('create-space-name-field')),
      '  Casa de Praia  ',
    );
    await tester.tap(find.byKey(const ValueKey('create-space-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.createSpaceCalls, 1);
    expect(repository.receivedCreateAccessTokens, [testSession.accessToken]);
    expect(repository.receivedSpaceNames, ['Casa de Praia']);
    expect(find.byType(CreateSpaceDialog), findsNothing);
  });

  testWidgets('mantém o diálogo aberto e permite tentar novamente após 403', (
    tester,
  ) async {
    var shouldFail = true;
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      createHandler: (_, _) async {
        if (shouldFail) {
          shouldFail = false;
          throw const ApiFailure(ApiFailureKind.forbidden, statusCode: 403);
        }
        return _createdSpace;
      },
    );

    await tester.pumpWidget(_dialogTestApp(repository));
    await tester.tap(find.byKey(const ValueKey('open-create-space-dialog')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('create-space-name-field')),
      'Casa de Praia',
    );

    await tester.tap(find.byKey(const ValueKey('create-space-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('create-space-error')), findsOneWidget);
    expect(
      find.text('Seu plano atual não permite criar outro espaço.'),
      findsOneWidget,
    );
    expect(repository.createSpaceCalls, 1);

    await tester.tap(find.byKey(const ValueKey('create-space-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.createSpaceCalls, 2);
    expect(repository.receivedSpaceNames, ['Casa de Praia', 'Casa de Praia']);
    expect(find.byType(CreateSpaceDialog), findsNothing);
  });

  testWidgets('bloqueia novo envio enquanto a criação está em andamento', (
    tester,
  ) async {
    final completer = Completer<CreatedSpace>();
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      createHandler: (_, _) => completer.future,
    );

    await tester.pumpWidget(_dialogTestApp(repository));
    await tester.tap(find.byKey(const ValueKey('open-create-space-dialog')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('create-space-name-field')),
      'Casa de Praia',
    );
    await tester.tap(find.byKey(const ValueKey('create-space-submit-button')));
    await tester.pump();

    expect(repository.createSpaceCalls, 1);
    expect(find.byKey(const ValueKey('create-space-progress')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('create-space-submit-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('create-space-cancel-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('create-space-submit-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(repository.createSpaceCalls, 1);

    completer.complete(_createdSpace);
    await tester.pumpAndSettle();
    expect(find.byType(CreateSpaceDialog), findsNothing);
  });

  testWidgets('impede reenvio quando o resultado do POST é incerto', (
    tester,
  ) async {
    final repository = FakeSpacesRepository(
      (_) async => makeSpacePage(),
      createHandler: (_, _) async {
        throw const ApiFailure(ApiFailureKind.timeout);
      },
    );

    await tester.pumpWidget(_dialogTestApp(repository));
    await tester.tap(find.byKey(const ValueKey('open-create-space-dialog')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('create-space-name-field')),
      'Casa de Praia',
    );
    await tester.tap(find.byKey(const ValueKey('create-space-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.createSpaceCalls, 1);
    expect(find.textContaining('Para evitar duplicidade'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('create-space-submit-button')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Fechar'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('create-space-submit-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(repository.createSpaceCalls, 1);
  });
}

const _createdSpace = CreatedSpace(
  id: 7,
  name: 'Casa de Praia',
  spaceAdminName: 'Usuário de Teste',
  active: false,
);

Widget _dialogTestApp(FakeSpacesRepository repository) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              key: const ValueKey('open-create-space-dialog'),
              onPressed: () {
                showDialog<CreatedSpace>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => CreateSpaceDialog(
                    accessToken: testSession.accessToken,
                    spacesRepository: repository,
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          );
        },
      ),
    ),
  );
}
