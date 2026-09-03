/// Behavioural coverage for `TomListFormToolbar` — the shared Add / Remove /
/// Move-up / Move-down bar that every list-shaped form leans on.
///
/// The toolbar is almost entirely *enablement* logic: which of the four
/// buttons is live depends on whether a row is selected and where that row
/// sits. That logic is invisible from the model side (a disabled button and an
/// absent button leave the list identically untouched), so it is asserted here
/// by reading each button's `onPressed` — a null callback is precisely the
/// contract the widget promises for "not meaningful right now".
///
/// The toolbar deliberately does *not* observe its list — the host owns
/// selection and rebuilds — so these tests assert on the model after an action
/// and re-pump explicitly when they want to see the new enablement.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../support/list_form_fixtures.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 600, child: child)),
  ),
);

OrderItemListForm _listWith(List<String> products) {
  final order = orderWith(products);
  return OrderItemListForm()..bind(order.items);
}

List<String> _formProducts(OrderItemListForm list) =>
    list.forms.map((f) => f.product.get()).toList();

void main() {
  setUpAll(initializeReflection);

  Finder addButton() => find.widgetWithText(FilledButton, 'Add');
  Finder removeButton() => find.widgetWithText(FilledButton, 'Remove');
  Finder upButton() => find.widgetWithIcon(IconButton, Icons.arrow_upward);
  Finder downButton() => find.widgetWithIcon(IconButton, Icons.arrow_downward);

  bool enabled(WidgetTester tester, Finder f) {
    final w = tester.widget(f);
    if (w is FilledButton) return w.onPressed != null;
    if (w is IconButton) return w.onPressed != null;
    fail('not a button: $w');
  }

  Future<void> pumpToolbar(
    WidgetTester tester,
    OrderItemListForm list, {
    int? selectedIndex,
    Future<void> Function(int?)? onSelectionChanged,
    bool showAdd = true,
    bool showRemove = true,
    bool showMoveUp = true,
    bool showMoveDown = true,
    Future<bool> Function()? beforeAdd,
    Future<bool> Function(int)? beforeRemove,
    Future<bool> Function(int, int)? beforeMove,
    List<Widget>? beforeActions,
    List<Widget>? afterActions,
    String? addLabel,
    String? removeLabel,
    String? moveUpLabel,
    String? addTooltip,
    IconData? addIcon,
    bool dense = true,
  }) async {
    await tester.pumpWidget(
      _app(
        TomListFormToolbar<OrderItem, OrderItemForm>(
          listForm: list,
          selectedIndex: selectedIndex,
          onSelectionChanged: onSelectionChanged,
          showAdd: showAdd,
          showRemove: showRemove,
          showMoveUp: showMoveUp,
          showMoveDown: showMoveDown,
          beforeAdd: beforeAdd,
          beforeRemove: beforeRemove,
          beforeMove: beforeMove,
          beforeActions: beforeActions,
          afterActions: afterActions,
          addLabel: addLabel,
          removeLabel: removeLabel,
          moveUpLabel: moveUpLabel,
          addTooltip: addTooltip,
          addIcon: addIcon,
          dense: dense,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  group('TomListFormToolbar rendering', () {
    testWidgets('renders the four standard actions', (tester) async {
      await pumpToolbar(tester, _listWith(['A', 'B']));

      expect(addButton(), findsOneWidget);
      expect(removeButton(), findsOneWidget);
      expect(upButton(), findsOneWidget);
      expect(downButton(), findsOneWidget);
    });

    testWidgets('the move pair is bundled so it wraps as one unit', (
      tester,
    ) async {
      // A lone arrow orphaned on a second line was the reported defect; the
      // fix was to give the Wrap a single atomic child for the pair.
      await pumpToolbar(tester, _listWith(['A', 'B']));

      final pairRow = find.ancestor(
        of: upButton(),
        matching: find.descendant(
          of: find.byType(Wrap),
          matching: find.byType(Row),
        ),
      );
      expect(
        find.descendant(of: pairRow.first, matching: downButton()),
        findsOneWidget,
      );
    });

    testWidgets('the move buttons are icon-only by default', (tester) async {
      await pumpToolbar(tester, _listWith(['A', 'B']));

      expect(tester.widget<IconButton>(upButton()).tooltip, 'Move up');
      expect(tester.widget<IconButton>(downButton()).tooltip, 'Move down');
    });

    testWidgets('a move label turns the arrow into a labelled button', (
      tester,
    ) async {
      await pumpToolbar(tester, _listWith(['A', 'B']), moveUpLabel: 'Earlier');

      expect(find.widgetWithText(FilledButton, 'Earlier'), findsOneWidget);
      expect(upButton(), findsNothing);
      // The unlabelled counterpart stays an icon button.
      expect(downButton(), findsOneWidget);
    });

    testWidgets('hides individual buttons on request', (tester) async {
      await pumpToolbar(
        tester,
        _listWith(['A', 'B']),
        showRemove: false,
        showMoveDown: false,
      );

      expect(addButton(), findsOneWidget);
      expect(removeButton(), findsNothing);
      expect(upButton(), findsOneWidget);
      expect(downButton(), findsNothing);
    });

    testWidgets('hiding every action collapses the toolbar entirely', (
      tester,
    ) async {
      await pumpToolbar(
        tester,
        _listWith(['A', 'B']),
        showAdd: false,
        showRemove: false,
        showMoveUp: false,
        showMoveDown: false,
      );

      expect(find.byType(Wrap), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('injects extra actions before and after the standard set', (
      tester,
    ) async {
      await pumpToolbar(
        tester,
        _listWith(['A', 'B']),
        beforeActions: const [Text('LEFT')],
        afterActions: const [Text('RIGHT')],
      );

      final left = tester.getCenter(find.text('LEFT')).dx;
      final add = tester.getCenter(addButton()).dx;
      final right = tester.getCenter(find.text('RIGHT')).dx;
      expect(left, lessThan(add));
      expect(add, lessThan(right));
    });

    testWidgets('honours explicit labels and icons', (tester) async {
      await pumpToolbar(
        tester,
        _listWith(['A']),
        addLabel: 'New row',
        removeLabel: 'Delete',
        addIcon: Icons.playlist_add,
      );

      expect(find.widgetWithText(FilledButton, 'New row'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_add), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('a tooltip wraps the button; no tooltip leaves it bare', (
      tester,
    ) async {
      await pumpToolbar(
        tester,
        _listWith(['A']),
        showRemove: false,
        showMoveUp: false,
        showMoveDown: false,
      );
      expect(
        find.ancestor(of: addButton(), matching: find.byType(Tooltip)),
        findsNothing,
      );

      await pumpToolbar(
        tester,
        _listWith(['A']),
        showRemove: false,
        showMoveUp: false,
        showMoveDown: false,
        addTooltip: 'Append a row',
      );
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(of: addButton(), matching: find.byType(Tooltip)),
            )
            .message,
        'Append a row',
      );
    });

    testWidgets('dense shrinks the leading icon', (tester) async {
      await pumpToolbar(tester, _listWith(['A']));
      final denseIcon = tester.widget<Icon>(
        find.descendant(of: addButton(), matching: find.byType(Icon)),
      );
      expect(denseIcon.size, 16.0);

      await pumpToolbar(tester, _listWith(['A']), dense: false);
      final looseIcon = tester.widget<Icon>(
        find.descendant(of: addButton(), matching: find.byType(Icon)),
      );
      expect(
        looseIcon.size,
        isNull,
        reason: 'the non-dense button inherits the ambient icon size',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TomListFormToolbar enablement', () {
    testWidgets('Add is always live — it needs no selection', (tester) async {
      await pumpToolbar(tester, _listWith([]), selectedIndex: null);
      expect(enabled(tester, addButton()), isTrue);
    });

    testWidgets('with no selection, Remove and both arrows are dead', (
      tester,
    ) async {
      await pumpToolbar(
        tester,
        _listWith(['A', 'B', 'C']),
        selectedIndex: null,
      );

      expect(enabled(tester, removeButton()), isFalse);
      expect(enabled(tester, upButton()), isFalse);
      expect(enabled(tester, downButton()), isFalse);
    });

    testWidgets('selecting the first row enables Remove and Move down only', (
      tester,
    ) async {
      await pumpToolbar(tester, _listWith(['A', 'B', 'C']), selectedIndex: 0);

      expect(enabled(tester, removeButton()), isTrue);
      expect(enabled(tester, upButton()), isFalse);
      expect(enabled(tester, downButton()), isTrue);
    });

    testWidgets('selecting the last row enables Remove and Move up only', (
      tester,
    ) async {
      await pumpToolbar(tester, _listWith(['A', 'B', 'C']), selectedIndex: 2);

      expect(enabled(tester, removeButton()), isTrue);
      expect(enabled(tester, upButton()), isTrue);
      expect(enabled(tester, downButton()), isFalse);
    });

    testWidgets('a middle row enables everything', (tester) async {
      await pumpToolbar(tester, _listWith(['A', 'B', 'C']), selectedIndex: 1);

      expect(enabled(tester, removeButton()), isTrue);
      expect(enabled(tester, upButton()), isTrue);
      expect(enabled(tester, downButton()), isTrue);
    });

    testWidgets('the only row of a one-row list cannot move either way', (
      tester,
    ) async {
      await pumpToolbar(tester, _listWith(['Only']), selectedIndex: 0);

      expect(enabled(tester, removeButton()), isTrue);
      expect(enabled(tester, upButton()), isFalse);
      expect(enabled(tester, downButton()), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('TomListFormToolbar actions', () {
    testWidgets('Add appends a row and selects it', (tester) async {
      final list = _listWith(['A']);
      final selections = <int?>[];
      await pumpToolbar(
        tester,
        list,
        onSelectionChanged: (i) async => selections.add(i),
      );

      await tester.tap(addButton());
      await tester.pump();

      expect(list.length, 2);
      expect(selections, [1], reason: 'selection follows the appended row');
    });

    testWidgets('Add works on an empty list and selects row 0', (tester) async {
      final list = _listWith([]);
      final selections = <int?>[];
      await pumpToolbar(
        tester,
        list,
        onSelectionChanged: (i) async => selections.add(i),
      );

      await tester.tap(addButton());
      await tester.pump();

      expect(list.length, 1);
      expect(selections, [0]);
    });

    testWidgets('Remove drops the selected row and clears selection', (
      tester,
    ) async {
      final list = _listWith(['A', 'B', 'C']);
      final selections = <int?>[];
      await pumpToolbar(
        tester,
        list,
        selectedIndex: 1,
        onSelectionChanged: (i) async => selections.add(i),
      );

      await tester.tap(removeButton());
      await tester.pump();

      expect(_formProducts(list), ['A', 'C']);
      expect(selections, [
        null,
      ], reason: 'the removed index no longer identifies a row');
    });

    testWidgets('Move up shifts the row and selection follows it', (
      tester,
    ) async {
      final list = _listWith(['A', 'B', 'C']);
      final selections = <int?>[];
      await pumpToolbar(
        tester,
        list,
        selectedIndex: 2,
        onSelectionChanged: (i) async => selections.add(i),
      );

      await tester.tap(upButton());
      await tester.pump();

      expect(_formProducts(list), ['A', 'C', 'B']);
      expect(selections, [1]);
    });

    testWidgets('Move down shifts the row and selection follows it', (
      tester,
    ) async {
      final list = _listWith(['A', 'B', 'C']);
      final selections = <int?>[];
      await pumpToolbar(
        tester,
        list,
        selectedIndex: 0,
        onSelectionChanged: (i) async => selections.add(i),
      );

      await tester.tap(downButton());
      await tester.pump();

      expect(_formProducts(list), ['B', 'A', 'C']);
      expect(selections, [1]);
    });

    testWidgets('actions still apply when no selection callback is supplied', (
      tester,
    ) async {
      // `onSelectionChanged` is optional — a host that derives selection from
      // its own observation of the list must not lose the mutation itself.
      final list = _listWith(['A', 'B']);
      await pumpToolbar(tester, list, selectedIndex: 0);

      await tester.tap(downButton());
      await tester.pump();
      expect(_formProducts(list), ['B', 'A']);

      await tester.tap(addButton());
      await tester.pump();
      expect(list.length, 3);
    });
  });

  // -------------------------------------------------------------------------
  group('TomListFormToolbar vetoes', () {
    testWidgets('beforeAdd returning false cancels the add', (tester) async {
      final list = _listWith(['A']);
      final selections = <int?>[];
      await pumpToolbar(
        tester,
        list,
        beforeAdd: () async => false,
        onSelectionChanged: (i) async => selections.add(i),
      );

      await tester.tap(addButton());
      await tester.pump();

      expect(list.length, 1);
      expect(
        selections,
        isEmpty,
        reason: 'a cancelled add must not move the selection either',
      );
    });

    testWidgets('beforeAdd returning true lets the add through', (
      tester,
    ) async {
      final list = _listWith(['A']);
      var asked = 0;
      await pumpToolbar(
        tester,
        list,
        beforeAdd: () async {
          asked++;
          return true;
        },
      );

      await tester.tap(addButton());
      await tester.pump();

      expect(asked, 1);
      expect(list.length, 2);
    });

    testWidgets('beforeRemove sees the index that would go', (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      final asked = <int>[];
      await pumpToolbar(
        tester,
        list,
        selectedIndex: 1,
        beforeRemove: (i) async {
          asked.add(i);
          return false;
        },
      );

      await tester.tap(removeButton());
      await tester.pump();

      expect(asked, [1]);
      expect(_formProducts(list), ['A', 'B', 'C']);
    });

    testWidgets('beforeMove sees post-move destination semantics', (
      tester,
    ) async {
      // `to` is where the row ends up, not ReorderableListView's pre-removal
      // index — the same convention TomListForm.move uses.
      final list = _listWith(['A', 'B', 'C']);
      final asked = <List<int>>[];
      await pumpToolbar(
        tester,
        list,
        selectedIndex: 2,
        beforeMove: (from, to) async {
          asked.add([from, to]);
          return false;
        },
      );

      await tester.tap(upButton());
      await tester.pump();

      expect(asked, [
        [2, 1],
      ]);
      expect(_formProducts(list), ['A', 'B', 'C']);
    });

    testWidgets('beforeMove returning true lets the move through', (
      tester,
    ) async {
      final list = _listWith(['A', 'B', 'C']);
      await pumpToolbar(
        tester,
        list,
        selectedIndex: 0,
        beforeMove: (_, _) async => true,
      );

      await tester.tap(downButton());
      await tester.pump();

      expect(_formProducts(list), ['B', 'A', 'C']);
    });
  });
}
