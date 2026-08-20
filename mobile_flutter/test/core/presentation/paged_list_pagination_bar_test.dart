import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/presentation/paged_list_pagination_bar.dart';

void main() {
  testWidgets('expõe ação semântica para selecionar outra página', (
    tester,
  ) async {
    int? selectedPage;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedListPaginationBar(
            keyPrefix: 'test',
            currentPage: 0,
            pageItemCount: 10,
            totalElements: 30,
            totalPages: 3,
            pageSize: 10,
            pageSizeOptions: const [10],
            onPageSelected: (page) => selectedPage = page,
            onPageSizeChanged: (_) {},
          ),
        ),
      ),
    );

    final nextPageSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Ir para página 2',
      ),
    );
    expect(nextPageSemantics.properties.button, isTrue);
    expect(nextPageSemantics.properties.onTap, isNotNull);

    nextPageSemantics.properties.onTap!();
    expect(selectedPage, 1);

    final currentPageSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Página 1, atual',
      ),
    );
    expect(currentPageSemantics.properties.selected, isTrue);
    expect(currentPageSemantics.properties.onTap, isNull);
  });
}
