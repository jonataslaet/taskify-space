import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/core/presentation/paged_list_pagination_bar.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/presentation/logout_button.dart';
import 'package:mobile_flutter/features/tasks/domain/task_execution_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_execution_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';

class TaskExecutionsPage extends StatefulWidget {
  const TaskExecutionsPage({
    required this.session,
    required this.spaceId,
    required this.spaceName,
    required this.taskId,
    required this.taskDescription,
    required this.tasksRepository,
    this.onSessionExpired,
    this.onLogout,
    super.key,
  }) : assert(spaceId > 0, 'spaceId deve ser positivo.'),
       assert(taskId > 0, 'taskId deve ser positivo.');

  final AuthSession session;
  final int spaceId;
  final String spaceName;
  final int taskId;
  final String taskDescription;
  final TasksRepository tasksRepository;
  final VoidCallback? onSessionExpired;
  final Future<void> Function()? onLogout;

  @override
  State<TaskExecutionsPage> createState() => _TaskExecutionsPageState();
}

class _TaskExecutionsPageState extends State<TaskExecutionsPage> {
  static const _pageSizeOptions = <int>[5, 10, 20, 50];

  final _scrollController = ScrollController();
  TaskExecutionPageResult? _result;
  ApiFailure? _failure;
  bool _isLoading = false;
  int? _removingExecutionId;
  int _requestGeneration = 0;
  int _requestedPage = 0;
  int _pageSize = 10;

