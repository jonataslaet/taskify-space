import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app/taskify_app.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/presentation/new_password_page.dart';
import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/task_execution_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';

import '../helpers/fakes.dart';

const _passwordRecoveryToken = '030447';

void main() {
  for (final initialRoute in <String>[
    '/new-password/$_passwordRecoveryToken',
    'https://app.example.com/new-password/$_passwordRecoveryToken',
    'taskifyspace://new-password/$_passwordRecoveryToken',
  ]) {
    testWidgets('abre a redefinição no cold start para $initialRoute', (
      tester,
    ) async {
      final authenticationRepository = FakeAuthenticationRepository(
        (_, _) async => testSession,
      );

      await tester.pumpWidget(
        TaskifyApp(
          authenticationRepository: authenticationRepository,
          spacesRepository: FakeSpacesRepository((_) async => makeSpacePage()),
          tasksRepository: _FakeTasksRepository(),
          initialRoute: initialRoute,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NewPasswordPage), findsOneWidget);
      expect(
        tester.widget<NewPasswordPage>(find.byType(NewPasswordPage)).token,
        _passwordRecoveryToken,
      );
      expect(find.text(_passwordRecoveryToken), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(NewPasswordPage))).canPop(),
        isTrue,
      );
    });
  }

  testWidgets('ignora um recovery link malformado no cold start', (
    tester,
  ) async {
    await tester.pumpWidget(
      TaskifyApp(
        authenticationRepository: FakeAuthenticationRepository(
          (_, _) async => testSession,
        ),
        spacesRepository: FakeSpacesRepository((_) async => makeSpacePage()),
        tasksRepository: _FakeTasksRepository(),
        initialRoute: '/new-password/token%20invalido',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NewPasswordPage), findsNothing);
    expect(find.byKey(const ValueKey('login-page')), findsOneWidget);
  });

  testWidgets('abre um recovery link absoluto com o aplicativo ativo', (
    tester,
  ) async {
    await tester.pumpWidget(
      TaskifyApp(
        authenticationRepository: FakeAuthenticationRepository(
          (_, _) async => testSession,
        ),
        spacesRepository: FakeSpacesRepository((_) async => makeSpacePage()),
        tasksRepository: _FakeTasksRepository(),
      ),
    );

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed('taskifyspace://new-password/$_passwordRecoveryToken');
    await tester.pumpAndSettle();

    expect(find.byType(NewPasswordPage), findsOneWidget);
    expect(find.text(_passwordRecoveryToken), findsNothing);
  });

  testWidgets(
    'warm link malformado preserva a tela sem buscar espacos novamente',
    (tester) async {
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
          tasksRepository: _FakeTasksRepository(),
        ),
      );
      await _fillValidCredentials(tester);
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();
      expect(spacesRepository.fetchSpacesCalls, 1);

      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('taskifyspace://new-password/token%20invalido');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('unknown-route-page')), findsOneWidget);
      expect(find.text('Link inválido'), findsWidgets);
      expect(
        find.byKey(const ValueKey('spaces-page'), skipOffstage: false),
        findsOneWidget,
      );
      expect(spacesRepository.fetchSpacesCalls, 1);

      await tester.tap(find.byKey(const ValueKey('unknown-route-back-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('unknown-route-page')), findsNothing);
      expect(find.byKey(const ValueKey('spaces-page')), findsOneWidget);
      expect(spacesRepository.fetchSpacesCalls, 1);
    },
  );

  testWidgets(
    'redefinir a senha limpa sessão e rotas e confirma o sucesso no login',
    (tester) async {
      final authenticationRepository = FakeAuthenticationRepository(
        (_, _) async => testSession,
        resetPasswordHandler: (_, _, _) async {},
      );
      final sessionStore = FakeSessionStore()..savedSession = testSession;
      final spacesRepository = FakeSpacesRepository(
        (_) async => makeSpacePage(content: const [testSpace]),
      );
      await tester.pumpWidget(
        TaskifyApp(
          authenticationRepository: authenticationRepository,
          spacesRepository: spacesRepository,
          tasksRepository: _FakeTasksRepository(),
          sessionStore: sessionStore,
        ),
      );
      await _fillValidCredentials(tester);
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();

      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/new-password/$_passwordRecoveryToken');
      await tester.pumpAndSettle();
      expect(find.byType(NewPasswordPage), findsOneWidget);
      expect(find.text(_passwordRecoveryToken), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('new-password-field')),
        'NovaSenha1!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-password-confirmation-field')),
        'NovaSenha1!',
      );
      await tester.tap(
        find.byKey(const ValueKey('new-password-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(authenticationRepository.resetPasswordCalls, 1);
      expect(authenticationRepository.receivedPasswordResetTokens, [
        _passwordRecoveryToken,
      ]);
      expect(authenticationRepository.receivedNewPasswords, ['NovaSenha1!']);
      expect(authenticationRepository.receivedNewPasswordConfirmations, [
        'NovaSenha1!',
      ]);
      expect(sessionStore.clearCalls, 1);
      expect(sessionStore.savedSession, isNull);
      expect(find.byType(NewPasswordPage), findsNothing);
      expect(find.byKey(const ValueKey('spaces-page')), findsNothing);
      expect(find.byKey(const ValueKey('login-page')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('password-reset-success')),
        findsOneWidget,
      );
      expect(
        Navigator.of(
          tester.element(find.byKey(const ValueKey('login-page'))),
        ).canPop(),
        isFalse,
      );
    },
  );

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
        tasksRepository: _FakeTasksRepository(),
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
        tasksRepository: _FakeTasksRepository(),
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
        tasksRepository: _FakeTasksRepository(),
      ),
    );

    await _fillValidCredentials(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(spacesRepository.fetchSpacesCalls, 0);
    expect(find.byKey(const Key('login-error')), findsOneWidget);
  });

  testWidgets(
    'limpa a sessão e retorna para o login em caso de falha de autenticação',
    (tester) async {
      final authenticationRepository = FakeAuthenticationRepository(
        (_, _) async => testSession,
      );
      final sessionStore = FakeSessionStore();
      final spacesRepository = FakeSpacesRepository(
        (_) async => throw const ApiFailure(ApiFailureKind.unauthorized),
      );

      await tester.pumpWidget(
        TaskifyApp(
          authenticationRepository: authenticationRepository,
          spacesRepository: spacesRepository,
          tasksRepository: _FakeTasksRepository(),
          sessionStore: sessionStore,
        ),
      );

      await _fillValidCredentials(tester);
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-page')), findsOneWidget);
      expect(sessionStore.savedSession, isNull);
    },
  );

  testWidgets(
    'revoga o refresh token, limpa a sessão e volta ao login a partir das tarefas',
    (tester) async {
      final logoutCompleter = Completer<void>();
      final authenticationRepository = FakeAuthenticationRepository(
        (_, _) async => testSession,
        logoutHandler: (_) => logoutCompleter.future,
      );
      final sessionStore = FakeSessionStore()..savedSession = testSession;
      final spacesRepository = FakeSpacesRepository(
        (_) async => makeSpacePage(content: const [testSpace]),
      );

      await tester.pumpWidget(
        TaskifyApp(
          authenticationRepository: authenticationRepository,
          spacesRepository: spacesRepository,
          tasksRepository: _FakeTasksRepository(),
          sessionStore: sessionStore,
        ),
      );
      await _fillValidCredentials(tester);
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('space-tasks-button-1')));
      await tester.pumpAndSettle();

      expect(find.text('Tarefas'), findsOneWidget);
      expect(find.byKey(const Key('logout-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('logout-button')));
      await tester.pump();

      expect(authenticationRepository.logoutCalls, 1);
      expect(authenticationRepository.receivedRefreshTokens, [
        testSession.refreshToken,
      ]);
      expect(find.byKey(const Key('logout-progress')), findsOneWidget);
      expect(sessionStore.savedSession, same(testSession));

      logoutCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-page')), findsOneWidget);
      expect(find.text('Tarefas'), findsNothing);
      expect(sessionStore.savedSession, isNull);
      expect(sessionStore.clearCalls, 1);
    },
  );

  testWidgets('encerra a sessão local mesmo quando a API de logout falha', (
    tester,
  ) async {
    final authenticationRepository = FakeAuthenticationRepository(
      (_, _) async => testSession,
      logoutHandler: (_) async =>
          throw const ApiFailure(ApiFailureKind.network),
    );
    final sessionStore = FakeSessionStore()..savedSession = testSession;
    final spacesRepository = FakeSpacesRepository(
      (_) async => makeSpacePage(content: const [testSpace]),
    );

    await tester.pumpWidget(
      TaskifyApp(
        authenticationRepository: authenticationRepository,
        spacesRepository: spacesRepository,
        tasksRepository: _FakeTasksRepository(),
        sessionStore: sessionStore,
      ),
    );
    await _fillValidCredentials(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();

    expect(authenticationRepository.logoutCalls, 1);
    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(sessionStore.savedSession, isNull);
    expect(sessionStore.clearCalls, 1);
  });
}

Future<void> _fillValidCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('email-field')),
    'user@example.com',
  );
  await tester.enterText(find.byKey(const Key('password-field')), 'Secret1!');
}

