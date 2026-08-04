import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';

class EditTaskDialog extends StatefulWidget {
  const EditTaskDialog({
    required this.task,
    required this.accessToken,
    required this.tasksRepository,
    this.onSessionExpired,
    super.key,
  });

  final TaskSummary task;
  final String accessToken;
  final TasksRepository tasksRepository;
  final VoidCallback? onSessionExpired;

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _scoreController;
  late final TextEditingController _datesController;
  late TaskCategory _category;
  late bool _hasSchedule;
  TaskFrequency? _frequency;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final schedule = widget.task.schedule;
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _scoreController = TextEditingController(
      text: _formatScore(widget.task.score),
    );
    _datesController = TextEditingController(
      text: schedule == null ? '' : _formatDates(schedule.localDates),
    );
    _category = widget.task.category;
    _hasSchedule = schedule != null;
    _frequency = schedule?.frequency;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _scoreController.dispose();
    _datesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final score = _parseScore(_scoreController.text).value!;
    final dates = _hasSchedule
        ? _parseDates(_datesController.text).value!
        : null;
    final schedule = _hasSchedule
        ? TaskScheduleSummary(localDates: dates!, frequency: _frequency!)
        : null;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updatedTask = await widget.tasksRepository.updateTask(
        accessToken: widget.accessToken,
        taskId: widget.task.id,
        update: TaskUpdate(
          description: _descriptionController.text.trim(),
          score: score,
          category: _category,
          schedule: schedule,
        ),
      );
      if (updatedTask.id != widget.task.id ||
          updatedTask.spaceId != widget.task.spaceId) {
        throw const ApiFailure(ApiFailureKind.malformedResponse);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updatedTask);
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      if (failure.kind == ApiFailureKind.unauthorized) {
        setState(() => _isSubmitting = false);
        widget.onSessionExpired?.call();
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = _updateFailureMessage(failure);
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = _updateFailureMessage(
          const ApiFailure(ApiFailureKind.unknown),
        );
      });
    }
  }

  String? _validateDescription(String? value) {
    final description = value?.trim() ?? '';
    if (description.isEmpty) {
      return 'Informe a descrição da tarefa.';
    }
    if (description.length > 255) {
      return 'A descrição deve ter no máximo 255 caracteres.';
    }
    return null;
  }

  String? _validateScore(String? value) {
    return _parseScore(value ?? '').error;
  }

  String? _validateDates(String? value) {
    if (!_hasSchedule) {
      return null;
    }
    return _parseDates(value ?? '').error;
  }

  @override
  Widget build(BuildContext context) {
    final readOnlyDetails = <String>[
      widget.task.active ? 'Ativa' : 'Inativa',
      if (widget.task.creatorName case final creator?) 'Criada por $creator',
    ].join(' · ');

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: const Text('Editar tarefa'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    readOnlyDetails,
                    key: const ValueKey('edit-task-read-only-details'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('edit-task-description-field'),
                    controller: _descriptionController,
                    enabled: !_isSubmitting,
                    autofocus: true,
                    maxLength: 255,
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                    validator: _validateDescription,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('edit-task-score-field'),
                    controller: _scoreController,
                    enabled: !_isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Pontuação',
                      hintText: 'Ex.: 80,00',
                    ),
                    validator: _validateScore,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskCategory>(
                    key: const ValueKey('edit-task-category-field'),
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      for (final category in TaskCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Text(_categoryLabel(category)),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (category) {
                            if (category != null) {
                              setState(() => _category = category);
                            }
                          },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    key: const ValueKey('edit-task-schedule-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Possui agenda'),
                    subtitle: const Text(
                      'Desligar esta opção remove a agenda atual.',
                    ),
                    value: _hasSchedule,
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _hasSchedule = value),
                  ),
                  if (_hasSchedule) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TaskFrequency>(
                      key: const ValueKey('edit-task-frequency-field'),
                      initialValue: _frequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequência',
                      ),
                      items: [
                        for (final frequency in TaskFrequency.values)
                          DropdownMenuItem(
                            value: frequency,
                            child: Text(_frequencyLabel(frequency)),
                          ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (frequency) =>
                                setState(() => _frequency = frequency),
                      validator: (frequency) => frequency == null
                          ? 'Informe a frequência da agenda.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('edit-task-dates-field'),
                      controller: _datesController,
                      enabled: !_isSubmitting,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Datas da agenda',
                        hintText: '2024-02-29, 2024-03-07',
                        helperText:
                            'Use AAAA-MM-DD e separe as datas por vírgula ou linha.',
                      ),
                      validator: _validateDates,
                    ),
                  ],
                  if (_errorMessage case final error?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const ValueKey('edit-task-error'),
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
        ),
        actions: [
          TextButton(
            key: const ValueKey('edit-task-cancel-button'),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            key: const ValueKey('edit-task-submit-button'),
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox.square(
                    key: ValueKey('edit-task-progress'),
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSubmitting ? 'Atualizando...' : 'Atualizar'),
          ),
        ],
      ),
    );
  }
}

