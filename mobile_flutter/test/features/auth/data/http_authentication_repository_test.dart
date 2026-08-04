import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/data/http_authentication_repository.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('HttpAuthenticationRepository', () {
    test(
      'envia o contrato correto e persiste a sessão antes de retornar',
      () async {
        final sessionStore = FakeSessionStore();
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'http://localhost:8080/auth/login');
          expect(
            request.headers['X-Device-Id'],
            '123e4567-e89b-42d3-a456-426614174000',
          );
          expect(request.headers, isNot(contains('Authorization')));
          expect(jsonDecode(request.body), <String, dynamic>{
            'username': 'user@example.com',
            'password': 'Secret1!',
          });
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 1,
              'username': 'user@example.com',
              'name': 'User',
              'accessToken': 'access-token-test-only',
              'refreshToken': 'refresh-token-test-only',
              'role': 'ROLE_ADMIN',
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final repository = _repository(client, sessionStore: sessionStore);

        final session = await repository.login(
          email: '  USER@EXAMPLE.COM ',
          password: 'Secret1!',
        );

        expect(session.role, 'ROLE_ADMIN');
        expect(sessionStore.savedSession, same(session));
      },
    );

    test(
      'aceita o 201 do cadastro sem exigir tokens nem criar sessão',
      () async {
        final sessionStore = FakeSessionStore()..failOnSave = true;
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'http://localhost:8080/users');
          expect(
            request.headers['X-Device-Id'],
            '123e4567-e89b-42d3-a456-426614174000',
          );
          expect(jsonDecode(request.body), <String, dynamic>{
            'email': 'user@example.com',
            'name': 'User',
            'password': 'Secret1!',
            'passwordConfirmation': 'Secret1!',
          });
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 2,
              'email': 'user@example.com',
              'name': 'User',
              'status': 'PENDING_EVALUATION',
              'role': 'ROLE_USER',
            }),
            201,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final repository = _repository(client, sessionStore: sessionStore);

        await repository.register(
          name: ' User ',
          email: 'USER@EXAMPLE.COM',
          password: 'Secret1!',
          passwordConfirmation: 'Secret1!',
        );

        expect(sessionStore.savedSession, isNull);
      },
    );

    test(
      'mapeia e-mail já cadastrado sem expor a resposta do backend',
      () async {
        final repository = _repository(
          MockClient((_) async => http.Response('duplicate details', 409)),
        );

        await expectLater(
          repository.register(
            name: 'User',
            email: 'user@example.com',
            password: 'Secret1!',
            passwordConfirmation: 'Secret1!',
          ),
          throwsA(
            isA<ApiFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  ApiFailureKind.validation,
                )
                .having((failure) => failure.statusCode, 'statusCode', 409)
                .having(
                  (failure) => failure.userMessage(),
                  'userMessage',
                  'Já existe uma conta com este e-mail.',
                ),
          ),
        );
      },
    );

    test('mapeia 401 sem interpretar a mensagem do backend', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('credential details', 401)),
      );

      await expectLater(
        repository.login(email: 'user@example.com', password: 'wrong'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.unauthorized,
          ),
        ),
      );
    });

    test('lê Retry-After no 429', () async {
      final repository = _repository(
        MockClient(
          (_) async =>
              http.Response('{}', 429, headers: const {'Retry-After': '12'}),
        ),
      );

      await expectLater(
        repository.login(email: 'user@example.com', password: 'Secret1!'),
        throwsA(
          isA<ApiFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                ApiFailureKind.rateLimited,
              )
              .having(
                (failure) => failure.retryAfter,
                'retryAfter',
                const Duration(seconds: 12),
              ),
        ),
      );
    });

    test('não conclui login quando a sessão não pode ser protegida', () async {
      final sessionStore = FakeSessionStore()..failOnSave = true;
      final repository = _repository(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'id': 1,
              'username': 'user@example.com',
              'name': 'User',
              'accessToken': 'access-token-test-only',
              'refreshToken': 'refresh-token-test-only',
              'role': 'ROLE_USER',
            }),
            200,
          ),
        ),
        sessionStore: sessionStore,
      );

      await expectLater(
        repository.login(email: 'user@example.com', password: 'Secret1!'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.storage,
          ),
        ),
      );
    });

    test('mapeia resposta de login sem tokens como malformada', () async {
      final repository = _repository(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'id': 1,
              'email': 'user@example.com',
              'name': 'User',
              'role': 'ROLE_USER',
            }),
            200,
          ),
        ),
      );

      await expectLater(
        repository.login(email: 'user@example.com', password: 'Secret1!'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.malformedResponse,
          ),
        ),
      );
    });

    test('mapeia timeout sem repetir o login', () async {
      var calls = 0;
      final repository = HttpAuthenticationRepository(
        client: MockClient((_) async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return http.Response('{}', 200);
        }),
        config: AppConfig(apiBaseUrl: 'http://localhost:8080'),
        sessionStore: FakeSessionStore(),
        installationIdStore: FakeInstallationIdStore(),
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.login(email: 'user@example.com', password: 'Secret1!'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.timeout,
          ),
        ),
      );
      expect(calls, 1);
    });
  });
}

HttpAuthenticationRepository _repository(
  http.Client client, {
  FakeSessionStore? sessionStore,
}) {
  return HttpAuthenticationRepository(
    client: client,
    config: AppConfig(apiBaseUrl: 'http://localhost:8080'),
    sessionStore: sessionStore ?? FakeSessionStore(),
    installationIdStore: FakeInstallationIdStore(),
  );
}
