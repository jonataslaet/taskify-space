import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_summary.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';

class ConfirmTaskExecutionDialog extends StatefulWidget {
  const ConfirmTaskExecutionDialog({
    required this.task,
    required this.session,
    required this.tasksRepository,
    required this.spacesRepository,
    required this.initialExecutionDate,
    this.onSessionExpired,
    super.key,
  });

  final TaskSummary task;
  final AuthSession session;
  final TasksRepository tasksRepository;
  final SpacesRepository spacesRepository;
  final DateTime initialExecutionDate;
  final VoidCallback? onSessionExpired;

  @override
  State<ConfirmTaskExecutionDialog> createState() =>
      _ConfirmTaskExecutionDialogState();
}

class _ConfirmTaskExecutionDialogState
    extends State<ConfirmTaskExecutionDialog> {
  late DateTime _executionDate;
  late Map<int, SpaceParticipantSummary> _selectedExecutors;
  bool _isSubmitting = false;
  bool _hasUncertainOutcome = false;
  String? _errorMessage;

  bool get _canEdit => !_isSubmitting && !_hasUncertainOutcome;

  @override
  void initState() {
    super.initState();
    _executionDate = _asCivilUtc(widget.initialExecutionDate);
    final currentUser = SpaceParticipantSummary(
      id: widget.session.id,
      name: widget.session.name ?? widget.session.username,
    );
    _selectedExecutors = <int, SpaceParticipantSummary>{
      currentUser.id: currentUser,
    };
  }

  Future<void> _pickExecutionDateTime() async {
    if (!_canEdit) {
      return;
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(
        _executionDate.year,
        _executionDate.month,
        _executionDate.day,
      ),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: 'Data da execução',
      cancelText: 'Cancelar',
      confirmText: 'Continuar',
    );
    if (!mounted || selectedDate == null) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_executionDate),
      helpText: 'Hora da execução',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (!mounted || selectedTime == null) {
      return;
    }

    setState(() {
      _executionDate = DateTime.utc(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  Future<void> _openExecutorSelector() async {
    if (!_canEdit) {
      return;
    }

    final selected = await showDialog<List<SpaceParticipantSummary>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExecutorSelectorDialog(
        accessToken: widget.session.accessToken,
        spaceId: widget.task.spaceId,
        spacesRepository: widget.spacesRepository,
        initialSelection: _selectedExecutors.values.toList(growable: false),
        authenticatedUserId: widget.session.id,
        onSessionExpired: widget.onSessionExpired,
      ),
    );
    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedExecutors = <int, SpaceParticipantSummary>{
        for (final participant in selected) participant.id: participant,
        widget.session.id: _selectedExecutors[widget.session.id]!,
      };
    });
  }

  void _removeExecutor(int participantId) {
    if (!_canEdit || participantId == widget.session.id) {
      return;
    }
    setState(() => _selectedExecutors.remove(participantId));
  }

  Future<void> _submit() async {
    if (!_canEdit) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.tasksRepository.confirmTaskExecution(
        accessToken: widget.session.accessToken,
        spaceId: widget.task.spaceId,
        taskId: widget.task.id,
        executorIds: Set<int>.unmodifiable(
          _selectedExecutors.keys.where((id) => id != widget.session.id),
        ),
        executionDate: _executionDate,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      if (failure.kind == ApiFailureKind.unauthorized &&
          widget.onSessionExpired != null) {
        setState(() => _isSubmitting = false);
        widget.onSessionExpired!.call();
        return;
      }
      setState(() {
        _isSubmitting = false;
        _hasUncertainOutcome = _isConfirmationOutcomeUncertain(failure);
        _errorMessage = _confirmationFailureMessage(failure);
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _hasUncertainOutcome = true;
        _errorMessage = _confirmationFailureMessage(
          const ApiFailure(ApiFailureKind.unknown),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedExecutors = _selectedExecutors.values.toList(growable: false);
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        key: const ValueKey('confirm-task-execution-dialog'),
        title: const Text('Registrar execução'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.task.description,
                  key: const ValueKey('confirm-task-execution-task'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF173B38),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Confirme quando a tarefa foi executada e quem participou.',
                ),
                const SizedBox(height: 20),
                Semantics(
                  key: const ValueKey('confirm-task-execution-date-time-field'),
                  button: true,
                  enabled: _canEdit,
                  label:
                      'Alterar data e hora da execução, '
                      '${_formatExecutionDateTime(_executionDate)}',
                  excludeSemantics: true,
                  onTap: _canEdit ? _pickExecutionDateTime : null,
                  child: InkWell(
                    onTap: _canEdit ? _pickExecutionDateTime : null,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      isEmpty: false,
                      decoration: InputDecoration(
                        enabled: _canEdit,
                        labelText: 'Data e hora da execução',
                        suffixIcon: const Icon(Icons.edit_calendar_outlined),
                      ),
                      child: Text(_formatExecutionDateTime(_executionDate)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  key: const ValueKey('confirm-task-execution-executors-field'),
                  button: true,
                  enabled: _canEdit,
                  label: selectedExecutors.isEmpty
                      ? 'Selecionar executores, nenhum selecionado'
                      : 'Selecionar executores, '
                            '${selectedExecutors.length} selecionados',
                  excludeSemantics: true,
                  onTap: _canEdit ? _openExecutorSelector : null,
                  child: InkWell(
                    onTap: _canEdit ? _openExecutorSelector : null,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      isEmpty: selectedExecutors.isEmpty,
                      decoration: InputDecoration(
                        enabled: _canEdit,
                        labelText: 'Executores',
                        suffixIcon: const Icon(Icons.group_add_outlined),
                      ),
                      child: Text(
                        selectedExecutors.isEmpty
                            ? 'Nenhum executor selecionado'
                            : selectedExecutors.length == 1
                            ? '1 executor selecionado'
                            : '${selectedExecutors.length} executores selecionados',
                      ),
                    ),
                  ),
                ),
                if (selectedExecutors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    key: const ValueKey(
                      'confirm-task-execution-selected-executors',
                    ),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final participant in selectedExecutors)
                        InputChip(
                          key: ValueKey(
                            'confirm-task-execution-selected-executor-'
                            '${participant.id}',
                          ),
                          label: Text(
                            participant.id == widget.session.id
                                ? '${participant.name} (você)'
                                : participant.name,
                          ),
                          onDeleted:
                              _canEdit && participant.id != widget.session.id
                              ? () => _removeExecutor(participant.id)
                              : null,
                        ),
                    ],
                  ),
                ],
                if (_errorMessage case final error?) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      key: const ValueKey('confirm-task-execution-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('confirm-task-execution-cancel-button'),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: Text(_hasUncertainOutcome ? 'Fechar' : 'Cancelar'),
          ),
          FilledButton.icon(
            key: const ValueKey('confirm-task-execution-submit-button'),
            onPressed: _canEdit ? _submit : null,
            icon: _isSubmitting
                ? const SizedBox.square(
                    key: ValueKey('confirm-task-execution-progress'),
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.task_alt_rounded),
            label: Text(_isSubmitting ? 'Registrando...' : 'Registrar'),
          ),
        ],
      ),
    );
  }
}