({num? value, String? error}) _parseScore(String rawValue) {
  final normalized = rawValue.trim().replaceAll(',', '.');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) {
    return (
      value: null,
      error: 'Informe uma pontuação positiva com até duas casas decimais.',
    );
  }

  final integerDigits = match.group(1)!.replaceFirst(RegExp(r'^0+'), '');
  final value = num.tryParse(normalized);
  if (value == null ||
      !value.isFinite ||
      value <= 0 ||
      (integerDigits.isEmpty ? 1 : integerDigits.length) > 36) {
    return (
      value: null,
      error: 'Informe uma pontuação positiva com até 36 dígitos inteiros.',
    );
  }
  return (value: value, error: null);
}

({List<DateTime>? value, String? error}) _parseDates(String rawValue) {
  final parts = rawValue
      .split(RegExp(r'[,;\n\r]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return (value: null, error: 'Informe ao menos uma data para a agenda.');
  }

  final datesByValue = <String, DateTime>{};
  for (final part in parts) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(part);
    if (match == null) {
      return (value: null, error: 'Use datas válidas no formato AAAA-MM-DD.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);
    if (year < 1 ||
        date.year != year ||
        date.month != month ||
        date.day != day) {
      return (value: null, error: 'Use datas válidas no formato AAAA-MM-DD.');
    }
    datesByValue[_formatDate(date)] = date;
  }

  final dates = datesByValue.values.toList()
    ..sort((first, second) => first.compareTo(second));
  return (value: dates, error: null);
}

String _formatDates(List<DateTime> dates) {
  final sortedDates = [...dates]
    ..sort((first, second) => first.compareTo(second));
  return sortedDates.map(_formatDate).join(', ');
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatScore(num score) {
  return score == score.roundToDouble()
      ? score.toStringAsFixed(0)
      : score.toString();
}

String _categoryLabel(TaskCategory category) {
  return switch (category) {
    TaskCategory.operational => 'Operacional',
    TaskCategory.financial => 'Financeira',
  };
}

String _frequencyLabel(TaskFrequency frequency) {
  return switch (frequency) {
    TaskFrequency.once => 'Uma vez',
    TaskFrequency.daily => 'Diária',
    TaskFrequency.monthly => 'Mensal',
    TaskFrequency.weekly => 'Semanal',
    TaskFrequency.yearly => 'Anual',
  };
}

String _updateFailureMessage(ApiFailure failure) {
  if (failure.statusCode == 409) {
    return 'Já existe outra tarefa com esta descrição no espaço.';
  }
  return switch (failure.kind) {
    ApiFailureKind.validation => 'Confira os dados informados.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Você não tem mais permissão para editar esta tarefa.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout =>
      'A API não confirmou a atualização a tempo. Você pode tentar novamente.',
    ApiFailureKind.network =>
      'Não foi possível confirmar a atualização. Confira sua conexão.',
    ApiFailureKind.server =>
      'O serviço está temporariamente indisponível. Tente novamente.',
    ApiFailureKind.malformedResponse =>
      'A API retornou uma tarefa diferente da esperada.',
    _ => 'Não foi possível atualizar a tarefa agora. Tente novamente.',
  };
}
