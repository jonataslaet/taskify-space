import 'package:mobile_flutter/core/device/installation_id_store.dart';
import 'package:mobile_flutter/core/storage/secure_storage_gateway.dart';
import 'package:mobile_flutter/core/storage/session_store.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';
import 'package:mobile_flutter/features/spaces/domain/created_space.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';

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

typedef FetchSpacesHandler =
    Future<SpacePageResult> Function(String accessToken);
typedef FetchSpacesPageHandler =
    Future<SpacePageResult> Function(String accessToken, int page, int size);
typedef CreateSpaceHandler =
    Future<CreatedSpace> Function(String accessToken, String name);

final class FakeSpacesRepository implements SpacesRepository {
  FakeSpacesRepository(
    this._handler, {
    this.fetchPageHandler,
    this.createHandler,
  });

  final FetchSpacesHandler _handler;
  final FetchSpacesPageHandler? fetchPageHandler;
  final CreateSpaceHandler? createHandler;
  int fetchSpacesCalls = 0;
  int createSpaceCalls = 0;
  final receivedAccessTokens = <String>[];
  final receivedPages = <int>[];
  final receivedPageSizes = <int>[];
  final receivedCreateAccessTokens = <String>[];
  final receivedSpaceNames = <String>[];
  final receivedFilters = <SpaceFilters>[];

  @override
  Future<CreatedSpace> createSpace({
    required String accessToken,
    required String name,
  }) {
    createSpaceCalls += 1;
    receivedCreateAccessTokens.add(accessToken);
    receivedSpaceNames.add(name);
    final handler = createHandler;
    if (handler == null) {
      return Future<CreatedSpace>.error(
        StateError('Handler de criação não configurado.'),
      );
    }
    return handler(accessToken, name);
  }

  @override
  Future<SpacePageResult> fetchSpaces({
    required String accessToken,
    SpaceFilters filters = const SpaceFilters(),
    int page = 0,
    int size = 10,
  }) {
    fetchSpacesCalls += 1;
    receivedAccessTokens.add(accessToken);
    receivedFilters.add(filters);
    receivedPages.add(page);
    receivedPageSizes.add(size);
    final pageHandler = fetchPageHandler;
    if (pageHandler != null) {
      return pageHandler(accessToken, page, size);
    }
    return _handler(accessToken);
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

const testSpace = SpaceSummary(
  id: 1,
  name: 'Residência do Casal Laet',
  spaceAdminName: 'Joice Laet',
  active: true,
  spaceUserRole: 'ROLE_SPACE_PARTICIPANT',
  spaceMembershipStatus: 'APPROVED',
  activeParticipationsCount: 4,
);

SpacePageResult makeSpacePage({List<SpaceSummary> content = const []}) {
  return SpacePageResult(
    content: content,
    size: 10,
    number: 0,
    totalElements: content.length,
    totalPages: content.isEmpty ? 0 : 1,
  );
}
