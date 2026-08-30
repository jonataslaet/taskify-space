import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/core/presentation/paged_list_pagination_bar.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/presentation/logout_button.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';
import 'package:mobile_flutter/features/spaces/presentation/edit_space_participation_dialog.dart';

class SpaceParticipationsPage extends StatefulWidget {
  const SpaceParticipationsPage({
    required this.session,
    required this.spaceId,
    required this.spaceName,
    required this.spacesRepository,
    required this.canEditParticipations,
    required this.canEditParticipationRoles,
    this.onSessionExpired,
    this.onLogout,
    super.key,
  }) : assert(spaceId > 0, 'spaceId deve ser positivo.'),
       assert(
         !canEditParticipationRoles || canEditParticipations,
         'Editar papéis exige permissão para editar participações.',
       );

  final AuthSession session;
  final int spaceId;
  final String spaceName;
  final SpacesRepository spacesRepository;
  final bool canEditParticipations;
  final bool canEditParticipationRoles;
  final VoidCallback? onSessionExpired;
  final Future<void> Function()? onLogout;

  @override
  State<SpaceParticipationsPage> createState() =>
      _SpaceParticipationsPageState();
}

class _SpaceParticipationsPageState extends State<SpaceParticipationsPage> {
  static const _pageSizeOptions = <int>[5, 10, 20, 50];

