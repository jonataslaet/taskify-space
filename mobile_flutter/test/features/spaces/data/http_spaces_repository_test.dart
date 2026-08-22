import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/data/http_spaces_repository.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';

void main() {
  group('HttpSpacesRepository', () {
    test('faz POST /spaces com o payload mínimo em JSON UTF-8', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://localhost:8080/api/spaces');
        expect(request.headers['Accept'], 'application/json');
        expect(
          request.headers['Authorization'],
          'Bearer access-token-test-only',
        );
        expect(
          request.headers['Content-Type'],
          'application/json; charset=utf-8',
        );
        expect(jsonDecode(utf8.decode(request.bodyBytes)), <String, dynamic>{
          'name': 'Residência Açú',
        });
        return _jsonResponse(_validCreatedBody(), statusCode: 201);
      });

      final result = await _repository(client).createSpace(
        accessToken: ' access-token-test-only ',
        name: '  Residência Açú  ',
      );

      expect(result.id, 3);
      expect(result.name, 'Residência Açú');
      expect(result.spaceAdminName, 'Joice Laet');
      expect(result.active, isFalse);
    });

    test('não envia campos controlados pelo backend na criação', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(utf8.decode(request.bodyBytes));
        expect(body, hasLength(1));
        expect(body, isNot(contains('spaceAdminName')));
        expect(body, isNot(contains('active')));
        return _jsonResponse(_validCreatedBody(), statusCode: 201);
      });

      await _repository(
        client,
      ).createSpace(accessToken: 'access-token-test-only', name: 'Meu espaço');
    });

    test('não faz POST com nome vazio ou maior que 255 caracteres', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return _jsonResponse(_validCreatedBody(), statusCode: 201);
        }),
      );

      for (final invalidName in <String>['   ', 'a' * 256]) {
        await expectLater(
          repository.createSpace(
            accessToken: 'access-token-test-only',
            name: invalidName,
          ),
          throwsA(
            isA<ApiFailure>().having(
              (failure) => failure.kind,
              'kind',
              ApiFailureKind.validation,
            ),
          ),
        );
      }
      expect(calls, 0);
    });

    test('não faz POST quando o token está vazio', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return _jsonResponse(_validCreatedBody(), statusCode: 201);
        }),
      );

      await expectLater(
        repository.createSpace(accessToken: '   ', name: 'Meu espaço'),
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

    test('exige status 201 na criação', () async {
      final repository = _repository(
        MockClient((_) async => _jsonResponse(_validCreatedBody())),
      );

      await expectLater(
        repository.createSpace(
          accessToken: 'access-token-test-only',
          name: 'Meu espaço',
        ),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.unknown)
              .having((failure) => failure.statusCode, 'statusCode', 200),
        ),
      );
    });

    test('mapeia 400 do POST para validation', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('{}', 400)),
      );

      await expectLater(
        repository.createSpace(
          accessToken: 'access-token-test-only',
          name: 'Meu espaço',
        ),
        throwsA(
          isA<ApiFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                ApiFailureKind.validation,
              )
              .having((failure) => failure.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('mapeia 403 do POST para forbidden', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('{}', 403)),
      );

      await expectLater(
        repository.createSpace(
          accessToken: 'access-token-test-only',
          name: 'Meu espaço',
        ),
        throwsA(
          isA<ApiFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                ApiFailureKind.forbidden,
              )
              .having((failure) => failure.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('não repete automaticamente o POST após timeout', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _jsonResponse(_validCreatedBody(), statusCode: 201);
        }),
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.createSpace(
          accessToken: 'access-token-test-only',
          name: 'Meu espaço',
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

    test('mapeia resposta 201 incompatível para malformedResponse', () async {
      final repository = _repository(
        MockClient(
          (_) async => _jsonResponse(<String, dynamic>{
            'id': 3,
            'name': 'Meu espaço',
          }, statusCode: 201),
        ),
      );

      await expectLater(
        repository.createSpace(
          accessToken: 'access-token-test-only',
          name: 'Meu espaço',
        ),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.malformedResponse,
          ),
        ),
      );
    });

    group('requestSpaceParticipation', () {
      test('faz POST contextual com Bearer, sem body ou query', () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'http://localhost:8080/api/spaces/7/participations/request',
          );
          expect(request.url.query, isEmpty);
          expect(request.headers['Accept'], 'application/json');
          expect(
            request.headers['Authorization'],
            'Bearer access-token-test-only',
          );
          expect(request.headers, isNot(contains('Content-Type')));
          expect(request.bodyBytes, isEmpty);
          return http.Response('', 204);
        });

        await _repository(client).requestSpaceParticipation(
          accessToken: ' access-token-test-only ',
          spaceId: 7,
        );
      });

      test('rejeita token ou spaceId inválidos antes da rede', () async {
        var calls = 0;
        final repository = _repository(
          MockClient((_) async {
            calls += 1;
            return http.Response('', 204);
          }),
        );

        for (final request in <Future<void>>[
          repository.requestSpaceParticipation(accessToken: '   ', spaceId: 7),
          repository.requestSpaceParticipation(
            accessToken: 'token',
            spaceId: 0,
          ),
          repository.requestSpaceParticipation(
            accessToken: 'token',
            spaceId: -1,
          ),
        ]) {
          await expectLater(
            request,
            throwsA(
              isA<ApiFailure>().having(
                (failure) => failure.kind,
                'kind',
                ApiFailureKind.validation,
              ),
            ),
          );
        }
        expect(calls, 0);
      });

      test('aceita somente 204 como sucesso', () async {
        final repository = _repository(
          MockClient((_) async => http.Response('{}', 200)),
        );

        await expectLater(
          repository.requestSpaceParticipation(
            accessToken: 'access-token-test-only',
            spaceId: 7,
          ),
          throwsA(
            isA<ApiFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  ApiFailureKind.unknown,
                )
                .having((failure) => failure.statusCode, 'statusCode', 200),
          ),
        );
      });

      for (final errorCase in <(int, ApiFailureKind)>[
        (400, ApiFailureKind.validation),
        (401, ApiFailureKind.unauthorized),
        (403, ApiFailureKind.forbidden),
        (404, ApiFailureKind.unknown),
        (409, ApiFailureKind.unknown),
        (503, ApiFailureKind.server),
      ]) {
        test('mapeia ${errorCase.$1} para ${errorCase.$2.name}', () async {
          final repository = _repository(
            MockClient((_) async => http.Response('{}', errorCase.$1)),
          );

          await expectLater(
            repository.requestSpaceParticipation(
              accessToken: 'access-token-test-only',
              spaceId: 7,
            ),
            throwsA(
              isA<ApiFailure>()
                  .having((failure) => failure.kind, 'kind', errorCase.$2)
                  .having(
                    (failure) => failure.statusCode,
                    'statusCode',
                    errorCase.$1,
                  ),
            ),
          );
        });
      }

      test('lê Retry-After no 429', () async {
        final repository = _repository(
          MockClient(
            (_) async => http.Response(
              '{}',
              429,
              headers: const <String, String>{'Retry-After': '12'},
            ),
          ),
        );

        await expectLater(
          repository.requestSpaceParticipation(
            accessToken: 'access-token-test-only',
            spaceId: 7,
          ),
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

      test('mapeia falha do cliente para network', () async {
        final repository = _repository(
          MockClient((request) async {
            throw http.ClientException('Falha simulada.', request.url);
          }),
        );

        await expectLater(
          repository.requestSpaceParticipation(
            accessToken: 'access-token-test-only',
            spaceId: 7,
          ),
          throwsA(
            isA<ApiFailure>().having(
              (failure) => failure.kind,
              'kind',
              ApiFailureKind.network,
            ),
          ),
        );
      });

      test('mapeia timeout sem repetir o POST', () async {
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
          repository.requestSpaceParticipation(
            accessToken: 'access-token-test-only',
            spaceId: 7,
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
    });

    test('faz GET /spaces com Bearer e interpreta a resposta', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/spaces');
        expect(request.url.queryParameters, <String, String>{
          'page': '0',
          'size': '10',
          'sort': 'id,asc',
        });
        expect(request.headers['Accept'], 'application/json');
        expect(
          request.headers['Authorization'],
          'Bearer access-token-test-only',
        );
        expect(request.headers, isNot(contains('Content-Type')));
        return _jsonResponse(_validBody());
      });

      final result = await _repository(
        client,
      ).fetchSpaces(accessToken: ' access-token-test-only ');

      expect(result.content, hasLength(2));
      expect(result.content.first.name, 'Residência do Casal Laet');
      expect(result.content.last.spaceUserRole, isNull);
      expect(result.totalElements, 2);
    });

    test('envia nome, papel e situação nos parâmetros esperados', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/spaces');
        expect(request.url.queryParameters, <String, String>{
          'page': '2',
          'size': '25',
          'sort': 'id,asc',
          'name': 'Residência do Casal',
          'spaceUserRole': 'ROLE_SPACE_MANAGER',
          'spaceMembershipStatus': 'APPROVED',
        });
        final body = _validBody();
        final page = body['page']! as Map<String, dynamic>;
        page['number'] = 2;
        page['totalPages'] = 3;
        return _jsonResponse(body);
      });

      await _repository(client).fetchSpaces(
        accessToken: 'access-token-test-only',
        filters: const SpaceFilters(
          name: '  Residência do Casal  ',
          role: SpaceUserRole.manager,
          status: SpaceMembershipStatus.approved,
        ),
        page: 2,
        size: 25,
      );
    });

    test(
      'omite filtros ausentes e nome em branco, preservando paginação',
      () async {
        final client = MockClient((request) async {
          expect(request.url.queryParameters, <String, String>{
            'page': '0',
            'size': '10',
            'sort': 'id,asc',
          });
          return _jsonResponse(_validBody());
        });

        await _repository(client).fetchSpaces(
          accessToken: 'access-token-test-only',
          filters: const SpaceFilters(name: '   '),
        );
      },
    );

    test('não faz GET com paginação inválida', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return _jsonResponse(_validBody());
        }),
      );

      for (final pagination in <(int, int)>[(-1, 10), (0, 0), (0, -1)]) {
        await expectLater(
          repository.fetchSpaces(
            accessToken: 'access-token-test-only',
            page: pagination.$1,
            size: pagination.$2,
          ),
          throwsA(
            isA<ApiFailure>().having(
              (failure) => failure.kind,
              'kind',
              ApiFailureKind.validation,
            ),
          ),
        );
      }
      expect(calls, 0);
    });

    test('não faz requisição quando o token está vazio', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return _jsonResponse(_validBody());
        }),
      );

      await expectLater(
        repository.fetchSpaces(accessToken: '   '),
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

    test('mapeia 401 para unauthorized', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('credential details', 401)),
      );

      await expectLater(
        repository.fetchSpaces(accessToken: 'access-token-test-only'),
        throwsA(
          isA<ApiFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                ApiFailureKind.unauthorized,
              )
              .having((failure) => failure.statusCode, 'statusCode', 401),
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
        repository.fetchSpaces(accessToken: 'access-token-test-only'),
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

    test('mapeia erro 5xx para server', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('{}', 503)),
      );

      await expectLater(
        repository.fetchSpaces(accessToken: 'access-token-test-only'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.server,
          ),
        ),
      );
    });

    test('mapeia JSON incompatível para malformedResponse', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('{"content":[]}', 200)),
      );

      await expectLater(
        repository.fetchSpaces(accessToken: 'access-token-test-only'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.malformedResponse,
          ),
        ),
      );
    });

    test('rejeita número de página diferente do solicitado', () async {
      final body = _validBody();
      final page = body['page']! as Map<String, dynamic>;
      page['number'] = 1;
      final repository = _repository(
        MockClient((_) async => _jsonResponse(body)),
      );

      await expectLater(
        repository.fetchSpaces(accessToken: 'access-token-test-only', page: 0),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.malformedResponse,
          ),
        ),
      );
    });

    test('mapeia falha do cliente para network', () async {
      final repository = _repository(
        MockClient((request) async {
          throw http.ClientException('Falha simulada.', request.url);
        }),
      );

      await expectLater(
        repository.fetchSpaces(accessToken: 'access-token-test-only'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.network,
          ),
        ),
      );
    });

    test('mapeia timeout sem repetir a requisição', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _jsonResponse(_validBody());
        }),
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.fetchSpaces(accessToken: 'access-token-test-only'),
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

