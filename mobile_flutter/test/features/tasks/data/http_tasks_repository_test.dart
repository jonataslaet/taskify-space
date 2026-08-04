import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/data/http_tasks_repository.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';

void main() {
  group('HttpTasksRepository', () {
    test(
      'faz GET /tasks paginado com Bearer e interpreta a resposta',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/tasks');
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
          return _jsonResponse(_validPageBody());
        });

        final result = await _repository(
          client,
        ).fetchTasks(accessToken: ' access-token-test-only ');

        expect(result.content, hasLength(1));
        expect(result.content.single.description, 'Trocar o botijão');
        expect(result.totalElements, 1);
      },
    );

    test('envia todos os filtros da TaskSpecification', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters, <String, String>{
          'page': '2',
          'size': '25',
          'sort': 'id,asc',
          'spaceId': '7',
          'description': 'Conta de água',
          'score': '12.5',
          'active': 'false',
          'categories': 'OPERATIONAL,FINANCIAL',
          'minScore': '1',
          'maxScore': '100.25',
        });
        return _jsonResponse(_validPageBody());
      });

      await _repository(client).fetchTasks(
        accessToken: 'access-token-test-only',
        filters: const TaskFilters(
          spaceId: 7,
          description: '  Conta de água  ',
          score: 12.5,
          active: false,
          categories: <TaskCategory>{
            TaskCategory.financial,
            TaskCategory.operational,
          },
          minScore: 1,
          maxScore: 100.25,
        ),
        page: 2,
        size: 25,
      );
    });

    test('omite filtros opcionais vazios', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters, <String, String>{
          'page': '0',
          'size': '10',
          'sort': 'id,asc',
        });
        return _jsonResponse(_validPageBody());
      });

      await _repository(client).fetchTasks(
        accessToken: 'access-token-test-only',
        filters: const TaskFilters(description: '   '),
      );
    });

    test('faz PUT com Bearer e preserva a agenda usando frequence', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/tasks/42');
        expect(request.url.query, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(
          request.headers['Authorization'],
          'Bearer access-token-test-only',
        );
        expect(
          request.headers['Content-Type'],
          'application/json; charset=utf-8',
        );
        expect(jsonDecode(request.body), <String, dynamic>{
          'description': 'Pagar conta de água',
          'score': 25.5,
          'category': 'FINANCIAL',
          'schedule': <String, dynamic>{
            'localDates': <String>['2026-08-04', '2026-08-11'],
            'frequence': 'WEEKLY',
          },
        });

        return _jsonResponse(<String, dynamic>{
          ..._validTaskBody(),
          'id': 42,
          'description': 'Pagar conta de água',
          'score': 25.5,
          'category': 'FINANCIAL',
          'schedule': <String, dynamic>{
            'localDates': <String>['2026-08-04', '2026-08-11'],
            'frequence': 'WEEKLY',
          },
        });
      });

      final result = await _repository(client).updateTask(
        accessToken: ' access-token-test-only ',
        taskId: 42,
        update: TaskUpdate(
          description: '  Pagar conta de água  ',
          score: 25.5,
          category: TaskCategory.financial,
          schedule: TaskScheduleSummary(
            localDates: <DateTime>[
              DateTime.utc(2026, 8, 4),
              DateTime.utc(2026, 8, 11),
            ],
            frequency: TaskFrequency.weekly,
          ),
        ),
      );

      expect(result.id, 42);
      expect(result.description, 'Pagar conta de água');
      expect(result.schedule?.frequency, TaskFrequency.weekly);
      expect(result.schedule?.localDates, <DateTime>[
        DateTime.utc(2026, 8, 4),
        DateTime.utc(2026, 8, 11),
      ]);
    });

    test('envia schedule nulo explicitamente para remover a agenda', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, <String>{
          'description',
          'score',
          'category',
          'schedule',
        });
        expect(body['schedule'], isNull);

        final responseBody = _validTaskBody()..remove('schedule');
        return _jsonResponse(responseBody);
      });

      final result = await _repository(client).updateTask(
        accessToken: 'access-token-test-only',
        taskId: 1,
        update: const TaskUpdate(
          description: 'Trocar o botijão',
          score: 90.5,
          category: TaskCategory.operational,
          schedule: null,
        ),
      );

      expect(result.schedule, isNull);
    });

    test('rejeita update inválido antes de acessar a rede', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return _jsonResponse(_validTaskBody());
        }),
      );
      final validUpdate = TaskUpdate(
        description: 'Tarefa válida',
        score: 10,
        category: TaskCategory.operational,
        schedule: TaskScheduleSummary(
          localDates: <DateTime>[DateTime.utc(2026, 8, 4)],
          frequency: TaskFrequency.once,
        ),
      );
      final requests = <Future<Object?>>[
        repository.updateTask(accessToken: ' ', taskId: 1, update: validUpdate),
        repository.updateTask(
          accessToken: 'token',
          taskId: 0,
          update: validUpdate,
        ),
        repository.updateTask(
          accessToken: 'token',
          taskId: 1,
          update: const TaskUpdate(
            description: ' ',
            score: 10,
            category: TaskCategory.operational,
            schedule: null,
          ),
        ),
        repository.updateTask(
          accessToken: 'token',
          taskId: 1,
          update: const TaskUpdate(
            description: 'Tarefa',
            score: 10.123,
            category: TaskCategory.operational,
            schedule: null,
          ),
        ),
        repository.updateTask(
          accessToken: 'token',
          taskId: 1,
          update: TaskUpdate(
            description: 'Tarefa',
            score: 10,
            category: TaskCategory.operational,
            schedule: TaskScheduleSummary(
              localDates: const <DateTime>[],
              frequency: TaskFrequency.daily,
            ),
          ),
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

    test('mapeia conflito 409 do update para validation', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('{}', 409)),
      );

      await expectLater(
        repository.updateTask(
          accessToken: 'access-token-test-only',
          taskId: 1,
          update: const TaskUpdate(
            description: 'Tarefa duplicada',
            score: 10,
            category: TaskCategory.operational,
            schedule: null,
          ),
        ),
        throwsA(
          isA<ApiFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                ApiFailureKind.validation,
              )
              .having((failure) => failure.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('rejeita resposta do PUT com id diferente do solicitado', () async {
      final repository = _repository(
        MockClient((_) async => _jsonResponse(_validTaskBody())),
      );

      await expectLater(
        repository.updateTask(
          accessToken: 'access-token-test-only',
          taskId: 42,
          update: const TaskUpdate(
            description: 'Tarefa',
            score: 10,
            category: TaskCategory.operational,
            schedule: null,
          ),
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

    test(
      'rejeita token, paginação, spaceId e scores inválidos sem rede',
      () async {
        var calls = 0;
        final repository = _repository(
          MockClient((_) async {
            calls += 1;
            return _jsonResponse(_validPageBody());
          }),
        );
        final requests = <Future<Object?>>[
          repository.fetchTasks(accessToken: '   '),
          repository.fetchTasks(accessToken: 'token', page: -1),
          repository.fetchTasks(accessToken: 'token', size: 0),
          repository.fetchTasks(
            accessToken: 'token',
            filters: const TaskFilters(spaceId: 0),
          ),
          repository.fetchTasks(
            accessToken: 'token',
            filters: const TaskFilters(score: double.nan),
          ),
          repository.fetchTasks(
            accessToken: 'token',
            filters: const TaskFilters(maxScore: double.infinity),
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
      },
    );

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
          repository.fetchTasks(accessToken: 'access-token-test-only'),
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
        repository.fetchTasks(accessToken: 'access-token-test-only'),
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

    test('mapeia JSON incompatível para malformedResponse', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('{"content":[]}', 200)),
      );

      await expectLater(
        repository.fetchTasks(accessToken: 'access-token-test-only'),
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
        repository.fetchTasks(accessToken: 'access-token-test-only'),
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
        repository.fetchTasks(accessToken: 'access-token-test-only'),
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

HttpTasksRepository _repository(
  http.Client client, {
  Duration timeout = const Duration(seconds: 15),
}) {
  return HttpTasksRepository(
    client: client,
    config: AppConfig(apiBaseUrl: 'http://localhost:8080/api/'),
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

Map<String, dynamic> _validPageBody() {
  return <String, dynamic>{
    'content': <dynamic>[_validTaskBody()],
    'page': <String, dynamic>{
      'size': 10,
      'number': 0,
      'totalElements': 1,
      'totalPages': 1,
    },
  };
}

Map<String, dynamic> _validTaskBody() {
  return <String, dynamic>{
    'id': 1,
    'spaceId': 7,
    'description': 'Trocar o botijão',
    'score': 90.5,
    'category': 'OPERATIONAL',
    'schedule': <String, dynamic>{
      'localDates': <String>['2026-08-02'],
      'frequence': 'WEEKLY',
    },
    'active': true,
    'creatorName': 'Joice Laet',
  };
}
