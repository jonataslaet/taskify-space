import 'package:mobile_flutter/core/device/installation_id_store.dart';
import 'package:mobile_flutter/core/storage/secure_storage_gateway.dart';
import 'package:mobile_flutter/core/storage/session_store.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';
import 'package:mobile_flutter/features/spaces/domain/created_space.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_summary.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';
import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/task_execution_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_execution_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';

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
  bool failOnClear = false;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    if (failOnClear) {
      throw StateError('Falha simulada ao limpar o armazenamento.');
    }
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
typedef RegisterHandler =
    Future<void> Function(
      String name,
      String email,
      String password,
      String passwordConfirmation,
    );
typedef LogoutHandler = Future<void> Function(String refreshToken);

final class FakeAuthenticationRepository implements AuthenticationRepository {
  FakeAuthenticationRepository(
    this._handler, {
    this.registerHandler,
    this.logoutHandler,
  });

  final LoginHandler _handler;
  final RegisterHandler? registerHandler;
  final LogoutHandler? logoutHandler;
  int loginCalls = 0;
  int registerCalls = 0;
  int logoutCalls = 0;
  final receivedRefreshTokens = <String>[];

  @override
  Future<AuthSession> login({required String email, required String password}) {
    loginCalls += 1;
    return _handler(email, password);
  }

  @override
  Future<void> logout({required String refreshToken}) {
    logoutCalls += 1;
    receivedRefreshTokens.add(refreshToken);
    final handler = logoutHandler;
    if (handler == null) {
      return Future<void>.error(
        StateError('Handler de logout não configurado.'),
      );
    }
    return handler(refreshToken);
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) {
    registerCalls += 1;
    final handler = registerHandler;
    if (handler == null) {
      return Future<void>.error(
        StateError('Handler de cadastro não configurado.'),
      );
    }
    return handler(name, email, password, passwordConfirmation);
  }
}

typedef FetchSpacesHandler =
    Future<SpacePageResult> Function(String accessToken);
typedef FetchSpacesPageHandler =
    Future<SpacePageResult> Function(String accessToken, int page, int size);
typedef CreateSpaceHandler =
    Future<CreatedSpace> Function(String accessToken, String name);
typedef FetchSpaceParticipantsHandler =
    Future<SpaceParticipantPageResult> Function(
      String accessToken,
      int spaceId,
      SpaceParticipantFilters filters,
      int page,
      int size,
    );
typedef SearchSpaceParticipantsHandler =
    Future<List<SpaceParticipantSummary>> Function(
      String accessToken,
      int spaceId,
      String name,
    );

final class FakeSpacesRepository implements SpacesRepository {
  FakeSpacesRepository(
    this._handler, {
    this.fetchPageHandler,
    this.createHandler,
    this.fetchParticipantsHandler,
    this.searchParticipantsHandler,
  });

  final FetchSpacesHandler _handler;
  final FetchSpacesPageHandler? fetchPageHandler;
  final CreateSpaceHandler? createHandler;
  final FetchSpaceParticipantsHandler? fetchParticipantsHandler;
  final SearchSpaceParticipantsHandler? searchParticipantsHandler;
  int fetchSpacesCalls = 0;
  int createSpaceCalls = 0;
  int fetchSpaceParticipantsCalls = 0;
  int searchSpaceParticipantsCalls = 0;
  final receivedAccessTokens = <String>[];
  final receivedPages = <int>[];
  final receivedPageSizes = <int>[];
  final receivedCreateAccessTokens = <String>[];
  final receivedSpaceNames = <String>[];
  final receivedFilters = <SpaceFilters>[];
  final receivedParticipantAccessTokens = <String>[];
  final receivedParticipantSpaceIds = <int>[];
  final receivedParticipantFilters = <SpaceParticipantFilters>[];
  final receivedParticipantPages = <int>[];
  final receivedParticipantPageSizes = <int>[];
  final receivedParticipantSearchAccessTokens = <String>[];
  final receivedParticipantSearchSpaceIds = <int>[];
  final receivedParticipantSearchNames = <String>[];

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

  @override
  Future<SpaceParticipantPageResult> fetchSpaceParticipants({
    required String accessToken,
    required int spaceId,
    SpaceParticipantFilters filters = const SpaceParticipantFilters(),
    int page = 0,
    int size = 10,
  }) {
    fetchSpaceParticipantsCalls += 1;
    receivedParticipantAccessTokens.add(accessToken);
    receivedParticipantSpaceIds.add(spaceId);
    receivedParticipantFilters.add(filters);
    receivedParticipantPages.add(page);
    receivedParticipantPageSizes.add(size);
    final handler = fetchParticipantsHandler;
    if (handler == null) {
      return Future<SpaceParticipantPageResult>.error(
        StateError('Handler de participantes não configurado.'),
      );
    }
    return handler(accessToken, spaceId, filters, page, size);
  }

