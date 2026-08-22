import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/created_space.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_summary.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

final class HttpSpacesRepository implements SpacesRepository {
  factory HttpSpacesRepository({
    required http.Client client,
    required AppConfig config,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return HttpSpacesRepository._(client, config, timeout);
  }

  const HttpSpacesRepository._(this._client, this._config, this._timeout);

  final http.Client _client;
  final AppConfig _config;
  final Duration _timeout;

  @override
  Future<CreatedSpace> createSpace({
    required String accessToken,
    required String name,
  }) async {
    final normalizedToken = accessToken.trim();
    final normalizedName = name.trim();
    if (normalizedToken.isEmpty ||
        normalizedName.isEmpty ||
        normalizedName.length > 255) {
      throw const ApiFailure(ApiFailureKind.validation);
    }

    try {
      final response = await _client
          .post(
            _config.endpoint('/spaces'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $normalizedToken',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(<String, String>{'name': normalizedName}),
          )
          .timeout(_timeout);

      if (response.statusCode != 201) {
        throw _mapFailure(response);
      }

      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is! Map<String, dynamic>) {
        throw const FormatException(
          'Resposta de criação de espaço não é um objeto JSON.',
        );
      }
      return CreatedSpace.fromJson(decodedBody);
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
  Future<SpacePageResult> fetchSpaces({
    required String accessToken,
    SpaceFilters filters = const SpaceFilters(),
    int page = 0,
    int size = 10,
  }) async {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty || page < 0 || size <= 0) {
      throw const ApiFailure(ApiFailureKind.validation);
    }

    try {
      final response = await _client
          .get(
            _spacesEndpoint(filters, page: page, size: size),
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
          'Resposta de espaços não é um objeto JSON.',
        );
      }
      final result = SpacePageResult.fromJson(decodedBody);
      if (result.number != page) {
        throw FormatException(
          'A API retornou a página ${result.number}, mas a página $page foi '
          'solicitada.',
        );
      }
      return result;
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
  Future<SpaceParticipantPageResult> fetchSpaceParticipants({
    required String accessToken,
    required int spaceId,
    SpaceParticipantFilters filters = const SpaceParticipantFilters(),
    int page = 0,
    int size = 10,
  }) async {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty || spaceId <= 0 || page < 0 || size <= 0) {
      throw const ApiFailure(ApiFailureKind.validation);
    }

    try {
      final response = await _client
          .get(
            _spaceParticipantsEndpoint(
              spaceId,
              filters,
              page: page,
              size: size,
            ),
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
          'Resposta de participantes não é um objeto JSON.',
        );
      }
      final result = SpaceParticipantPageResult.fromJson(decodedBody);
      if (result.number != page) {
        throw FormatException(
          'A API retornou a página ${result.number}, mas a página $page foi '
          'solicitada.',
        );
      }
      return result;
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
  Future<void> requestSpaceParticipation({
    required String accessToken,
    required int spaceId,
  }) async {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty || spaceId <= 0) {
      throw const ApiFailure(ApiFailureKind.validation);
    }

    try {
      final response = await _client
          .post(
            _config.endpoint('/spaces/$spaceId/participations/request'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $normalizedToken',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 204) {
        throw _mapFailure(response);
      }
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(ApiFailureKind.timeout);
    } on http.ClientException {
      throw const ApiFailure(ApiFailureKind.network);
    } on Object {
      throw const ApiFailure(ApiFailureKind.unknown);
    }
  }

  @override
  Future<List<SpaceParticipantSummary>> searchSpaceParticipants({
    required String accessToken,
    required int spaceId,
    required String name,
  }) async {
    final normalizedToken = accessToken.trim();
    final normalizedName = name.trim();
    if (normalizedToken.isEmpty || spaceId <= 0 || normalizedName.isEmpty) {
      throw const ApiFailure(ApiFailureKind.validation);
    }

    try {
      final response = await _client
          .get(
            _config
                .endpoint('/spaces/$spaceId/participants/search')
                .replace(
                  queryParameters: <String, String>{'name': normalizedName},
                ),
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
      if (decodedBody is! List<dynamic>) {
        throw const FormatException(
          'Resposta de busca de participantes não é uma lista JSON.',
        );
      }
      return List<SpaceParticipantSummary>.unmodifiable(<
        SpaceParticipantSummary
      >[
        for (var index = 0; index < decodedBody.length; index += 1)
          SpaceParticipantSummary.fromJson(
            _stringKeyedMap(decodedBody[index], field: 'participants[$index]'),
          ),
      ]);
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

  Uri _spacesEndpoint(
    SpaceFilters filters, {
    required int page,
    required int size,
  }) {
    final normalizedName = filters.name?.trim();
    final queryParameters = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'sort': 'id,asc',
      if (normalizedName != null && normalizedName.isNotEmpty)
        'name': normalizedName,
      if (filters.role case final role?) 'spaceUserRole': role.apiValue,
      if (filters.status case final status?)
        'spaceMembershipStatus': status.apiValue,
    };

    final endpoint = _config.endpoint('/spaces');
    return endpoint.replace(queryParameters: queryParameters);
  }

  Uri _spaceParticipantsEndpoint(
    int spaceId,
    SpaceParticipantFilters filters, {
    required int page,
    required int size,
  }) {
    final normalizedName = filters.name?.trim();
    final selectedTaskCategories = <String>[
      for (final category in TaskCategory.values)
        if (filters.taskCategories.contains(category)) category.apiValue,
    ];
    final queryParameters = <String, Object>{
      'page': page.toString(),
      'size': size.toString(),
      if (normalizedName != null && normalizedName.isNotEmpty)
        'name': normalizedName,
      if (filters.role case final role?) 'spaceUserRole': role.apiValue,
      if (selectedTaskCategories.isNotEmpty)
        'taskCategories': selectedTaskCategories,
      if (filters.sort case final sort?) 'sort': sort.apiValue,
    };

    return _config
        .endpoint('/spaces/$spaceId/participants')
        .replace(queryParameters: queryParameters);
  }

  Map<String, dynamic> _stringKeyedMap(Object? value, {required String field}) {
    if (value is! Map) {
      throw FormatException('Campo $field ausente ou inválido.');
    }

    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('Campo $field inválido.');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  ApiFailure _mapFailure(http.Response response) {
    final statusCode = response.statusCode;
    return switch (statusCode) {
      400 => ApiFailure(ApiFailureKind.validation, statusCode: statusCode),
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
