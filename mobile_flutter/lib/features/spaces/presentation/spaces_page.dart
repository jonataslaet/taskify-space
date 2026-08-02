import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/spaces/domain/created_space.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';
import 'package:mobile_flutter/features/spaces/presentation/create_space_dialog.dart';

class SpacesPage extends StatefulWidget {
  const SpacesPage({
    required this.session,
    required this.spacesRepository,
    super.key,
  });

  final AuthSession session;
  final SpacesRepository spacesRepository;

  @override
  State<SpacesPage> createState() => _SpacesPageState();
}

class _SpacesPageState extends State<SpacesPage> {
  static const _pageSizeOptions = <int>[5, 10, 20, 50];

  final _nameFilterController = TextEditingController();
  final _scrollController = ScrollController();
  SpacePageResult? _result;
  ApiFailure? _failure;
  SpaceUserRole? _selectedRole;
  SpaceMembershipStatus? _selectedStatus;
  SpaceFilters _appliedFilters = const SpaceFilters();
  bool _isLoading = false;
  bool _areFiltersExpanded = false;
  int _requestGeneration = 0;
  int _requestedPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSpaces());
  }

  @override
  void didUpdateWidget(covariant SpacesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged =
        oldWidget.session.id != widget.session.id ||
        oldWidget.session.accessToken != widget.session.accessToken;
    if (!sessionChanged &&
        identical(oldWidget.spacesRepository, widget.spacesRepository)) {
      return;
    }

    _requestGeneration += 1;
    _result = null;
    _failure = null;
    _selectedRole = null;
    _selectedStatus = null;
    _appliedFilters = const SpaceFilters();
    _isLoading = false;
    _areFiltersExpanded = false;
    _requestedPage = 0;
    _pageSize = 10;
    _nameFilterController.clear();
    unawaited(
      _loadSpaces(filters: const SpaceFilters(), page: 0, size: _pageSize),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadSpaces({
    SpaceFilters? filters,
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
      _isLoading = true;
      _failure = null;
    });
    if ((filters != null || page != null || size != null) &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    try {
      final result = await widget.spacesRepository.fetchSpaces(
        accessToken: widget.session.accessToken,
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
        await _loadSpaces(
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
      _loadSpaces(
        filters: SpaceFilters(
          name: _nameFilterController.text,
          role: _selectedRole,
          status: _selectedStatus,
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
      _selectedStatus = null;
    });
    unawaited(_loadSpaces(filters: const SpaceFilters(), page: 0));
  }

  void _toggleFilters() {
    setState(() {
      _areFiltersExpanded = !_areFiltersExpanded;
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
    unawaited(_loadSpaces(page: page));
  }

  void _changePageSize(int? size) {
    if (_isLoading ||
        size == null ||
        size == _pageSize ||
        !_pageSizeOptions.contains(size)) {
      return;
    }
    unawaited(_loadSpaces(page: 0, size: size));
  }

  Future<void> _openCreateSpaceDialog() async {
    final createdSpace = await showDialog<CreatedSpace>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateSpaceDialog(
        accessToken: widget.session.accessToken,
        spacesRepository: widget.spacesRepository,
      ),
    );
    if (!mounted || createdSpace == null) {
      return;
    }

    final message = createdSpace.active
        ? 'Espaço "${createdSpace.name}" criado com sucesso.'
        : 'Espaço "${createdSpace.name}" criado. Ele está inativo e ainda não '
              'aparece nesta lista.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('space-created-message'),
          content: Text(message),
        ),
      );

    if (createdSpace.active) {
      unawaited(_loadSpaces());
    }
  }

  bool get _hasActiveFilters {
    return (_appliedFilters.name?.trim().isNotEmpty ?? false) ||
        _appliedFilters.role != null ||
        _appliedFilters.status != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taskify Space')),
      body: SafeArea(child: _buildBody(context)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('create-space-button'),
        onPressed: _openCreateSpaceDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo espaço'),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _result == null) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('spaces-loading')),
      );
    }

    final failure = _failure;
    if (failure != null && _result == null) {
      return _SpacesError(
        message: _failureMessage(failure.kind),
        isRetrying: _isLoading,
        onRetry: () =>
            unawaited(_loadSpaces(page: _requestedPage, size: _pageSize)),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: () => _loadSpaces(page: result.number),
      child: ListView(
        controller: _scrollController,
        key: const ValueKey('spaces-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          _SpacesHeader(session: widget.session, total: result.totalElements),
          const SizedBox(height: 16),
          _SpacesFilterPanel(
            nameController: _nameFilterController,
            selectedRole: _selectedRole,
            selectedStatus: _selectedStatus,
            isLoading: _isLoading,
            isExpanded: _areFiltersExpanded,
            hasActiveFilters: _hasActiveFilters,
            onRoleChanged: (role) => setState(() => _selectedRole = role),
            onStatusChanged: (status) =>
                setState(() => _selectedStatus = status),
            onToggle: _toggleFilters,
            onApply: _applyFilters,
            onClear: _clearFilters,
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(
                  key: ValueKey('spaces-filter-progress'),
                ),
              ),
            )
          else if (failure != null)
            _SpacesError(
              message: _failureMessage(failure.kind),
              isRetrying: false,
              onRetry: () =>
                  unawaited(_loadSpaces(page: _requestedPage, size: _pageSize)),
            )
          else ...[
            if (result.content.isEmpty)
              _SpacesEmpty(isFiltered: _hasActiveFilters)
            else
              for (final space in result.content) ...[
                _SpaceCard(space: space),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            _SpacesPaginationBar(
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

class _SpacesHeader extends StatelessWidget {
  const _SpacesHeader({required this.session, required this.total});

  final AuthSession session;
  final int total;

  @override
  Widget build(BuildContext context) {
    final displayName = session.name ?? session.username;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Olá, $displayName!',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF173B38),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          total == 1 ? '1 espaço encontrado' : '$total espaços encontrados',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5D716F),
          ),
        ),
      ],
    );
  }
}

class _SpacesPaginationBar extends StatelessWidget {
  const _SpacesPaginationBar({
    required this.currentPage,
    required this.pageItemCount,
    required this.totalElements,
    required this.totalPages,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.onPageSelected,
    required this.onPageSizeChanged,
  });

  final int currentPage;
  final int pageItemCount;
  final int totalElements;
  final int totalPages;
  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<int?> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstItem = totalElements == 0 ? 0 : currentPage * pageSize + 1;
    final lastItem = totalElements == 0 ? 0 : firstItem + pageItemCount - 1;
    final pageTokens = _visiblePageTokens(currentPage, totalPages);

    return Card(
      key: const ValueKey('spaces-pagination-bar'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDDE8E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                totalPages == 0
                    ? 'Nenhuma página disponível'
                    : 'Página ${currentPage + 1} de $totalPages · '
                          '$firstItem–$lastItem de $totalElements',
                key: const ValueKey('spaces-page-summary'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5D716F),
                ),
              ),
            ),
            if (totalPages > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('spaces-page-previous'),
                    tooltip: 'Página anterior',
                    onPressed: currentPage > 0
                        ? () => onPageSelected(currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (
                            var index = 0;
                            index < pageTokens.length;
                            index++
                          )
                            if (pageTokens[index] case final page?)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: _PageNumberButton(
                                  page: page,
                                  isCurrent: page == currentPage,
                                  onPressed: () => onPageSelected(page),
                                ),
                              )
                            else
                              SizedBox(
                                key: ValueKey('spaces-page-ellipsis-$index'),
                                width: 30,
                                child: const ExcludeSemantics(
                                  child: Center(child: Text('…')),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('spaces-page-next'),
                    tooltip: 'Próxima página',
                    onPressed: currentPage + 1 < totalPages
                        ? () => onPageSelected(currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                const Text('Registros por página'),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const ValueKey('spaces-page-size'),
                    value: pageSize,
                    items: [
                      for (final option in pageSizeOptions)
                        DropdownMenuItem<int>(
                          value: option,
                          child: Text('$option'),
                        ),
                    ],
                    onChanged: onPageSizeChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  const _PageNumberButton({
    required this.page,
    required this.isCurrent,
    required this.onPressed,
  });

  final int page;
  final bool isCurrent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = '${page + 1}';
    final button = isCurrent
        ? FilledButton(
            key: ValueKey('spaces-page-$page'),
            onPressed: null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.square(48),
              padding: EdgeInsets.zero,
              disabledBackgroundColor: Theme.of(context).colorScheme.primary,
              disabledForegroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(label),
          )
        : OutlinedButton(
            key: ValueKey('spaces-page-$page'),
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.square(48),
              padding: EdgeInsets.zero,
            ),
            child: Text(label),
          );

    return Semantics(
      button: true,
      selected: isCurrent,
      label: isCurrent ? 'Página $label, atual' : 'Ir para página $label',
      child: ExcludeSemantics(child: button),
    );
  }
}

List<int?> _visiblePageTokens(int currentPage, int totalPages) {
  if (totalPages <= 0) {
    return const [];
  }
  if (totalPages <= 7) {
    return List<int>.generate(totalPages, (index) => index);
  }

  final lastPage = totalPages - 1;
  if (currentPage <= 3) {
    return <int?>[0, 1, 2, 3, null, lastPage];
  }
  if (currentPage >= lastPage - 3) {
    return <int?>[0, null, lastPage - 3, lastPage - 2, lastPage - 1, lastPage];
  }
  return <int?>[
    0,
    null,
    currentPage - 1,
    currentPage,
    currentPage + 1,
    null,
    lastPage,
  ];
}

class _SpacesFilterPanel extends StatelessWidget {
  const _SpacesFilterPanel({
    required this.nameController,
    required this.selectedRole,
    required this.selectedStatus,
    required this.isLoading,
    required this.isExpanded,
    required this.hasActiveFilters,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onToggle,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController nameController;
  final SpaceUserRole? selectedRole;
  final SpaceMembershipStatus? selectedStatus;
  final bool isLoading;
  final bool isExpanded;
  final bool hasActiveFilters;
  final ValueChanged<SpaceUserRole?> onRoleChanged;
  final ValueChanged<SpaceMembershipStatus?> onStatusChanged;
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
                          key: const ValueKey('spaces-active-filters'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF37615E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const ValueKey('spaces-toggle-filters'),
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
                key: const ValueKey('spaces-filter-panel'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('spaces-name-filter'),
                    controller: nameController,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Nome do espaço',
                      hintText: 'Digite parte do nome',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: (_) => onApply(),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final roleFilter = _FilterDropdown<SpaceUserRole>(
                        key: const ValueKey('spaces-role-filter'),
                        label: 'Meu papel',
                        allLabel: 'Todos os papéis',
                        value: selectedRole,
                        values: SpaceUserRole.values,
                        valueLabel: _roleFilterLabel,
                        enabled: !isLoading,
                        onChanged: onRoleChanged,
                      );
                      final statusFilter =
                          _FilterDropdown<SpaceMembershipStatus>(
                            key: const ValueKey('spaces-status-filter'),
                            label: 'Minha participação',
                            allLabel: 'Todas as situações',
                            value: selectedStatus,
                            values: const [
                              SpaceMembershipStatus.pending,
                              SpaceMembershipStatus.approved,
                            ],
                            valueLabel: _statusFilterLabel,
                            enabled: !isLoading,
                            onChanged: onStatusChanged,
                          );

                      if (constraints.maxWidth >= 560) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: roleFilter),
                            const SizedBox(width: 12),
                            Expanded(child: statusFilter),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          roleFilter,
                          const SizedBox(height: 12),
                          statusFilter,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Papel e participação consideram o seu vínculo com o '
                    'espaço.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5D716F),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        key: const ValueKey('spaces-clear-filters'),
                        onPressed: isLoading ? null : onClear,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Limpar filtros'),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('spaces-apply-filters'),
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

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required super.key,
    required this.label,
    required this.allLabel,
    required this.value,
    required this.values,
    required this.valueLabel,
    required this.enabled,
    required this.onChanged,
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

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.space});

  final SpaceSummary space;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('space-card-${space.id}'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDDE8E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2EF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: Color(0xFF006C67),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        space.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF173B38),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (space.spaceAdminName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Responsável: ${space.spaceAdminName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5D716F),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.group_outlined,
                  label: _participantsLabel(space.activeParticipationsCount),
                ),
                _InfoChip(
                  icon: _membershipIcon(space.spaceMembershipStatus),
                  label: _membershipLabel(space),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

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

class _SpacesEmpty extends StatelessWidget {
  const _SpacesEmpty({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: ValueKey(isFiltered ? 'spaces-filter-empty' : 'spaces-empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.other_houses_outlined,
              size: 64,
              color: Color(0xFF6C8582),
            ),
            const SizedBox(height: 18),
            Text(
              isFiltered
                  ? 'Nenhum espaço corresponde aos filtros.'
                  : 'Nenhum espaço está disponível no momento.',
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

class _SpacesError extends StatelessWidget {
  const _SpacesError({
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
            key: const ValueKey('spaces-error'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 18),
              Text(
                'Não foi possível carregar os espaços',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('spaces-retry-button'),
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

String _roleFilterLabel(SpaceUserRole role) {
  return switch (role) {
    SpaceUserRole.admin => 'Administrador',
    SpaceUserRole.manager => 'Gerente',
    SpaceUserRole.participant => 'Participante',
  };
}

String _statusFilterLabel(SpaceMembershipStatus status) {
  return switch (status) {
    SpaceMembershipStatus.pending => 'Pendente',
    SpaceMembershipStatus.approved => 'Aprovada',
    SpaceMembershipStatus.blocked => 'Bloqueada',
    SpaceMembershipStatus.cancelled => 'Cancelada',
    SpaceMembershipStatus.denied => 'Negada',
    SpaceMembershipStatus.suspended => 'Suspensa',
  };
}

String _participantsLabel(int count) {
  return count == 1 ? '1 participante ativo' : '$count participantes ativos';
}

IconData _membershipIcon(String? status) {
  return switch (status) {
    'APPROVED' => Icons.verified_outlined,
    'PENDING' => Icons.hourglass_top_rounded,
    _ => Icons.explore_outlined,
  };
}

String _membershipLabel(SpaceSummary space) {
  return switch (space.spaceMembershipStatus) {
    'APPROVED' => switch (space.spaceUserRole) {
      'ROLE_SPACE_ADMIN' => 'Administrador',
      'ROLE_SPACE_MANAGER' => 'Gerente',
      'ROLE_SPACE_PARTICIPANT' => 'Participante',
      _ => 'Participação aprovada',
    },
    'PENDING' => 'Participação pendente',
    _ => 'Disponível',
  };
}

String _failureMessage(ApiFailureKind kind) {
  return switch (kind) {
    ApiFailureKind.unauthorized =>
      'Sua sessão não pôde ser autenticada. Tente entrar novamente.',
    ApiFailureKind.forbidden => 'Seu acesso não permite consultar os espaços.',
    ApiFailureKind.rateLimited =>
      'Muitas solicitações foram feitas. Aguarde um pouco e tente novamente.',
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
