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

    test('envia somente o refresh token ao encerrar a sessão', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://localhost:8080/auth/logout');
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(
          request.headers.keys.map((header) => header.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(
          request.headers.keys.map((header) => header.toLowerCase()),
          isNot(contains('x-device-id')),
        );
        expect(jsonDecode(request.body), <String, dynamic>{
          'refreshToken': 'refresh-token-test-only',
        });
        expect(request.body, isNot(contains('access-token-test-only')));
        return http.Response('', 204);
      });
      final repository = _repository(client);

      await repository.logout(refreshToken: 'refresh-token-test-only');
    });

    test(
      'solicita recuperação com e-mail normalizado e ignora o texto da resposta',
      () async {
        final sessionStore = FakeSessionStore()..failOnSave = true;
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'http://localhost:8080/auth/recovery-token',
          );
          expect(request.headers['Accept'], 'application/json');
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(
            request.headers['X-Device-Id'],
            '123e4567-e89b-42d3-a456-426614174000',
          );
          expect(
            request.headers.keys.map((header) => header.toLowerCase()),
            isNot(contains('authorization')),
          );
          expect(jsonDecode(request.body), <String, dynamic>{
            'address': 'user@example.com',
          });
          return http.Response(
            'Resposta genérica que não é JSON',
            200,
            headers: const {'content-type': 'text/plain; charset=utf-8'},
          );
        });
        final repository = _repository(client, sessionStore: sessionStore);

        await repository.requestPasswordRecovery(email: '  USER@EXAMPLE.COM  ');

        expect(sessionStore.savedSession, isNull);
      },
    );

    test(
      'rejeita e-mail vazio antes de consultar installation store ou rede',
      () async {
        var calls = 0;
        final installationIdStore = FakeInstallationIdStore()..fail = true;
        final repository = _repository(
          MockClient((_) async {
            calls += 1;
            return http.Response('', 200);
          }),
          installationIdStore: installationIdStore,
        );

        await expectLater(
          repository.requestPasswordRecovery(email: '   '),
          throwsA(
            isA<ApiFailure>().having(
              (failure) => failure.kind,
              'kind',
              ApiFailureKind.validation,
            ),
          ),
        );
        expect(calls, 0);
      },
    );

    test(
      'mapeia falha ao obter installation id sem solicitar recuperação',
      () async {
        var calls = 0;
        final installationIdStore = FakeInstallationIdStore()..fail = true;
        final repository = _repository(
          MockClient((_) async {
            calls += 1;
            return http.Response('', 200);
          }),
          installationIdStore: installationIdStore,
        );

        await expectLater(
          repository.requestPasswordRecovery(email: 'user@example.com'),
          throwsA(
            isA<ApiFailure>().having(
              (failure) => failure.kind,
              'kind',
              ApiFailureKind.storage,
            ),
          ),
        );
        expect(calls, 0);
      },
    );

    test('exige 200 na solicitação de recuperação', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('', 204)),
      );

      await expectLater(
        repository.requestPasswordRecovery(email: 'user@example.com'),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.unknown)
              .having((failure) => failure.statusCode, 'statusCode', 204),
        ),
      );
    });

    test('lê Retry-After da recuperação no 429', () async {
      final repository = _repository(
        MockClient(
          (_) async =>
              http.Response('', 429, headers: const {'Retry-After': '9'}),
        ),
      );

      await expectLater(
        repository.requestPasswordRecovery(email: 'user@example.com'),
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
                const Duration(seconds: 9),
              ),
        ),
      );
    });

    test('mapeia falha de rede na solicitação de recuperação', () async {
      final repository = _repository(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      await expectLater(
        repository.requestPasswordRecovery(email: 'user@example.com'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.network,
          ),
        ),
      );
    });

    test(
      'redefine a senha preservando zero inicial e sem auth, device ou sessão',
      () async {
        final sessionStore = FakeSessionStore()..failOnSave = true;
        final installationIdStore = FakeInstallationIdStore()..fail = true;
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'http://localhost:8080/auth/new-password/012345',
          );
          expect(request.headers['Accept'], 'application/json');
          expect(request.headers['Content-Type'], contains('application/json'));
          final normalizedHeaderNames = request.headers.keys.map(
            (header) => header.toLowerCase(),
          );
          expect(normalizedHeaderNames, isNot(contains('authorization')));
          expect(normalizedHeaderNames, isNot(contains('x-device-id')));
          expect(jsonDecode(request.body), <String, dynamic>{
            'newPassword': 'Strong1!',
            'newPasswordConfirmation': 'Strong1!',
          });
          return http.Response('corpo ignorado', 204);
        });
        final repository = _repository(
          client,
          sessionStore: sessionStore,
          installationIdStore: installationIdStore,
        );

        await repository.resetPassword(
          token: ' 012345 ',
          newPassword: 'Strong1!',
          newPasswordConfirmation: 'Strong1!',
        );

        expect(sessionStore.savedSession, isNull);
      },
    );

    test(
      'rejeita códigos que não tenham seis dígitos ASCII antes da rede',
      () async {
        var calls = 0;
        final repository = _repository(
          MockClient((_) async {
            calls += 1;
            return http.Response('', 204);
          }),
        );

        for (final code in <String>[
          '',
          '   ',
          '12345',
          '1234567',
          '12A456',
          '123-456',
          '123 456',
          '１２３４５６',
          '١٢٣٤٥٦',
        ]) {
          await expectLater(
            repository.resetPassword(
              token: code,
              newPassword: 'Strong1!',
              newPasswordConfirmation: 'Strong1!',
            ),
            throwsA(
              isA<ApiFailure>().having(
                (failure) => failure.kind,
                'kind',
                ApiFailureKind.validation,
              ),
            ),
            reason: 'O código "$code" deveria ser rejeitado.',
          );
        }
        expect(calls, 0);
      },
    );

    test('rejeita senhas fora da política antes da rede', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return http.Response('', 204);
        }),
      );
      final invalidPasswords = <String>[
        'Aa1!aaa',
        'Aa1!${List<String>.filled(29, 'a').join()}',
        'Aaaaaaa!',
        'AAAAAAA1!',
        'aaaaaaa1!',
        'Aaaaaaa1',
        'Aa1! aaa',
        'Aaaaaa1%',
        'Aa12345\\',
      ];

      for (final password in invalidPasswords) {
        await expectLater(
          repository.resetPassword(
            token: '123456',
            newPassword: password,
            newPasswordConfirmation: password,
          ),
          throwsA(
            isA<ApiFailure>().having(
              (failure) => failure.kind,
              'kind',
              ApiFailureKind.validation,
            ),
          ),
          reason: 'A senha "$password" deveria ser rejeitada.',
        );
      }
      expect(calls, 0);
    });

    test(
      'aceita colchetes como único caractere especial da nova senha',
      () async {
        final receivedPasswords = <String>[];
        final repository = _repository(
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            receivedPasswords.add(body['newPassword'] as String);
            return http.Response('', 204);
          }),
        );

        for (final password in <String>['Aa12345[', 'Aa12345]']) {
          await repository.resetPassword(
            token: '123456',
            newPassword: password,
            newPasswordConfirmation: password,
          );
        }

        expect(receivedPasswords, <String>['Aa12345[', 'Aa12345]']);
      },
    );

    test('rejeita confirmação diferente antes da rede', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return http.Response('', 204);
        }),
      );

      await expectLater(
        repository.resetPassword(
          token: '123456',
          newPassword: 'Strong1!',
          newPasswordConfirmation: 'Strong2!',
        ),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.validation,
          ),
        ),
      );
      expect(calls, 0);
    });

    test('exige 204 na redefinição de senha', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        repository.resetPassword(
          token: '123456',
          newPassword: 'Strong1!',
          newPasswordConfirmation: 'Strong1!',
        ),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.unknown)
              .having((failure) => failure.statusCode, 'statusCode', 200),
        ),
      );
    });

    for (final failureCase in <({int statusCode, ApiFailureKind kind})>[
      (statusCode: 400, kind: ApiFailureKind.validation),
      (statusCode: 401, kind: ApiFailureKind.unauthorized),
      (statusCode: 403, kind: ApiFailureKind.forbidden),
      (statusCode: 500, kind: ApiFailureKind.server),
    ]) {
      test(
        'mapeia ${failureCase.statusCode} na redefinição de senha',
        () async {
          final repository = _repository(
            MockClient((_) async => http.Response('', failureCase.statusCode)),
          );

          await expectLater(
            repository.resetPassword(
              token: '123456',
              newPassword: 'Strong1!',
              newPasswordConfirmation: 'Strong1!',
            ),
            throwsA(
              isA<ApiFailure>()
                  .having((failure) => failure.kind, 'kind', failureCase.kind)
                  .having(
                    (failure) => failure.statusCode,
                    'statusCode',
                    failureCase.statusCode,
                  ),
            ),
          );
        },
      );
    }

    test('mapeia timeout sem repetir a redefinição de senha', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return http.Response('', 204);
        }),
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.resetPassword(
          token: '123456',
          newPassword: 'Strong1!',
          newPasswordConfirmation: 'Strong1!',
        ),
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
  FakeInstallationIdStore? installationIdStore,
  Duration timeout = const Duration(seconds: 15),
}) {
  return HttpAuthenticationRepository(
    client: client,
    config: AppConfig(apiBaseUrl: 'http://localhost:8080'),
    sessionStore: sessionStore ?? FakeSessionStore(),
    installationIdStore: installationIdStore ?? FakeInstallationIdStore(),
    timeout: timeout,
  );
}
