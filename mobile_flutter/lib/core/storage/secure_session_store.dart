import 'dart:convert';

import 'package:mobile_flutter/core/storage/secure_storage_gateway.dart';
import 'package:mobile_flutter/core/storage/session_store.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';

final class SecureSessionStore implements SessionStore {
  const SecureSessionStore(this._storage);

  static const _storageKey = 'taskify.auth.session.v1';

  final SecureStorageGateway _storage;

  @override
  Future<void> save(AuthSession session) {
    return _storage.write(_storageKey, jsonEncode(session.toJson()));
  }

  @override
  Future<AuthSession?> read() async {
    final encodedSession = await _storage.read(_storageKey);
    if (encodedSession == null) {
      return null;
    }
    final decodedSession = jsonDecode(encodedSession);
    if (decodedSession is! Map<String, dynamic>) {
      throw const FormatException('Sessão armazenada em formato inválido.');
    }
    return AuthSession.fromJson(decodedSession);
  }

  @override
  Future<void> clear() => _storage.delete(_storageKey);
}
