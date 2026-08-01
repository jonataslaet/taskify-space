import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app/taskify_app.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('troca a tela de login pela confirmação sem exibir tokens', (
    tester,
  ) async {
    final repository = FakeAuthenticationRepository(
      (_, _) async => testSession,
    );
    await tester.pumpWidget(TaskifyApp(authenticationRepository: repository));

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'user@example.com',
    );
    await tester.enterText(find.byKey(const Key('password-field')), 'Secret1!');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Olá, Usuário de Teste!'), findsOneWidget);
    expect(find.text('access-token-test-only'), findsNothing);
    expect(find.text('refresh-token-test-only'), findsNothing);
  });
}
