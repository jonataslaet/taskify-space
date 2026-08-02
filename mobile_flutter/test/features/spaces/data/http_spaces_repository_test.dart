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
    test('faz GET /spaces com Bearer e interpreta a resposta', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://10.0.2.2:8080/api/spaces');
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
          'name': 'Residência do Casal',
          'spaceUserRole': 'ROLE_SPACE_MANAGER',
          'spaceMembershipStatus': 'APPROVED',
        });
        return _jsonResponse(_validBody());
      });

      await _repository(client).fetchSpaces(
        accessToken: 'access-token-test-only',
        filters: const SpaceFilters(
          name: '  Residência do Casal  ',
          role: SpaceUserRole.manager,
          status: SpaceMembershipStatus.approved,
        ),
      );
    });

    test('omite filtros ausentes e nome em branco da query', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'http://10.0.2.2:8080/api/spaces');
        expect(request.url.hasQuery, isFalse);
        return _jsonResponse(_validBody());
      });

      await _repository(client).fetchSpaces(
        accessToken: 'access-token-test-only',
        filters: const SpaceFilters(name: '   '),
      );
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
    config: AppConfig(apiBaseUrl: 'http://10.0.2.2:8080/api/'),
    timeout: timeout,
  );
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
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