class _ExecutorSelectorDialog extends StatefulWidget {
  const _ExecutorSelectorDialog({
    required this.accessToken,
    required this.spaceId,
    required this.spacesRepository,
    required this.initialSelection,
    required this.authenticatedUserId,
    required this.onSessionExpired,
  });

  final String accessToken;
  final int spaceId;
  final SpacesRepository spacesRepository;
  final List<SpaceParticipantSummary> initialSelection;
  final int authenticatedUserId;
  final VoidCallback? onSessionExpired;

  @override
  State<_ExecutorSelectorDialog> createState() =>
      _ExecutorSelectorDialogState();
}

class _ExecutorSelectorDialogState extends State<_ExecutorSelectorDialog> {
  static const _debounceDuration = Duration(milliseconds: 350);

  final _searchController = TextEditingController();
  late Map<int, SpaceParticipantSummary> _selected;
  Timer? _debounce;
  List<SpaceParticipantSummary> _results = const [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selected = <int, SpaceParticipantSummary>{
      for (final participant in widget.initialSelection)
        participant.id: participant,
    };
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _requestGeneration += 1;
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String rawQuery) {
    _debounce?.cancel();
    final query = rawQuery.trim();
    final requestGeneration = ++_requestGeneration;
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _isLoading = false;
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _debounce = Timer(
      _debounceDuration,
      () => unawaited(_search(query, requestGeneration)),
    );
  }

