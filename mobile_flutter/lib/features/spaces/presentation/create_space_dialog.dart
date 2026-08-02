import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';

class CreateSpaceDialog extends StatefulWidget {
  const CreateSpaceDialog({
    required this.accessToken,
    required this.spacesRepository,
    this.onSessionExpired,
    super.key,
  });

  final String accessToken;
  final SpacesRepository spacesRepository;
  final VoidCallback? onSessionExpired;

  @override
  State<CreateSpaceDialog> createState() => _CreateSpaceDialogState();
}

class _CreateSpaceDialogState extends State<CreateSpaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasUncertainOutcome = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final createdSpace = await widget.spacesRepository.createSpace(
        accessToken: widget.accessToken,
        name: _nameController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(createdSpace);
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      if (failure.kind == ApiFailureKind.unauthorized ||
          failure.kind == ApiFailureKind.forbidden) {
        widget.onSessionExpired?.call();
        return;
      }
      setState(() {
        _isSubmitting = false;
        _hasUncertainOutcome = _isCreationOutcomeUncertain(failure.kind);
        _errorMessage = _creationFailureMessage(failure.kind);
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _hasUncertainOutcome = true;
        _errorMessage = _creationFailureMessage(ApiFailureKind.unknown);
      });
    }
  }

  String? _validateName(String? value) {
    final normalizedName = value?.trim() ?? '';
    if (normalizedName.isEmpty) {
      return 'Informe o nome do espaço.';
    }
    if (normalizedName.length > 255) {
      return 'O nome deve ter no máximo 255 caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: const Text('Novo espaço'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'O espaço será criado inativo e não aparecerá nesta lista '
                  'até ser ativado.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('create-space-name-field'),
                  controller: _nameController,
                  enabled: !_isSubmitting && !_hasUncertainOutcome,
                  autofocus: true,
                  maxLength: 255,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Nome do espaço',
                    hintText: 'Ex.: Casa da praia',
                  ),
                  validator: _validateName,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorMessage case final errorMessage?) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      errorMessage,
                      key: const ValueKey('create-space-error'),
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
            key: const ValueKey('create-space-cancel-button'),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: Text(_hasUncertainOutcome ? 'Fechar' : 'Cancelar'),
          ),
          FilledButton.icon(
            key: const ValueKey('create-space-submit-button'),
            onPressed: _isSubmitting || _hasUncertainOutcome ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox.square(
                    key: ValueKey('create-space-progress'),
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_home_work_outlined),
            label: Text(_isSubmitting ? 'Criando...' : 'Criar espaço'),
          ),
        ],
      ),
    );
  }
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

String _creationFailureMessage(ApiFailureKind kind) {
  return switch (kind) {
    ApiFailureKind.validation => 'Confira o nome informado.',
    ApiFailureKind.unauthorized =>
      'Sua sessão não pôde ser autenticada. Tente entrar novamente.',
    ApiFailureKind.forbidden =>
      'Seu plano atual não permite criar outro espaço.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde um pouco e tente novamente.',
    ApiFailureKind.timeout =>
      'A API não confirmou a criação a tempo. Para evitar duplicidade, aguarde '
          'antes de tentar novamente.',
    ApiFailureKind.network =>
      'A criação não pôde ser confirmada. Confira sua conexão e aguarde antes '
          'de tentar novamente.',
    ApiFailureKind.server =>
      'O serviço está temporariamente indisponível. Tente novamente.',
    ApiFailureKind.malformedResponse =>
      'O espaço pode ter sido criado, mas a API retornou uma resposta '
          'inesperada.',
    _ => 'Não foi possível criar o espaço agora. Tente novamente.',
  };
}