  @override
  Future<List<SpaceParticipantSummary>> searchSpaceParticipants({
    required String accessToken,
    required int spaceId,
    required String name,
  }) {
    searchSpaceParticipantsCalls += 1;
    receivedParticipantSearchAccessTokens.add(accessToken);
    receivedParticipantSearchSpaceIds.add(spaceId);
    receivedParticipantSearchNames.add(name);
    final handler = searchParticipantsHandler;
    if (handler != null) {
      return handler(accessToken, spaceId, name);
    }
    return Future<List<SpaceParticipantSummary>>.value(
      const <SpaceParticipantSummary>[],
    );
  }
}

typedef FetchTasksHandler =
    Future<TaskPageResult> Function(
      String accessToken,
      int spaceId,
      TaskFilters filters,
      int page,
      int size,
    );
typedef FetchTaskExecutionsHandler =
    Future<TaskExecutionPageResult> Function(
      String accessToken,
      int spaceId,
      int taskId,
      int page,
      int size,
    );
typedef ConfirmTaskExecutionHandler =
    Future<void> Function(
      String accessToken,
      int spaceId,
      int taskId,
      Set<int> executorIds,
      DateTime? executionDate,
    );
typedef UpdateTaskHandler =
    Future<TaskSummary> Function(
      String accessToken,
      int spaceId,
      int taskId,
      TaskUpdate update,
    );
typedef CreateTaskHandler =
    Future<TaskSummary> Function(
      String accessToken,
      int spaceId,
      TaskCreation creation,
    );
typedef ToggleTaskActiveHandler =
    Future<void> Function(String accessToken, int spaceId, int taskId);

final class FakeTasksRepository implements TasksRepository {
  FakeTasksRepository({
    this.handler,
    this.fetchTaskExecutionsHandler,
    this.confirmTaskExecutionHandler,
    this.createHandler,
    this.updateHandler,
    this.toggleTaskActiveHandler,
  });

  final FetchTasksHandler? handler;
  final FetchTaskExecutionsHandler? fetchTaskExecutionsHandler;
  final ConfirmTaskExecutionHandler? confirmTaskExecutionHandler;
  final CreateTaskHandler? createHandler;
  final UpdateTaskHandler? updateHandler;
  final ToggleTaskActiveHandler? toggleTaskActiveHandler;
  int fetchTasksCalls = 0;
  int fetchTaskExecutionsCalls = 0;
  int confirmTaskExecutionCalls = 0;
  int createTaskCalls = 0;
  int updateTaskCalls = 0;
  int toggleTaskActiveCalls = 0;
  final receivedAccessTokens = <String>[];
  final receivedSpaceIds = <int>[];
  final receivedFilters = <TaskFilters>[];
  final receivedPages = <int>[];
  final receivedPageSizes = <int>[];
  final receivedTaskExecutionAccessTokens = <String>[];
  final receivedTaskExecutionSpaceIds = <int>[];
  final receivedTaskExecutionTaskIds = <int>[];
  final receivedTaskExecutionPages = <int>[];
  final receivedTaskExecutionPageSizes = <int>[];
  final receivedConfirmTaskExecutionAccessTokens = <String>[];
  final receivedConfirmTaskExecutionSpaceIds = <int>[];
  final receivedConfirmTaskExecutionTaskIds = <int>[];
  final receivedConfirmTaskExecutionExecutorIds = <Set<int>>[];
  final receivedConfirmTaskExecutionDates = <DateTime?>[];
  final receivedCreateAccessTokens = <String>[];
  final receivedCreateSpaceIds = <int>[];
  final receivedTaskCreations = <TaskCreation>[];
  final receivedUpdateAccessTokens = <String>[];
  final receivedUpdateSpaceIds = <int>[];
  final receivedTaskIds = <int>[];
  final receivedTaskUpdates = <TaskUpdate>[];
  final receivedToggleTaskActiveAccessTokens = <String>[];
  final receivedToggleTaskActiveSpaceIds = <int>[];
  final receivedToggleTaskActiveIds = <int>[];

  @override
  Future<void> confirmTaskExecution({
    required String accessToken,
    required int spaceId,
    required int taskId,
    Set<int> executorIds = const <int>{},
    DateTime? executionDate,
  }) {
    confirmTaskExecutionCalls += 1;
    receivedConfirmTaskExecutionAccessTokens.add(accessToken);
    receivedConfirmTaskExecutionSpaceIds.add(spaceId);
    receivedConfirmTaskExecutionTaskIds.add(taskId);
    receivedConfirmTaskExecutionExecutorIds.add(
      Set<int>.unmodifiable(executorIds),
    );
    receivedConfirmTaskExecutionDates.add(executionDate);
    final handler = confirmTaskExecutionHandler;
    if (handler == null) {
      return Future<void>.error(
        StateError('Handler de confirmacao de tarefa nao configurado.'),
      );
    }
    return handler(accessToken, spaceId, taskId, executorIds, executionDate);
  }

