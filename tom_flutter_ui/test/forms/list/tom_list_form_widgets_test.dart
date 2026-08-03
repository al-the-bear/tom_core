/// Widget-level coverage for the inline list-form presentation:
/// `TomInlineListForm`, `TomListRowMoveButtons` and `TomReorderHandle`.
///
/// The controller (`TomListForm`) is pinned separately in
/// `tom_list_form_test.dart`; this suite is about what the user *sees and
/// touches*. That split matters because the two halves fail differently: a
/// controller bug corrupts the model, whereas a presentation bug leaves the
/// model correct and the screen wrong — a disabled arrow that should be live,
/// a separator drawn after the last row, a row that never repaints after an
/// edit. None of those are visible from the controller tests.
///
/// Two deliberate choices run through the file:
///
///   * **Assert on geometry, not on widget shape, wherever the property under
///     test is a layout property.** `spacing`, `axis` and the leading/trailing
///     placement of the move buttons all describe where things end up on
///     screen, so the tests measure that. Matching on `Row` vs `Column` would
///     pass just as happily if the children were in the wrong order, and would
///     break the moment an unrelated `Row` appeared inside `IconButton`.
///
///   * **Drive `ReorderableListView` through its `onReorderItem` field rather
///     than by synthesising a drag.** The forwarding logic in
///     `_buildRows` — the self-move guard and the "`to` is already
///     post-removal" contract — is what this widget owns; the drag gesture
///     itself belongs to Flutter and is tested there.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../support/list_form_fixtures.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 400, child: child))),
    );

/// A list form bound to a fresh order carrying [products].
OrderItemListForm _listWith(List<String> products) {
  final order = orderWith(products);
  return OrderItemListForm()..bind(order.items);
}

List<String> _formProducts(OrderItemListForm list) =>
    list.forms.map((f) => f.product.get()).toList();

/// The default inline row body: the row's product, tagged with its index so a
/// test can tell "row 0 shows Bolt" from "some row shows Bolt".
Widget _productRow(BuildContext _, int index, OrderItemForm form) =>
    Text('$index:${form.product.get()}');

