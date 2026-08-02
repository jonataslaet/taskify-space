import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app/taskify_app.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('busca os espaços após o login sem exibir tokens', (
    tester,
  ) async {
    final authenticationRepository = FakeAuthenticationRepository(
      (_, _) async => testSession,
    );
    final spacesRepository = FakeSpacesRepository(
      (_) async => makeSpacePage(content: const [testSpace]),
    );
    await tester.pumpWidget(
      TaskifyApp(
        authenticationRepository: authenticationRepository,
        spacesRepository: spacesRepository,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'user@example.com',
    );
    await tester.enterText(find.byKey(const Key('password-field')), 'Secret1!');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Olá, Usuário de Teste!'), findsOneWidget);
    expect(find.text('Residência do Casal Laet'), findsOneWidget);
    expect(spacesRepository.fetchSpacesCalls, 1);
    expect(spacesRepository.receivedAccessTokens, [testSession.accessToken]);
    expect(find.text('access-token-test-only'), findsNothing);
    expect(find.text('refresh-token-test-only'), findsNothing);
  });

  testWidgets('só busca os espaços depois que o login termina', (tester) async {
    final loginCompleter = Completer<AuthSession>();
    final authenticationRepository = FakeAuthenticationRepository(
      (_, _) => loginCompleter.future,
    );
    final spacesRepository = FakeSpacesRepository((_) async => makeSpacePage());
    await tester.pumpWidget(
      TaskifyApp(
        authenticationRepository: authenticationRepository,
        spacesRepository: spacesRepository,
      ),
    );

    await _fillValidCredentials(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();
    expect(spacesRepository.fetchSpacesCalls, 0);

    loginCompleter.complete(testSession);
    await tester.pumpAndSettle();

    expect(spacesRepository.fetchSpacesCalls, 1);
    expect(spacesRepository.receivedAccessTokens, [testSession.accessToken]);

    await tester.pump();
    expect(spacesRepository.fetchSpacesCalls, 1);
  });

  testWidgets('não busca os espaços quando o login falha', (tester) async {
    final authenticationRepository = FakeAuthenticationRepository(
      (_, _) async => throw const ApiFailure(ApiFailureKind.unauthorized),
    );
    final spacesRepository = FakeSpacesRepository((_) async => makeSpacePage());
    await tester.pumpWidget(
      TaskifyApp(
        authenticationRepository: authenticationRepository,
        spacesRepository: spacesRepository,
      ),
    );

    await _fillValidCredentials(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(spacesRepository.fetchSpacesCalls, 0);
    expect(find.byKey(const Key('login-error')), findsOneWidget);
  });
}

Future<void> _fillValidCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('email-field')),
    'user@example.com',
  );
  await tester.enterText(find.byKey(const Key('password-field')), 'Secret1!');
}
