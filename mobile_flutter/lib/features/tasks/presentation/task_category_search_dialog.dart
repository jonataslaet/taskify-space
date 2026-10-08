import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category.dart';
import 'package:mobile_flutter/features/tasks/domain/task_category_summary.dart';

typedef TaskCategorySearch =
    Future<List<TaskCategorySummary>> Function(String? name);

class TaskCategorySearchDialog extends StatefulWidget {
  const TaskCategorySearchDialog({
    required this.keyPrefix,
    required this.searchCategories,
    required this.initialCategory,
    this.onSessionExpired,
    super.key,
  });

  final String keyPrefix;
  final TaskCategorySearch searchCategories;
  final TaskCategory? initialCategory;
  final VoidCallback? onSessionExpired;

  @override
  State<TaskCategorySearchDialog> createState() =>
      _TaskCategorySearchDialogState();
}

class _TaskCategorySearchDialogState extends State<TaskCategorySearchDialog> {
  final _searchController = TextEditingController();
  List<TaskCategorySummary> _results = const [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_isSearching) {
      return;
    }

    final query = _searchController.text.trim();
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final categories = await widget.searchCategories(
        query.isEmpty ? null : query,
      );
      if (!mounted) {
        return;
      }
      final categoriesById = <int, TaskCategorySummary>{
        for (final category in categories) category.id: category,
      };
      setState(() {
        _results = categoriesById.values.toList(growable: false);
        _isSearching = false;
        _hasSearched = true;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      if (failure.kind == ApiFailureKind.unauthorized &&
          widget.onSessionExpired != null) {
        setState(() => _isSearching = false);
        widget.onSessionExpired!.call();
        return;
      }
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _errorMessage = _categorySearchFailureMessage(failure.kind);
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _errorMessage = _categorySearchFailureMessage(ApiFailureKind.unknown);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyPrefix = widget.keyPrefix;
    return AlertDialog(
      key: ValueKey('$keyPrefix-category-search-dialog'),
      title: const Text('Buscar categoria'),
      content: SizedBox(
        width: 480,
        height: 390,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: ValueKey('$keyPrefix-category-search-field'),
              controller: _searchController,
              enabled: !_isSearching,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Nome da categoria',
                hintText: 'Digite parte do nome',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: ValueKey('$keyPrefix-category-search-button'),
              onPressed: _isSearching ? null : _search,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Buscar'),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildSearchBody()),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: ValueKey('$keyPrefix-category-search-cancel-button'),
          onPressed: _isSearching ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildSearchBody() {
    final keyPrefix = widget.keyPrefix;
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          key: ValueKey('$keyPrefix-category-search-progress'),
        ),
      );
    }
    if (_errorMessage case final error?) {
      return Center(
        child: Semantics(
          liveRegion: true,
          child: Text(
            error,
            key: ValueKey('$keyPrefix-category-search-error'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Digite parte do nome e toque em Buscar. '
          'Deixe o campo vazio para listar todas as categorias.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma categoria encontrada.',
          key: ValueKey('$keyPrefix-category-search-empty'),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      key: ValueKey('$keyPrefix-category-search-results'),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];
        final isSelected = result.category == widget.initialCategory;
        return ListTile(
          key: ValueKey('$keyPrefix-category-option-${result.id}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.label_outline_rounded),
          title: Text(result.category.apiValue),
          trailing: isSelected
              ? const Icon(Icons.check_rounded, semanticLabel: 'Selecionada')
              : null,
          onTap: () => Navigator.of(context).pop(result.category),
        );
      },
    );
  }
}

class TaskCategoryMultiSelectDialog extends StatefulWidget {
  const TaskCategoryMultiSelectDialog({
    required this.keyPrefix,
    required this.searchCategories,
    required this.initialCategories,
    this.onSessionExpired,
    super.key,
  });

  final String keyPrefix;
  final TaskCategorySearch searchCategories;
  final Set<TaskCategory> initialCategories;
  final VoidCallback? onSessionExpired;

  @override
  State<TaskCategoryMultiSelectDialog> createState() =>
      _TaskCategoryMultiSelectDialogState();
}

class _TaskCategoryMultiSelectDialogState
    extends State<TaskCategoryMultiSelectDialog> {
  final _searchController = TextEditingController();
  late final Map<String, TaskCategory> _selectedCategories;
  List<TaskCategorySummary> _results = const [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedCategories = <String, TaskCategory>{
      for (final category in widget.initialCategories)
        category.apiValue: category,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_isSearching) {
      return;
    }

    final query = _searchController.text.trim();
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final categories = await widget.searchCategories(
        query.isEmpty ? null : query,
      );
      if (!mounted) {
        return;
      }
      final categoriesByName = <String, TaskCategorySummary>{
        for (final category in categories) category.category.apiValue: category,
      };
      setState(() {
        _results = categoriesByName.values.toList(growable: false);
        _isSearching = false;
        _hasSearched = true;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      if (failure.kind == ApiFailureKind.unauthorized &&
          widget.onSessionExpired != null) {
        setState(() => _isSearching = false);
        widget.onSessionExpired!.call();
        return;
      }
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _errorMessage = _categorySearchFailureMessage(failure.kind);
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _errorMessage = _categorySearchFailureMessage(ApiFailureKind.unknown);
      });
    }
  }

  void _toggleCategory(TaskCategory category, bool selected) {
    setState(() {
      if (selected) {
        _selectedCategories[category.apiValue] = category;
      } else {
        _selectedCategories.remove(category.apiValue);
      }
    });
  }

  void _applySelection() {
    Navigator.of(
      context,
    ).pop(Set<TaskCategory>.unmodifiable(_selectedCategories.values));
  }

  @override
  Widget build(BuildContext context) {
    final keyPrefix = widget.keyPrefix;
    final selected = _selectedCategories.values.toList(growable: false);
    return AlertDialog(
      key: ValueKey('$keyPrefix-category-search-dialog'),
      title: const Text('Selecionar categorias'),
      content: SizedBox(
        width: 480,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: ValueKey('$keyPrefix-category-search-field'),
              controller: _searchController,
              enabled: !_isSearching,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Nome da categoria',
                hintText: 'Digite parte do nome',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: ValueKey('$keyPrefix-category-search-button'),
              onPressed: _isSearching ? null : _search,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Buscar'),
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  key: ValueKey('$keyPrefix-category-selection'),
                  scrollDirection: Axis.horizontal,
                  itemCount: selected.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = selected[index];
                    return InputChip(
                      key: ValueKey(
                        '$keyPrefix-category-selection-${category.apiValue}',
                      ),
                      label: Text(category.apiValue),
                      onDeleted: _isSearching
                          ? null
                          : () => _toggleCategory(category, false),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildSearchBody()),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: ValueKey('$keyPrefix-category-search-cancel-button'),
          onPressed: _isSearching ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: ValueKey('$keyPrefix-category-search-apply-button'),
          onPressed: _isSearching ? null : _applySelection,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  Widget _buildSearchBody() {
    final keyPrefix = widget.keyPrefix;
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          key: ValueKey('$keyPrefix-category-search-progress'),
        ),
      );
    }
    if (_errorMessage case final error?) {
      return Center(
        child: Semantics(
          liveRegion: true,
          child: Text(
            error,
            key: ValueKey('$keyPrefix-category-search-error'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Digite parte do nome e toque em Buscar. '
          'Deixe o campo vazio para listar todas as categorias.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma categoria encontrada.',
          key: ValueKey('$keyPrefix-category-search-empty'),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      key: ValueKey('$keyPrefix-category-search-results'),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];
        final category = result.category;
        return CheckboxListTile(
          key: ValueKey('$keyPrefix-category-option-${result.id}'),
          value: _selectedCategories.containsKey(category.apiValue),
          onChanged: (selected) => _toggleCategory(category, selected ?? false),
          title: Text(category.apiValue),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        );
      },
    );
  }
}

String _categorySearchFailureMessage(ApiFailureKind kind) {
  return switch (kind) {
    ApiFailureKind.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    ApiFailureKind.forbidden =>
      'Seu acesso não permite consultar as categorias deste espaço.',
    ApiFailureKind.rateLimited =>
      'Muitas buscas foram feitas. Aguarde e tente novamente.',
    ApiFailureKind.timeout => 'A busca demorou mais que o esperado.',
    ApiFailureKind.network => 'Não foi possível conectar à API.',
    ApiFailureKind.server => 'O serviço de busca está indisponível.',
    ApiFailureKind.malformedResponse =>
      'A API retornou categorias em um formato inesperado.',
    _ => 'Não foi possível buscar categorias agora.',
  };
}
