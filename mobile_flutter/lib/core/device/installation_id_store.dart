import 'dart:math';

import 'package:mobile_flutter/core/storage/secure_storage_gateway.dart';

abstract interface class InstallationIdStore {
  Future<String> getOrCreate();
}

typedef InstallationIdGenerator = String Function();

final class SecureInstallationIdStore implements InstallationIdStore {
  factory SecureInstallationIdStore(
    SecureStorageGateway storage, {
    InstallationIdGenerator generator = generateInstallationId,
  }) {
    return SecureInstallationIdStore._(storage, generator);
  }

  SecureInstallationIdStore._(this._storage, this._generator);

  static const _storageKey = 'taskify.installation.id.v1';
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final SecureStorageGateway _storage;
  final InstallationIdGenerator _generator;
  Future<String>? _installationId;

  @override
  Future<String> getOrCreate() {
    final currentInstallationId = _installationId;
    if (currentInstallationId != null) {
      return currentInstallationId;
    }

    return _installationId = _loadOrCreate().onError((error, stackTrace) {
      _installationId = null;
      if (error == null) {
        throw StateError('Falha desconhecida ao obter o identificador.');
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<String> _loadOrCreate() async {
    final storedValue = await _storage.read(_storageKey);
    if (storedValue != null && _uuidPattern.hasMatch(storedValue)) {
      return storedValue;
    }

    final installationId = _generator();
    if (!_uuidPattern.hasMatch(installationId)) {
      throw StateError('O gerador retornou um identificador inválido.');
    }
    await _storage.write(_storageKey, installationId);
    return installationId;
  }
}

String generateInstallationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
