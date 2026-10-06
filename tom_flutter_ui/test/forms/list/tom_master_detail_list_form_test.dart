/// Behavioural coverage for `TomMasterDetailListForm`.
///
/// The scaffold's substance is the *selection*, not the layout: what the
/// detail pane shows, when it refuses to change, and what happens to the
/// selection when the list moves underneath it. Three behaviours carry real
/// risk and are pinned here first:
///
///   * **The unsaved-changes guard on selection change.** Clicking another
///     row while the current one is dirty must not silently drop the edits.
///     The guard's three outcomes (Cancel / Discard / Save) each leave a
///     different combination of selection and row value, and a failed save
///     must behave like Cancel — the user is not sent away from a row they
///     could not save.
///
///   * **Selection versus a shrinking list.** A row removed from outside the
///     widget can leave the selection pointing past the end. The detail
///     builder is then handed an out-of-range index, which is a crash, so the
///     widget clears the selection instead.
///
///   * **The draggable splitter's clamp.** Its bounds are a `min` and an
///     implicit `max` of half the viewport, both applied on every build, not
///     only on drag.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../support/list_form_fixtures.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

const double _viewport = 600;

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: _viewport, height: 400, child: child),
    ),
  ),
);

OrderItemListForm _listWith(List<String> products) {
  final order = orderWith(products);
  return OrderItemListForm()..bind(order.items);
}

/// Key on the widget that fills the master pane, so its measured width is the
/// pane width the scaffold actually granted.
const _masterKey = ValueKey('master-pane');

/// A master pane that reports the current selection and offers one button per
/// row plus a "clear" button — enough surface to drive every selection path.
Widget _master(
  BuildContext context,
  TomListForm<OrderItem, OrderItemForm> list,
  int? selected,
  Future<void> Function(int?) selectIndex,
) => Container(
  key: _masterKey,
  alignment: Alignment.topLeft,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('sel:${selected ?? '-'}'),
      for (var i = 0; i < list.length; i++)
        TextButton(onPressed: () => selectIndex(i), child: Text('pick-$i')),
      TextButton(
        onPressed: () => selectIndex(null),
        child: const Text('clear'),
      ),
    ],
  ),
);

/// The detail pane, rebuilt from the row form's own change notifier.
///
/// Why the `ListenableBuilder` rather than a bare `Text`: the scaffold does
/// **not** repaint on a field edit — it observes the *list* (structure) and the
/// selection, and leaves value-level repainting to the widgets the host puts in
/// the pane. A real detail pane is built from Tom field widgets, each of which
/// observes its own field. Listening to `form.changes` here is the smallest
/// stand-in for that, and it is what makes "the pane shows the edited value"
/// deterministic instead of dependent on some unrelated rebuild.
Widget _detail(BuildContext _, int index, OrderItemForm form) =>
    ListenableBuilder(
      listenable: form.changes,
      builder: (_, _) => Text('detail-$index:${form.product.get()}'),
    );

