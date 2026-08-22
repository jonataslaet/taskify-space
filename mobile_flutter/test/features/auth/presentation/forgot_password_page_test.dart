import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/presentation/forgot_password_page.dart';
import 'package:mobile_flutter/features/auth/presentation/new_password_page.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('preenche o e-mail inicial e valida antes de chamar a API', (
    tester,
  ) async {
    final repository = _repository((_) async {});
    await tester.pumpWidget(
      _testApp(repository, initialEmail: '  user@example.com  '),
    );

    final emailField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('forgot-password-email-field')),
    );
    expect(emailField.controller?.text, 'user@example.com');
    expect(
      tester.widget<AutofillGroup>(find.byType(AutofillGroup)).onDisposeAction,
      AutofillContextAction.cancel,
    );

    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-email-field')),
      'email-invalido',
    );
    await tester.tap(
      find.byKey(const ValueKey('forgot-password-submit-button')),
    );
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(repository.requestPasswordRecoveryCalls, 0);
  });

  testWidgets('abre a tela de código sem revelar se a conta existe', (
    tester,
  ) async {
    final repository = _repository((email) async {
      expect(email, 'missing@example.com');
    });
    await tester.pumpWidget(_testApp(repository));

    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-email-field')),
      '  missing@example.com  ',
    );
    tester.testTextInput.log.clear();
    await tester.tap(
      find.byKey(const ValueKey('forgot-password-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.requestPasswordRecoveryCalls, 1);
    expect(repository.receivedPasswordRecoveryEmails, ['missing@example.com']);
    expect(find.byType(NewPasswordPage), findsOneWidget);
    expect(
      find.text(
        'Caso o email informado exista, receberá nele um código de validação, '
        'o qual colocará no campo de validação desta tela',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('new-password-code-field')),
      findsOneWidget,
    );
    expect(
      tester.testTextInput.log.where(
        (call) => call.method == 'TextInput.finishAutofillContext',
      ),
      isEmpty,
    );

    await tester.tap(find.byKey(const ValueKey('new-password-back-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('forgot-password-email-field')),
          )
          .controller
          ?.text,
      '  missing@example.com  ',
    );
    expect(
      find.byKey(const ValueKey('forgot-password-success')),
      findsOneWidget,
    );
    expect(find.text('Enviar novamente'), findsOneWidget);
  });

  testWidgets('bloqueia formulário, volta e reenvio durante a solicitação', (
    tester,
  ) async {
    final response = Completer<void>();
    final repository = _repository((_) => response.future);
    await tester.pumpWidget(
      _testApp(repository, initialEmail: 'user@example.com'),
    );

    await tester.tap(
      find.byKey(const ValueKey('forgot-password-submit-button')),
    );
    await tester.pump();

    expect(repository.requestPasswordRecoveryCalls, 1);
    expect(
      find.byKey(const ValueKey('forgot-password-progress')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('forgot-password-submit-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('forgot-password-email-field')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('forgot-password-back-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('forgot-password-submit-button')),
    );
    await tester.pump();
    expect(repository.requestPasswordRecoveryCalls, 1);

    response.complete();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('new-password-code-field')),
      findsOneWidget,
    );
  });

  testWidgets('respeita Retry-After e libera nova tentativa ao terminar', (
    tester,
  ) async {
    final repository = _repository(
      (_) async => throw const ApiFailure(
        ApiFailureKind.rateLimited,
        statusCode: 429,
        retryAfter: Duration(seconds: 2),
      ),
    );
    await tester.pumpWidget(
      _testApp(repository, initialEmail: 'user@example.com'),
    );

    await tester.tap(
      find.byKey(const ValueKey('forgot-password-submit-button')),
    );
    await tester.pump();

    expect(find.text('Tente novamente em 2s'), findsOneWidget);
    expect(
      find.text('Muitas solicitações. Aguarde um pouco e tente novamente.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('forgot-password-submit-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tente novamente em 1s'), findsOneWidget);
    expect(
      find.text('Muitas solicitações. Aguarde um pouco e tente novamente.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('forgot-password-error')), findsNothing);
    expect(find.text('Enviar código'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('forgot-password-submit-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('mostra erro contextual e permite corrigir o e-mail', (
    tester,
  ) async {
    final repository = _repository(
      (_) async => throw const ApiFailure(ApiFailureKind.network),
    );
    await tester.pumpWidget(
      _testApp(repository, initialEmail: 'user@example.com'),
    );

    await tester.tap(
      find.byKey(const ValueKey('forgot-password-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('forgot-password-error')), findsOneWidget);
    expect(
      find.text('Não foi possível conectar à API. Confira sua conexão.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-email-field')),
      'other@example.com',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('forgot-password-error')), findsNothing);
  });

  testWidgets('permanece rolável em uma tela estreita e baixa', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _repository((_) async {});

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('forgot-password-submit-button')),
    );
    expect(tester.takeException(), isNull);
  });
}

FakeAuthenticationRepository _repository(
  RequestPasswordRecoveryHandler handler,
) {
  return FakeAuthenticationRepository(
    (_, _) async => testSession,
    requestPasswordRecoveryHandler: handler,
  );
}

Widget _testApp(
  FakeAuthenticationRepository repository, {
  String initialEmail = '',
}) {
  return MaterialApp(
    home: ForgotPasswordPage(
      authenticationRepository: repository,
      initialEmail: initialEmail,
    ),
  );
}