  @override
  Future<TaskPageResult> fetchTasks({
    required String accessToken,
    required int spaceId,
    TaskFilters filters = const TaskFilters(),
    int page = 0,
    int size = 10,
  }) {
    fetchTasksCalls += 1;
    receivedAccessTokens.add(accessToken);
    receivedSpaceIds.add(spaceId);
    receivedFilters.add(filters);
    receivedPages.add(page);
    receivedPageSizes.add(size);
    final fetchHandler = handler;
    if (fetchHandler != null) {
      return fetchHandler(accessToken, spaceId, filters, page, size);
    }
    return Future<TaskPageResult>.value(makeTaskPage());
  }

  @override
  Future<TaskExecutionPageResult> fetchTaskExecutions({
    required String accessToken,
    required int spaceId,
    required int taskId,
    int page = 0,
    int size = 10,
  }) {
    fetchTaskExecutionsCalls += 1;
    receivedTaskExecutionAccessTokens.add(accessToken);
    receivedTaskExecutionSpaceIds.add(spaceId);
    receivedTaskExecutionTaskIds.add(taskId);
    receivedTaskExecutionPages.add(page);
    receivedTaskExecutionPageSizes.add(size);
    final handler = fetchTaskExecutionsHandler;
    if (handler != null) {
      return handler(accessToken, spaceId, taskId, page, size);
    }
    return Future<TaskExecutionPageResult>.value(
      makeTaskExecutionPage(size: size, number: page),
    );
  }

  @override
  Future<TaskSummary> createTask({
    required String accessToken,
    required int spaceId,
    required TaskCreation creation,
  }) {
    createTaskCalls += 1;
    receivedCreateAccessTokens.add(accessToken);
    receivedCreateSpaceIds.add(spaceId);
    receivedTaskCreations.add(creation);
    final handler = createHandler;
    if (handler == null) {
      return Future<TaskSummary>.error(
        StateError('Handler de criação de tarefa não configurado.'),
      );
    }
    return handler(accessToken, spaceId, creation);
  }

  @override
  Future<TaskSummary> updateTask({
    required String accessToken,
    required int spaceId,
    required int taskId,
    required TaskUpdate update,
  }) {
    updateTaskCalls += 1;
    receivedUpdateAccessTokens.add(accessToken);
    receivedUpdateSpaceIds.add(spaceId);
    receivedTaskIds.add(taskId);
    receivedTaskUpdates.add(update);
    final handler = updateHandler;
    if (handler == null) {
      return Future<TaskSummary>.error(
        StateError('Handler de atualização de tarefa não configurado.'),
      );
    }
    return handler(accessToken, spaceId, taskId, update);
  }

  @override
  Future<void> toggleTaskActive({
    required String accessToken,
    required int spaceId,
    required int taskId,
  }) {
    toggleTaskActiveCalls += 1;
    receivedToggleTaskActiveAccessTokens.add(accessToken);
    receivedToggleTaskActiveSpaceIds.add(spaceId);
    receivedToggleTaskActiveIds.add(taskId);
    final handler = toggleTaskActiveHandler;
    if (handler == null) {
      return Future<void>.error(
        StateError('Handler de status de tarefa não configurado.'),
      );
    }
    return handler(accessToken, spaceId, taskId);
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

SpaceParticipantPageResult makeSpaceParticipantPage({
  List<SpaceParticipant> content = const [],
  int size = 10,
  int number = 0,
  int? totalElements,
  int? totalPages,
}) {
  return SpaceParticipantPageResult(
    content: content,
    size: size,
    number: number,
    totalElements: totalElements ?? content.length,
    totalPages: totalPages ?? (content.isEmpty ? 0 : 1),
  );
}

TaskPageResult makeTaskPage({List<TaskSummary> content = const []}) {
  return TaskPageResult(
    content: content,
    size: 10,
    number: 0,
    totalElements: content.length,
    totalPages: content.isEmpty ? 0 : 1,
  );
}

TaskExecutionPageResult makeTaskExecutionPage({
  List<TaskExecutionSummary> content = const [],
  int size = 10,
  int number = 0,
  int? totalElements,
  int? totalPages,
}) {
  return TaskExecutionPageResult(
    content: content,
    size: size,
    number: number,
    totalElements: totalElements ?? content.length,
    totalPages: totalPages ?? (content.isEmpty ? 0 : 1),
  );
}
