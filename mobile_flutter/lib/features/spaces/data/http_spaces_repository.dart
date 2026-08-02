import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';

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
  Future<SpacePageResult> fetchSpaces({
    required String accessToken,
    SpaceFilters filters = const SpaceFilters(),
  }) async {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty) {
      throw const ApiFailure(ApiFailureKind.validation);
    }

    try {
      final response = await _client
          .get(
            _spacesEndpoint(filters),
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
      return SpacePageResult.fromJson(decodedBody);
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

  Uri _spacesEndpoint(SpaceFilters filters) {
    final normalizedName = filters.name?.trim();
    final queryParameters = <String, String>{
      if (normalizedName != null && normalizedName.isNotEmpty)
        'name': normalizedName,
      if (filters.role case final role?) 'spaceUserRole': role.apiValue,
      if (filters.status case final status?)
        'spaceMembershipStatus': status.apiValue,
    };

    final endpoint = _config.endpoint('/spaces');
    if (queryParameters.isEmpty) {
      return endpoint;
    }
    return endpoint.replace(queryParameters: queryParameters);
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
