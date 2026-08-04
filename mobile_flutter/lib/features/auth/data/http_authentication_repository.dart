import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/device/installation_id_store.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/core/storage/session_store.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';

final class HttpAuthenticationRepository implements AuthenticationRepository {
  factory HttpAuthenticationRepository({
    required http.Client client,
    required AppConfig config,
    required SessionStore sessionStore,
    required InstallationIdStore installationIdStore,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return HttpAuthenticationRepository._(
      client,
      config,
      sessionStore,
      installationIdStore,
      timeout,
    );
  }

  const HttpAuthenticationRepository._(
    this._client,
    this._config,
    this._sessionStore,
    this._installationIdStore,
    this._timeout,
  );

  final http.Client _client;
  final AppConfig _config;
  final SessionStore _sessionStore;
  final InstallationIdStore _installationIdStore;
  final Duration _timeout;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    late final String installationId;
    try {
      installationId = await _installationIdStore.getOrCreate();
    } on Object {
      throw const ApiFailure(ApiFailureKind.storage);
    }

    try {
      final response = await _client
          .post(
            _config.endpoint('/auth/login'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
              'X-Device-Id': installationId,
            },
            body: jsonEncode(<String, String>{
              'username': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw _mapFailure(response);
      }

      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is! Map<String, dynamic>) {
        throw const FormatException('Resposta de login não é um objeto JSON.');
      }
      return _persistAndReturnSession(decodedBody);
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
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    late final String installationId;
    try {
      installationId = await _installationIdStore.getOrCreate();
    } on Object {
      throw const ApiFailure(ApiFailureKind.storage);
    }

    try {
      final endpoint = _config.endpoint('/users');
      final requestBody = jsonEncode(<String, String>{
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        'password': password,
        'passwordConfirmation': passwordConfirmation,
      });
      debugPrint('Registro: POST $endpoint');
      debugPrint('Registro body: $requestBody');
      final response = await _client
          .post(
            endpoint,
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
              'X-Device-Id': installationId,
            },
            body: requestBody,
          )
          .timeout(_timeout);
      debugPrint('Registro status: ${response.statusCode}');
      debugPrint('Registro response: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw _mapFailure(response);
      }

      final decodedBody = _decodeJsonBody(response.bodyBytes);
      if (decodedBody is! Map<String, dynamic>) {
        throw const FormatException('Resposta de cadastro não é um objeto JSON.');
      }
      return _persistAndReturnSession(decodedBody);
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

  Future<AuthSession> _persistAndReturnSession(Map<String, dynamic> decodedBody) async {
    final session = AuthSession.fromJson(decodedBody);
    try {
      await _sessionStore.save(session);
    } on Object {
      throw const ApiFailure(ApiFailureKind.storage);
    }
    return session;
  }

  Object _decodeJsonBody(List<int> bodyBytes) {
    final decodedBody = jsonDecode(utf8.decode(bodyBytes));
    if (decodedBody is Map<String, dynamic>) {
      return decodedBody;
    }
    if (decodedBody is Map) {
      return Map<String, dynamic>.from(decodedBody);
    }
    return decodedBody;
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