  final _usernameFilterController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<SpaceMembershipStatus> _selectedStatuses =
      <SpaceMembershipStatus>{};
  SpaceParticipationPageResult? _result;
  ApiFailure? _failure;
  SpaceParticipationFilters _appliedFilters = const SpaceParticipationFilters();
  bool _isLoading = false;
  bool _areFiltersExpanded = false;
  int _requestGeneration = 0;
  int _editGeneration = 0;
  int _requestedPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    unawaited(_loadParticipations());
  }

  @override
  void didUpdateWidget(covariant SpaceParticipationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged =
        oldWidget.session.id != widget.session.id ||
        oldWidget.session.accessToken != widget.session.accessToken;
    final sourceChanged =
        sessionChanged ||
        oldWidget.spaceId != widget.spaceId ||
        oldWidget.canEditParticipations != widget.canEditParticipations ||
        oldWidget.canEditParticipationRoles !=
            widget.canEditParticipationRoles ||
        !identical(oldWidget.spacesRepository, widget.spacesRepository);
    if (!sourceChanged) {
      return;
    }

    _requestGeneration += 1;
    _editGeneration += 1;
    _result = null;
    _failure = null;
    _selectedStatuses.clear();
    _appliedFilters = const SpaceParticipationFilters();
    _isLoading = false;
    _areFiltersExpanded = false;
    _requestedPage = 0;
    _pageSize = 10;
    _usernameFilterController.clear();
    unawaited(_loadParticipations());
  }

  @override
  void dispose() {
    _editGeneration += 1;
    _usernameFilterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipations({
    SpaceParticipationFilters? filters,
    int? page,
    int? size,
  }) async {
    if (_isLoading) {
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
      _failure = null;
      _isLoading = true;
    });
    if ((filters != null || page != null || size != null) &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    try {
      final result = await widget.spacesRepository.fetchSpaceParticipations(
        accessToken: widget.session.accessToken,
        spaceId: widget.spaceId,
        filters: requestedFilters,
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
        await _loadParticipations(
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

  void _applyFilters() {
    if (_isLoading) {
      return;
    }
    unawaited(
      _loadParticipations(
        filters: SpaceParticipationFilters(
          username: _usernameFilterController.text,
          statuses: Set<SpaceMembershipStatus>.unmodifiable(_selectedStatuses),
        ),
        page: 0,
      ),
    );
  }

  void _clearFilters() {
    if (_isLoading) {
      return;
    }
    _usernameFilterController.clear();
    setState(_selectedStatuses.clear);
    unawaited(
      _loadParticipations(filters: const SpaceParticipationFilters(), page: 0),
    );
  }

  void _toggleStatus(SpaceMembershipStatus status, bool selected) {
    setState(() {
      if (selected) {
        _selectedStatuses.add(status);
      } else {
        _selectedStatuses.remove(status);
      }
    });
  }

  void _goToPage(int page) {
    final result = _result;
    if (_isLoading ||
        result == null ||
        page < 0 ||
        page >= result.totalPages ||
        page == result.number) {
      return;
    }
    unawaited(_loadParticipations(page: page));
  }

  void _changePageSize(int? size) {
    if (_isLoading ||
        size == null ||
        size == _pageSize ||
        !_pageSizeOptions.contains(size)) {
      return;
    }
    unawaited(_loadParticipations(page: 0, size: size));
  }

  bool _canEditParticipation(SpaceParticipation participation) {
    if (!widget.canEditParticipations) {
      return false;
    }
    return widget.canEditParticipationRoles ||
        participation.spaceUserRole == SpaceUserRole.participant;
  }

  Future<void> _openEditParticipation(SpaceParticipation participation) async {
    if (_isLoading || !_canEditParticipation(participation)) {
      return;
    }

    final editGeneration = ++_editGeneration;
    final sourceAccessToken = widget.session.accessToken;
    final sourceSpaceId = widget.spaceId;
    final sourceRepository = widget.spacesRepository;
    final updated = await showDialog<SpaceParticipation>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditSpaceParticipationDialog(
        participation: participation,
        accessToken: sourceAccessToken,
        spaceId: sourceSpaceId,
        spacesRepository: sourceRepository,
        canEditRole: widget.canEditParticipationRoles,
        onSessionExpired: widget.onSessionExpired,
      ),
    );
    if (!mounted ||
        editGeneration != _editGeneration ||
        widget.session.accessToken != sourceAccessToken ||
        widget.spaceId != sourceSpaceId ||
        !identical(widget.spacesRepository, sourceRepository) ||
        updated == null) {
      return;
    }

    Navigator.of(context).pop(updated);
  }

  bool get _hasActiveFilters {
    return (_appliedFilters.username?.trim().isNotEmpty ?? false) ||
        _appliedFilters.statuses.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Participações'),
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
          key: ValueKey('space-participations-loading'),
        ),
      );
    }

    final failure = _failure;
    if (failure != null && _result == null) {
      return _ParticipationsError(
        message: _participationsFailureMessage(failure),
        isRetrying: _isLoading,
        onRetry: () => unawaited(
          _loadParticipations(page: _requestedPage, size: _pageSize),
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: () =>
          _loadParticipations(page: result.number, size: _pageSize),
      child: ListView(
        key: const ValueKey('space-participations-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _ParticipationsHeader(
            spaceName: widget.spaceName,
            total: result.totalElements,
          ),
          const SizedBox(height: 16),
          _ParticipationsFilterPanel(
            usernameController: _usernameFilterController,
            selectedStatuses: _selectedStatuses,
            isLoading: _isLoading,
            isExpanded: _areFiltersExpanded,
            hasActiveFilters: _hasActiveFilters,
            onStatusChanged: _toggleStatus,
            onToggle: () =>
                setState(() => _areFiltersExpanded = !_areFiltersExpanded),
            onApply: _applyFilters,
            onClear: _clearFilters,
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(
                  key: ValueKey('space-participations-filter-progress'),
                ),
              ),
            )
          else if (failure != null)
            _ParticipationsError(
              message: _participationsFailureMessage(failure),
              isRetrying: false,
              onRetry: () => unawaited(
                _loadParticipations(page: _requestedPage, size: _pageSize),
              ),
            )
          else ...[
            if (result.content.isEmpty)
              _ParticipationsEmpty(isFiltered: _hasActiveFilters)
            else
              for (final participation in result.content) ...[
                _ParticipationCard(
                  participation: participation,
                  showEditAction: widget.canEditParticipations,
                  onEdit: _canEditParticipation(participation)
                      ? () => unawaited(_openEditParticipation(participation))
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            PagedListPaginationBar(
              keyPrefix: 'space-participations',
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

class _ParticipationsHeader extends StatelessWidget {
  const _ParticipationsHeader({required this.spaceName, required this.total});

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
          key: const ValueKey('space-participations-space-name'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF173B38),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          total == 1
              ? '1 participação encontrada'
              : '$total participações encontradas',
          key: const ValueKey('space-participations-total'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5D716F),
          ),
        ),
      ],
    );
  }
}

class _ParticipationsFilterPanel extends StatelessWidget {
  const _ParticipationsFilterPanel({
    required this.usernameController,
    required this.selectedStatuses,
    required this.isLoading,
    required this.isExpanded,
    required this.hasActiveFilters,
    required this.onStatusChanged,
    required this.onToggle,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController usernameController;
  final Set<SpaceMembershipStatus> selectedStatuses;
  final bool isLoading;
  final bool isExpanded;
  final bool hasActiveFilters;
  final void Function(SpaceMembershipStatus status, bool selected)
  onStatusChanged;
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
                          key: const ValueKey(
                            'space-participations-active-filters',
                          ),
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
                  key: const ValueKey('space-participations-toggle-filters'),
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
                key: const ValueKey('space-participations-filter-panel'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('space-participations-username-filter'),
                    controller: usernameController,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Nome do usuário',
                      hintText: 'Digite parte do nome',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: (_) => onApply(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Situações da participação',
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
                      for (final status in SpaceMembershipStatus.values)
                        FilterChip(
                          key: ValueKey(
                            'space-participations-status-${status.apiValue}',
                          ),
                          label: Text(_statusLabel(status)),
                          selected: selectedStatuses.contains(status),
                          onSelected: isLoading
                              ? null
                              : (selected) => onStatusChanged(status, selected),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey(
                          'space-participations-clear-filters',
                        ),
                        onPressed: isLoading ? null : onClear,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Limpar'),
                      ),
                      FilledButton.icon(
                        key: const ValueKey(
                          'space-participations-apply-filters',
                        ),
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

class _ParticipationCard extends StatelessWidget {
  const _ParticipationCard({
    required this.participation,
    required this.showEditAction,
    required this.onEdit,
  });

  final SpaceParticipation participation;
  final bool showEditAction;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = _roleLabel(participation.spaceUserRole);
    final statusLabel = _statusLabel(participation.spaceMembershipStatus);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Card(
        key: ValueKey('space-participation-card-${participation.id}'),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDDE8E5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  label:
                      '${participation.name}. Papel: $roleLabel. '
                      'Situação: $statusLabel.',
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 23,
                          backgroundColor: const Color(0xFFE3F2EF),
                          foregroundColor: const Color(0xFF006C67),
                          child: Text(
                            _initials(participation.name),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                participation.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF173B38),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ParticipationInfoChip(
                                    icon: Icons.badge_outlined,
                                    label: roleLabel,
                                  ),
                                  _ParticipationInfoChip(
                                    icon: _statusIcon(
                                      participation.spaceMembershipStatus,
                                    ),
                                    label: statusLabel,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showEditAction) ...[
                const SizedBox(width: 8),
                _ParticipationEditButton(
                  participation: participation,
                  onPressed: onEdit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipationEditButton extends StatelessWidget {
  const _ParticipationEditButton({
    required this.participation,
    required this.onPressed,
  });

  final SpaceParticipation participation;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tooltip = enabled
        ? 'Editar participação de ${participation.name}'
        : 'Somente administradores podem editar vínculos de administradores '
              'ou gerentes';
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          key: ValueKey('space-participation-edit-button-${participation.id}'),
          onPressed: onPressed,
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
    );
  }
}

class _ParticipationInfoChip extends StatelessWidget {
  const _ParticipationInfoChip({required this.icon, required this.label});

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

class _ParticipationsEmpty extends StatelessWidget {
  const _ParticipationsEmpty({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: ValueKey(
            isFiltered
                ? 'space-participations-filter-empty'
                : 'space-participations-empty',
          ),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_search_outlined,
              size: 64,
              color: Color(0xFF6C8582),
            ),
            const SizedBox(height: 18),
            Text(
              isFiltered
                  ? 'Nenhuma participação corresponde aos filtros.'
                  : 'Nenhuma participação foi encontrada neste espaço.',
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

class _ParticipationsError extends StatelessWidget {
  const _ParticipationsError({
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
            key: const ValueKey('space-participations-error'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 18),
              Text(
                'Não foi possível carregar as participações',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('space-participations-retry-button'),
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

IconData _statusIcon(SpaceMembershipStatus status) {
  return switch (status) {
    SpaceMembershipStatus.pending => Icons.hourglass_top_rounded,
    SpaceMembershipStatus.approved => Icons.verified_outlined,
    SpaceMembershipStatus.blocked => Icons.block_outlined,
    SpaceMembershipStatus.cancelled => Icons.cancel_outlined,
    SpaceMembershipStatus.denied => Icons.do_not_disturb_alt_outlined,
    SpaceMembershipStatus.suspended => Icons.pause_circle_outline_rounded,
  };
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return '?';
  }
  final first = words.first.characters.first;
  final last = words.length > 1 ? words.last.characters.first : '';
  return '$first$last'.toUpperCase();
}

String _participationsFailureMessage(ApiFailure failure) {
  if (failure.statusCode == 404) {
    return 'O espaço não foi encontrado.';
  }
  return switch (failure.kind) {
    ApiFailureKind.validation =>
      'Os filtros informados não puderam ser aplicados.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Apenas administradores e gerentes do espaço podem consultar as '
          'participações.',
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
