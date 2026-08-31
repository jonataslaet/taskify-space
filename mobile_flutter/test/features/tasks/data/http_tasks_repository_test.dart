import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/data/http_tasks_repository.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';

void main() {
  group('HttpTasksRepository', () {
    test(
      'faz GET /spaces/{spaceId}/tasks paginado com Bearer e interpreta a resposta',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/spaces/7/tasks');
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
        ).fetchTasks(accessToken: ' access-token-test-only ', spaceId: 7);

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
        spaceId: 7,
        filters: const TaskFilters(
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
        spaceId: 7,
        filters: const TaskFilters(description: '   '),
      );
    });

    test('faz POST /spaces/{spaceId}/tasks com payload completo', () async {
      late http.Request receivedRequest;
      final client = MockClient((request) async {
        receivedRequest = request;

        return _jsonResponse(<String, dynamic>{
          ..._validTaskBody(),
          'id': 9,
          'spaceId': 1,
          'description': 'Pagar conta de água',
          'score': 80.0,
          'category': 'FINANCIAL',
          'active': true,
          'creatorName': 'Joice Laet',
          'schedule': <String, dynamic>{
            'localDates': <String>['2024-02-29', '2024-02-28', '2024-02-27'],
            'frequence': 'WEEKLY',
          },
        }, statusCode: 201);
      });

      final result = await _repository(client).createTask(
        accessToken: ' access-token-test-only ',
        spaceId: 1,
        creation: TaskCreation(
          spaceId: 1,
          description: 'Pagar conta de água',
          score: 80.0,
          category: TaskCategory.financial,
          active: true,
          creatorName: 'Joice Laet',
          schedule: TaskScheduleSummary(
            localDates: <DateTime>[
              DateTime.utc(2024, 2, 29),
              DateTime.utc(2024, 2, 28),
              DateTime.utc(2024, 2, 27),
            ],
            frequency: TaskFrequency.weekly,
          ),
        ),
      );

      expect(receivedRequest.method, 'POST');
      expect(
        receivedRequest.url.toString(),
        'http://localhost:8080/api/spaces/1/tasks',
      );
      expect(receivedRequest.url.query, isEmpty);
      expect(receivedRequest.headers['Accept'], 'application/json');
      expect(
        receivedRequest.headers['Authorization'],
        'Bearer access-token-test-only',
      );
      expect(
        receivedRequest.headers['Content-Type'],
        'application/json; charset=utf-8',
      );
      expect(
        jsonDecode(utf8.decode(receivedRequest.bodyBytes)),
        <String, dynamic>{
          'spaceId': 1,
          'description': 'Pagar conta de água',
          'score': 80.0,
          'category': 'FINANCIAL',
          'active': true,
          'creatorName': 'Joice Laet',
          'schedule': <String, dynamic>{
            'localDates': <String>['2024-02-29', '2024-02-28', '2024-02-27'],
            'frequence': 'WEEKLY',
          },
        },
      );
      expect(result.id, 9);
      expect(result.spaceId, 1);
      expect(result.description, 'Pagar conta de água');
      expect(result.active, isTrue);
      expect(result.creatorName, 'Joice Laet');
      expect(result.schedule?.frequency, TaskFrequency.weekly);
    });

    test('aceita POST com agenda diária sem datas', () async {
      late http.Request receivedRequest;
      final client = MockClient((request) async {
        receivedRequest = request;
        return _jsonResponse(<String, dynamic>{
          ..._validTaskBody(),
          'schedule': <String, dynamic>{
            'localDates': <String>[],
            'frequence': 'DAILY',
          },
        }, statusCode: 201);
      });

      final result = await _repository(client).createTask(
        accessToken: 'access-token-test-only',
        spaceId: 7,
        creation: _validCreation(
          schedule: TaskScheduleSummary(
            localDates: const <DateTime>[],
            frequency: TaskFrequency.daily,
          ),
        ),
      );

      expect(receivedRequest.method, 'POST');
      expect(receivedRequest.url.path, '/api/spaces/7/tasks');
      expect(
        jsonDecode(utf8.decode(receivedRequest.bodyBytes)),
        <String, dynamic>{
          'spaceId': 7,
          'description': 'Trocar o botijão',
          'score': 90.5,
          'category': 'OPERATIONAL',
          'active': true,
          'creatorName': 'Joice Laet',
          'schedule': <String, dynamic>{
            'localDates': <String>[],
            'frequence': 'DAILY',
          },
        },
      );
      expect(result.schedule?.frequency, TaskFrequency.daily);
      expect(result.schedule?.localDates, isEmpty);
    });

    test('envia schedule nulo quando a tarefa não possui agenda', () async {
      late http.Request receivedRequest;
      final client = MockClient((request) async {
        receivedRequest = request;

        final responseBody = _validTaskBody()..remove('schedule');
        return _jsonResponse(responseBody, statusCode: 201);
      });

      final result = await _repository(client).createTask(
        accessToken: 'access-token-test-only',
        spaceId: 7,
        creation: const TaskCreation(
          spaceId: 7,
          description: 'Trocar o botijão',
          score: 90.5,
          category: TaskCategory.operational,
          schedule: null,
          active: true,
          creatorName: 'Joice Laet',
        ),
      );

      expect(receivedRequest.method, 'POST');
      expect(receivedRequest.url.path, '/api/spaces/7/tasks');
      expect(
        jsonDecode(utf8.decode(receivedRequest.bodyBytes)),
        <String, dynamic>{
          'spaceId': 7,
          'description': 'Trocar o botijão',
          'score': 90.5,
          'category': 'OPERATIONAL',
          'active': true,
          'creatorName': 'Joice Laet',
          'schedule': null,
        },
      );
      expect(result.schedule, isNull);
    });

    test('exige status 201 na criação', () async {
      final repository = _repository(
        MockClient((_) async => _jsonResponse(_validTaskBody())),
      );

      await expectLater(
        repository.createTask(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          creation: const TaskCreation(
            spaceId: 7,
            description: 'Trocar o botijão',
            score: 90.5,
            category: TaskCategory.operational,
            schedule: null,
            active: true,
            creatorName: 'Joice Laet',
          ),
        ),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.unknown)
              .having((failure) => failure.statusCode, 'statusCode', 200),
        ),
      );
    });

    test('rejeita criação ou espaço inválido antes da rede', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return _jsonResponse(_validTaskBody(), statusCode: 201);
        }),
      );
      final requests = <Future<Object?>>[
        repository.createTask(
          accessToken: '   ',
          spaceId: 7,
          creation: _validCreation(),
        ),
        repository.createTask(
          accessToken: 'token',
          spaceId: 0,
          creation: _validCreation(),
        ),
        repository.createTask(
          accessToken: 'token',
          spaceId: -1,
          creation: _validCreation(),
        ),
        repository.createTask(
          accessToken: 'token',
          spaceId: 7,
          creation: _validCreation(spaceId: 0),
        ),
        repository.createTask(
          accessToken: 'token',
          spaceId: 8,
          creation: _validCreation(spaceId: 7),
        ),
        repository.createTask(
          accessToken: 'token',
          spaceId: 7,
          creation: _validCreation(description: '   '),
        ),
        repository.createTask(
          accessToken: 'token',
          spaceId: 7,
          creation: _validCreation(score: 0),
        ),
        repository.createTask(
          accessToken: 'token',
          spaceId: 7,
          creation: _validCreation(creatorName: '   '),
        ),
        repository.createTask(
          accessToken: 'token',
          spaceId: 7,
          creation: _validCreation(
            schedule: TaskScheduleSummary(
              localDates: const [],
              frequency: TaskFrequency.weekly,
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

    test('rejeita criação retornada para outro espaço', () async {
      final repository = _repository(
        MockClient(
          (_) async => _jsonResponse(<String, dynamic>{
            ..._validTaskBody(),
            'spaceId': 8,
          }, statusCode: 201),
        ),
      );

      await expectLater(
        repository.createTask(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          creation: _validCreation(),
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

    test('mapeia conflito 409 da criação para validation', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('{}', 409)),
      );

      await expectLater(
        repository.createTask(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          creation: _validCreation(),
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

    test('faz PATCH da tarefa com Bearer e sem body', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(
          request.url.toString(),
          'http://localhost:8080/api/spaces/7/tasks/42',
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

      await _repository(client).toggleTaskActive(
        accessToken: ' access-token-test-only ',
        spaceId: 7,
        taskId: 42,
      );
    });

    test('rejeita PATCH inválido antes da rede', () async {
      var calls = 0;
      final repository = _repository(
        MockClient((_) async {
          calls += 1;
          return http.Response('', 204);
        }),
      );

      for (final request in <Future<void>>[
        repository.toggleTaskActive(accessToken: '   ', spaceId: 7, taskId: 1),
        repository.toggleTaskActive(
          accessToken: 'token',
          spaceId: 0,
          taskId: 1,
        ),
        repository.toggleTaskActive(
          accessToken: 'token',
          spaceId: -1,
          taskId: 1,
        ),
        repository.toggleTaskActive(
          accessToken: 'token',
          spaceId: 7,
          taskId: 0,
        ),
        repository.toggleTaskActive(
          accessToken: 'token',
          spaceId: 7,
          taskId: -1,
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

    test('aceita somente 204 como sucesso do PATCH', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('', 200)),
      );

      await expectLater(
        repository.toggleTaskActive(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          taskId: 1,
        ),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.unknown)
              .having((failure) => failure.statusCode, 'statusCode', 200),
        ),
      );
    });

    for (final errorCase in <(int, ApiFailureKind)>[
      (401, ApiFailureKind.unauthorized),
      (403, ApiFailureKind.forbidden),
      (404, ApiFailureKind.unknown),
      (503, ApiFailureKind.server),
    ]) {
      test(
        'mapeia ${errorCase.$1} do PATCH para ${errorCase.$2.name}',
        () async {
          final repository = _repository(
            MockClient((_) async => http.Response('{}', errorCase.$1)),
          );

          await expectLater(
            repository.toggleTaskActive(
              accessToken: 'access-token-test-only',
              spaceId: 7,
              taskId: 1,
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
        },
      );
    }

    test('mapeia falha do cliente no PATCH para network', () async {
      final repository = _repository(
        MockClient((request) async {
          throw http.ClientException('Falha simulada.', request.url);
        }),
      );

      await expectLater(
        repository.toggleTaskActive(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          taskId: 1,
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

    test('mapeia timeout do PATCH sem repetir a requisição', () async {
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
        repository.toggleTaskActive(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          taskId: 1,
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

    test('faz PUT com Bearer e preserva a agenda usando frequence', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/spaces/7/tasks/42');
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
        spaceId: 7,
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

    test('aceita PUT com agenda diária sem datas', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/spaces/7/tasks/1');
        expect(jsonDecode(request.body), <String, dynamic>{
          'description': 'Trocar o botijão',
          'score': 90.5,
          'category': 'OPERATIONAL',
          'schedule': <String, dynamic>{
            'localDates': <String>[],
            'frequence': 'DAILY',
          },
        });

        return _jsonResponse(<String, dynamic>{
          ..._validTaskBody(),
          'schedule': <String, dynamic>{
            'localDates': <String>[],
            'frequence': 'DAILY',
          },
        });
      });

      final result = await _repository(client).updateTask(
        accessToken: 'access-token-test-only',
        spaceId: 7,
        taskId: 1,
        update: TaskUpdate(
          description: 'Trocar o botijão',
          score: 90.5,
          category: TaskCategory.operational,
          schedule: TaskScheduleSummary(
            localDates: const <DateTime>[],
            frequency: TaskFrequency.daily,
          ),
        ),
      );

      expect(result.schedule?.frequency, TaskFrequency.daily);
      expect(result.schedule?.localDates, isEmpty);
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
        spaceId: 7,
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

    test('rejeita update inválido antes da rede', () async {
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
        repository.updateTask(
          accessToken: ' ',
          spaceId: 7,
          taskId: 1,
          update: validUpdate,
        ),
        repository.updateTask(
          accessToken: 'token',
          spaceId: 0,
          taskId: 1,
          update: validUpdate,
        ),
        repository.updateTask(
          accessToken: 'token',
          spaceId: -1,
          taskId: 1,
          update: validUpdate,
        ),
        repository.updateTask(
          accessToken: 'token',
          spaceId: 7,
          taskId: 0,
          update: validUpdate,
        ),
        repository.updateTask(
          accessToken: 'token',
          spaceId: 7,
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
          spaceId: 7,
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
          spaceId: 7,
          taskId: 1,
          update: TaskUpdate(
            description: 'Tarefa',
            score: 10,
            category: TaskCategory.operational,
            schedule: TaskScheduleSummary(
              localDates: const <DateTime>[],
              frequency: TaskFrequency.weekly,
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
          spaceId: 7,
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
          spaceId: 7,
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
          repository.fetchTasks(accessToken: '   ', spaceId: 7),
          repository.fetchTasks(accessToken: 'token', spaceId: 0),
          repository.fetchTasks(accessToken: 'token', spaceId: -1),
          repository.fetchTasks(accessToken: 'token', spaceId: 7, page: -1),
          repository.fetchTasks(accessToken: 'token', spaceId: 7, size: 0),
          repository.fetchTasks(
            accessToken: 'token',
            spaceId: 7,
            filters: const TaskFilters(score: double.nan),
          ),
          repository.fetchTasks(
            accessToken: 'token',
            spaceId: 7,
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
          repository.fetchTasks(
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
          (_) async =>
              http.Response('{}', 429, headers: const {'Retry-After': '12'}),
        ),
      );

      await expectLater(
        repository.fetchTasks(
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

    test('mapeia JSON incompatível para malformedResponse', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('{"content":[]}', 200)),
      );

      await expectLater(
        repository.fetchTasks(
          accessToken: 'access-token-test-only',
          spaceId: 7,
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

    test('mapeia falha do cliente para network', () async {
      final repository = _repository(
        MockClient((request) async {
          throw http.ClientException('Falha simulada.', request.url);
        }),
      );

      await expectLater(
        repository.fetchTasks(
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
        repository.fetchTasks(
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

    group('fetchTaskExecutions', () {
      test(
        'faz GET contextual paginado com Bearer e interpreta a resposta',
        () async {
          final client = MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/spaces/7/tasks/42/executions');
            expect(request.url.queryParametersAll, <String, List<String>>{
              'page': <String>['0'],
              'size': <String>['10'],
              'sort': <String>['createdAt,desc', 'id,desc'],
            });
            expect(request.headers['Accept'], 'application/json');
            expect(
              request.headers['Authorization'],
              'Bearer access-token-test-only',
            );
            expect(request.headers, isNot(contains('Content-Type')));
            return _jsonResponse(_validExecutionPageBody());
          });

          final result = await _repository(client).fetchTaskExecutions(
            accessToken: ' access-token-test-only ',
            spaceId: 7,
            taskId: 42,
          );

          expect(result.content, hasLength(1));
          expect(result.content.single.id, 1);
          expect(
            result.content.single.executionDate,
            DateTime.utc(2026, 8, 21, 18, 31),
          );
          expect(result.content.single.score, 90.0);
          expect(result.content.single.executorNames, <String>[
            'Bella Laet',
            'Joice Laet',
            'Jonatas Laet',
            'Ralph Laet',
          ]);
          expect(result.totalElements, 1);
        },
      );

      test('envia paginação e ordena o histórico de forma estável', () async {
        final client = MockClient((request) async {
          expect(request.url.queryParametersAll, <String, List<String>>{
            'page': <String>['2'],
            'size': <String>['25'],
            'sort': <String>['createdAt,desc', 'id,desc'],
          });
          return _jsonResponse(
            _validExecutionPageBody(
              page: 2,
              size: 25,
              totalElements: 51,
              totalPages: 3,
            ),
          );
        });

        final result = await _repository(client).fetchTaskExecutions(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          taskId: 42,
          page: 2,
          size: 25,
        );

        expect(result.number, 2);
        expect(result.size, 25);
        expect(result.totalElements, 51);
      });

      test('rejeita token, IDs ou paginação inválidos antes da rede', () async {
        var calls = 0;
        final repository = _repository(
          MockClient((_) async {
            calls += 1;
            return _jsonResponse(_validExecutionPageBody());
          }),
        );
        final requests = <Future<Object?>>[
          repository.fetchTaskExecutions(
            accessToken: '   ',
            spaceId: 7,
            taskId: 42,
          ),
          repository.fetchTaskExecutions(
            accessToken: 'token',
            spaceId: 0,
            taskId: 42,
          ),
          repository.fetchTaskExecutions(
            accessToken: 'token',
            spaceId: -1,
            taskId: 42,
          ),
          repository.fetchTaskExecutions(
            accessToken: 'token',
            spaceId: 7,
            taskId: 0,
          ),
          repository.fetchTaskExecutions(
            accessToken: 'token',
            spaceId: 7,
            taskId: -1,
          ),
          repository.fetchTaskExecutions(
            accessToken: 'token',
            spaceId: 7,
            taskId: 42,
            page: -1,
          ),
          repository.fetchTaskExecutions(
            accessToken: 'token',
            spaceId: 7,
            taskId: 42,
            size: 0,
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
            (_) async =>
                _jsonResponse(_validExecutionPageBody(), statusCode: 201),
          ),
        );

        await expectLater(
          repository.fetchTaskExecutions(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
          ),
          throwsA(
            isA<ApiFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  ApiFailureKind.unknown,
                )
                .having((failure) => failure.statusCode, 'statusCode', 201),
          ),
        );
      });

      test('rejeita página diferente da solicitada', () async {
        final repository = _repository(
          MockClient(
            (_) async =>
                _jsonResponse(_validExecutionPageBody(page: 1, totalPages: 2)),
          ),
        );

        await expectLater(
          repository.fetchTaskExecutions(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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
          repository.fetchTaskExecutions(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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

      test('mapeia execução incompatível para malformedResponse', () async {
        final body = _validExecutionPageBody();
        final execution = (body['content'] as List<dynamic>).single;
        (execution as Map<String, dynamic>)['executionDate'] =
            '31/02/2026 18:31';
        final repository = _repository(
          MockClient((_) async => _jsonResponse(body)),
        );

        await expectLater(
          repository.fetchTaskExecutions(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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
        (409, ApiFailureKind.validation),
        (503, ApiFailureKind.server),
      ]) {
        test('mapeia ${errorCase.$1} para ${errorCase.$2.name}', () async {
          final repository = _repository(
            MockClient((_) async => http.Response('{}', errorCase.$1)),
          );

          await expectLater(
            repository.fetchTaskExecutions(
              accessToken: 'access-token-test-only',
              spaceId: 7,
              taskId: 42,
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
          repository.fetchTaskExecutions(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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
          repository.fetchTaskExecutions(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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
            return _jsonResponse(_validExecutionPageBody());
          }),
          timeout: const Duration(milliseconds: 1),
        );

        await expectLater(
          repository.fetchTaskExecutions(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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

    group('removeCurrentUserFromTaskExecution', () {
      test('faz DELETE com Bearer, sem body e aceita 204', () async {
        final client = MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(
            request.url.toString(),
            'http://localhost:8080/api/spaces/7/tasks/42/executions/9/me',
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

        await _repository(client).removeCurrentUserFromTaskExecution(
          accessToken: ' access-token-test-only ',
          spaceId: 7,
          taskId: 42,
          taskExecutionId: 9,
        );
      });

      test('rejeita token ou IDs inválidos antes da rede', () async {
        var calls = 0;
        final repository = _repository(
          MockClient((_) async {
            calls += 1;
            return http.Response('', 204);
          }),
        );
        final requests = <Future<void>>[
          repository.removeCurrentUserFromTaskExecution(
            accessToken: '   ',
            spaceId: 7,
            taskId: 42,
            taskExecutionId: 9,
          ),
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'token',
            spaceId: 0,
            taskId: 42,
            taskExecutionId: 9,
          ),
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'token',
            spaceId: -1,
            taskId: 42,
            taskExecutionId: 9,
          ),
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: 0,
            taskExecutionId: 9,
          ),
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: -1,
            taskExecutionId: 9,
          ),
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: 42,
            taskExecutionId: 0,
          ),
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: 42,
            taskExecutionId: -1,
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

      test('rejeita status diferente de 204', () async {
        final repository = _repository(
          MockClient((_) async => http.Response('{}', 200)),
        );

        await expectLater(
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
            taskExecutionId: 9,
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
        (409, ApiFailureKind.validation),
        (503, ApiFailureKind.server),
      ]) {
        test('mapeia ${errorCase.$1} para ${errorCase.$2.name}', () async {
          final repository = _repository(
            MockClient((_) async => http.Response('{}', errorCase.$1)),
          );

          await expectLater(
            repository.removeCurrentUserFromTaskExecution(
              accessToken: 'access-token-test-only',
              spaceId: 7,
              taskId: 42,
              taskExecutionId: 9,
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

      test('mapeia 429 e lê Retry-After', () async {
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
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
            taskExecutionId: 9,
          ),
          throwsA(
            isA<ApiFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  ApiFailureKind.rateLimited,
                )
                .having((failure) => failure.statusCode, 'statusCode', 429)
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
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
            taskExecutionId: 9,
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
            return http.Response('', 204);
          }),
          timeout: const Duration(milliseconds: 1),
        );

        await expectLater(
          repository.removeCurrentUserFromTaskExecution(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
            taskExecutionId: 9,
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

    group('confirmTaskExecution', () {
      test('faz POST com executores ordenados e data em 24 horas', () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/spaces/7/tasks/42');
          expect(request.url.queryParametersAll, <String, List<String>>{
            'usersIds': <String>['2,5,9'],
            'executionDate': <String>['2026-08-21-18-31'],
          });
          expect(request.headers['Accept'], 'application/json');
          expect(
            request.headers['Authorization'],
            'Bearer access-token-test-only',
          );
          expect(request.headers, isNot(contains('Content-Type')));
          expect(request.bodyBytes, isEmpty);
          return http.Response('', 204);
        });

        await _repository(client).confirmTaskExecution(
          accessToken: ' access-token-test-only ',
          spaceId: 7,
          taskId: 42,
          executorIds: <int>{9, 2, 5},
          executionDate: DateTime(2026, 8, 21, 18, 31, 59),
        );
      });

      test('omite todos os parâmetros opcionais', () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/spaces/7/tasks/42');
          expect(request.url.query, isEmpty);
          expect(request.bodyBytes, isEmpty);
          return http.Response('', 204);
        });

        await _repository(client).confirmTaskExecution(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          taskId: 42,
        );
      });

      test('omite cada parâmetro opcional de forma independente', () async {
        var calls = 0;
        final client = MockClient((request) async {
          calls += 1;
          if (calls == 1) {
            expect(request.url.queryParametersAll, <String, List<String>>{
              'usersIds': <String>['2,3'],
            });
          } else {
            expect(request.url.queryParametersAll, <String, List<String>>{
              'executionDate': <String>['2026-08-21-00-05'],
            });
          }
          return http.Response('', 204);
        });
        final repository = _repository(client);

        await repository.confirmTaskExecution(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          taskId: 42,
          executorIds: const <int>{3, 2},
        );
        await repository.confirmTaskExecution(
          accessToken: 'access-token-test-only',
          spaceId: 7,
          taskId: 42,
          executionDate: DateTime.utc(2026, 8, 21, 0, 5),
        );

        expect(calls, 2);
      });

      test('rejeita token, IDs ou data inválidos antes da rede', () async {
        var calls = 0;
        final repository = _repository(
          MockClient((_) async {
            calls += 1;
            return http.Response('', 204);
          }),
        );
        final requests = <Future<void>>[
          repository.confirmTaskExecution(
            accessToken: '   ',
            spaceId: 7,
            taskId: 42,
          ),
          repository.confirmTaskExecution(
            accessToken: 'token',
            spaceId: 0,
            taskId: 42,
          ),
          repository.confirmTaskExecution(
            accessToken: 'token',
            spaceId: -1,
            taskId: 42,
          ),
          repository.confirmTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: 0,
          ),
          repository.confirmTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: -1,
          ),
          repository.confirmTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: 42,
            executorIds: const <int>{0},
          ),
          repository.confirmTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: 42,
            executorIds: const <int>{-1},
          ),
          repository.confirmTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: 42,
            executionDate: DateTime.utc(0, 1, 1),
          ),
          repository.confirmTaskExecution(
            accessToken: 'token',
            spaceId: 7,
            taskId: 42,
            executionDate: DateTime.utc(10000, 1, 1),
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

      test('aceita somente 204 como sucesso', () async {
        final repository = _repository(
          MockClient((_) async => http.Response('{}', 200)),
        );

        await expectLater(
          repository.confirmTaskExecution(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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
        (409, ApiFailureKind.validation),
        (503, ApiFailureKind.server),
      ]) {
        test('mapeia ${errorCase.$1} para ${errorCase.$2.name}', () async {
          final repository = _repository(
            MockClient((_) async => http.Response('{}', errorCase.$1)),
          );

          await expectLater(
            repository.confirmTaskExecution(
              accessToken: 'access-token-test-only',
              spaceId: 7,
              taskId: 42,
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
          repository.confirmTaskExecution(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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
          repository.confirmTaskExecution(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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
            return http.Response('', 204);
          }),
          timeout: const Duration(milliseconds: 1),
        );

        await expectLater(
          repository.confirmTaskExecution(
            accessToken: 'access-token-test-only',
            spaceId: 7,
            taskId: 42,
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

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
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

Map<String, dynamic> _validExecutionPageBody({
  int page = 0,
  int size = 10,
  int totalElements = 1,
  int totalPages = 1,
}) {
  return <String, dynamic>{
    'content': <dynamic>[
      <String, dynamic>{
        'id': 1,
        'executionDate': '21/08/2026 18:31',
        'score': 90.0,
        'executorNames': <dynamic>[
          'Bella Laet',
          'Joice Laet',
          'Jonatas Laet',
          'Ralph Laet',
        ],
      },
    ],
    'page': <String, dynamic>{
      'size': size,
      'number': page,
      'totalElements': totalElements,
      'totalPages': totalPages,
    },
  };
}

TaskCreation _validCreation({
  int spaceId = 7,
  String description = 'Trocar o botijão',
  num score = 90.5,
  String creatorName = 'Joice Laet',
  TaskScheduleSummary? schedule,
}) {
  return TaskCreation(
    spaceId: spaceId,
    description: description,
    score: score,
    category: TaskCategory.operational,
    active: true,
    creatorName: creatorName,
    schedule: schedule,
  );
}
