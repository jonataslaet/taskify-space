import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';

final class HttpTasksRepository implements TasksRepository {
  factory HttpTasksRepository({
    required http.Client client,
    required AppConfig config,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return HttpTasksRepository._(client, config, timeout);
  }

  const HttpTasksRepository._(this._client, this._config, this._timeout);

  final http.Client _client;
  final AppConfig _config;
  final Duration _timeout;

  @override
  Future<TaskSummary> createTask({
    required String accessToken,
    required TaskCreation creation,
  }) async {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty || !_isValidCreation(creation)) {
      throw const ApiFailure(ApiFailureKind.validation);
    }

    try {
      final response = await _client
          .post(
            _config.endpoint('/tasks'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $normalizedToken',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(creation.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode != 201) {
        throw _mapFailure(response);
      }

      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is! Map<String, dynamic>) {
        throw const FormatException(
          'Resposta de criação de tarefa não é um objeto JSON.',
        );
      }
      final createdTask = TaskSummary.fromJson(decodedBody);
      if (createdTask.spaceId != creation.spaceId) {
        throw const FormatException(
          'A API criou a tarefa em um espaço diferente do solicitado.',
        );
      }
      return createdTask;
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(ApiFailureKind.timeout);
    } on http.ClientException {
      throw const ApiFailure(ApiFailureKind.network);
    } on FormatException {
      throw const ApiFailure(ApiFailureKind.malformedResponse);
    } on Object {
      throw const ApiFailure(ApiFailureKind.unknown);
    }
  }

  @override
  Future<TaskSummary> updateTask({
    required String accessToken,
    required int taskId,
    required TaskUpdate update,
  }) async {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty || taskId <= 0 || !_isValidUpdate(update)) {
      throw const ApiFailure(ApiFailureKind.validation);
    }

    try {
      final response = await _client
          .put(
            _config.endpoint('/tasks/$taskId'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $normalizedToken',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(update.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw _mapFailure(response);
      }

      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is! Map<String, dynamic>) {
        throw const FormatException(
          'Resposta de atualização de tarefa não é um objeto JSON.',
        );
      }
      final updatedTask = TaskSummary.fromJson(decodedBody);
      if (updatedTask.id != taskId) {
        throw const FormatException(
          'A API retornou uma tarefa diferente da atualizada.',
        );
      }
      return updatedTask;
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(ApiFailureKind.timeout);
    } on http.ClientException {
      throw const ApiFailure(ApiFailureKind.network);
    } on FormatException {
      throw const ApiFailure(ApiFailureKind.malformedResponse);
    } on Object {
      throw const ApiFailure(ApiFailureKind.unknown);
    }
  }

  @override
  Future<TaskPageResult> fetchTasks({
    required String accessToken,
    TaskFilters filters = const TaskFilters(),
    int page = 0,
    int size = 10,
  }) async {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty ||
        page < 0 ||
        size <= 0 ||
        (filters.spaceId != null && filters.spaceId! <= 0) ||
        _hasNonFiniteScore(filters)) {
      throw const ApiFailure(ApiFailureKind.validation);
    }

    try {
      final response = await _client
          .get(
            _tasksEndpoint(filters, page: page, size: size),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $normalizedToken',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw _mapFailure(response);
      }

      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is! Map<String, dynamic>) {
        throw const FormatException(
          'Resposta de tarefas não é um objeto JSON.',
        );
      }
      return TaskPageResult.fromJson(decodedBody);
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(ApiFailureKind.timeout);
    } on http.ClientException {
      throw const ApiFailure(ApiFailureKind.network);
    } on FormatException {
      throw const ApiFailure(ApiFailureKind.malformedResponse);
    } on Object {
      throw const ApiFailure(ApiFailureKind.unknown);
    }
  }

  Uri _tasksEndpoint(
    TaskFilters filters, {
    required int page,
    required int size,
  }) {
    final normalizedDescription = filters.description?.trim();
    final selectedCategories = TaskCategory.values
        .where(filters.categories.contains)
        .map((category) => category.apiValue)
        .join(',');
    final queryParameters = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'sort': 'id,asc',
      if (filters.spaceId case final spaceId?) 'spaceId': spaceId.toString(),
      if (normalizedDescription != null && normalizedDescription.isNotEmpty)
        'description': normalizedDescription,
      if (filters.score case final score?) 'score': score.toString(),
      if (filters.active case final active?) 'active': active.toString(),
      if (selectedCategories.isNotEmpty) 'categories': selectedCategories,
      if (filters.minScore case final minScore?)
        'minScore': minScore.toString(),
      if (filters.maxScore case final maxScore?)
        'maxScore': maxScore.toString(),
    };

    return _config.endpoint('/tasks').replace(queryParameters: queryParameters);
  }

  bool _hasNonFiniteScore(TaskFilters filters) {
    return <num?>[
      filters.score,
      filters.minScore,
      filters.maxScore,
    ].any((score) => score != null && !score.isFinite);
  }

  bool _isValidUpdate(TaskUpdate update) {
    return _isValidTaskFields(
      description: update.description,
      score: update.score,
      schedule: update.schedule,
    );
  }

  bool _isValidCreation(TaskCreation creation) {
    return creation.spaceId > 0 &&
        creation.creatorName.trim().isNotEmpty &&
        _isValidTaskFields(
          description: creation.description,
          score: creation.score,
          schedule: creation.schedule,
        );
  }

  bool _isValidTaskFields({
    required String description,
    required num score,
    required TaskScheduleSummary? schedule,
  }) {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty || normalizedDescription.length > 255) {
      return false;
    }

    if (!score.isFinite || score <= 0 || !_hasAtMostTwoDecimalPlaces(score)) {
      return false;
    }

    if (score is int) {
      if (score.toString().length > 36) {
        return false;
      }
    } else if (score >= 1e36) {
      return false;
    }

    return schedule == null ||
        (schedule.localDates.isNotEmpty &&
            schedule.localDates.every(
              (date) => date.year >= 1 && date.year <= 9999,
            ));
  }

  bool _hasAtMostTwoDecimalPlaces(num value) {
    if (value is int) {
      return true;
    }
    final asDouble = value.toDouble();
    return double.parse(asDouble.toStringAsFixed(2)) == asDouble;
  }

  ApiFailure _mapFailure(http.Response response) {
    final statusCode = response.statusCode;
    return switch (statusCode) {
      400 => ApiFailure(ApiFailureKind.validation, statusCode: statusCode),
      409 => ApiFailure(ApiFailureKind.validation, statusCode: statusCode),
      401 => ApiFailure(ApiFailureKind.unauthorized, statusCode: statusCode),
      403 => ApiFailure(ApiFailureKind.forbidden, statusCode: statusCode),
      429 => ApiFailure(
        ApiFailureKind.rateLimited,
        statusCode: statusCode,
        retryAfter: _parseRetryAfter(
          _headerValue(response.headers, 'retry-after'),
        ),
      ),
      >= 500 => ApiFailure(ApiFailureKind.server, statusCode: statusCode),
      _ => ApiFailure(ApiFailureKind.unknown, statusCode: statusCode),
    };
  }

  Duration? _parseRetryAfter(String? value) {
    final seconds = int.tryParse(value ?? '');
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  String? _headerValue(Map<String, String> headers, String name) {
    final normalizedName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == normalizedName) {
        return entry.value;
      }
    }
    return null;
  }
}
