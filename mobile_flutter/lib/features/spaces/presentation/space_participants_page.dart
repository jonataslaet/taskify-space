import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/core/presentation/paged_list_pagination_bar.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/presentation/logout_button.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';

class SpaceParticipantsPage extends StatefulWidget {
  const SpaceParticipantsPage({
    required this.session,
    required this.spaceId,
    required this.spaceName,
    required this.spacesRepository,
    this.onSessionExpired,
    this.onLogout,
    super.key,
  });

  final AuthSession session;
  final int spaceId;
  final String spaceName;
  final SpacesRepository spacesRepository;
  final VoidCallback? onSessionExpired;
  final Future<void> Function()? onLogout;

  @override
  State<SpaceParticipantsPage> createState() => _SpaceParticipantsPageState();
}

class _SpaceParticipantsPageState extends State<SpaceParticipantsPage> {
  static const _pageSizeOptions = <int>[5, 10, 20, 50];

  final _nameFilterController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<TaskCategory> _selectedCategories = <TaskCategory>{};
  SpaceParticipantPageResult? _result;
  ApiFailure? _failure;
  SpaceUserRole? _selectedRole;
  ParticipantSort? _selectedSort;
  SpaceParticipantFilters _appliedFilters = const SpaceParticipantFilters();
  bool _isLoading = false;
  bool _areFiltersExpanded = false;
  int _requestGeneration = 0;
  int _requestedPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    unawaited(_loadParticipants());
  }

  @override
  void didUpdateWidget(covariant SpaceParticipantsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged =
        oldWidget.session.id != widget.session.id ||
        oldWidget.session.accessToken != widget.session.accessToken;
    if (!sessionChanged &&
        oldWidget.spaceId == widget.spaceId &&
        identical(oldWidget.spacesRepository, widget.spacesRepository)) {
      return;
    }

    _requestGeneration += 1;
    _result = null;
    _failure = null;
    _selectedRole = null;
    _selectedSort = null;
    _selectedCategories.clear();
    _appliedFilters = const SpaceParticipantFilters();
    _isLoading = false;
    _areFiltersExpanded = false;
    _requestedPage = 0;
    _pageSize = 10;
    _nameFilterController.clear();
    unawaited(_loadParticipants());
  }

  @override
  void dispose() {
    _nameFilterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants({
    SpaceParticipantFilters? filters,
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
      final result = await widget.spacesRepository.fetchSpaceParticipants(
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
        await _loadParticipants(
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
      _loadParticipants(
        filters: SpaceParticipantFilters(
          name: _nameFilterController.text,
          role: _selectedRole,
          taskCategories: Set<TaskCategory>.unmodifiable(_selectedCategories),
          sort: _selectedSort,
        ),
        page: 0,
      ),
    );
  }

  void _clearFilters() {
    if (_isLoading) {
      return;
    }
    _nameFilterController.clear();
    setState(() {
      _selectedRole = null;
      _selectedSort = null;
      _selectedCategories.clear();
    });
    unawaited(
      _loadParticipants(filters: const SpaceParticipantFilters(), page: 0),
    );
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
    if (_isLoading ||
        result == null ||
        page < 0 ||
        page >= result.totalPages ||
        page == result.number) {
      return;
    }
    unawaited(_loadParticipants(page: page));
  }

  void _changePageSize(int? size) {
    if (_isLoading ||
        size == null ||
        size == _pageSize ||
        !_pageSizeOptions.contains(size)) {
      return;
    }
    unawaited(_loadParticipants(page: 0, size: size));
  }

  bool get _hasActiveFilters {
    return (_appliedFilters.name?.trim().isNotEmpty ?? false) ||
        _appliedFilters.role != null ||
        _appliedFilters.taskCategories.isNotEmpty ||
        _appliedFilters.sort != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Participantes'),
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
          key: ValueKey('space-participants-loading'),
        ),
      );
    }

    final failure = _failure;
    if (failure != null && _result == null) {
      return _ParticipantsError(
        message: _participantsFailureMessage(failure),
        isRetrying: _isLoading,
        onRetry: () =>
            unawaited(_loadParticipants(page: _requestedPage, size: _pageSize)),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: () => _loadParticipants(page: result.number),
      child: ListView(
        key: const ValueKey('space-participants-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _ParticipantsHeader(
            spaceName: widget.spaceName,
            total: result.totalElements,
          ),
          const SizedBox(height: 16),
          _ParticipantsFilterPanel(
            nameController: _nameFilterController,
            selectedRole: _selectedRole,
            selectedCategories: _selectedCategories,
            selectedSort: _selectedSort,
            isLoading: _isLoading,
            isExpanded: _areFiltersExpanded,
            hasActiveFilters: _hasActiveFilters,
            onRoleChanged: (role) => setState(() => _selectedRole = role),
            onCategoryChanged: _toggleCategory,
            onSortChanged: (sort) => setState(() => _selectedSort = sort),
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
                  key: ValueKey('space-participants-filter-progress'),
                ),
              ),
            )
          else if (failure != null)
            _ParticipantsError(
              message: _participantsFailureMessage(failure),
              isRetrying: false,
              onRetry: () => unawaited(
                _loadParticipants(page: _requestedPage, size: _pageSize),
              ),
            )
          else ...[
            if (result.content.isEmpty)
              _ParticipantsEmpty(isFiltered: _hasActiveFilters)
            else
              for (final participant in result.content) ...[
                _ParticipantCard(participant: participant),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            PagedListPaginationBar(
              keyPrefix: 'space-participants',
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

class _ParticipantsHeader extends StatelessWidget {
  const _ParticipantsHeader({required this.spaceName, required this.total});

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
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF173B38),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          total == 1
              ? '1 participante ativo encontrado'
              : '$total participantes ativos encontrados',
          key: const ValueKey('space-participants-total'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5D716F),
          ),
        ),
      ],
    );
  }
}

