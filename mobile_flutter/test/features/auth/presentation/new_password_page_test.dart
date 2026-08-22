import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/presentation/new_password_page.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('valida os requisitos e a confirmação antes de chamar a API', (
    tester,
  ) async {
    final repository = _repository((_, _, _) async {});
    await tester.pumpWidget(_testApp(repository));
    expect(
      tester.widget<AutofillGroup>(find.byType(AutofillGroup)).onDisposeAction,
      AutofillContextAction.cancel,
    );
    expect(find.text('Redefinir senha'), findsOneWidget);
    expect(_semanticButtonLabel('Redefinir senha'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('new-password-submit-button')));
    await tester.pump();
    expect(find.text('Informe a nova senha.'), findsOneWidget);
    expect(find.text('Confirme a nova senha.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('new-password-field')),
      'fraca senha',
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-password-confirmation-field')),
      'outra senha',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('new-password-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('new-password-submit-button')));
    await tester.pump();

    expect(
      find.text(
        'Use de 8 a 32 caracteres, sem espaços, com letra maiúscula, '
        'letra minúscula, número e caractere especial como !, @, #, \$, - '
        'ou _.',
      ),
      findsOneWidget,
    );
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    expect(repository.resetPasswordCalls, 0);
  });

  testWidgets('alterna a visibilidade dos dois campos', (tester) async {
    final repository = _repository((_, _, _) async {});
    await tester.pumpWidget(_testApp(repository));

    expect(_editableText(tester, 'new-password-field').obscureText, isTrue);
    expect(
      _editableText(tester, 'new-password-confirmation-field').obscureText,
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('new-password-visibility-button')),
    );
    await tester.pump();

    expect(_editableText(tester, 'new-password-field').obscureText, isFalse);
    expect(
      _editableText(tester, 'new-password-confirmation-field').obscureText,
      isFalse,
    );
  });

  testWidgets('modo manual mostra instrução exata e exige seis dígitos ASCII', (
    tester,
  ) async {
    final repository = _repository((_, _, _) async {});
    await tester.pumpWidget(_testApp(repository, withCode: true));

    expect(
      find.byKey(const ValueKey('new-password-code-instructions')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Caso o email informado exista, receberá nele um código de validação, '
        'o qual colocará no campo de validação desta tela',
      ),
      findsOneWidget,
    );
    final codeField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('new-password-code-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(codeField.keyboardType, TextInputType.number);
    expect(codeField.autofillHints, const [AutofillHints.oneTimeCode]);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(_semanticButtonLabel('Confirmar'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('new-password-code-field')),
      '12a٣45678',
    );
    expect(codeField.controller?.text, '124567');
    await tester.enterText(
      find.byKey(const ValueKey('new-password-code-field')),
      '123',
    );
    await _fillValidPasswords(tester);
    await _tapSubmit(tester);

    expect(
      find.text('Informe os 6 dígitos do código de validação.'),
      findsOneWidget,
    );
    expect(repository.resetPasswordCalls, 0);
  });

  testWidgets('modo manual envia o código e salva autofill somente no 204', (
    tester,
  ) async {
    final response = Completer<void>();
    var callbackCalls = 0;
    final repository = _repository((token, password, confirmation) {
      expect(token, '654321');
      expect(password, 'Secret1!');
      expect(confirmation, 'Secret1!');
      return response.future;
    });
    await tester.pumpWidget(
      _testApp(
        repository,
        withCode: true,
        onPasswordReset: () async {
          expect(_savedAutofillContexts(tester), [true]);
          callbackCalls += 1;
        },
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-password-code-field')),
      '654321',
    );
    await _fillValidPasswords(tester);
    tester.testTextInput.log.clear();

    await _tapSubmit(tester);
    expect(repository.resetPasswordCalls, 1);
    expect(_savedAutofillContexts(tester), isEmpty);

    response.complete();
    await tester.pumpAndSettle();

    expect(repository.receivedPasswordResetTokens, ['654321']);
    expect(callbackCalls, 1);
    expect(_savedAutofillContexts(tester), [true]);
    expect(find.byKey(const ValueKey('new-password-success')), findsOneWidget);
  });

  for (final failure in const [
    ApiFailure(ApiFailureKind.unauthorized, statusCode: 401),
    ApiFailure(ApiFailureKind.unknown, statusCode: 404),
  ]) {
    testWidgets(
      '${failure.statusCode} fica inline no modo manual e permite correção',
      (tester) async {
        var attempts = 0;
        final repository = _repository((token, _, _) async {
          attempts += 1;
          if (attempts == 1) {
            expect(token, '111111');
            throw failure;
          }
          expect(token, '222222');
        });
        await tester.pumpWidget(_testApp(repository, withCode: true));
        await tester.enterText(
          find.byKey(const ValueKey('new-password-code-field')),
          '111111',
        );
        await _fillValidPasswords(tester);

        await _tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(find.text('Código inválido ou expirado'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('new-password-code-field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('new-password-invalid-token')),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const ValueKey('new-password-code-field')),
          '222222',
        );
        await tester.pump();
        expect(find.text('Código inválido ou expirado'), findsNothing);

        await _tapSubmit(tester);
        await tester.pumpAndSettle();
        expect(repository.resetPasswordCalls, 2);
        expect(
          find.byKey(const ValueKey('new-password-success')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('envia token e senhas uma vez e chama o callback no sucesso', (
    tester,
  ) async {
    const token = '030447';
    var callbackCalls = 0;
    final repository = _repository((
      receivedToken,
      password,
      confirmation,
    ) async {
      expect(receivedToken, token);
      expect(password, 'Secret1!');
      expect(confirmation, 'Secret1!');
    });
    await tester.pumpWidget(
      _testApp(
        repository,
        token: token,
        onPasswordReset: () async {
          expect(_savedAutofillContexts(tester), [true]);
          callbackCalls += 1;
        },
      ),
    );

    expect(find.textContaining(token), findsNothing);
    await _fillValidPasswords(tester);
    tester.testTextInput.log.clear();
    await tester.tap(find.byKey(const ValueKey('new-password-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.resetPasswordCalls, 1);
    expect(repository.receivedPasswordResetTokens, [token]);
    expect(repository.receivedNewPasswords, ['Secret1!']);
    expect(repository.receivedNewPasswordConfirmations, ['Secret1!']);
    expect(callbackCalls, 1);
    expect(find.byKey(const ValueKey('new-password-success')), findsOneWidget);
    expect(find.textContaining(token), findsNothing);
  });

  testWidgets('bloqueia campos, voltar e reenvio enquanto aguarda a API', (
    tester,
  ) async {
    final response = Completer<void>();
    final repository = _repository((_, _, _) => response.future);
    await tester.pumpWidget(_testApp(repository));
    await _fillValidPasswords(tester);
    tester.testTextInput.log.clear();

    await tester.tap(find.byKey(const ValueKey('new-password-submit-button')));
    await tester.pump();

    expect(repository.resetPasswordCalls, 1);
    expect(_savedAutofillContexts(tester), isEmpty);
    expect(find.byKey(const ValueKey('new-password-progress')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('new-password-submit-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('new-password-field')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('new-password-confirmation-field')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('new-password-back-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('new-password-submit-button')));
    await tester.pump();
    expect(repository.resetPasswordCalls, 1);

    response.complete();
    await tester.pumpAndSettle();
    expect(_savedAutofillContexts(tester), [true]);
    expect(find.byKey(const ValueKey('new-password-success')), findsOneWidget);
  });

  for (final failure in const [
    ApiFailure(ApiFailureKind.unauthorized, statusCode: 401),
    ApiFailure(ApiFailureKind.unknown, statusCode: 404),
  ]) {
    testWidgets(
      '${failure.statusCode} trata o link como inválido ou expirado',
      (tester) async {
        var callbackCalls = 0;
        final repository = _repository((_, _, _) async => throw failure);
        await tester.pumpWidget(
          _testApp(repository, onPasswordReset: () async => callbackCalls += 1),
        );
        await _fillValidPasswords(tester);

        await tester.tap(
          find.byKey(const ValueKey('new-password-submit-button')),
        );
        await tester.pumpAndSettle();

        expect(repository.resetPasswordCalls, 1);
        expect(callbackCalls, 0);
        expect(
          find.byKey(const ValueKey('new-password-invalid-token')),
          findsOneWidget,
        );
        expect(find.text('Link inválido ou expirado'), findsOneWidget);
        expect(find.byKey(const ValueKey('new-password-error')), findsNothing);
      },
    );
  }

  testWidgets('mostra erro contextual e permite nova tentativa', (
    tester,
  ) async {
    var attempts = 0;
    final repository = _repository((_, _, _) async {
      attempts += 1;
      if (attempts == 1) {
        throw const ApiFailure(ApiFailureKind.network);
      }
    });
    await tester.pumpWidget(_testApp(repository));
    await _fillValidPasswords(tester);
    tester.testTextInput.log.clear();

    await tester.tap(find.byKey(const ValueKey('new-password-submit-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-password-error')), findsOneWidget);
    expect(
      find.text('Não foi possível conectar à API. Confira sua conexão.'),
      findsOneWidget,
    );
    expect(_savedAutofillContexts(tester), isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('new-password-confirmation-field')),
      'Secret2!',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('new-password-error')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('new-password-field')),
      'Secret2!',
    );

    await tester.tap(find.byKey(const ValueKey('new-password-submit-button')));
    await tester.pumpAndSettle();
    expect(repository.resetPasswordCalls, 2);
    expect(find.byKey(const ValueKey('new-password-success')), findsOneWidget);
  });

  for (final invalidToken in ['', 'abc123']) {
    testWidgets(
      'token inválido "$invalidToken" não mostra formulário nem chama a API',
      (tester) async {
        final repository = _repository((_, _, _) async {});
        await tester.pumpWidget(_testApp(repository, token: invalidToken));

        expect(find.byTooltip('Voltar à tela anterior'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('new-password-invalid-token')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('new-password-field')), findsNothing);
        expect(repository.resetPasswordCalls, 0);
      },
    );
  }

  testWidgets('modo manual permanece rolável em tela estreita e baixa', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _repository((_, _, _) async {});

    await tester.pumpWidget(_testApp(repository, withCode: true));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('new-password-code-field')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('new-password-submit-button')),
    );
    expect(tester.takeException(), isNull);
  });
}

EditableText _editableText(WidgetTester tester, String fieldKey) {
  return tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(ValueKey(fieldKey)),
      matching: find.byType(EditableText),
    ),
  );
}

Finder _semanticButtonLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        widget.properties.label == label,
  );
}

List<bool> _savedAutofillContexts(WidgetTester tester) {
  return tester.testTextInput.log
      .where((call) => call.method == 'TextInput.finishAutofillContext')
      .map((call) => call.arguments as bool)
      .where((shouldSave) => shouldSave)
      .toList();
}

Future<void> _fillValidPasswords(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('new-password-field')),
    'Secret1!',
  );
  await tester.enterText(
    find.byKey(const ValueKey('new-password-confirmation-field')),
    'Secret1!',
  );
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submitButton = find.byKey(const ValueKey('new-password-submit-button'));
  await tester.ensureVisible(submitButton);
  await tester.tap(submitButton);
  await tester.pump();
}

FakeAuthenticationRepository _repository(ResetPasswordHandler handler) {
  return FakeAuthenticationRepository(
    (_, _) async => testSession,
    resetPasswordHandler: handler,
  );
}

Widget _testApp(
  FakeAuthenticationRepository repository, {
  String token = '030447',
  bool withCode = false,
  Future<void> Function()? onPasswordReset,
}) {
  return MaterialApp(
    home: withCode
        ? NewPasswordPage.withCode(
            authenticationRepository: repository,
            onPasswordReset: onPasswordReset ?? () async {},
          )
        : NewPasswordPage(
            authenticationRepository: repository,
            token: token,
            onPasswordReset: onPasswordReset ?? () async {},
          ),
  );
}