void main() {
  setUpAll(initializeReflection);

  // -------------------------------------------------------------------------
  // TomReorderHandle
  // -------------------------------------------------------------------------

  group('TomReorderHandle', () {
    testWidgets('renders the default drag icon at the default size',
        (tester) async {
      await tester.pumpWidget(_app(TomReorderHandle(index: 0)));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.drag_indicator);
      expect(icon.size, 18.0);
      expect(icon.color, isNull);
    });

    testWidgets('reports its row index to the enclosing reorderable list',
        (tester) async {
      // The handle does not itself reorder anything; its whole job is to tell
      // the host which row the drag picked up.
      await tester.pumpWidget(_app(TomReorderHandle(index: 3)));

      final listener = tester.widget<ReorderableDragStartListener>(
        find.byType(ReorderableDragStartListener),
      );
      expect(listener.index, 3);
    });

    testWidgets('shows the default tooltip', (tester) async {
      await tester.pumpWidget(_app(TomReorderHandle(index: 0)));

      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Drag to reorder',
      );
    });

    testWidgets('an empty tooltip suppresses the Tooltip wrapper entirely',
        (tester) async {
      // Not the same as a whitespace tooltip: an empty string is the opt-out,
      // so no hover target is created at all.
      await tester.pumpWidget(_app(TomReorderHandle(index: 0, tooltip: '')));

      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('honours explicit icon, size, colour and tooltip',
        (tester) async {
      await tester.pumpWidget(_app(TomReorderHandle(
        index: 0,
        icon: Icons.menu,
        size: 30,
        color: const Color(0xFF00FF00),
        tooltip: 'Grab me',
      )));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.menu);
      expect(icon.size, 30.0);
      expect(icon.color, const Color(0xFF00FF00));
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Grab me',
      );
    });

    testWidgets('applies the default padding around the icon', (tester) async {
      await tester.pumpWidget(_app(TomReorderHandle(index: 0)));

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.byType(Icon),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, const EdgeInsets.symmetric(horizontal: 4, vertical: 6));
    });

    testWidgets('honours explicit padding', (tester) async {
      await tester.pumpWidget(_app(
        TomReorderHandle(index: 0, padding: const EdgeInsets.all(12)),
      ));

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.byType(Icon),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, const EdgeInsets.all(12));
    });

    testWidgets('offers the grab cursor so the row reads as draggable',
        (tester) async {
      await tester.pumpWidget(_app(TomReorderHandle(index: 0)));

      final region = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(ReorderableDragStartListener),
          matching: find.byType(MouseRegion),
        ).first,
      );
      expect(region.cursor, SystemMouseCursors.grab);
    });
  });

  // -------------------------------------------------------------------------
  // TomListRowMoveButtons
  // -------------------------------------------------------------------------

  group('TomListRowMoveButtons', () {
    Finder upButton() =>
        find.widgetWithIcon(IconButton, Icons.arrow_upward);
    Finder downButton() =>
        find.widgetWithIcon(IconButton, Icons.arrow_downward);

    bool enabled(WidgetTester tester, Finder button) =>
        tester.widget<IconButton>(button).onPressed != null;

    Future<void> pumpButtons(
      WidgetTester tester,
      OrderItemListForm list,
      int index, {
      void Function(int, int)? onReorder,
      Future<bool> Function(int, int)? beforeMove,
      Axis axis = Axis.horizontal,
      double? spacing,
      bool dense = true,
    }) async {
      await tester.pumpWidget(_app(TomListRowMoveButtons<OrderItem, OrderItemForm>(
        listForm: list,
        index: index,
        onReorder: onReorder,
        beforeMove: beforeMove,
        axis: axis,
        spacing: spacing,
        dense: dense,
      )));
    }

    testWidgets('renders an up and a down arrow', (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1);

      expect(upButton(), findsOneWidget);
      expect(downButton(), findsOneWidget);
    });

    testWidgets('the first row cannot move up', (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 0);

      expect(enabled(tester, upButton()), isFalse);
      expect(enabled(tester, downButton()), isTrue);
    });

    testWidgets('the last row cannot move down', (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 2);

      expect(enabled(tester, upButton()), isTrue);
      expect(enabled(tester, downButton()), isFalse);
    });

    testWidgets('a middle row can move both ways', (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1);

      expect(enabled(tester, upButton()), isTrue);
      expect(enabled(tester, downButton()), isTrue);
    });

    testWidgets('a single-row list disables both arrows', (tester) async {
      // The row is simultaneously first and last, so both gates close. The
      // arrows still render — greyed rather than absent — which is what keeps
      // the row chrome from reflowing as rows come and go.
      await pumpButtons(tester, _listWith(['Only']), 0);

      expect(upButton(), findsOneWidget);
      expect(downButton(), findsOneWidget);
      expect(enabled(tester, upButton()), isFalse);
      expect(enabled(tester, downButton()), isFalse);
    });

    testWidgets('tapping up moves the row one place earlier', (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      await pumpButtons(tester, list, 1);

      await tester.tap(upButton());
      await tester.pump();

      expect(_formProducts(list), ['B', 'A', 'C']);
    });

    testWidgets('tapping down moves the row one place later', (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      await pumpButtons(tester, list, 1);

      await tester.tap(downButton());
      await tester.pump();

      expect(_formProducts(list), ['A', 'C', 'B']);
    });

    testWidgets('onReorder reports the source and destination indices',
        (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      final calls = <List<int>>[];
      await pumpButtons(tester, list, 1,
          onReorder: (from, to) => calls.add([from, to]));

      await tester.tap(downButton());
      await tester.pump();

      expect(calls, [
        [1, 2]
      ]);
    });

    testWidgets('onReorder runs after the move, not before', (tester) async {
      // A caller that updates a selection index from this hook has to be able
      // to read the already-reordered list.
      final list = _listWith(['A', 'B', 'C']);
      List<String>? seen;
      await pumpButtons(tester, list, 0,
          onReorder: (_, _) => seen = _formProducts(list));

      await tester.tap(downButton());
      await tester.pump();

      expect(seen, ['B', 'A', 'C']);
    });

    testWidgets('beforeMove returning false vetoes the move', (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      final reordered = <int>[];
      await pumpButtons(tester, list, 1,
          beforeMove: (_, _) async => false,
          onReorder: (from, _) => reordered.add(from));

      await tester.tap(downButton());
      await tester.pump();

      expect(_formProducts(list), ['A', 'B', 'C']);
      expect(reordered, isEmpty, reason: 'a vetoed move must not notify');
    });

    testWidgets('beforeMove returning true lets the move through',
        (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      final asked = <List<int>>[];
      await pumpButtons(tester, list, 1, beforeMove: (from, to) async {
        asked.add([from, to]);
        return true;
      });

      await tester.tap(downButton());
      await tester.pump();

      expect(asked, [
        [1, 2]
      ]);
      expect(_formProducts(list), ['A', 'C', 'B']);
    });

    testWidgets('horizontal is the default axis', (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1);

      final up = tester.getCenter(upButton());
      final down = tester.getCenter(downButton());
      expect(down.dx, greaterThan(up.dx));
      expect(down.dy, up.dy);
    });

    testWidgets('the vertical axis stacks down beneath up', (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1,
          axis: Axis.vertical);

      final up = tester.getCenter(upButton());
      final down = tester.getCenter(downButton());
      expect(down.dy, greaterThan(up.dy));
      expect(down.dx, up.dx);
    });

    testWidgets('spacing widens the horizontal gap between the arrows',
        (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1, spacing: 0);
      final tight = tester.getTopLeft(downButton()).dx -
          tester.getBottomRight(upButton()).dx;

      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1, spacing: 12);
      final loose = tester.getTopLeft(downButton()).dx -
          tester.getBottomRight(upButton()).dx;

      expect(loose - tight, 12.0);
    });

    testWidgets('spacing on the vertical axis opens a vertical gap',
        (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1,
          axis: Axis.vertical, spacing: 0);
      final tight = tester.getTopLeft(downButton()).dy -
          tester.getBottomRight(upButton()).dy;

      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1,
          axis: Axis.vertical, spacing: 12);
      final loose = tester.getTopLeft(downButton()).dy -
          tester.getBottomRight(upButton()).dy;

      expect(loose - tight, 12.0);
    });

    testWidgets('dense is the default and compacts both buttons',
        (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1);

      expect(tester.widget<IconButton>(upButton()).visualDensity,
          VisualDensity.compact);
      expect(tester.widget<IconButton>(downButton()).visualDensity,
          VisualDensity.compact);
    });

    testWidgets('dense: false restores the standard hit target',
        (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1, dense: false);

      expect(tester.widget<IconButton>(upButton()).visualDensity,
          VisualDensity.standard);
    });

    testWidgets('honours explicit icons and tooltips', (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(
        TomListRowMoveButtons<OrderItem, OrderItemForm>(
          listForm: list,
          index: 1,
          moveUpIcon: Icons.keyboard_arrow_up,
          moveDownIcon: Icons.keyboard_arrow_down,
          moveUpTooltip: 'Earlier',
          moveDownTooltip: 'Later',
        ),
      ));

      expect(find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up),
          findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down),
          findsOneWidget);
      final tooltips = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .map((b) => b.tooltip)
          .toList();
      expect(tooltips, ['Earlier', 'Later']);
    });

    testWidgets('the default tooltips read as plain directions',
        (tester) async {
      await pumpButtons(tester, _listWith(['A', 'B', 'C']), 1);

      expect(tester.widget<IconButton>(upButton()).tooltip, 'Move up');
      expect(tester.widget<IconButton>(downButton()).tooltip, 'Move down');
    });

    testWidgets('honours an explicit icon size', (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(
        TomListRowMoveButtons<OrderItem, OrderItemForm>(
          listForm: list,
          index: 1,
          iconSize: 32,
        ),
      ));

      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.size, 32.0);
      }
    });
  });

  // -------------------------------------------------------------------------
  // TomInlineListForm — composition
  // -------------------------------------------------------------------------

  group('TomInlineListForm composition', () {
    Widget inline(
      OrderItemListForm list, {
      Widget Function(BuildContext, int, OrderItemForm)? rowBuilder,
      Widget Function(BuildContext, TomListForm<OrderItem, OrderItemForm>)?
          headerBuilder,
      Widget Function(BuildContext, TomListForm<OrderItem, OrderItemForm>)?
          footerBuilder,
      Widget Function(BuildContext, TomListForm<OrderItem, OrderItemForm>)?
          toolbarBuilder,
      Widget Function(BuildContext)? emptyBuilder,
      Widget Function(BuildContext, int)? rowSeparatorBuilder,
      EdgeInsetsGeometry? padding,
      bool reorderable = false,
      void Function(int, int)? onReorder,
      bool showRowMoveButtons = false,
      TomRowMoveButtonsPosition rowMoveButtonsPosition =
          TomRowMoveButtonsPosition.trailing,
    }) =>
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: list,
          rowBuilder: rowBuilder ?? _productRow,
          headerBuilder: headerBuilder,
          footerBuilder: footerBuilder,
          toolbarBuilder: toolbarBuilder,
          emptyBuilder: emptyBuilder,
          rowSeparatorBuilder: rowSeparatorBuilder,
          padding: padding,
          reorderable: reorderable,
          onReorder: onReorder,
          showRowMoveButtons: showRowMoveButtons,
          rowMoveButtonsPosition: rowMoveButtonsPosition,
        );

    testWidgets('renders exactly one row per sub-form, in list order',
        (tester) async {
      await tester.pumpWidget(_app(inline(_listWith(['A', 'B', 'C']))));

      expect(find.text('0:A'), findsOneWidget);
      expect(find.text('1:B'), findsOneWidget);
      expect(find.text('2:C'), findsOneWidget);
      expect(tester.getTopLeft(find.text('1:B')).dy,
          greaterThan(tester.getTopLeft(find.text('0:A')).dy));
    });

    testWidgets("the row builder receives the list's own sub-form instance",
        (tester) async {
      // Not a copy and not a fresh form bound to the same item: rows edit the
      // very form the list owns, which is what makes per-row dirty state and
      // structural mutation propagate without any sibling reconciliation.
      final list = _listWith(['A', 'B']);
      final seen = <OrderItemForm>[];
      await tester.pumpWidget(_app(inline(
        list,
        rowBuilder: (ctx, i, form) {
          seen.add(form);
          return Text('$i');
        },
      )));

      expect(identical(seen[0], list[0]), isTrue);
      expect(identical(seen[1], list[1]), isTrue);
    });

    testWidgets('renders header, rows, footer and toolbar in that order',
        (tester) async {
      await tester.pumpWidget(_app(inline(
        _listWith(['A']),
        headerBuilder: (_, _) => const Text('HEADER'),
        footerBuilder: (_, _) => const Text('FOOTER'),
        toolbarBuilder: (_, _) => const Text('TOOLBAR'),
      )));

      final header = tester.getTopLeft(find.text('HEADER')).dy;
      final row = tester.getTopLeft(find.text('0:A')).dy;
      final footer = tester.getTopLeft(find.text('FOOTER')).dy;
      final toolbar = tester.getTopLeft(find.text('TOOLBAR')).dy;

      expect(header, lessThan(row));
      expect(row, lessThan(footer));
      expect(footer, lessThan(toolbar));
    });

    testWidgets('the chrome builders receive the list form itself',
        (tester) async {
      final list = _listWith(['A']);
      TomListForm<OrderItem, OrderItemForm>? given;
      await tester.pumpWidget(_app(inline(
        list,
        headerBuilder: (_, l) {
          given = l;
          return const SizedBox.shrink();
        },
      )));

      expect(identical(given, list), isTrue);
    });

    testWidgets('an empty list shows the empty builder instead of rows',
        (tester) async {
      await tester.pumpWidget(_app(inline(
        _listWith([]),
        emptyBuilder: (_) => const Text('Nothing here'),
      )));

      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.textContaining(':'), findsNothing);
    });

    testWidgets('header, footer and toolbar still render around the empty state',
        (tester) async {
      // The empty state replaces the *rows*, not the chrome — the Add button
      // lives in the toolbar, so hiding it when the list is empty would leave
      // the user with no way out.
      await tester.pumpWidget(_app(inline(
        _listWith([]),
        headerBuilder: (_, _) => const Text('HEADER'),
        footerBuilder: (_, _) => const Text('FOOTER'),
        toolbarBuilder: (_, _) => const Text('TOOLBAR'),
        emptyBuilder: (_) => const Text('Nothing here'),
      )));

      expect(find.text('HEADER'), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('FOOTER'), findsOneWidget);
      expect(find.text('TOOLBAR'), findsOneWidget);
    });

    testWidgets('an empty list with no empty builder renders no placeholder',
        (tester) async {
      await tester.pumpWidget(_app(inline(
        _listWith([]),
        headerBuilder: (_, _) => const Text('HEADER'),
      )));

      expect(find.text('HEADER'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('the empty builder disappears once a row exists',
        (tester) async {
      final list = _listWith([]);
      await tester.pumpWidget(_app(inline(
        list,
        emptyBuilder: (_) => const Text('Nothing here'),
      )));
      expect(find.text('Nothing here'), findsOneWidget);

      list.add();
      await tester.pump();

      expect(find.text('Nothing here'), findsNothing);
      expect(find.text('0:'), findsOneWidget);
    });

    testWidgets('applies the configured padding', (tester) async {
      await tester.pumpWidget(_app(inline(
        _listWith(['A']),
        padding: const EdgeInsets.all(16),
      )));

      final padded = tester.widgetList<Padding>(find.byType(Padding)).where(
          (p) => p.padding == const EdgeInsets.all(16));
      expect(padded, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // TomInlineListForm — separators
  // -------------------------------------------------------------------------

  group('TomInlineListForm separators', () {
    testWidgets('inserts one separator between each pair of rows',
        (tester) async {
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: _listWith(['A', 'B', 'C']),
        rowBuilder: _productRow,
        rowSeparatorBuilder: (_, i) => Text('sep-$i'),
      )));

      // Three rows means two separators — never one above row 0 and never one
      // trailing the last row.
      expect(find.text('sep-0'), findsOneWidget);
      expect(find.text('sep-1'), findsOneWidget);
      expect(find.text('sep-2'), findsNothing);
    });

    testWidgets('the separator index identifies the row above it',
        (tester) async {
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: _listWith(['A', 'B']),
        rowBuilder: _productRow,
        rowSeparatorBuilder: (_, i) => Text('sep-$i'),
      )));

      final rowA = tester.getTopLeft(find.text('0:A')).dy;
      final sep = tester.getTopLeft(find.text('sep-0')).dy;
      final rowB = tester.getTopLeft(find.text('1:B')).dy;
      expect(sep, greaterThan(rowA));
      expect(rowB, greaterThan(sep));
    });

    testWidgets('a single row gets no separator at all', (tester) async {
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: _listWith(['A']),
        rowBuilder: _productRow,
        rowSeparatorBuilder: (_, i) => Text('sep-$i'),
      )));

      expect(find.textContaining('sep-'), findsNothing);
    });

    testWidgets('separators are ignored in reorderable mode', (tester) async {
      // ReorderableListView renders one widget per row with no slot between
      // them, so a separator would have to become a row of its own and would
      // then be draggable. Dropping it is the documented behaviour.
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: _listWith(['A', 'B', 'C']),
        rowBuilder: _productRow,
        reorderable: true,
        rowSeparatorBuilder: (_, i) => Text('sep-$i'),
      )));

      expect(find.textContaining('sep-'), findsNothing);
      expect(find.text('0:A'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // TomInlineListForm — reordering
  // -------------------------------------------------------------------------

  group('TomInlineListForm reordering', () {
    Widget reorderable(
      OrderItemListForm list, {
      void Function(int, int)? onReorder,
    }) =>
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: list,
          rowBuilder: _productRow,
          reorderable: true,
          onReorder: onReorder,
        );

    ReorderableListView view(WidgetTester tester) =>
        tester.widget<ReorderableListView>(find.byType(ReorderableListView));

    testWidgets('reorderable swaps the plain column for a reorderable list',
        (tester) async {
      await tester.pumpWidget(_app(reorderable(_listWith(['A', 'B']))));

      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('non-reorderable lists build no ReorderableListView',
        (tester) async {
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: _listWith(['A', 'B']),
        rowBuilder: _productRow,
      )));

      expect(find.byType(ReorderableListView), findsNothing);
    });

    testWidgets('a downward reorder moves the row to the reported index',
        (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(reorderable(list)));

      // `onReorderItem` already reports `to` adjusted for the removed row, so
      // it matches TomListForm's final-index semantics with no translation.
      view(tester).onReorderItem!(0, 2);
      await tester.pump();

      expect(_formProducts(list), ['B', 'C', 'A']);
    });

    testWidgets('an upward reorder moves the row to the reported index',
        (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(reorderable(list)));

      view(tester).onReorderItem!(2, 0);
      await tester.pump();

      expect(_formProducts(list), ['C', 'A', 'B']);
    });

    testWidgets('a drop back onto the same index changes nothing',
        (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      final calls = <List<int>>[];
      await tester
          .pumpWidget(_app(reorderable(list, onReorder: (f, t) => calls.add([f, t]))));

      view(tester).onReorderItem!(1, 1);
      await tester.pump();

      expect(_formProducts(list), ['A', 'B', 'C']);
      expect(calls, isEmpty, reason: 'a no-op drop must not report a reorder');
    });

    testWidgets('onReorder reports the normalised source and destination',
        (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      final calls = <List<int>>[];
      await tester
          .pumpWidget(_app(reorderable(list, onReorder: (f, t) => calls.add([f, t]))));

      view(tester).onReorderItem!(0, 2);
      await tester.pump();

      expect(calls, [
        [0, 2]
      ]);
    });

    testWidgets('the reordered rows repaint in their new order',
        (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(reorderable(list)));

      view(tester).onReorderItem!(0, 2);
      await tester.pump();

      final positions = {
        for (final p in ['A', 'B', 'C'])
          p: tester.getTopLeft(find.textContaining(':$p')).dy,
      };
      expect(positions['B']!, lessThan(positions['C']!));
      expect(positions['C']!, lessThan(positions['A']!));
    });

    testWidgets('rows carry drag handles wired to their own index',
        (tester) async {
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: _listWith(['A', 'B', 'C']),
        rowBuilder: (ctx, i, form) => Row(children: [
          TomReorderHandle(index: i),
          Expanded(child: Text('$i:${form.product.get()}')),
        ]),
        reorderable: true,
      )));

      final indices = tester
          .widgetList<ReorderableDragStartListener>(
              find.byType(ReorderableDragStartListener))
          .map((l) => l.index)
          .toList();
      expect(indices, [0, 1, 2]);
    });
  });

  // -------------------------------------------------------------------------
  // TomInlineListForm — auto row move buttons
  // -------------------------------------------------------------------------

  group('TomInlineListForm row move buttons', () {
    Widget withButtons(
      OrderItemListForm list, {
      bool show = true,
      TomRowMoveButtonsPosition position = TomRowMoveButtonsPosition.trailing,
      void Function(int, int)? onReorder,
    }) =>
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: list,
          rowBuilder: _productRow,
          showRowMoveButtons: show,
          rowMoveButtonsPosition: position,
          onReorder: onReorder,
        );

    testWidgets('adds one button pair per row when enabled', (tester) async {
      await tester.pumpWidget(_app(withButtons(_listWith(['A', 'B', 'C']))));

      expect(find.byType(TomListRowMoveButtons<OrderItem, OrderItemForm>),
          findsNWidgets(3));
    });

    testWidgets('adds nothing when disabled', (tester) async {
      await tester
          .pumpWidget(_app(withButtons(_listWith(['A', 'B']), show: false)));

      expect(find.byType(TomListRowMoveButtons<OrderItem, OrderItemForm>),
          findsNothing);
    });

    testWidgets('trailing is the default and puts the arrows after the row body',
        (tester) async {
      await tester.pumpWidget(_app(withButtons(_listWith(['A', 'B']))));

      final body = tester.getCenter(find.text('0:A')).dx;
      final buttons = tester
          .getCenter(find.byType(TomListRowMoveButtons<OrderItem, OrderItemForm>).first)
          .dx;
      expect(buttons, greaterThan(body));
    });

    testWidgets('leading puts the arrows before the row body', (tester) async {
      await tester.pumpWidget(_app(withButtons(
        _listWith(['A', 'B']),
        position: TomRowMoveButtonsPosition.leading,
      )));

      final body = tester.getCenter(find.text('0:A')).dx;
      final buttons = tester
          .getCenter(find.byType(TomListRowMoveButtons<OrderItem, OrderItemForm>).first)
          .dx;
      expect(buttons, lessThan(body));
    });

    testWidgets('each pair is bound to its own row index', (tester) async {
      // Row 0 must not be able to move up and the last row must not be able to
      // move down — the pairs are per-row, not shared.
      await tester.pumpWidget(_app(withButtons(_listWith(['A', 'B', 'C']))));

      final ups = tester
          .widgetList<IconButton>(
              find.widgetWithIcon(IconButton, Icons.arrow_upward))
          .toList();
      final downs = tester
          .widgetList<IconButton>(
              find.widgetWithIcon(IconButton, Icons.arrow_downward))
          .toList();

      expect(ups.map((b) => b.onPressed != null), [false, true, true]);
      expect(downs.map((b) => b.onPressed != null), [true, true, false]);
    });

    testWidgets('tapping a row arrow reorders and repaints the list',
        (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(withButtons(list)));

      await tester.tap(
          find.widgetWithIcon(IconButton, Icons.arrow_downward).first);
      await tester.pump();

      expect(_formProducts(list), ['B', 'A', 'C']);
      expect(find.text('0:B'), findsOneWidget);
      expect(find.text('1:A'), findsOneWidget);
    });

    testWidgets('the inline onReorder hook fires for row-button moves too',
        (tester) async {
      // The buttons are constructed by the inline list, so its `onReorder` is
      // the only hook a caller has for them.
      final list = _listWith(['A', 'B', 'C']);
      final calls = <List<int>>[];
      await tester.pumpWidget(
          _app(withButtons(list, onReorder: (f, t) => calls.add([f, t]))));

      await tester.tap(
          find.widgetWithIcon(IconButton, Icons.arrow_downward).first);
      await tester.pump();

      expect(calls, [
        [0, 1]
      ]);
    });
  });

  // -------------------------------------------------------------------------
  // TomInlineListForm — live observation
  // -------------------------------------------------------------------------

  group('TomInlineListForm observation', () {
    testWidgets('an added row appears without the host rebuilding',
        (tester) async {
      final list = _listWith(['A']);
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: list,
        rowBuilder: _productRow,
      )));

      list.add();
      await tester.pump();

      expect(find.text('0:A'), findsOneWidget);
      expect(find.text('1:'), findsOneWidget);
    });

    testWidgets('a removed row disappears', (tester) async {
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: list,
        rowBuilder: _productRow,
      )));

      list.removeAt(0);
      await tester.pump();

      expect(find.text('0:B'), findsOneWidget);
      expect(find.textContaining('A'), findsNothing);
    });

    testWidgets('a per-row field edit repaints that row', (tester) async {
      // Row builders read row-form state freely, so the list has to wake on
      // field-level notifications and not just structural ones — otherwise
      // every builder would need its own observer.
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: list,
        rowBuilder: _productRow,
      )));

      list[0].product.setValue('Z');
      await tester.pump();

      expect(find.text('0:Z'), findsOneWidget);
      expect(find.text('0:A'), findsNothing);

      // `setValue` arms the validation debounce; let it fire so the test ends
      // with no pending timer.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the observer is detached on dispose', (tester) async {
      // A leaked observer turns a later structural change into a setState on
      // an unmounted State, which is a hard error rather than a silent leak.
      final list = _listWith(['A']);
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: list,
        rowBuilder: _productRow,
      )));

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      list.add();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('swapping in a different list form re-targets the observer',
        (tester) async {
      final first = _listWith(['A']);
      final second = _listWith(['X']);

      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: first,
        rowBuilder: _productRow,
      )));
      await tester.pumpWidget(_app(TomInlineListForm<OrderItem, OrderItemForm>(
        listForm: second,
        rowBuilder: _productRow,
      )));

      expect(find.text('0:X'), findsOneWidget);

      second.add();
      await tester.pump();
      expect(find.text('1:'), findsOneWidget);

      // The old list must no longer drive this widget.
      first.add();
      await tester.pump();
      expect(find.textContaining('A'), findsNothing);
    });
  });
}
