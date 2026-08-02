import 'package:flutter/material.dart';

class PagedListPaginationBar extends StatelessWidget {
  const PagedListPaginationBar({
    required this.keyPrefix,
    required this.currentPage,
    required this.pageItemCount,
    required this.totalElements,
    required this.totalPages,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.onPageSelected,
    required this.onPageSizeChanged,
    super.key,
  });

  final String keyPrefix;
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
      key: ValueKey('$keyPrefix-pagination-bar'),
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
                key: ValueKey('$keyPrefix-page-summary'),
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
                    key: ValueKey('$keyPrefix-page-previous'),
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
                                  keyPrefix: keyPrefix,
                                  page: page,
                                  isCurrent: page == currentPage,
                                  onPressed: () => onPageSelected(page),
                                ),
                              )
                            else
                              SizedBox(
                                key: ValueKey(
                                  '$keyPrefix-page-ellipsis-$index',
                                ),
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
                    key: ValueKey('$keyPrefix-page-next'),
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
                    key: ValueKey('$keyPrefix-page-size'),
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
    required this.keyPrefix,
    required this.page,
    required this.isCurrent,
    required this.onPressed,
  });

  final String keyPrefix;
  final int page;
  final bool isCurrent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = '${page + 1}';
    final button = isCurrent
        ? FilledButton(
            key: ValueKey('$keyPrefix-page-$page'),
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
            key: ValueKey('$keyPrefix-page-$page'),
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
