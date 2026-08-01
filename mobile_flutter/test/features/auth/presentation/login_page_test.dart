import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/presentation/login_page.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('valida os campos e permite mostrar a senha', (tester) async {
    final repository = FakeAuthenticationRepository(
      (_, _) async => testSession,
    );
    await tester.pumpWidget(_testApp(repository));

    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('password-field')), 'Secret1!');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('password-field')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('password-field')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isFalse,
    );
  });

  testWidgets('bloqueia envios concorrentes e entrega a sessão no sucesso', (
    tester,
  ) async {
    final completer = Completer<AuthSession>();
    final repository = FakeAuthenticationRepository((_, _) => completer.future);
    AuthSession? authenticatedSession;
    await tester.pumpWidget(
      _testApp(
        repository,
        onAuthenticated: (session) => authenticatedSession = session,
      ),
    );

    await _fillValidCredentials(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();
    expect(find.byKey(const ValueKey('login-progress')), findsOneWidget);
    expect(repository.loginCalls, 1);

    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();
    expect(repository.loginCalls, 1);

    completer.complete(testSession);
    await tester.pumpAndSettle();
    expect(authenticatedSession, same(testSession));
  });

  testWidgets('exibe o erro seguro de autenticação', (tester) async {
    final repository = FakeAuthenticationRepository(
      (_, _) async => throw const ApiFailure(ApiFailureKind.unauthorized),
    );
    await tester.pumpWidget(_testApp(repository));

    await _fillValidCredentials(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(
      find.text('E-mail ou senha inválidos, ou cadastro ainda não liberado.'),
      findsOneWidget,
    );
  });

  testWidgets('respeita Retry-After e mantém o botão bloqueado', (
    tester,
  ) async {
    final repository = FakeAuthenticationRepository(
      (_, _) async => throw const ApiFailure(
        ApiFailureKind.rateLimited,
        retryAfter: Duration(seconds: 2),
      ),
    );
    await tester.pumpWidget(_testApp(repository));

    await _fillValidCredentials(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    expect(find.text('Tente novamente em 2s'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('login-button')),
    );
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.byKey(const Key('login-error')), findsNothing);
  });
}

Widget _testApp(
  FakeAuthenticationRepository repository, {
  ValueChanged<AuthSession>? onAuthenticated,
}) {
  return MaterialApp(
    home: LoginPage(
      authenticationRepository: repository,
      onAuthenticated: onAuthenticated ?? (_) {},
    ),
  );
}

Future<void> _fillValidCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('email-field')),
    'user@example.com',
  );
  await tester.enterText(find.byKey(const Key('password-field')), 'Secret1!');
}
