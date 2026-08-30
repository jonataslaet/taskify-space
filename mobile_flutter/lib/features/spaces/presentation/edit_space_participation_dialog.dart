import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';

class EditSpaceParticipationDialog extends StatefulWidget {
  const EditSpaceParticipationDialog({
    required this.participation,
    required this.accessToken,
    required this.spaceId,
    required this.spacesRepository,
    required this.canEditRole,
    this.onSessionExpired,
    super.key,
  }) : assert(spaceId > 0, 'spaceId deve ser positivo.');

  final SpaceParticipation participation;
  final String accessToken;
  final int spaceId;
  final SpacesRepository spacesRepository;
  final bool canEditRole;
  final VoidCallback? onSessionExpired;

  @override
  State<EditSpaceParticipationDialog> createState() =>
      _EditSpaceParticipationDialogState();
}

class _EditSpaceParticipationDialogState
    extends State<EditSpaceParticipationDialog> {
  late SpaceUserRole _role;
  late SpaceMembershipStatus _status;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canEdit => !_isSubmitting;

  bool get _hasChanges {
    return _status != widget.participation.spaceMembershipStatus ||
        (widget.canEditRole && _role != widget.participation.spaceUserRole);
  }

  @override
  void initState() {
    super.initState();
    _role = widget.participation.spaceUserRole;
    _status = widget.participation.spaceMembershipStatus;
  }

  Future<void> _submit() async {
    if (!_canEdit || !_hasChanges) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final changedStatus = _status != widget.participation.spaceMembershipStatus
        ? _status
        : null;
    final changedRole =
        widget.canEditRole && _role != widget.participation.spaceUserRole
        ? _role
        : null;

    try {
      final updated = await widget.spacesRepository.updateSpaceParticipation(
        accessToken: widget.accessToken,
        spaceId: widget.spaceId,
        membershipId: widget.participation.id,
        status: changedStatus,
        spaceUserRole: changedRole,
      );
      if (updated.id != widget.participation.id) {
        throw const ApiFailure(ApiFailureKind.malformedResponse);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updated);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        key: const ValueKey('edit-space-participation-dialog'),
        title: const Text('Editar participação'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.participation.name,
                  key: const ValueKey('edit-space-participation-name'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF173B38),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<SpaceUserRole>(
                  key: const ValueKey('edit-space-participation-role-field'),
                  initialValue: _role,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Papel no espaço',
                    helperText: widget.canEditRole
                        ? null
                        : 'Somente administradores podem alterar o papel.',
                  ),
                  items: [
                    for (final role in SpaceUserRole.values)
                      DropdownMenuItem<SpaceUserRole>(
                        value: role,
                        child: Text(_roleLabel(role)),
                      ),
                  ],
                  onChanged: _canEdit && widget.canEditRole
                      ? (role) {
                          if (role != null) {
                            setState(() => _role = role);
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<SpaceMembershipStatus>(
                  key: const ValueKey('edit-space-participation-status-field'),
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Situação da participação',
                  ),
                  items: [
                    for (final status in SpaceMembershipStatus.values)
                      DropdownMenuItem<SpaceMembershipStatus>(
                        value: status,
                        child: Text(_statusLabel(status)),
                      ),
                  ],
                  onChanged: _canEdit
                      ? (status) {
                          if (status != null) {
                            setState(() => _status = status);
                          }
                        }
                      : null,
                ),
                if (_errorMessage case final error?) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      key: const ValueKey('edit-space-participation-error'),
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
            key: const ValueKey('edit-space-participation-cancel-button'),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            key: const ValueKey('edit-space-participation-submit-button'),
            onPressed: _canEdit && _hasChanges ? _submit : null,
            icon: _isSubmitting
                ? const SizedBox.square(
                    key: ValueKey('edit-space-participation-progress'),
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

String _roleLabel(SpaceUserRole role) {
  return switch (role) {
    SpaceUserRole.admin => 'Administrador',
    SpaceUserRole.manager => 'Gerente',
    SpaceUserRole.participant => 'Participante',
  };
}

String _statusLabel(SpaceMembershipStatus status) {
  return switch (status) {
    SpaceMembershipStatus.pending => 'Pendente',
    SpaceMembershipStatus.approved => 'Aprovada',
    SpaceMembershipStatus.blocked => 'Bloqueada',
    SpaceMembershipStatus.cancelled => 'Cancelada',
    SpaceMembershipStatus.denied => 'Negada',
    SpaceMembershipStatus.suspended => 'Suspensa',
  };
}

String _updateFailureMessage(ApiFailure failure) {
  if (const <int>{400, 403, 404, 409}.contains(failure.statusCode)) {
    final apiMessage = failure.apiMessage?.trim();
    if (apiMessage != null && apiMessage.isNotEmpty) {
      return apiMessage;
    }
  }
  if (failure.statusCode == 404) {
    return 'A participação ou o espaço não foi encontrado.';
  }
  if (failure.statusCode == 409) {
    return 'Já existe outro vínculo para este usuário neste espaço.';
  }
  return switch (failure.kind) {
    ApiFailureKind.validation => 'Confira o papel e a situação informados.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'A alteração não é permitida. Confira sua permissão, os limites do '
          'plano e se o espaço mantém um administrador aprovado.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout =>
      'A API não confirmou a atualização a tempo. Você pode tentar novamente.',
    ApiFailureKind.network =>
      'Não foi possível confirmar a atualização. Confira sua conexão.',
    ApiFailureKind.server =>
      'O serviço está temporariamente indisponível. Tente novamente.',
    ApiFailureKind.malformedResponse =>
      'A API retornou uma participação diferente da esperada.',
    _ => 'Não foi possível atualizar a participação agora. Tente novamente.',
  };
}
