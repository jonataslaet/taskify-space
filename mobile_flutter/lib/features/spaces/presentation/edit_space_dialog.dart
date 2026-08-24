import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';
import 'package:mobile_flutter/features/spaces/domain/space_update.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';

class EditSpaceDialog extends StatefulWidget {
  EditSpaceDialog({
    required this.space,
    required this.accessToken,
    required this.spacesRepository,
    this.onSessionExpired,
    super.key,
  }) : assert(space.id > 0, 'space.id deve ser positivo.');

  final SpaceSummary space;
  final String accessToken;
  final SpacesRepository spacesRepository;
  final VoidCallback? onSessionExpired;

  @override
  State<EditSpaceDialog> createState() => _EditSpaceDialogState();
}

class _EditSpaceDialogState extends State<EditSpaceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _available;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canEditAvailability => widget.space.canEditAvailability;

  bool get _hasChanges {
    return _nameController.text.trim() != widget.space.name ||
        (_canEditAvailability && _available != widget.space.available);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.space.name);
    _available = widget.space.available;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting ||
        !_hasChanges ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updatedSpace = await widget.spacesRepository.updateSpace(
        accessToken: widget.accessToken,
        spaceId: widget.space.id,
        update: SpaceUpdate(
          name: _nameController.text.trim(),
          available: _canEditAvailability ? _available : null,
        ),
      );
      if (updatedSpace.id != widget.space.id) {
        throw const ApiFailure(ApiFailureKind.malformedResponse);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updatedSpace);
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
        key: const ValueKey('edit-space-dialog'),
        title: const Text('Editar espaço'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('edit-space-name-field'),
                    controller: _nameController,
                    enabled: !_isSubmitting,
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
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    key: const ValueKey('edit-space-available-field'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Disponível'),
                    subtitle: Text(
                      _canEditAvailability
                          ? 'Permite que outros usuários encontrem e solicitem '
                                'participação neste espaço.'
                          : 'Somente administradores podem alterar a '
                                'disponibilidade.',
                    ),
                    value: _available,
                    onChanged: !_isSubmitting && _canEditAvailability
                        ? (available) => setState(() => _available = available)
                        : null,
                  ),
                  if (_errorMessage case final errorMessage?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        errorMessage,
                        key: const ValueKey('edit-space-error'),
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
            key: const ValueKey('edit-space-cancel-button'),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            key: const ValueKey('edit-space-submit-button'),
            onPressed: !_isSubmitting && _hasChanges ? _submit : null,
            icon: _isSubmitting
                ? const SizedBox.square(
                    key: ValueKey('edit-space-progress'),
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

String _updateFailureMessage(ApiFailure failure) {
  return switch (failure.kind) {
    ApiFailureKind.validation => 'Confira os dados informados.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Você não tem mais permissão para editar este espaço.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout =>
      'A API não confirmou a atualização a tempo. Você pode tentar novamente.',
    ApiFailureKind.network =>
      'Não foi possível confirmar a atualização. Confira sua conexão.',
    ApiFailureKind.server =>
      'O serviço está temporariamente indisponível. Tente novamente.',
    ApiFailureKind.malformedResponse =>
      'A API retornou um espaço diferente do atualizado.',
    _ => 'Não foi possível atualizar o espaço agora. Tente novamente.',
  };
}
