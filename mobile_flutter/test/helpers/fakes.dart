import 'package:mobile_flutter/core/device/installation_id_store.dart';
import 'package:mobile_flutter/core/storage/secure_storage_gateway.dart';
import 'package:mobile_flutter/core/storage/session_store.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';

final class FakeSecureStorageGateway implements SecureStorageGateway {
  final values = <String, String>{};
  int writeCount = 0;
  bool failNextWrite = false;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Falha simulada de escrita.');
    }
    writeCount += 1;
    values[key] = value;
  }
}

final class FakeSessionStore implements SessionStore {
  AuthSession? savedSession;
  bool failOnSave = false;

  @override
  Future<void> clear() async {
    savedSession = null;
  }

  @override
  Future<AuthSession?> read() async => savedSession;

  @override
  Future<void> save(AuthSession session) async {
    if (failOnSave) {
      throw StateError('Falha simulada de armazenamento.');
    }
    savedSession = session;
  }
}

final class FakeInstallationIdStore implements InstallationIdStore {
  FakeInstallationIdStore({
    this.value = '123e4567-e89b-42d3-a456-426614174000',
  });

  final String value;
  bool fail = false;

  @override
  Future<String> getOrCreate() async {
    if (fail) {
      throw StateError('Falha simulada de armazenamento.');
    }
    return value;
  }
}

typedef LoginHandler =
    Future<AuthSession> Function(String email, String password);

final class FakeAuthenticationRepository implements AuthenticationRepository {
  FakeAuthenticationRepository(this._handler);

  final LoginHandler _handler;
  int loginCalls = 0;

  @override
  Future<AuthSession> login({required String email, required String password}) {
    loginCalls += 1;
    return _handler(email, password);
  }
}

const testSession = AuthSession(
  id: 1,
  username: 'user@example.com',
  name: 'Usuário de Teste',
  accessToken: 'access-token-test-only',
  refreshToken: 'refresh-token-test-only',
  role: 'ROLE_USER',
);