/// Marks a row dirty and drains the validation debounce `setValue` arms.
Future<void> _edit(
  WidgetTester tester,
  OrderItemForm form,
  String value,
) async {
  form.product.setValue(value);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(initializeReflection);

  Widget scaffold(
    OrderItemListForm list, {
    int? initialSelectedIndex,
    bool guard = true,
    WidgetBuilder? emptyDetailBuilder,
    double? masterPaneWidth,
    double? gap,
    EdgeInsetsGeometry? padding,
    bool draggableSplitter = false,
    double? minMasterPaneWidth,
    double? maxMasterPaneWidth,
    Widget Function(BuildContext, int, OrderItemForm)? detailBuilder,
  }) => TomMasterDetailListForm<OrderItem, OrderItemForm>(
    listForm: list,
    masterBuilder: _master,
    detailBuilder: detailBuilder ?? _detail,
    emptyDetailBuilder: emptyDetailBuilder,
    initialSelectedIndex: initialSelectedIndex,
    guardUnsavedSelectionChange: guard,
    masterPaneWidth: masterPaneWidth,
    gap: gap,
    padding: padding,
    draggableSplitter: draggableSplitter,
    minMasterPaneWidth: minMasterPaneWidth,
    maxMasterPaneWidth: maxMasterPaneWidth,
  );

  Future<void> pick(WidgetTester tester, int index) async {
    await tester.tap(find.text('pick-$index'));
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------------
  group('TomMasterDetailListForm selection', () {
    testWidgets('starts with nothing selected and the empty detail', (
      tester,
    ) async {
      await tester.pumpWidget(_app(scaffold(_listWith(['A', 'B']))));

      expect(find.text('sel:-'), findsOneWidget);
      expect(
        find.text('Select an item from the list to edit it.'),
        findsOneWidget,
      );
      expect(find.textContaining('detail-'), findsNothing);
    });

    testWidgets('picking a row shows its detail', (tester) async {
      await tester.pumpWidget(_app(scaffold(_listWith(['A', 'B']))));

      await pick(tester, 1);

      expect(find.text('detail-1:B'), findsOneWidget);
      expect(find.text('sel:1'), findsOneWidget);
      expect(
        find.text('Select an item from the list to edit it.'),
        findsNothing,
      );
    });

    testWidgets("the detail builder receives the list's own sub-form", (
      tester,
    ) async {
      // The whole point of the no-sibling-form architecture: the detail edits
      // the very form the list owns, so its dirty state rolls up without any
      // reconciliation step.
      final list = _listWith(['A', 'B']);
      OrderItemForm? given;
      await tester.pumpWidget(
        _app(
          scaffold(
            list,
            detailBuilder: (ctx, i, f) {
              given = f;
              return Text('detail-$i');
            },
          ),
        ),
      );

      await pick(tester, 1);

      expect(identical(given, list[1]), isTrue);
    });

    testWidgets('selecting null returns to the empty detail', (tester) async {
      await tester.pumpWidget(_app(scaffold(_listWith(['A']))));
      await pick(tester, 0);
      expect(find.text('detail-0:A'), findsOneWidget);

      await tester.tap(find.text('clear'));
      await tester.pumpAndSettle();

      expect(find.text('sel:-'), findsOneWidget);
      expect(find.textContaining('detail-'), findsNothing);
    });

    testWidgets('initialSelectedIndex opens that row on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(scaffold(_listWith(['A', 'B']), initialSelectedIndex: 1)),
      );
      await tester.pumpAndSettle();

      expect(find.text('detail-1:B'), findsOneWidget);
    });

    testWidgets('a custom empty detail replaces the built-in hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          scaffold(
            _listWith(['A']),
            emptyDetailBuilder: (_) => const Text('Pick something'),
          ),
        ),
      );

      expect(find.text('Pick something'), findsOneWidget);
      expect(
        find.text('Select an item from the list to edit it.'),
        findsNothing,
      );
    });

    testWidgets('an empty list shows the empty detail', (tester) async {
      await tester.pumpWidget(_app(scaffold(_listWith([]))));

      expect(
        find.text('Select an item from the list to edit it.'),
        findsOneWidget,
      );
    });

    testWidgets('re-picking the selected row is a no-op', (tester) async {
      // Important because the guard would otherwise prompt for a switch that
      // isn't happening.
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 0);
      await _edit(tester, list[0], 'X');

      await pick(tester, 0);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('sel:0'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('TomMasterDetailListForm unsaved-changes guard', () {
    testWidgets('a clean row switches without a prompt', (tester) async {
      await tester.pumpWidget(_app(scaffold(_listWith(['A', 'B']))));
      await pick(tester, 0);

      await pick(tester, 1);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('detail-1:B'), findsOneWidget);
    });

    testWidgets('a dirty row prompts before switching away', (tester) async {
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 0);
      await _edit(tester, list[0], 'X');

      await tester.tap(find.text('pick-1'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
      // The detail pane shows the *edited* value — the point of the assertion
      // is the row index, not the value: row 0 is still the selected one.
      expect(
        find.text('detail-0:X'),
        findsOneWidget,
        reason: 'still on row 0 until the user answers',
      );
    });

    testWidgets('Cancel keeps both the selection and the edit', (tester) async {
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 0);
      await _edit(tester, list[0], 'X');

      await tester.tap(find.text('pick-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('sel:0'), findsOneWidget);
      expect(list[0].product.get(), 'X', reason: 'the edit is not thrown away');
    });

    testWidgets('Discard rolls the row back and moves on', (tester) async {
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 0);
      await _edit(tester, list[0], 'X');

      await tester.tap(find.text('pick-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(list[0].product.get(), 'A');
      expect(find.text('detail-1:B'), findsOneWidget);
    });

    testWidgets('Save commits the row and moves on', (tester) async {
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 0);
      await _edit(tester, list[0], 'X');

      await tester.tap(find.text('pick-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(list[0].product.get(), 'X');
      expect(list[0].isDirty, isFalse, reason: 'the save re-baselined the row');
      expect(find.text('detail-1:B'), findsOneWidget);
    });

    testWidgets('a Save that fails validation keeps the user on the row', (
      tester,
    ) async {
      // Sending the user away from a row they could not save would strand the
      // error where they can no longer see it.
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 0);
      await _edit(tester, list[0], ''); // `product` is required

      await tester.tap(find.text('pick-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('sel:0'), findsOneWidget);
      expect(find.text('detail-0:'), findsOneWidget);
      expect(list[0].isDirty, isTrue, reason: 'the edit is still unsaved');
    });

    testWidgets('the prompt cannot be dismissed by tapping the barrier', (
      tester,
    ) async {
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 0);
      await _edit(tester, list[0], 'X');

      await tester.tap(find.text('pick-1'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
    });

    testWidgets('guardUnsavedSelectionChange: false switches silently', (
      tester,
    ) async {
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(scaffold(list, guard: false)));
      await pick(tester, 0);
      await _edit(tester, list[0], 'X');

      await pick(tester, 1);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('detail-1:B'), findsOneWidget);
      expect(
        list[0].product.get(),
        'X',
        reason: 'the edit is merely left as-is',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TomMasterDetailListForm list changes', () {
    testWidgets('an added row appears in the master pane', (tester) async {
      final list = _listWith(['A']);
      await tester.pumpWidget(_app(scaffold(list)));

      list.add();
      await tester.pump();

      expect(find.text('pick-1'), findsOneWidget);
    });

    testWidgets('removing the selected row clears the selection', (
      tester,
    ) async {
      // Otherwise the detail builder is handed an index past the end.
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 1);
      expect(find.text('detail-1:B'), findsOneWidget);

      list.removeAt(1);
      await tester.pump();

      expect(find.text('sel:-'), findsOneWidget);
      expect(
        find.text('Select an item from the list to edit it.'),
        findsOneWidget,
      );
    });

    testWidgets('a removal above the selection leaves the index in range', (
      tester,
    ) async {
      // The selection is positional, so after the removal row 1 shows what
      // was row 2 before it.
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 1);

      list.removeAt(0);
      await tester.pump();

      expect(find.text('detail-1:C'), findsOneWidget);
    });

    testWidgets('the detail pane is handed the live row form, so an observing '
        'host sees edits', (tester) async {
      final list = _listWith(['A']);
      await tester.pumpWidget(_app(scaffold(list)));
      await pick(tester, 0);

      await _edit(tester, list[0], 'Z');

      expect(find.text('detail-0:Z'), findsOneWidget);
    });

    testWidgets('swapping in another list clears the stale selection', (
      tester,
    ) async {
      final first = _listWith(['A', 'B']);
      final second = _listWith(['X']);
      await tester.pumpWidget(_app(scaffold(first)));
      await pick(tester, 1);

      await tester.pumpWidget(_app(scaffold(second)));
      await tester.pumpAndSettle();

      expect(find.text('sel:-'), findsOneWidget);
      expect(find.text('pick-0'), findsOneWidget);
      expect(find.text('pick-1'), findsNothing);
    });

    testWidgets('the observer is released on dispose', (tester) async {
      final list = _listWith(['A']);
      await tester.pumpWidget(_app(scaffold(list)));

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      list.add();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('TomMasterDetailListForm layout', () {
    double masterWidth(WidgetTester tester) =>
        tester.getSize(find.byKey(_masterKey)).width;

    testWidgets('the master pane defaults to 280 logical pixels', (
      tester,
    ) async {
      await tester.pumpWidget(_app(scaffold(_listWith(['A']))));

      expect(masterWidth(tester), 280.0);
    });

    testWidgets('honours an explicit master pane width', (tester) async {
      await tester.pumpWidget(
        _app(scaffold(_listWith(['A']), masterPaneWidth: 150)),
      );

      expect(masterWidth(tester), 150.0);
    });

    testWidgets('the gap separates the two panes', (tester) async {
      await tester.pumpWidget(
        _app(scaffold(_listWith(['A']), masterPaneWidth: 200, gap: 40)),
      );

      final masterRight = tester.getBottomRight(find.byKey(_masterKey)).dx;
      final detailLeft = tester
          .getTopLeft(find.text('Select an item from the list to edit it.'))
          .dx;
      expect(detailLeft - masterRight, greaterThanOrEqualTo(40.0));
    });

    testWidgets('applies the configured padding', (tester) async {
      await tester.pumpWidget(
        _app(scaffold(_listWith(['A']), padding: const EdgeInsets.all(20))),
      );

      expect(
        tester.getTopLeft(find.byKey(_masterKey)).dx,
        tester.getTopLeft(find.byType(Scaffold)).dx +
            (800 - _viewport) / 2 +
            20,
      );
    });

    testWidgets('a fixed scaffold has no resize handle', (tester) async {
      await tester.pumpWidget(_app(scaffold(_listWith(['A']))));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
        ),
        findsNothing,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TomMasterDetailListForm draggable splitter', () {
    double masterWidth(WidgetTester tester) =>
        tester.getSize(find.byKey(_masterKey)).width;

    Finder handle() => find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
    );

    testWidgets('renders a resize handle', (tester) async {
      await tester.pumpWidget(
        _app(scaffold(_listWith(['A']), draggableSplitter: true)),
      );

      expect(handle(), findsOneWidget);
    });

    testWidgets('dragging right widens the master pane', (tester) async {
      await tester.pumpWidget(
        _app(
          scaffold(
            _listWith(['A']),
            draggableSplitter: true,
            masterPaneWidth: 200,
          ),
        ),
      );
      expect(masterWidth(tester), 200.0);

      await tester.drag(handle(), const Offset(50, 0));
      await tester.pump();

      expect(masterWidth(tester), 250.0);
    });

    testWidgets('dragging left narrows the master pane', (tester) async {
      await tester.pumpWidget(
        _app(
          scaffold(
            _listWith(['A']),
            draggableSplitter: true,
            masterPaneWidth: 250,
          ),
        ),
      );

      await tester.drag(handle(), const Offset(-60, 0));
      await tester.pump();

      expect(masterWidth(tester), 190.0);
    });

    testWidgets('the pane never narrows past the minimum', (tester) async {
      await tester.pumpWidget(
        _app(
          scaffold(
            _listWith(['A']),
            draggableSplitter: true,
            masterPaneWidth: 200,
            minMasterPaneWidth: 120,
          ),
        ),
      );

      await tester.drag(handle(), const Offset(-400, 0));
      await tester.pump();

      expect(masterWidth(tester), 120.0);
    });

    testWidgets(
      'without an explicit maximum the pane stops at half the width',
      (tester) async {
        await tester.pumpWidget(
          _app(
            scaffold(
              _listWith(['A']),
              draggableSplitter: true,
              masterPaneWidth: 200,
            ),
          ),
        );

        await tester.drag(handle(), const Offset(400, 0));
        await tester.pump();

        expect(masterWidth(tester), _viewport / 2);
      },
    );

    testWidgets('an explicit maximum wins over the half-width default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          scaffold(
            _listWith(['A']),
            draggableSplitter: true,
            masterPaneWidth: 200,
            maxMasterPaneWidth: 240,
          ),
        ),
      );

      await tester.drag(handle(), const Offset(400, 0));
      await tester.pump();

      expect(masterWidth(tester), 240.0);
    });

    testWidgets('a maximum below the minimum collapses to the minimum', (
      tester,
    ) async {
      // A contradictory configuration must still produce a usable pane rather
      // than a negative-width one.
      await tester.pumpWidget(
        _app(
          scaffold(
            _listWith(['A']),
            draggableSplitter: true,
            masterPaneWidth: 200,
            minMasterPaneWidth: 150,
            maxMasterPaneWidth: 100,
          ),
        ),
      );
      await tester.pump();

      expect(masterWidth(tester), 150.0);
    });

    testWidgets('the starting width is clamped before any drag', (
      tester,
    ) async {
      // The clamp runs on every build, so an over-wide starting value is
      // corrected immediately instead of on first interaction.
      await tester.pumpWidget(
        _app(
          scaffold(
            _listWith(['A']),
            draggableSplitter: true,
            masterPaneWidth: 590,
          ),
        ),
      );

      expect(masterWidth(tester), _viewport / 2);
    });
  });
}
