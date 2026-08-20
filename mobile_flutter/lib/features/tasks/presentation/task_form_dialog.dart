import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_schedule_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/task_update.dart';

typedef TaskFormSubmit = Future<TaskSummary> Function(TaskUpdate task);
typedef TaskFormFailureMessage = String Function(ApiFailure failure);

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({
    required this.keyPrefix,
    required this.title,
    required this.details,
    required this.initialDescription,
    required this.initialScore,
    required this.initialCategory,
    required this.initialSchedule,
    required this.scheduleSubtitle,
    required this.submitLabel,
    required this.submittingLabel,
    required this.submitIcon,
    required this.onSubmit,
    required this.failureMessage,
    this.creationOutcomeCanBeUncertain = false,
    this.onSessionExpired,
    super.key,
  });

  final String keyPrefix;
  final String title;
  final String details;
  final String initialDescription;
  final num? initialScore;
  final TaskCategory initialCategory;
  final TaskScheduleSummary? initialSchedule;
  final String scheduleSubtitle;
  final String submitLabel;
  final String submittingLabel;
  final IconData submitIcon;
  final TaskFormSubmit onSubmit;
  final TaskFormFailureMessage failureMessage;
  final bool creationOutcomeCanBeUncertain;
  final VoidCallback? onSessionExpired;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _scoreController;
  late final TextEditingController _datesController;
  late TaskCategory _category;
  late bool _hasSchedule;
  TaskFrequency? _frequency;
  bool _isSubmitting = false;
  bool _hasUncertainOutcome = false;
  String? _errorMessage;

  bool get _canEdit => !_isSubmitting && !_hasUncertainOutcome;

  @override
  void initState() {
    super.initState();
    final schedule = widget.initialSchedule;
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _scoreController = TextEditingController(
      text: widget.initialScore == null
          ? ''
          : _formatScore(widget.initialScore!),
    );
    _datesController = TextEditingController(
      text: schedule == null ? '' : _formatDates(schedule.localDates),
    );
    _category = widget.initialCategory;
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
    if (!_canEdit || !(_formKey.currentState?.validate() ?? false)) {
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
      final task = await widget.onSubmit(
        TaskUpdate(
          description: _descriptionController.text.trim(),
          score: score,
          category: _category,
          schedule: schedule,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(task);
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
        _hasUncertainOutcome =
            widget.creationOutcomeCanBeUncertain &&
            _isCreationOutcomeUncertain(failure.kind);
        _errorMessage = widget.failureMessage(failure);
      });
    } on Object {
      if (!mounted) {
        return;
      }
      const failure = ApiFailure(ApiFailureKind.unknown);
      setState(() {
        _isSubmitting = false;
        _hasUncertainOutcome = widget.creationOutcomeCanBeUncertain;
        _errorMessage = widget.failureMessage(failure);
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
    final keyPrefix = widget.keyPrefix;
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: Text(widget.title),
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
                    widget.details,
                    key: ValueKey('$keyPrefix-read-only-details'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: ValueKey('$keyPrefix-description-field'),
                    controller: _descriptionController,
                    enabled: _canEdit,
                    autofocus: true,
                    maxLength: 255,
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                    validator: _validateDescription,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey('$keyPrefix-score-field'),
                    controller: _scoreController,
                    enabled: _canEdit,
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
                    key: ValueKey('$keyPrefix-category-field'),
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      for (final category in TaskCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Text(_categoryLabel(category)),
                        ),
                    ],
                    onChanged: _canEdit
                        ? (category) {
                            if (category != null) {
                              setState(() => _category = category);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    key: ValueKey('$keyPrefix-schedule-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Possui agenda'),
                    subtitle: Text(widget.scheduleSubtitle),
                    value: _hasSchedule,
                    onChanged: _canEdit
                        ? (value) => setState(() => _hasSchedule = value)
                        : null,
                  ),
                  if (_hasSchedule) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TaskFrequency>(
                      key: ValueKey('$keyPrefix-frequency-field'),
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
                      onChanged: _canEdit
                          ? (frequency) =>
                                setState(() => _frequency = frequency)
                          : null,
                      validator: (frequency) => frequency == null
                          ? 'Informe a frequência da agenda.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('$keyPrefix-dates-field'),
                      controller: _datesController,
                      enabled: _canEdit,
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
                        key: ValueKey('$keyPrefix-error'),
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
            key: ValueKey('$keyPrefix-cancel-button'),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: Text(_hasUncertainOutcome ? 'Fechar' : 'Cancelar'),
          ),
          FilledButton.icon(
            key: ValueKey('$keyPrefix-submit-button'),
            onPressed: _canEdit ? _submit : null,
            icon: _isSubmitting
                ? SizedBox.square(
                    key: ValueKey('$keyPrefix-progress'),
                    dimension: 18,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(widget.submitIcon),
            label: Text(
              _isSubmitting ? widget.submittingLabel : widget.submitLabel,
            ),
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

bool _isCreationOutcomeUncertain(ApiFailureKind kind) {
  return switch (kind) {
    ApiFailureKind.timeout ||
    ApiFailureKind.network ||
    ApiFailureKind.malformedResponse ||
    ApiFailureKind.unknown => true,
    _ => false,
  };
}
