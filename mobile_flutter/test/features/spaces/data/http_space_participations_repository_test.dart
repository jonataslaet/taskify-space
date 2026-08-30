import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/data/http_spaces_repository.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation_filters.dart';

void main() {
  group('HttpSpacesRepository.fetchSpaceParticipations', () {
    test('faz GET contextual com Bearer, sort e interpreta a página', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/spaces/7/participations');
        expect(request.url.queryParametersAll, <String, List<String>>{
          'page': <String>['0'],
          'size': <String>['10'],
          'sort': <String>['id,asc'],
        });
        expect(request.headers['Accept'], 'application/json');
        expect(
          request.headers['Authorization'],
          'Bearer access-token-test-only',
        );
        expect(request.headers, isNot(contains('Content-Type')));
        return _jsonResponse(_validPageBody());
      });

      final result = await _repository(client).fetchSpaceParticipations(
        accessToken: ' access-token-test-only ',
        spaceId: 7,
      );

      expect(result.content, hasLength(1));
      expect(result.content.single.id, 11);
      expect(result.content.single.name, 'Jônatas Laet');
      expect(result.content.single.spaceUserRole, SpaceUserRole.manager);
      expect(
        result.content.single.spaceMembershipStatus,
        SpaceMembershipStatus.pending,
      );
      expect(result.totalElements, 1);
    });

    test('envia usuário normalizado e statuses em CSV na ordem dos enums', () {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/spaces/42/participations');
        expect(request.url.queryParametersAll, <String, List<String>>{
          'page': <String>['2'],
          'size': <String>['25'],
          'sort': <String>['id,asc'],
          'username': <String>['Joice Laet'],
          'statuses': <String>['PENDING,APPROVED,DENIED'],
        });
        final body = _validPageBody();
        final page = body['page']! as Map<String, dynamic>;
        page['number'] = 2;
        page['totalPages'] = 3;
        return _jsonResponse(body);
      });

      return _repository(client).fetchSpaceParticipations(
        accessToken: 'access-token-test-only',
        spaceId: 42,
        filters: const SpaceParticipationFilters(
          username: '  Joice Laet  ',
          statuses: <SpaceMembershipStatus>{
            SpaceMembershipStatus.denied,
            SpaceMembershipStatus.approved,
            SpaceMembershipStatus.pending,
          },
        ),
        page: 2,
        size: 25,
      );
    });

    test('omite usuário em branco e statuses vazios', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParametersAll, <String, List<String>>{
          'page': <String>['0'],
          'size': <String>['10'],
          'sort': <String>['id,asc'],
        });
        return _jsonResponse(_validPageBody());
      });

      await _repository(client).fetchSpaceParticipations(
        accessToken: 'access-token-test-only',
        spaceId: 7,
        filters: const SpaceParticipationFilters(username: '   '),
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
          repository.fetchSpaceParticipations(accessToken: ' ', spaceId: 1),
          repository.fetchSpaceParticipations(accessToken: 'token', spaceId: 0),
          repository.fetchSpaceParticipations(
            accessToken: 'token',
            spaceId: -1,
          ),
          repository.fetchSpaceParticipations(
            accessToken: 'token',
            spaceId: 1,
            page: -1,
          ),
          repository.fetchSpaceParticipations(
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
        repository.fetchSpaceParticipations(
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
        repository.fetchSpaceParticipations(
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

    test('mapeia objeto superior incompatível para malformedResponse', () {
      final repository = _repository(
        MockClient((_) async => http.Response('[1, 2]', 200)),
      );

      return expectLater(
        repository.fetchSpaceParticipations(
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

    test('mapeia participação incompatível para malformedResponse', () {
      final body = _validPageBody()..['content'] = <dynamic>['user'];
      final repository = _repository(
        MockClient((_) async => _jsonResponse(body)),
      );

      return expectLater(
        repository.fetchSpaceParticipations(
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
      (404, ApiFailureKind.unknown),
      (503, ApiFailureKind.server),
    ]) {
      test('mapeia ${errorCase.$1} para ${errorCase.$2.name}', () async {
        final repository = _repository(
          MockClient((_) async => http.Response('{}', errorCase.$1)),
        );

        await expectLater(
          repository.fetchSpaceParticipations(
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
                )
                .having((failure) => failure.apiMessage, 'apiMessage', isNull),
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
        repository.fetchSpaceParticipations(
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
        repository.fetchSpaceParticipations(
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
        repository.fetchSpaceParticipations(
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

  group('HttpSpacesRepository.updateSpaceParticipation', () {
    test('faz PATCH com ambos os parâmetros e interpreta o vínculo', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/spaces/7/participations/11');
        expect(request.url.queryParameters, <String, String>{
          'status': 'APPROVED',
          'spaceUserRole': 'ROLE_SPACE_ADMIN',
        });
        expect(request.headers['Accept'], 'application/json');
        expect(
          request.headers['Authorization'],
          'Bearer access-token-test-only',
        );
        expect(request.headers, isNot(contains('Content-Type')));
        expect(request.body, isEmpty);
        return _jsonResponse(
          _validParticipationBody(
            spaceUserRole: 'ROLE_SPACE_ADMIN',
            spaceMembershipStatus: 'APPROVED',
          ),
        );
      });

      final participation = await _repository(client).updateSpaceParticipation(
        accessToken: ' access-token-test-only ',
        spaceId: 7,
        membershipId: 11,
        status: SpaceMembershipStatus.approved,
        spaceUserRole: SpaceUserRole.admin,
      );

      expect(participation.id, 11);
      expect(participation.name, 'Jônatas Laet');
      expect(participation.spaceUserRole, SpaceUserRole.admin);
      expect(
        participation.spaceMembershipStatus,
        SpaceMembershipStatus.approved,
      );
    });

    for (final updateCase
        in <
          (String, SpaceMembershipStatus?, SpaceUserRole?, Map<String, String>)
        >[
          (
            'somente status',
            SpaceMembershipStatus.suspended,
            null,
            <String, String>{'status': 'SUSPENDED'},
          ),
          (
            'somente papel',
            null,
            SpaceUserRole.participant,
            <String, String>{'spaceUserRole': 'ROLE_SPACE_PARTICIPANT'},
          ),
          ('nenhum parâmetro', null, null, const <String, String>{}),
        ]) {
      test('envia ${updateCase.$1} sem criar parâmetros extras', () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/spaces/2/participations/11');
          expect(request.url.queryParameters, updateCase.$4);
          expect(request.headers, isNot(contains('Content-Type')));
          expect(request.body, isEmpty);
          return _jsonResponse(_validParticipationBody());
        });

        await _repository(client).updateSpaceParticipation(
          accessToken: 'access-token-test-only',
          spaceId: 2,
          membershipId: 11,
          status: updateCase.$2,
          spaceUserRole: updateCase.$3,
        );
      });
    }

    test('rejeita token ou identificadores inválidos antes da rede', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return _jsonResponse(_validParticipationBody());
        }),
      );

      for (final request in <Future<Object?>>[
        repository.updateSpaceParticipation(
          accessToken: '   ',
          spaceId: 1,
          membershipId: 1,
        ),
        repository.updateSpaceParticipation(
          accessToken: 'token',
          spaceId: 0,
          membershipId: 1,
        ),
        repository.updateSpaceParticipation(
          accessToken: 'token',
          spaceId: -1,
          membershipId: 1,
        ),
        repository.updateSpaceParticipation(
          accessToken: 'token',
          spaceId: 1,
          membershipId: 0,
        ),
        repository.updateSpaceParticipation(
          accessToken: 'token',
          spaceId: 1,
          membershipId: -1,
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

    test('aceita somente 200 como sucesso', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('', 204)),
      );

      await expectLater(
        repository.updateSpaceParticipation(
          accessToken: 'access-token-test-only',
          spaceId: 1,
          membershipId: 11,
        ),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.unknown)
              .having((failure) => failure.statusCode, 'statusCode', 204),
        ),
      );
    });

    test('rejeita participação diferente da solicitada', () async {
      final repository = _repository(
        MockClient((_) async => _jsonResponse(_validParticipationBody(id: 12))),
      );

      await expectLater(
        repository.updateSpaceParticipation(
          accessToken: 'access-token-test-only',
          spaceId: 1,
          membershipId: 11,
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

    for (final malformedResponse in <http.Response>[
      http.Response('[1, 2]', 200),
      _jsonResponse(<String, dynamic>{
        ..._validParticipationBody(),
        'spaceMembershipStatus': 'UNKNOWN',
      }),
    ]) {
      test('mapeia resposta incompatível para malformedResponse', () async {
        final repository = _repository(
          MockClient((_) async => malformedResponse),
        );

        await expectLater(
          repository.updateSpaceParticipation(
            accessToken: 'access-token-test-only',
            spaceId: 1,
            membershipId: 11,
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
    }

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
          repository.updateSpaceParticipation(
            accessToken: 'access-token-test-only',
            spaceId: 1,
            membershipId: 11,
          ),
          throwsA(
            isA<ApiFailure>()
                .having((failure) => failure.kind, 'kind', errorCase.$2)
                .having(
                  (failure) => failure.statusCode,
                  'statusCode',
                  errorCase.$1,
                )
                .having((failure) => failure.apiMessage, 'apiMessage', isNull),
          ),
        );
      });
    }

    test('preserva a mensagem da API no 403', () async {
      final repository = _repository(
        MockClient(
          (_) async => _jsonResponse(<String, dynamic>{
            'message':
                '  O espaço precisa manter pelo menos um administrador aprovado.  ',
          }, statusCode: 403),
        ),
      );

      await expectLater(
        repository.updateSpaceParticipation(
          accessToken: 'access-token-test-only',
          spaceId: 1,
          membershipId: 11,
        ),
        throwsA(
          isA<ApiFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                ApiFailureKind.forbidden,
              )
              .having(
                (failure) => failure.apiMessage,
                'apiMessage',
                'O espaço precisa manter pelo menos um administrador aprovado.',
              ),
        ),
      );
    });

    for (final invalidMessageCase in <(String, http.Response)>[
      ('corpo não JSON', http.Response('not-json', 403)),
      (
        'mensagem não textual',
        _jsonResponse(<String, dynamic>{'message': 42}, statusCode: 403),
      ),
      (
        'mensagem vazia',
        _jsonResponse(<String, dynamic>{'message': '   '}, statusCode: 403),
      ),
    ]) {
      test('ignora ${invalidMessageCase.$1} sem mascarar o 403', () async {
        final repository = _repository(
          MockClient((_) async => invalidMessageCase.$2),
        );

        await expectLater(
          repository.updateSpaceParticipation(
            accessToken: 'access-token-test-only',
            spaceId: 1,
            membershipId: 11,
          ),
          throwsA(
            isA<ApiFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  ApiFailureKind.forbidden,
                )
                .having((failure) => failure.statusCode, 'statusCode', 403)
                .having((failure) => failure.apiMessage, 'apiMessage', isNull),
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
        repository.updateSpaceParticipation(
          accessToken: 'access-token-test-only',
          spaceId: 1,
          membershipId: 11,
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
        repository.updateSpaceParticipation(
          accessToken: 'access-token-test-only',
          spaceId: 1,
          membershipId: 11,
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

    test('mapeia timeout sem repetir o PATCH', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _jsonResponse(_validParticipationBody());
        }),
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.updateSpaceParticipation(
          accessToken: 'access-token-test-only',
          spaceId: 1,
          membershipId: 11,
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

Map<String, dynamic> _validParticipationBody({
  int id = 11,
  String spaceUserRole = 'ROLE_SPACE_MANAGER',
  String spaceMembershipStatus = 'PENDING',
}) {
  return <String, dynamic>{
    'id': id,
    'name': 'Jônatas Laet',
    'spaceUserRole': spaceUserRole,
    'spaceMembershipStatus': spaceMembershipStatus,
  };
}

Map<String, dynamic> _validPageBody() {
  return <String, dynamic>{
    'content': <dynamic>[
      <String, dynamic>{
        'id': 11,
        'name': 'Jônatas Laet',
        'spaceUserRole': 'ROLE_SPACE_MANAGER',
        'spaceMembershipStatus': 'PENDING',
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