final class _FakeTasksRepository implements TasksRepository {
  @override
  Future<void> confirmTaskExecution({
    required String accessToken,
    required int spaceId,
    required int taskId,
    Set<int> executorIds = const <int>{},
    DateTime? executionDate,
  }) {
    return Future<void>.error(
      StateError('Confirmacao de tarefa nao esperada neste teste.'),
    );
  }

  @override
  Future<TaskSummary> createTask({
    required String accessToken,
    required int spaceId,
    required TaskCreation creation,
  }) {
    return Future<TaskSummary>.error(
      StateError('Criação de tarefa não esperada neste teste.'),
    );
  }

  @override
  Future<TaskPageResult> fetchTasks({
    required String accessToken,
    required int spaceId,
    TaskFilters filters = const TaskFilters(),
    int page = 0,
    int size = 10,
  }) async {
    return TaskPageResult(
      content: const [],
      size: size,
      number: page,
      totalElements: 0,
      totalPages: 0,
    );
  }

  @override
  Future<TaskExecutionPageResult> fetchTaskExecutions({
    required String accessToken,
    required int spaceId,
    required int taskId,
    int page = 0,
    int size = 10,
  }) async {
    return TaskExecutionPageResult(
      content: const [],
      size: size,
      number: page,
      totalElements: 0,
      totalPages: 0,
    );
  }

  @override
  Future<TaskSummary> updateTask({
    required String accessToken,
    required int spaceId,
    required int taskId,
    required TaskUpdate update,
  }) {
    return Future<TaskSummary>.error(
      StateError('Atualização de tarefa não esperada neste teste.'),
    );
  }

  @override
  Future<void> toggleTaskActive({
    required String accessToken,
    required int spaceId,
    required int taskId,
  }) {
    return Future<void>.error(
      StateError('Alteração de status de tarefa não esperada neste teste.'),
    );
  }
}
