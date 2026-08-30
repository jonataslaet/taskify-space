import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/data/http_spaces_repository.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

void main() {
  group('HttpSpacesRepository.fetchSpaceParticipants', () {
    test('faz GET contextual com Bearer e interpreta a página', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/spaces/7/participants');
        expect(request.url.queryParametersAll, <String, List<String>>{
          'page': <String>['0'],
          'size': <String>['10'],
        });
        expect(request.headers['Accept'], 'application/json');
        expect(
          request.headers['Authorization'],
          'Bearer access-token-test-only',
        );
        expect(request.headers, isNot(contains('Content-Type')));
        return _jsonResponse(_validPageBody());
      });

      final result = await _repository(client).fetchSpaceParticipants(
        accessToken: ' access-token-test-only ',
        spaceId: 7,
      );

      expect(result.content, hasLength(1));
      expect(result.content.single.name, 'Joice Laet');
      expect(result.content.single.contributionPercentual, 0.625);
      expect(result.totalElements, 1);
    });

    test('envia filtros, categorias repetidas e ordenação segura', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/spaces/42/participants');
        expect(request.url.queryParametersAll, <String, List<String>>{
          'page': <String>['2'],
          'size': <String>['25'],
          'name': <String>['Joice Laet'],
          'spaceUserRole': <String>['ROLE_SPACE_MANAGER'],
          'taskCategories': <String>['OPERATIONAL', 'FINANCIAL'],
          'sort': <String>['score,desc'],
        });
        final body = _validPageBody();
        final page = body['page']! as Map<String, dynamic>;
        page['number'] = 2;
        page['totalPages'] = 3;
        return _jsonResponse(body);
      });

      await _repository(client).fetchSpaceParticipants(
        accessToken: 'access-token-test-only',
        spaceId: 42,
        filters: const SpaceParticipantFilters(
          name: '  Joice Laet  ',
          role: SpaceUserRole.manager,
          taskCategories: <TaskCategory>{
            TaskCategory.financial,
            TaskCategory.operational,
          },
          sort: ParticipantSort.scoreDescending,
        ),
        page: 2,
        size: 25,
      );
    });

    test('omite nome em branco, categorias vazias e sort ausente', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParametersAll, <String, List<String>>{
          'page': <String>['0'],
          'size': <String>['10'],
        });
        return _jsonResponse(_validPageBody());
      });

      await _repository(client).fetchSpaceParticipants(
        accessToken: 'access-token-test-only',
        spaceId: 7,
        filters: const SpaceParticipantFilters(name: '   '),
      );
    });

    test(
      'rejeita token, spaceId ou paginação inválidos antes da rede',
      () async {
        var calls = 0;
        final repository = _repository(
          MockClient((_) async {
            calls += 1;
            return _jsonResponse(_validPageBody());
          }),
        );

        for (final request in <Future<Object?>>[
          repository.fetchSpaceParticipants(accessToken: ' ', spaceId: 1),
          repository.fetchSpaceParticipants(accessToken: 'token', spaceId: 0),
          repository.fetchSpaceParticipants(accessToken: 'token', spaceId: -1),
          repository.fetchSpaceParticipants(
            accessToken: 'token',
            spaceId: 1,
            page: -1,
          ),
          repository.fetchSpaceParticipants(
            accessToken: 'token',
            spaceId: 1,
            size: 0,
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
      },
    );

    test('aceita somente 200 como sucesso', () async {
      final repository = _repository(
        MockClient(
          (_) async => _jsonResponse(_validPageBody(), statusCode: 201),
        ),
      );

      await expectLater(
        repository.fetchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 1,
        ),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.unknown)
              .having((failure) => failure.statusCode, 'statusCode', 201),
        ),
      );
    });

    test('rejeita página diferente da solicitada', () async {
      final body = _validPageBody();
      (body['page'] as Map<String, dynamic>)['number'] = 1;
      final repository = _repository(
        MockClient((_) async => _jsonResponse(body)),
      );

      await expectLater(
        repository.fetchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 1,
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

    test('mapeia resposta incompatível para malformedResponse', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('[1, 2]', 200)),
      );

      await expectLater(
        repository.fetchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 1,
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

    for (final errorCase in <(int, ApiFailureKind)>[
      (400, ApiFailureKind.validation),
      (401, ApiFailureKind.unauthorized),
      (403, ApiFailureKind.forbidden),
      (503, ApiFailureKind.server),
    ]) {
      test('mapeia ${errorCase.$1} para ${errorCase.$2.name}', () async {
        final repository = _repository(
          MockClient((_) async => http.Response('{}', errorCase.$1)),
        );

        await expectLater(
          repository.fetchSpaceParticipants(
            accessToken: 'access-token-test-only',
            spaceId: 1,
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
          (_) async =>
              http.Response('{}', 429, headers: const {'Retry-After': '12'}),
        ),
      );

      await expectLater(
        repository.fetchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 1,
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
        repository.fetchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 1,
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

    test('mapeia timeout sem repetir a requisição', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _jsonResponse(_validPageBody());
        }),
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.fetchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 1,
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

  group('HttpSpacesRepository.searchSpaceParticipants', () {
    test('faz GET por nome com Bearer e interpreta a lista', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/spaces/7/participants/search');
        expect(request.url.queryParameters, <String, String>{
          'name': 'Joice Laet',
        });
        expect(request.headers['Accept'], 'application/json');
        expect(
          request.headers['Authorization'],
          'Bearer access-token-test-only',
        );
        expect(request.headers, isNot(contains('Content-Type')));
        return _jsonListResponse(<dynamic>[
          <String, dynamic>{'id': 2, 'name': 'Joice Laet'},
          <String, dynamic>{'id': 3, 'name': 'Jônatas Laet'},
        ]);
      });

      final result = await _repository(client).searchSpaceParticipants(
        accessToken: ' access-token-test-only ',
        spaceId: 7,
        name: '  Joice Laet  ',
      );

      expect(result, hasLength(2));
      expect(result.first.id, 2);
      expect(result.first.name, 'Joice Laet');
      expect(result.last.name, 'Jônatas Laet');
      expect(() => result.clear(), throwsUnsupportedError);
    });

    test('aceita uma lista vazia', () async {
      final repository = _repository(
        MockClient((_) async => _jsonListResponse(const <dynamic>[])),
      );

      final result = await repository.searchSpaceParticipants(
        accessToken: 'access-token-test-only',
        spaceId: 7,
        name: 'Inexistente',
      );

      expect(result, isEmpty);
    });

    test('rejeita token, spaceId ou nome inválidos antes da rede', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return _jsonListResponse(const <dynamic>[]);
        }),
      );
      final requests = <Future<Object?>>[
        repository.searchSpaceParticipants(
          accessToken: '   ',
          spaceId: 7,
          name: 'Joice',
        ),
        repository.searchSpaceParticipants(
          accessToken: 'token',
          spaceId: 0,
          name: 'Joice',
        ),
        repository.searchSpaceParticipants(
          accessToken: 'token',
          spaceId: -1,
          name: 'Joice',
        ),
        repository.searchSpaceParticipants(
          accessToken: 'token',
          spaceId: 7,
          name: '   ',
        ),
      ];

      for (final request in requests) {
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

    test('aceita somente 200 como sucesso', () async {
      final repository = _repository(
        MockClient(
          (_) async => _jsonListResponse(const <dynamic>[], statusCode: 201),
        ),
      );

      await expectLater(
        repository.searchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          name: 'Joice',
        ),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.unknown)
              .having((failure) => failure.statusCode, 'statusCode', 201),
        ),
      );
    });

    test('mapeia resposta incompatível para malformedResponse', () async {
      final repository = _repository(
        MockClient((_) async => _jsonResponse(_validPageBody())),
      );

      await expectLater(
        repository.searchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          name: 'Joice',
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

    test('mapeia item incompatível para malformedResponse', () async {
      final repository = _repository(
        MockClient(
          (_) async => _jsonListResponse(<dynamic>[
            <String, dynamic>{'id': 1, 'name': '   '},
          ]),
        ),
      );

      await expectLater(
        repository.searchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          name: 'Joice',
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

    for (final errorCase in <(int, ApiFailureKind)>[
      (400, ApiFailureKind.validation),
      (401, ApiFailureKind.unauthorized),
      (403, ApiFailureKind.forbidden),
      (404, ApiFailureKind.unknown),
      (503, ApiFailureKind.server),
    ]) {
      test('mapeia ${errorCase.$1} para ${errorCase.$2.name}', () async {
        final repository = _repository(
          MockClient((_) async => http.Response('{}', errorCase.$1)),
        );

        await expectLater(
          repository.searchSpaceParticipants(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            name: 'Joice',
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
        repository.searchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          name: 'Joice',
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
        repository.searchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          name: 'Joice',
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

    test('mapeia timeout sem repetir a requisição', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _jsonListResponse(const <dynamic>[]);
        }),
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.searchSpaceParticipants(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          name: 'Joice',
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

http.Response _jsonListResponse(List<dynamic> body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}

Map<String, dynamic> _validPageBody() {
  return <String, dynamic>{
    'content': <dynamic>[
      <String, dynamic>{
        'id': 1,
        'name': 'Joice Laet',
        'spaceUserRole': 'ROLE_SPACE_ADMIN',
        'taskCategories': <dynamic>['OPERATIONAL', 'FINANCIAL'],
        'score': 105.5,
        'contributionPercentual': 0.625,
      },
    ],
    'page': <String, dynamic>{
      'size': 10,
      'number': 0,
      'totalElements': 1,
      'totalPages': 1,
    },
  };
}
