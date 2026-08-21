import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/core/presentation/paged_list_pagination_bar.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/presentation/logout_button.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_filters.dart';
import 'package:mobile_flutter/features/tasks/domain/task_page_result.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';
import 'package:mobile_flutter/features/tasks/presentation/create_task_dialog.dart';
import 'package:mobile_flutter/features/tasks/presentation/edit_task_dialog.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({
    required this.session,
    required this.spaceId,
    required this.spaceName,
    required this.tasksRepository,
    this.canEditTasks = false,
    this.onSessionExpired,
    this.onLogout,
    super.key,
  }) : assert(spaceId > 0, 'spaceId deve ser positivo.');

  final AuthSession session;
  final int spaceId;
  final String spaceName;
  final TasksRepository tasksRepository;
  final bool canEditTasks;
  final VoidCallback? onSessionExpired;
  final Future<void> Function()? onLogout;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  static const _pageSizeOptions = <int>[5, 10, 20, 50];

  final _descriptionController = TextEditingController();
  final _scoreController = TextEditingController();
  final _minScoreController = TextEditingController();
  final _maxScoreController = TextEditingController();
  final _scrollController = ScrollController();

  late TaskFilters _appliedFilters;
  TaskPageResult? _result;
  ApiFailure? _failure;
  bool? _selectedActive;
  final Set<TaskCategory> _selectedCategories = <TaskCategory>{};
  bool _isLoading = false;
  int? _togglingTaskId;
  bool _areFiltersExpanded = false;
  String? _filterValidationMessage;
  int _requestGeneration = 0;
  int _requestedPage = 0;
  int _pageSize = 10;

  bool get _isBusy => _isLoading || _togglingTaskId != null;

  @override
  void initState() {
    super.initState();
    _appliedFilters = const TaskFilters();
    unawaited(_loadTasks());
  }

  @override
  void didUpdateWidget(covariant TasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged =
        oldWidget.session.id != widget.session.id ||
        oldWidget.session.accessToken != widget.session.accessToken;
    final sourceChanged =
        sessionChanged ||
        oldWidget.spaceId != widget.spaceId ||
        !identical(oldWidget.tasksRepository, widget.tasksRepository);
    if (!sourceChanged) {
      return;
    }

    _requestGeneration += 1;
    _result = null;
    _failure = null;
    _selectedActive = null;
    _selectedCategories.clear();
    _appliedFilters = const TaskFilters();
    _isLoading = false;
    _togglingTaskId = null;
    _areFiltersExpanded = false;
    _filterValidationMessage = null;
    _requestedPage = 0;
    _pageSize = 10;
    _clearFilterControllers();
    unawaited(_loadTasks(filters: const TaskFilters(), page: 0));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _scoreController.dispose();
    _minScoreController.dispose();
    _maxScoreController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks({TaskFilters? filters, int? page, int? size}) async {
    if (_isBusy) {
      return;
    }

    final requestedFilters = filters ?? _appliedFilters;
    final requestedPage = page ?? _result?.number ?? 0;
    final requestedSize = size ?? _pageSize;
    final requestGeneration = ++_requestGeneration;
    setState(() {
      _appliedFilters = requestedFilters;
      _requestedPage = requestedPage;
      _pageSize = requestedSize;
      _isLoading = true;
      _failure = null;
    });
    if ((filters != null || page != null || size != null) &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    try {
      final result = await widget.tasksRepository.fetchTasks(
        accessToken: widget.session.accessToken,
        spaceId: widget.spaceId,
        filters: requestedFilters,
        page: requestedPage,
        size: requestedSize,
      );
      if (result.number != requestedPage ||
          result.content.any((task) => task.spaceId != widget.spaceId)) {
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
        await _loadTasks(
          filters: requestedFilters,
          page: lastAvailablePage,
          size: requestedSize,
        );
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
      if (failure.kind == ApiFailureKind.unauthorized ||
          failure.kind == ApiFailureKind.forbidden) {
        widget.onSessionExpired?.call();
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

  void _applyFilters() {
    if (_isBusy) {
      return;
    }

    final score = _parseOptionalScore(_scoreController.text);
    final minScore = _parseOptionalScore(_minScoreController.text);
    final maxScore = _parseOptionalScore(_maxScoreController.text);
    if (!score.isValid || !minScore.isValid || !maxScore.isValid) {
      setState(() {
        _filterValidationMessage =
            'Informe pontuações válidas usando números não negativos.';
      });
      return;
    }
    if (minScore.value != null &&
        maxScore.value != null &&
        minScore.value! > maxScore.value!) {
      setState(() {
        _filterValidationMessage =
            'A pontuação mínima não pode ser maior que a máxima.';
      });
      return;
    }

    setState(() => _filterValidationMessage = null);
    unawaited(
      _loadTasks(
        filters: TaskFilters(
          description: _descriptionController.text,
          score: score.value,
          active: _selectedActive,
          categories: Set<TaskCategory>.unmodifiable(_selectedCategories),
          minScore: minScore.value,
          maxScore: maxScore.value,
        ),
        page: 0,
      ),
    );
  }

  void _clearFilters() {
    if (_isBusy) {
      return;
    }
    _clearFilterControllers();
    setState(() {
      _selectedActive = null;
      _selectedCategories.clear();
      _filterValidationMessage = null;
    });
    unawaited(_loadTasks(filters: const TaskFilters(), page: 0));
  }

  void _clearFilterControllers() {
    _descriptionController.clear();
    _scoreController.clear();
    _minScoreController.clear();
    _maxScoreController.clear();
  }

  void _toggleFilters() {
    setState(() => _areFiltersExpanded = !_areFiltersExpanded);
  }

  void _toggleCategory(TaskCategory category, bool selected) {
    setState(() {
      if (selected) {
        _selectedCategories.add(category);
      } else {
        _selectedCategories.remove(category);
      }
    });
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
    unawaited(_loadTasks(page: page));
  }

  void _changePageSize(int? size) {
    if (_isBusy ||
        size == null ||
        size == _pageSize ||
        !_pageSizeOptions.contains(size)) {
      return;
    }
    unawaited(_loadTasks(page: 0, size: size));
  }

  Future<void> _openEditTask(TaskSummary task) async {
    if (_isBusy) {
      return;
    }
    final updatedTask = await showDialog<TaskSummary>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditTaskDialog(
        task: task,
        accessToken: widget.session.accessToken,
        tasksRepository: widget.tasksRepository,
        onSessionExpired: widget.onSessionExpired,
      ),
    );
    if (!mounted || updatedTask == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('task-updated-message'),
          content: Text('Tarefa "${updatedTask.description}" atualizada.'),
        ),
      );

    final result = _result;
    await _loadTasks(page: result?.number ?? _requestedPage, size: _pageSize);
  }

  Future<void> _openCreateTask() async {
    if (_isBusy) {
      return;
    }
    final creatorName = widget.session.name ?? widget.session.username;
    final createdTask = await showDialog<TaskSummary>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateTaskDialog(
        spaceId: widget.spaceId,
        creatorName: creatorName,
        accessToken: widget.session.accessToken,
        tasksRepository: widget.tasksRepository,
        onSessionExpired: widget.onSessionExpired,
      ),
    );
    if (!mounted || createdTask == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('task-created-message'),
          content: Text('Tarefa "${createdTask.description}" criada.'),
        ),
      );

    final result = _result;
    await _loadTasks(page: result?.number ?? _requestedPage, size: _pageSize);
  }

  Future<void> _toggleTaskActive(TaskSummary task) async {
    if (!widget.canEditTasks || _isBusy) {
      return;
    }

    final requestGeneration = _requestGeneration;
    setState(() => _togglingTaskId = task.id);

    try {
      await widget.tasksRepository.toggleTaskActive(
        accessToken: widget.session.accessToken,
        spaceId: widget.spaceId,
        taskId: task.id,
      );
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }

      setState(() => _togglingTaskId = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const ValueKey('task-status-updated-message'),
            content: Text('Status da tarefa "${task.description}" alterado.'),
          ),
        );

      final result = _result;
      await _loadTasks(page: result?.number ?? _requestedPage, size: _pageSize);
    } on ApiFailure catch (failure) {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() => _togglingTaskId = null);
      if (failure.kind == ApiFailureKind.unauthorized) {
        widget.onSessionExpired?.call();
        return;
      }
      _showTaskStatusError(failure);
      if (_shouldRefreshTasksAfterToggleFailure(failure)) {
        final result = _result;
        await _loadTasks(
          page: result?.number ?? _requestedPage,
          size: _pageSize,
        );
      }
    } on Object {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() => _togglingTaskId = null);
      const failure = ApiFailure(ApiFailureKind.unknown);
      _showTaskStatusError(failure);
      final result = _result;
      await _loadTasks(page: result?.number ?? _requestedPage, size: _pageSize);
    }
  }

  void _showTaskStatusError(ApiFailure failure) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('task-status-error'),
          content: Text(_toggleTaskFailureMessage(failure)),
        ),
      );
  }

  bool get _hasActiveFilters {
    return (_appliedFilters.description?.trim().isNotEmpty ?? false) ||
        _appliedFilters.score != null ||
        _appliedFilters.active != null ||
        _appliedFilters.categories.isNotEmpty ||
        _appliedFilters.minScore != null ||
        _appliedFilters.maxScore != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas'),
        actions: widget.onLogout == null
            ? null
            : [LogoutButton(onLogout: widget.onLogout!)],
      ),
      body: SafeArea(child: _buildBody(context)),
      floatingActionButton: widget.canEditTasks
          ? FloatingActionButton.extended(
              key: const ValueKey('create-task-button'),
              onPressed: _isBusy ? null : _openCreateTask,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Nova tarefa'),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _result == null) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('tasks-loading')),
      );
    }

    final failure = _failure;
    if (failure != null && _result == null) {
      return _TasksError(
        message: _failureMessage(failure.kind),
        isRetrying: _isLoading,
        onRetry: () =>
            unawaited(_loadTasks(page: _requestedPage, size: _pageSize)),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: () => _loadTasks(page: result.number, size: _pageSize),
      child: ListView(
        controller: _scrollController,
        key: const ValueKey('tasks-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          widget.canEditTasks ? 100 : 32,
        ),
        children: [
          _TasksHeader(
            spaceName: widget.spaceName,
            total: result.totalElements,
          ),
          const SizedBox(height: 16),
          _TasksFilterPanel(
            descriptionController: _descriptionController,
            scoreController: _scoreController,
            minScoreController: _minScoreController,
            maxScoreController: _maxScoreController,
            selectedActive: _selectedActive,
            selectedCategories: _selectedCategories,
            isLoading: _isBusy,
            isExpanded: _areFiltersExpanded,
            hasActiveFilters: _hasActiveFilters,
            validationMessage: _filterValidationMessage,
            onActiveChanged: (active) =>
                setState(() => _selectedActive = active),
            onCategoryChanged: _toggleCategory,
            onToggle: _toggleFilters,
            onApply: _applyFilters,
            onClear: _clearFilters,
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(
                  key: ValueKey('tasks-filter-progress'),
                ),
              ),
            )
          else if (failure != null)
            _TasksError(
              message: _failureMessage(failure.kind),
              isRetrying: false,
              onRetry: () =>
                  unawaited(_loadTasks(page: _requestedPage, size: _pageSize)),
            )
          else ...[
            if (result.content.isEmpty)
              _TasksEmpty(isFiltered: _hasActiveFilters)
            else
              for (final task in result.content) ...[
                _TaskCard(
                  task: task,
                  canEdit: widget.canEditTasks,
                  isToggling: _togglingTaskId == task.id,
                  onToggleActive: widget.canEditTasks && !_isBusy
                      ? () => _toggleTaskActive(task)
                      : null,
                  onEdit: widget.canEditTasks && !_isBusy
                      ? () => _openEditTask(task)
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            PagedListPaginationBar(
              keyPrefix: 'tasks',
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

class _TasksHeader extends StatelessWidget {
  const _TasksHeader({required this.spaceName, required this.total});

  final String spaceName;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          spaceName,
          key: const ValueKey('tasks-space-name'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF173B38),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          total == 1 ? '1 tarefa encontrada' : '$total tarefas encontradas',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5D716F),
          ),
        ),
      ],
    );
  }
}

class _TasksFilterPanel extends StatelessWidget {
  const _TasksFilterPanel({
    required this.descriptionController,
    required this.scoreController,
    required this.minScoreController,
    required this.maxScoreController,
    required this.selectedActive,
    required this.selectedCategories,
    required this.isLoading,
    required this.isExpanded,
    required this.hasActiveFilters,
    required this.validationMessage,
    required this.onActiveChanged,
    required this.onCategoryChanged,
    required this.onToggle,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController descriptionController;
  final TextEditingController scoreController;
  final TextEditingController minScoreController;
  final TextEditingController maxScoreController;
  final bool? selectedActive;
  final Set<TaskCategory> selectedCategories;
  final bool isLoading;
  final bool isExpanded;
  final bool hasActiveFilters;
  final String? validationMessage;
  final ValueChanged<bool?> onActiveChanged;
  final void Function(TaskCategory category, bool selected) onCategoryChanged;
  final VoidCallback onToggle;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDDE8E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buscar e filtrar',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF173B38),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hasActiveFilters) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Filtros ativos',
                          key: const ValueKey('tasks-active-filters'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF37615E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('tasks-toggle-filters'),
                  onPressed: onToggle,
                  icon: Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  label: Text(isExpanded ? 'Contrair' : 'Expandir'),
                ),
              ],
            ),
            if (isExpanded)
              Column(
                key: const ValueKey('tasks-filter-panel'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('tasks-description-filter'),
                    controller: descriptionController,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Digite parte da descrição',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: (_) => onApply(),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Situação'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<bool>(
                        key: const ValueKey('tasks-active-filter'),
                        value: selectedActive,
                        isDense: true,
                        isExpanded: true,
                        hint: const Text('Todas'),
                        items: const [
                          DropdownMenuItem<bool>(
                            value: null,
                            child: Text('Todas'),
                          ),
                          DropdownMenuItem<bool>(
                            value: true,
                            child: Text('Ativas'),
                          ),
                          DropdownMenuItem<bool>(
                            value: false,
                            child: Text('Inativas'),
                          ),
                        ],
                        onChanged: isLoading ? null : onActiveChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Categorias',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF173B38),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in TaskCategory.values)
                        FilterChip(
                          key: ValueKey('tasks-category-${category.name}'),
                          label: Text(_categoryLabel(category)),
                          selected: selectedCategories.contains(category),
                          onSelected: isLoading
                              ? null
                              : (selected) =>
                                    onCategoryChanged(category, selected),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final fields = <Widget>[
                        _ScoreField(
                          fieldKey: const ValueKey('tasks-score-filter'),
                          controller: scoreController,
                          label: 'Pontuação exata',
                          enabled: !isLoading,
                        ),
                        _ScoreField(
                          fieldKey: const ValueKey('tasks-min-score-filter'),
                          controller: minScoreController,
                          label: 'Pontuação mínima',
                          enabled: !isLoading,
                        ),
                        _ScoreField(
                          fieldKey: const ValueKey('tasks-max-score-filter'),
                          controller: maxScoreController,
                          label: 'Pontuação máxima',
                          enabled: !isLoading,
                        ),
                      ];
                      if (constraints.maxWidth >= 720) {
                        return Row(
                          children: [
                            for (
                              var index = 0;
                              index < fields.length;
                              index++
                            ) ...[
                              Expanded(child: fields[index]),
                              if (index < fields.length - 1)
                                const SizedBox(width: 10),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: [
                          for (
                            var index = 0;
                            index < fields.length;
                            index++
                          ) ...[
                            fields[index],
                            if (index < fields.length - 1)
                              const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
                  if (validationMessage != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        validationMessage!,
                        key: const ValueKey('tasks-filter-error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        key: const ValueKey('tasks-clear-filters'),
                        onPressed: isLoading ? null : onClear,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Limpar filtros'),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('tasks-apply-filters'),
                        onPressed: isLoading ? null : onApply,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Aplicar filtros'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreField extends StatelessWidget {
  const _ScoreField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: 'Ex.: 10,5'),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.canEdit,
    required this.isToggling,
    required this.onToggleActive,
    required this.onEdit,
  });

  final TaskSummary task;
  final bool canEdit;
  final bool isToggling;
  final VoidCallback? onToggleActive;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('task-card-${task.id}'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDDE8E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2EF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    task.active
                        ? Icons.task_alt_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: const Color(0xFF006C67),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.description,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF173B38),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (task.creatorName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Criada por: ${task.creatorName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5D716F),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    key: ValueKey('task-edit-button-${task.id}'),
                    tooltip: 'Editar tarefa',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TaskInfoChip(
                  icon: Icons.stars_outlined,
                  label: '${_scoreLabel(task.score)} pontos',
                ),
                _TaskInfoChip(
                  icon: task.category == TaskCategory.financial
                      ? Icons.payments_outlined
                      : Icons.build_outlined,
                  label: _categoryLabel(task.category),
                ),
                _TaskStatusChip(
                  key: ValueKey('task-active-toggle-${task.id}'),
                  active: task.active,
                  canToggle: canEdit,
                  isToggling: isToggling,
                  onPressed: onToggleActive,
                ),
                if (task.schedule case final schedule?)
                  _TaskInfoChip(
                    icon: Icons.event_repeat_outlined,
                    label: _scheduleLabel(schedule),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({
    required this.active,
    required this.canToggle,
    required this.isToggling,
    required this.onPressed,
    super.key,
  });

  final bool active;
  final bool canToggle;
  final bool isToggling;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = active ? 'Ativa' : 'Inativa';
    final actionLabel = active ? 'Desativar tarefa' : 'Ativar tarefa';
    final tooltip = isToggling
        ? 'Alterando status da tarefa'
        : canToggle
        ? actionLabel
        : label;
    return Semantics(
      button: canToggle,
      enabled: onPressed != null,
      liveRegion: isToggling,
      label: tooltip,
      value: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: const Color(0xFFF1F6F5),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(999),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isToggling)
                        const SizedBox.square(
                          key: ValueKey('task-status-progress'),
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          active
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 16,
                          color: const Color(0xFF37615E),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFF37615E),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskInfoChip extends StatelessWidget {
  const _TaskInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF37615E)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF37615E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksEmpty extends StatelessWidget {
  const _TasksEmpty({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: ValueKey(isFiltered ? 'tasks-filter-empty' : 'tasks-empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_outlined, size: 64, color: Color(0xFF6C8582)),
            const SizedBox(height: 18),
            Text(
              isFiltered
                  ? 'Nenhuma tarefa corresponde aos filtros.'
                  : 'Nenhuma tarefa foi encontrada neste espaço.',
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

class _TasksError extends StatelessWidget {
  const _TasksError({
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
            key: const ValueKey('tasks-error'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 18),
              Text(
                'Não foi possível carregar as tarefas',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('tasks-retry-button'),
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

({num? value, bool isValid}) _parseOptionalScore(String rawValue) {
  final normalizedValue = rawValue.trim().replaceAll(',', '.');
  if (normalizedValue.isEmpty) {
    return (value: null, isValid: true);
  }
  final value = num.tryParse(normalizedValue);
  return (value: value, isValid: value != null && value.isFinite && value >= 0);
}

String _categoryLabel(TaskCategory category) {
  return switch (category) {
    TaskCategory.operational => 'Operacional',
    TaskCategory.financial => 'Financeira',
  };
}

String _scoreLabel(num score) {
  if (score == score.roundToDouble()) {
    return score.toStringAsFixed(0);
  }
  return score.toString();
}

String _scheduleLabel(TaskScheduleSummary schedule) {
  final frequency = switch (schedule.frequency) {
    TaskFrequency.once => 'Uma vez',
    TaskFrequency.daily => 'Diária',
    TaskFrequency.weekly => 'Semanal',
    TaskFrequency.monthly => 'Mensal',
    TaskFrequency.yearly => 'Anual',
  };
  if (schedule.localDates.isEmpty) {
    return frequency;
  }
  final firstDate = schedule.localDates.first;
  final formattedDate =
      '${firstDate.day.toString().padLeft(2, '0')}/'
      '${firstDate.month.toString().padLeft(2, '0')}/'
      '${firstDate.year}';
  return '$frequency · $formattedDate';
}

String _failureMessage(ApiFailureKind kind) {
  return switch (kind) {
    ApiFailureKind.validation =>
      'Os filtros informados não puderam ser processados.',
    ApiFailureKind.unauthorized =>
      'Sua sessão não pôde ser autenticada. Tente entrar novamente.',
    ApiFailureKind.forbidden =>
      'Seu acesso não permite consultar as tarefas deste espaço.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde um pouco e tente novamente.',
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

String _toggleTaskFailureMessage(ApiFailure failure) {
  if (failure.statusCode == 404) {
    return 'A tarefa não foi encontrada. Atualize a lista e tente novamente.';
  }
  return switch (failure.kind) {
    ApiFailureKind.validation =>
      'Não foi possível alterar o status desta tarefa.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Você não tem permissão para alterar o status desta tarefa.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout ||
    ApiFailureKind.network ||
    ApiFailureKind.server ||
    ApiFailureKind.unknown =>
      'Não foi possível confirmar a alteração. A lista será atualizada '
          'para conferir o status.',
    _ => 'Não foi possível alterar o status da tarefa agora.',
  };
}

bool _shouldRefreshTasksAfterToggleFailure(ApiFailure failure) {
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