HttpSpacesRepository _repository(
  http.Client client, {
  Duration timeout = const Duration(seconds: 15),
}) {
  return HttpSpacesRepository(
    client: client,
    config: AppConfig(apiBaseUrl: 'http://localhost:8080/api/'),
    timeout: timeout,
  );
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, dynamic> _validCreatedBody() {
  return <String, dynamic>{
    'id': 3,
    'name': 'Residência Açú',
    'spaceAdminName': 'Joice Laet',
    'active': false,
  };
}

Map<String, dynamic> _validBody() {
  return <String, dynamic>{
    'content': <dynamic>[
      <String, dynamic>{
        'id': 1,
        'name': 'Residência do Casal Laet',
        'spaceAdminName': 'Joice Laet',
        'active': true,
        'spaceUserRole': 'ROLE_SPACE_PARTICIPANT',
        'spaceMembershipStatus': 'APPROVED',
        'activeParticipationsCount': 4,
      },
      <String, dynamic>{
        'id': 2,
        'name': 'Residência do Marido da Bella',
        'spaceAdminName': 'Bella Laet',
        'active': true,
        'activeParticipationsCount': 2,
      },
    ],
    'page': <String, dynamic>{
      'size': 10,
      'number': 0,
      'totalElements': 2,
      'totalPages': 1,
    },
  };
}
