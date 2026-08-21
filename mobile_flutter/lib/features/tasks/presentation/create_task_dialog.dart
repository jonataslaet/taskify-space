import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_creation.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';
import 'package:mobile_flutter/features/tasks/presentation/task_form_dialog.dart';

class CreateTaskDialog extends StatelessWidget {
  const CreateTaskDialog({
    required this.spaceId,
    required this.creatorName,
    required this.accessToken,
    required this.tasksRepository,
    this.onSessionExpired,
    super.key,
  });

  final int spaceId;
  final String creatorName;
  final String accessToken;
  final TasksRepository tasksRepository;
  final VoidCallback? onSessionExpired;

  @override
  Widget build(BuildContext context) {
    return TaskFormDialog(
      keyPrefix: 'create-task',
      title: 'Nova tarefa',
      details: 'Ativa · Criada por $creatorName',
      initialDescription: '',
      initialScore: null,
      initialCategory: TaskCategory.operational,
      initialSchedule: null,
      scheduleSubtitle: 'Ative para informar a frequência e as datas.',
      submitLabel: 'Criar tarefa',
      submittingLabel: 'Criando...',
      submitIcon: Icons.add_task_rounded,
      creationOutcomeCanBeUncertain: true,
      onSessionExpired: onSessionExpired,
      failureMessage: _creationFailureMessage,
      onSubmit: (task) async {
        final createdTask = await tasksRepository.createTask(
          accessToken: accessToken,
          spaceId: spaceId,
          creation: TaskCreation(
            spaceId: spaceId,
            description: task.description,
            score: task.score,
            category: task.category,
            active: true,
            creatorName: creatorName,
            schedule: task.schedule,
          ),
        );
        if (createdTask.spaceId != spaceId) {
          throw const ApiFailure(ApiFailureKind.malformedResponse);
        }
        return createdTask;
      },
    );
  }
}

String _creationFailureMessage(ApiFailure failure) {
  if (failure.statusCode == 409) {
    return 'Já existe outra tarefa com esta descrição no espaço.';
  }
  return switch (failure.kind) {
    ApiFailureKind.validation => 'Confira os dados informados.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Você não tem permissão para criar tarefas neste espaço.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout =>
      'A API não confirmou a criação a tempo. Para evitar duplicidade, '
          'aguarde antes de tentar novamente.',
    ApiFailureKind.network =>
      'A criação não pôde ser confirmada. Confira sua conexão e aguarde antes '
          'de tentar novamente.',
    ApiFailureKind.server =>
      'O serviço está temporariamente indisponível. Tente novamente.',
    ApiFailureKind.malformedResponse =>
      'A tarefa pode ter sido criada, mas a API retornou uma resposta '
          'inesperada.',
    _ => 'Não foi possível criar a tarefa agora. Tente novamente.',
  };
}