  Future<void> _search(String query, int requestGeneration) async {
    try {
      final participants = await widget.spacesRepository
          .searchSpaceParticipants(
            accessToken: widget.accessToken,
            spaceId: widget.spaceId,
            name: query,
          );
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      final participantsById = <int, SpaceParticipantSummary>{
        for (final participant in participants) participant.id: participant,
      };
      setState(() {
        _results = participantsById.values.toList(growable: false);
        _isLoading = false;
        _hasSearched = true;
      });
    } on ApiFailure catch (failure) {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      if (failure.kind == ApiFailureKind.unauthorized &&
          widget.onSessionExpired != null) {
        setState(() => _isLoading = false);
        widget.onSessionExpired!.call();
        return;
      }
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _errorMessage = _participantSearchFailureMessage(failure.kind);
      });
    } on Object {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _errorMessage = _participantSearchFailureMessage(
          ApiFailureKind.unknown,
        );
      });
    }
  }

  void _toggleParticipant(SpaceParticipantSummary participant, bool selected) {
    setState(() {
      if (selected) {
        _selected[participant.id] = participant;
      } else {
        _selected.remove(participant.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected.values.toList(growable: false);
    return AlertDialog(
      key: const ValueKey('confirm-task-execution-executor-selector'),
      title: const Text('Selecionar executores'),
      content: SizedBox(
        width: 520,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey(
                'confirm-task-execution-executor-search-field',
              ),
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Buscar participante',
                hintText: 'Digite parte do nome',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: _scheduleSearch,
              onSubmitted: (query) {
                _debounce?.cancel();
                final normalizedQuery = query.trim();
                final requestGeneration = ++_requestGeneration;
                if (normalizedQuery.isEmpty) {
                  _scheduleSearch('');
                  return;
                }
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                unawaited(_search(normalizedQuery, requestGeneration));
              },
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  key: const ValueKey(
                    'confirm-task-execution-executor-selection',
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: selected.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final participant = selected[index];
                    return InputChip(
                      key: ValueKey(
                        'confirm-task-execution-executor-selection-'
                        '${participant.id}',
                      ),
                      label: Text(
                        participant.id == widget.authenticatedUserId
                            ? '${participant.name} (você)'
                            : participant.name,
                      ),
                      onDeleted: participant.id == widget.authenticatedUserId
                          ? null
                          : () => _toggleParticipant(participant, false),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(child: _buildSearchBody()),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('confirm-task-execution-executor-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('confirm-task-execution-executor-apply-button'),
          onPressed: () => Navigator.of(
            context,
          ).pop(_selected.values.toList(growable: false)),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  Widget _buildSearchBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('confirm-task-execution-executor-search-progress'),
        ),
      );
    }
    if (_errorMessage case final error?) {
      return Center(
        child: Semantics(
          liveRegion: true,
          child: Text(
            error,
            key: const ValueKey('confirm-task-execution-executor-search-error'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Digite um nome para buscar participantes.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum participante encontrado.',
          key: ValueKey('confirm-task-execution-executor-search-empty'),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('confirm-task-execution-executor-results'),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final participant = _results[index];
        final isAuthenticatedUser =
            participant.id == widget.authenticatedUserId;
        return CheckboxListTile(
          key: ValueKey(
            'confirm-task-execution-executor-option-${participant.id}',
          ),
          value: isAuthenticatedUser || _selected.containsKey(participant.id),
          onChanged: isAuthenticatedUser
              ? null
              : (selected) =>
                    _toggleParticipant(participant, selected ?? false),
          title: Text(
            isAuthenticatedUser
                ? '${participant.name} (você)'
                : participant.name,
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }
}

DateTime _asCivilUtc(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day, date.hour, date.minute);
}

String _formatExecutionDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

bool _isConfirmationOutcomeUncertain(ApiFailure failure) {
  if (failure.statusCode == 404) {
    return false;
  }
  return switch (failure.kind) {
    ApiFailureKind.timeout ||
    ApiFailureKind.network ||
    ApiFailureKind.server ||
    ApiFailureKind.malformedResponse ||
    ApiFailureKind.unknown => true,
    _ => false,
  };
}

String _confirmationFailureMessage(ApiFailure failure) {
  if (failure.statusCode == 404) {
    return 'A tarefa ou o espaço não foi encontrado.';
  }
  return switch (failure.kind) {
    ApiFailureKind.validation =>
      'Não foi possível registrar com os dados informados.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Esta tarefa está inativa ou seu acesso não permite registrar a execução.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout ||
    ApiFailureKind.network ||
    ApiFailureKind.server ||
    ApiFailureKind.malformedResponse ||
    ApiFailureKind.unknown =>
      'A confirmação não pôde ser verificada. Para evitar duplicidade, feche '
          'e confira o histórico antes de tentar novamente.',
    _ => 'Não foi possível registrar a execução agora.',
  };
}

String _participantSearchFailureMessage(ApiFailureKind kind) {
  return switch (kind) {
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Seu acesso não permite consultar os participantes deste espaço.',
    ApiFailureKind.rateLimited =>
      'Muitas buscas foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout => 'A busca demorou mais que o esperado.',
    ApiFailureKind.network => 'Não foi possível conectar à API.',
    ApiFailureKind.server => 'O serviço de busca está indisponível.',
    ApiFailureKind.malformedResponse =>
      'A API retornou participantes em um formato inesperado.',
    _ => 'Não foi possível buscar participantes agora.',
  };
}