  bool get _isBusy => _isLoading || _removingExecutionId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadExecutions());
  }

  @override
  void didUpdateWidget(covariant TaskExecutionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged =
        oldWidget.session.id != widget.session.id ||
        oldWidget.session.accessToken != widget.session.accessToken;
    final sourceChanged =
        sessionChanged ||
        oldWidget.spaceId != widget.spaceId ||
        oldWidget.taskId != widget.taskId ||
        !identical(oldWidget.tasksRepository, widget.tasksRepository);
    if (!sourceChanged) {
      return;
    }

    _requestGeneration += 1;
    _result = null;
    _failure = null;
    _isLoading = false;
    _removingExecutionId = null;
    _requestedPage = 0;
    _pageSize = 10;
    unawaited(_loadExecutions());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExecutions({int? page, int? size}) async {
    if (_isBusy) {
      return;
    }

    final requestedPage = page ?? _result?.number ?? 0;
    final requestedSize = size ?? _pageSize;
    final requestGeneration = ++_requestGeneration;
    setState(() {
      _requestedPage = requestedPage;
      _pageSize = requestedSize;
      _failure = null;
      _isLoading = true;
    });
    if ((page != null || size != null) && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    try {
      final result = await widget.tasksRepository.fetchTaskExecutions(
        accessToken: widget.session.accessToken,
        spaceId: widget.spaceId,
        taskId: widget.taskId,
        page: requestedPage,
        size: requestedSize,
      );
      if (result.number != requestedPage) {
        throw const ApiFailure(ApiFailureKind.malformedResponse);
      }
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }

      final lastAvailablePage = result.totalPages == 0
          ? 0
          : result.totalPages - 1;
      if (requestedPage > lastAvailablePage) {
        setState(() => _isLoading = false);
        await _loadExecutions(page: lastAvailablePage, size: requestedSize);
        return;
      }

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } on ApiFailure catch (failure) {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      final onSessionExpired = widget.onSessionExpired;
      if (failure.kind == ApiFailureKind.unauthorized &&
          onSessionExpired != null) {
        setState(() => _isLoading = false);
        onSessionExpired();
        return;
      }
      setState(() {
        _failure = failure;
        _isLoading = false;
      });
    } on Object {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() {
        _failure = const ApiFailure(ApiFailureKind.unknown);
        _isLoading = false;
      });
    }
  }

  void _goToPage(int page) {
    final result = _result;
    if (_isBusy ||
        result == null ||
        page < 0 ||
        page >= result.totalPages ||
        page == result.number) {
      return;
    }
    unawaited(_loadExecutions(page: page));
  }

  void _changePageSize(int? size) {
    if (_isBusy ||
        size == null ||
        size == _pageSize ||
        !_pageSizeOptions.contains(size)) {
      return;
    }
    unawaited(_loadExecutions(page: 0, size: size));
  }

  Future<void> _confirmRemoveFromExecution(
    TaskExecutionSummary execution,
  ) async {
    if (_isBusy) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: ValueKey('task-executions-remove-dialog-${execution.id}'),
        title: const Text('Sair da execução'),
        content: Text(
          'Tem certeza disso que deseja se excluir dessa execução?',
          key: ValueKey('task-executions-remove-message-${execution.id}'),
        ),
        actions: [
          TextButton(
            key: ValueKey('task-executions-remove-cancel-${execution.id}'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: ValueKey('task-executions-remove-confirm-${execution.id}'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }

    await _removeFromExecution(execution);
  }

  Future<void> _removeFromExecution(TaskExecutionSummary execution) async {
    if (_isBusy) {
      return;
    }

    final requestGeneration = _requestGeneration;
    setState(() => _removingExecutionId = execution.id);

    try {
      await widget.tasksRepository.removeCurrentUserFromTaskExecution(
        accessToken: widget.session.accessToken,
        spaceId: widget.spaceId,
        taskId: widget.taskId,
        taskExecutionId: execution.id,
      );
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }

      setState(() => _removingExecutionId = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            key: ValueKey('task-execution-removed-message'),
            content: Text('Você saiu desta execução.'),
          ),
        );

      final result = _result;
      await _loadExecutions(
        page: result?.number ?? _requestedPage,
        size: _pageSize,
      );
    } on ApiFailure catch (failure) {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() => _removingExecutionId = null);
      if (failure.kind == ApiFailureKind.unauthorized) {
        widget.onSessionExpired?.call();
        return;
      }
      _showRemoveFromExecutionError(failure);
      if (_shouldRefreshAfterRemovalFailure(failure)) {
        final result = _result;
        await _loadExecutions(
          page: result?.number ?? _requestedPage,
          size: _pageSize,
        );
      }
    } on Object {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() => _removingExecutionId = null);
      const failure = ApiFailure(ApiFailureKind.unknown);
      _showRemoveFromExecutionError(failure);
      final result = _result;
      await _loadExecutions(
        page: result?.number ?? _requestedPage,
        size: _pageSize,
      );
    }
  }

  void _showRemoveFromExecutionError(ApiFailure failure) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('task-execution-remove-error'),
          content: Text(_removeFromExecutionFailureMessage(failure)),
        ),
      );
  }

  Future<void> _showExecutors(TaskExecutionSummary execution) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: ValueKey('task-executions-executors-dialog-${execution.id}'),
        title: const Text('Executores'),
        content: execution.executorNames.isEmpty
            ? Text(
                'Nenhum executor informado.',
                key: ValueKey(
                  'task-executions-executors-empty-${execution.id}',
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < execution.executorNames.length;
                        index += 1
                      )
                        ListTile(
                          key: ValueKey(
                            'task-executions-executor-${execution.id}-$index',
                          ),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline_rounded),
                          title: Text(execution.executorNames[index]),
                        ),
                    ],
                  ),
                ),
              ),
        actions: [
          TextButton(
            key: const ValueKey('task-executions-executors-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execuções'),
        actions: widget.onLogout == null
            ? null
            : [LogoutButton(onLogout: widget.onLogout!)],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _result == null) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('task-executions-loading'),
        ),
      );
    }

    final failure = _failure;
    if (failure != null && _result == null) {
      return _ExecutionsError(
        message: _executionsFailureMessage(failure),
        isRetrying: _isLoading,
        onRetry: () =>
            unawaited(_loadExecutions(page: _requestedPage, size: _pageSize)),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: () => _loadExecutions(page: result.number, size: _pageSize),
      child: ListView(
        key: const ValueKey('task-executions-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _ExecutionsHeader(
            spaceName: widget.spaceName,
            taskDescription: widget.taskDescription,
            total: result.totalElements,
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(
                  key: ValueKey('task-executions-page-progress'),
                ),
              ),
            )
          else if (failure != null)
            _ExecutionsError(
              message: _executionsFailureMessage(failure),
              isRetrying: false,
              onRetry: () => unawaited(
                _loadExecutions(page: _requestedPage, size: _pageSize),
              ),
            )
          else ...[
            if (result.content.isEmpty)
              const _ExecutionsEmpty()
            else
              for (final execution in result.content) ...[
                _ExecutionCard(
                  execution: execution,
                  isRemoving: _removingExecutionId == execution.id,
                  onShowExecutors: () => unawaited(_showExecutors(execution)),
                  onRemoveFromExecution: _removingExecutionId == null
                      ? () => unawaited(_confirmRemoveFromExecution(execution))
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            PagedListPaginationBar(
              keyPrefix: 'task-executions',
              currentPage: result.number,
              pageItemCount: result.content.length,
              totalElements: result.totalElements,
              totalPages: result.totalPages,
              pageSize: _pageSize,
              pageSizeOptions: _pageSizeOptions,
              onPageSelected: _goToPage,
              onPageSizeChanged: _changePageSize,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExecutionsHeader extends StatelessWidget {
  const _ExecutionsHeader({
    required this.spaceName,
    required this.taskDescription,
    required this.total,
  });

  final String spaceName;
  final String taskDescription;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          spaceName,
          key: const ValueKey('task-executions-space-name'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5D716F),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          taskDescription,
          key: const ValueKey('task-executions-task-description'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF173B38),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          total == 1 ? '1 execução encontrada' : '$total execuções encontradas',
          key: const ValueKey('task-executions-total'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5D716F),
          ),
        ),
      ],
    );
  }
}

class _ExecutionCard extends StatelessWidget {
  const _ExecutionCard({
    required this.execution,
    required this.isRemoving,
    required this.onShowExecutors,
    required this.onRemoveFromExecution,
  });

  final TaskExecutionSummary execution;
  final bool isRemoving;
  final VoidCallback onShowExecutors;
  final VoidCallback? onRemoveFromExecution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('task-executions-card-${execution.id}'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDDE8E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2EF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                color: Color(0xFF006C67),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _executionDateLabel(execution.executionDate),
                    key: ValueKey('task-executions-date-${execution.id}'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF173B38),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_scoreLabel(execution.score)} pontos',
                    key: ValueKey('task-executions-score-${execution.id}'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D716F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              key: ValueKey('task-executions-executors-button-${execution.id}'),
              label:
                  'Ver executores da execução de '
                  '${_executionDateLabel(execution.executionDate)}',
              container: true,
              button: true,
              excludeSemantics: true,
              onTap: onShowExecutors,
              child: IconButton(
                tooltip: 'Ver executores',
                onPressed: onShowExecutors,
                icon: const Icon(Icons.groups_outlined),
              ),
            ),
            const SizedBox(width: 4),
            Semantics(
              key: ValueKey('task-executions-remove-button-${execution.id}'),
              label: isRemoving
                  ? 'Saindo da execução'
                  : 'Sair da execução de '
                        '${_executionDateLabel(execution.executionDate)}',
              container: true,
              button: true,
              enabled: onRemoveFromExecution != null,
              excludeSemantics: true,
              onTap: onRemoveFromExecution,
              child: IconButton(
                tooltip: 'Sair da execução',
                onPressed: onRemoveFromExecution,
                icon: isRemoving
                    ? SizedBox.square(
                        key: ValueKey(
                          'task-executions-remove-progress-${execution.id}',
                        ),
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.error,
                        ),
                      )
                    : Icon(
                        Icons.person_remove_outlined,
                        color: theme.colorScheme.error,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutionsEmpty extends StatelessWidget {
  const _ExecutionsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: const ValueKey('task-executions-empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_busy_outlined,
              size: 64,
              color: Color(0xFF6C8582),
            ),
            const SizedBox(height: 18),
            Text(
              'Nenhuma execução foi encontrada para esta tarefa.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutionsError extends StatelessWidget {
  const _ExecutionsError({
    required this.message,
    required this.isRetrying,
    required this.onRetry,
  });

  final String message;
  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            key: const ValueKey('task-executions-error'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 18),
              Text(
                'Não foi possível carregar as execuções',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('task-executions-retry-button'),
                onPressed: isRetrying ? null : onRetry,
                icon: isRetrying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _executionDateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String _scoreLabel(num score) {
  if (score == score.roundToDouble()) {
    return score.toInt().toString();
  }
  return score
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _executionsFailureMessage(ApiFailure failure) {
  return switch (failure.kind) {
    ApiFailureKind.validation => 'A tarefa informada não pôde ser consultada.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Seu acesso não permite consultar as execuções desta tarefa.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout =>
      'A conexão demorou mais que o esperado. Tente novamente.',
    ApiFailureKind.network =>
      'Não foi possível conectar à API. Confira sua conexão.',
    ApiFailureKind.server =>
      'O serviço está temporariamente indisponível. Tente novamente.',
    ApiFailureKind.malformedResponse =>
      'A API retornou uma resposta inesperada.',
    _ => 'Ocorreu um erro inesperado. Tente novamente.',
  };
}

String _removeFromExecutionFailureMessage(ApiFailure failure) {
  if (failure.statusCode == 404) {
    return 'A execução não foi encontrada. A lista será atualizada.';
  }
  return switch (failure.kind) {
    ApiFailureKind.validation =>
      'Não foi possível excluir você desta execução.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Você não tem permissão para sair desta execução.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout ||
    ApiFailureKind.network ||
    ApiFailureKind.server ||
    ApiFailureKind.unknown =>
      'Não foi possível confirmar a alteração. A lista será atualizada.',
    _ => 'Não foi possível sair desta execução agora.',
  };
}

bool _shouldRefreshAfterRemovalFailure(ApiFailure failure) {
  if (failure.statusCode == 404) {
    return true;
  }
  return switch (failure.kind) {
    ApiFailureKind.timeout ||
    ApiFailureKind.network ||
    ApiFailureKind.server ||
    ApiFailureKind.unknown => true,
    _ => false,
  };
}
