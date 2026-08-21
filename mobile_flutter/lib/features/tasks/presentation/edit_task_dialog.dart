import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/domain/task_summary.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';
import 'package:mobile_flutter/features/tasks/presentation/task_form_dialog.dart';

class EditTaskDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final readOnlyDetails = <String>[
      task.active ? 'Ativa' : 'Inativa',
      if (task.creatorName case final creator?) 'Criada por $creator',
    ].join(' · ');

    return TaskFormDialog(
      keyPrefix: 'edit-task',
      title: 'Editar tarefa',
      details: readOnlyDetails,
      initialDescription: task.description,
      initialScore: task.score,
      initialCategory: task.category,
      initialSchedule: task.schedule,
      scheduleSubtitle: 'Desligar esta opção remove a agenda atual.',
      submitLabel: 'Atualizar',
      submittingLabel: 'Atualizando...',
      submitIcon: Icons.save_outlined,
      onSessionExpired: onSessionExpired,
      failureMessage: _updateFailureMessage,
      onSubmit: (update) async {
        final updatedTask = await tasksRepository.updateTask(
          accessToken: accessToken,
          spaceId: task.spaceId,
          taskId: task.id,
          update: update,
        );
        if (updatedTask.id != task.id || updatedTask.spaceId != task.spaceId) {
          throw const ApiFailure(ApiFailureKind.malformedResponse);
        }
        return updatedTask;
      },
    );
  }
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