class _ParticipantsFilterPanel extends StatelessWidget {
  const _ParticipantsFilterPanel({
    required this.nameController,
    required this.selectedRole,
    required this.selectedCategories,
    required this.selectedSort,
    required this.isLoading,
    required this.isExpanded,
    required this.hasActiveFilters,
    required this.onRoleChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onToggle,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController nameController;
  final SpaceUserRole? selectedRole;
  final Set<TaskCategory> selectedCategories;
  final ParticipantSort? selectedSort;
  final bool isLoading;
  final bool isExpanded;
  final bool hasActiveFilters;
  final ValueChanged<SpaceUserRole?> onRoleChanged;
  final void Function(TaskCategory category, bool selected) onCategoryChanged;
  final ValueChanged<ParticipantSort?> onSortChanged;
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
                            'space-participants-active-filters',
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
                  key: const ValueKey('space-participants-toggle-filters'),
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
                key: const ValueKey('space-participants-filter-panel'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('space-participants-name-filter'),
                    controller: nameController,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Nome do participante',
                      hintText: 'Digite parte do nome',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: (_) => onApply(),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final role = _ParticipantDropdown<SpaceUserRole>(
                        key: const ValueKey('space-participants-role-filter'),
                        label: 'Papel no espaço',
                        allLabel: 'Todos os papéis',
                        value: selectedRole,
                        values: SpaceUserRole.values,
                        valueLabel: _roleLabel,
                        enabled: !isLoading,
                        onChanged: onRoleChanged,
                      );
                      final sort = _ParticipantDropdown<ParticipantSort>(
                        key: const ValueKey('space-participants-sort-filter'),
                        label: 'Ordenação',
                        allLabel: 'Padrão (nome)',
                        value: selectedSort,
                        values: ParticipantSort.values,
                        valueLabel: _sortLabel,
                        enabled: !isLoading,
                        onChanged: onSortChanged,
                      );
                      if (constraints.maxWidth >= 560) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: role),
                            const SizedBox(width: 12),
                            Expanded(child: sort),
                          ],
                        );
                      }
                      return Column(
                        children: [role, const SizedBox(height: 12), sort],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Categorias consideradas na pontuação',
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
                          key: ValueKey(
                            'space-participants-category-${category.apiValue}',
                          ),
                          label: Text(_categoryLabel(category)),
                          selected: selectedCategories.contains(category),
                          onSelected: isLoading
                              ? null
                              : (selected) =>
                                    onCategoryChanged(category, selected),
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
                        key: const ValueKey('space-participants-clear-filters'),
                        onPressed: isLoading ? null : onClear,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Limpar'),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('space-participants-apply-filters'),
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

class _ParticipantDropdown<T> extends StatelessWidget {
  const _ParticipantDropdown({
    required this.label,
    required this.allLabel,
    required this.value,
    required this.values,
    required this.valueLabel,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String allLabel;
  final T? value;
  final List<T> values;
  final String Function(T value) valueLabel;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          hint: Text(allLabel),
          items: [
            DropdownMenuItem<T>(value: null, child: Text(allLabel)),
            for (final item in values)
              DropdownMenuItem<T>(value: item, child: Text(valueLabel(item))),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.participant});

  final SpaceParticipant participant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('space-participant-card-${participant.id}'),
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
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFE3F2EF),
                foregroundColor: const Color(0xFF006C67),
                child: Text(
                  _initials(participant.name),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.name,
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
                      _ParticipantInfoChip(
                        icon: Icons.badge_outlined,
                        label: _roleLabel(participant.spaceUserRole),
                      ),
                      _ParticipantInfoChip(
                        icon: Icons.stars_outlined,
                        label: '${_scoreLabel(participant.score)} pontos',
                      ),
                      for (final category in participant.taskCategories)
                        _ParticipantInfoChip(
                          icon: category == TaskCategory.financial
                              ? Icons.payments_outlined
                              : Icons.build_outlined,
                          label: _categoryLabel(category),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantInfoChip extends StatelessWidget {
  const _ParticipantInfoChip({required this.icon, required this.label});

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

class _ParticipantsEmpty extends StatelessWidget {
  const _ParticipantsEmpty({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: ValueKey(
            isFiltered
                ? 'space-participants-filter-empty'
                : 'space-participants-empty',
          ),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.group_off_outlined,
              size: 64,
              color: Color(0xFF6C8582),
            ),
            const SizedBox(height: 18),
            Text(
              isFiltered
                  ? 'Nenhum participante corresponde aos filtros.'
                  : 'Nenhum participante ativo foi encontrado.',
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

class _ParticipantsError extends StatelessWidget {
  const _ParticipantsError({
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
            key: const ValueKey('space-participants-error'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 18),
              Text(
                'Não foi possível carregar os participantes',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('space-participants-retry-button'),
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

String _categoryLabel(TaskCategory category) {
  return switch (category) {
    TaskCategory.operational => 'Operacional',
    TaskCategory.financial => 'Financeira',
  };
}

String _sortLabel(ParticipantSort sort) {
  return switch (sort) {
    ParticipantSort.idAscending => 'ID: crescente',
    ParticipantSort.idDescending => 'ID: decrescente',
    ParticipantSort.nameAscending => 'Nome: A–Z',
    ParticipantSort.nameDescending => 'Nome: Z–A',
    ParticipantSort.spaceUserRoleAscending => 'Papel: crescente',
    ParticipantSort.spaceUserRoleDescending => 'Papel: decrescente',
    ParticipantSort.scoreAscending => 'Menor pontuação',
    ParticipantSort.scoreDescending => 'Maior pontuação',
  };
}

String _scoreLabel(num score) {
  if (score == score.roundToDouble()) {
    return score.toInt().toString();
  }
  return score
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
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

String _participantsFailureMessage(ApiFailure failure) {
  return switch (failure.kind) {
    ApiFailureKind.validation =>
      'Os filtros informados não puderam ser aplicados.',
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'É necessária uma participação aprovada para consultar este espaço.',
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
