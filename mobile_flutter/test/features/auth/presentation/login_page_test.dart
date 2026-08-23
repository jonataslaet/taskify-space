import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/presentation/forgot_password_page.dart';
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
    expect(
      find.text('Muitas tentativas. Aguarde um pouco e tente novamente.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('login-button')),
    );
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tente novamente em 1s'), findsOneWidget);
    expect(
      find.text('Muitas tentativas. Aguarde um pouco e tente novamente.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.byKey(const Key('login-error')), findsNothing);
  });

  testWidgets('confirma o cadastro sem autenticar antes da confirmação', (
    tester,
  ) async {
    final repository = FakeAuthenticationRepository(
      (_, _) async => testSession,
      registerHandler: (name, email, password, passwordConfirmation) async {
        expect(name, 'Jonatas Blendo');
        expect(email, 'jonataslaetprogramador@gmail.com');
        expect(password, 'Secret1!');
        expect(passwordConfirmation, 'Secret1!');
      },
    );
    AuthSession? authenticatedSession;
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _testApp(
        repository,
        onAuthenticated: (session) => authenticatedSession = session,
      ),
    );

    await tester.tap(find.byKey(const Key('toggle-auth-mode-button')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('name-field')),
      'Jonatas Blendo',
    );
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'jonataslaetprogramador@gmail.com',
    );
    await tester.enterText(find.byKey(const Key('password-field')), 'Secret1!');
    await tester.enterText(
      find.byKey(const Key('password-confirmation-field')),
      'Secret1!',
    );
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(repository.registerCalls, 1);
    expect(authenticatedSession, isNull);
    expect(find.byKey(const Key('registration-success')), findsOneWidget);
    expect(
      find.text(
        'Cadastro realizado! Verifique jonataslaetprogramador@gmail.com para '
        'confirmar o cadastro antes de entrar.',
      ),
      findsOneWidget,
    );
    expect(repository.loginCalls, 0);
    expect(find.byKey(const Key('login-error')), findsNothing);
    expect(find.byKey(const Key('name-field')), findsNothing);
    expect(find.byKey(const Key('password-confirmation-field')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('email-field')))
          .controller
          ?.text,
      'jonataslaetprogramador@gmail.com',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('password-field')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.text('Entrar'), findsWidgets);
  });

  testWidgets('abre recuperação com o e-mail atual pré-preenchido', (
    tester,
  ) async {
    var passwordResetCallbacks = 0;
    final repository = FakeAuthenticationRepository(
      (_, _) async => testSession,
    );
    await tester.pumpWidget(
      _testApp(
        repository,
        onPasswordReset: () async => passwordResetCallbacks += 1,
      ),
    );
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'user@example.com',
    );
    tester.testTextInput.log.clear();

    await tester.tap(find.byKey(const Key('forgot-password-button')));
    await tester.pumpAndSettle();

    expect(_savedAutofillContexts(tester), [false]);
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    expect(find.byKey(const ValueKey('forgot-password-page')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('forgot-password-email-field')),
          )
          .controller
          ?.text,
      'user@example.com',
    );

    await tester.tap(find.byKey(const ValueKey('forgot-password-back-button')));
    await tester.pumpAndSettle();

    expect(passwordResetCallbacks, 0);
  });

  testWidgets(
    'propaga redefinição por código, limpa senha e confirma no login',
    (tester) async {
      final repository = FakeAuthenticationRepository(
        (_, _) async => testSession,
        requestPasswordRecoveryHandler: (email) async {
          expect(email, 'user@example.com');
        },
        resetPasswordHandler: (token, password, confirmation) async {
          expect(token, '123456');
          expect(password, 'NewSecret1!');
          expect(confirmation, 'NewSecret1!');
        },
      );
      var passwordResetCallbacks = 0;
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _testApp(
          repository,
          onPasswordReset: () async => passwordResetCallbacks += 1,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('email-field')),
        'user@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password-field')),
        'OldSecret1!',
      );

      await tester.tap(find.byKey(const Key('forgot-password-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('forgot-password-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('new-password-code-field')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-password-code-field')),
        '123456',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-password-field')),
        'NewSecret1!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-password-confirmation-field')),
        'NewSecret1!',
      );
      final resetButton = find.byKey(
        const ValueKey('new-password-submit-button'),
      );
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(repository.requestPasswordRecoveryCalls, 1);
      expect(repository.resetPasswordCalls, 1);
      expect(passwordResetCallbacks, 1);
      expect(find.byType(ForgotPasswordPage), findsNothing);
      expect(find.byKey(const Key('password-reset-success')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('email-field')))
            .controller
            ?.text,
        'user@example.com',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('password-field')))
            .controller
            ?.text,
        isEmpty,
      );
    },
  );

  testWidgets('não oferece recuperação no modo de cadastro', (tester) async {
    final repository = FakeAuthenticationRepository(
      (_, _) async => testSession,
    );
    await tester.pumpWidget(_testApp(repository));

    expect(find.byKey(const Key('forgot-password-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggle-auth-mode-button')));
    await tester.pump();

    expect(find.byKey(const Key('forgot-password-button')), findsNothing);
  });

  testWidgets('anuncia a senha redefinida recebida na primeira construção', (
    tester,
  ) async {
    final repository = FakeAuthenticationRepository(
      (_, _) async => testSession,
    );
    await tester.pumpWidget(_testApp(repository, passwordResetSucceeded: true));

    expect(find.byKey(const Key('password-reset-success')), findsOneWidget);
    expect(
      find.text('Senha redefinida com sucesso. Entre com sua nova senha.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('reage quando o resultado de redefinição muda para sucesso', (
    tester,
  ) async {
    final repository = FakeAuthenticationRepository(
      (_, _) async => testSession,
    );
    const pageKey = ValueKey('stable-login-page');

    await tester.pumpWidget(_testApp(repository, loginPageKey: pageKey));
    expect(find.byKey(const Key('password-reset-success')), findsNothing);

    await tester.pumpWidget(
      _testApp(repository, loginPageKey: pageKey, passwordResetSucceeded: true),
    );
    await tester.pump();

    expect(find.byKey(const Key('password-reset-success')), findsOneWidget);
  });
}

Widget _testApp(
  FakeAuthenticationRepository repository, {
  ValueChanged<AuthSession>? onAuthenticated,
  Future<void> Function()? onPasswordReset,
  bool passwordResetSucceeded = false,
  Key? loginPageKey,
}) {
  return MaterialApp(
    home: LoginPage(
      key: loginPageKey,
      authenticationRepository: repository,
      onAuthenticated: onAuthenticated ?? (_) {},
      onPasswordReset: onPasswordReset ?? () async {},
      passwordResetSucceeded: passwordResetSucceeded,
    ),
  );
}

List<bool> _savedAutofillContexts(WidgetTester tester) {
  return tester.testTextInput.log
      .where((call) => call.method == 'TextInput.finishAutofillContext')
      .map((call) => call.arguments as bool)
      .toList();
}

Future<void> _fillValidCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('email-field')),
    'user@example.com',
  );
  await tester.enterText(find.byKey(const Key('password-field')), 'Secret1!');
}
