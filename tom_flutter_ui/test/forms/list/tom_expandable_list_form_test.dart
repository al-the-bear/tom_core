/// Behavioural coverage for `TomExpandableListForm` and its controller.
///
/// Two things here are genuinely hard to infer from reading the source and are
/// therefore the spine of this suite:
///
///   * **The single-open veto ordering.** Opening row N under
///     `singleOpen` implicitly *collapses* whichever row M was open. The
///     widget runs `onBeforeChange(M, …, false)` before
///     `onBeforeChange(N, …, true)` precisely so a dirty M can refuse to be
///     closed behind the user's back. Get that order wrong and the classic
///     "validate before switching away" pattern silently loses edits.
///
///   * **Expansion survives a drag.** A reorder renumbers every row, so the
///     controller's expanded-index set has to be remapped or the wrong row is
///     left open afterwards. The remap is index arithmetic with two
///     directions and three cases each; it is pinned here through the widget
///     rather than by unit-testing a private helper.
///
/// Ownership is also asserted: the widget disposes a controller it created and
/// must *not* dispose one the host passed in — a host that reuses its
/// controller across two screens would otherwise get a use-after-dispose.
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
    body: Center(child: SizedBox(width: 400, child: child)),
  ),
);

OrderItemListForm _listWith(List<String> products) {
  final order = orderWith(products);
  return OrderItemListForm()..bind(order.items);
}

List<String> _formProducts(OrderItemListForm list) =>
    list.forms.map((f) => f.product.get()).toList();

Widget _summary(BuildContext _, int index, OrderItemForm form) =>
    Text('sum-$index:${form.product.get()}');

Widget _body(BuildContext _, int index, OrderItemForm form) =>
    Text('body-$index');

void main() {
  setUpAll(initializeReflection);

  // -------------------------------------------------------------------------
  // Controller
  // -------------------------------------------------------------------------

  group('TomExpandableListFormController', () {
    test('starts empty by default', () {
      final c = TomExpandableListFormController();
      expect(c.expanded, isEmpty);
      expect(c.isExpanded(0), isFalse);
      c.dispose();
    });

    test('seeds from initialExpanded', () {
      final c = TomExpandableListFormController(initialExpanded: {1, 3});
      expect(c.expanded, {1, 3});
      expect(c.isExpanded(1), isTrue);
      expect(c.isExpanded(2), isFalse);
      c.dispose();
    });

    test('copies the seed rather than aliasing it', () {
      // A host that keeps its seed set around must not be able to mutate the
      // controller's state behind its back.
      final seed = {1};
      final c = TomExpandableListFormController(initialExpanded: seed);
      seed.add(2);
      expect(c.expanded, {1});
      c.dispose();
    });

    test('exposes an unmodifiable view', () {
      final c = TomExpandableListFormController(initialExpanded: {0});
      expect(() => c.expanded.add(1), throwsUnsupportedError);
      c.dispose();
    });

    test('singleOpen expansion replaces whatever was open', () {
      final c = TomExpandableListFormController(initialExpanded: {0});
      c.expand(2);
      expect(c.expanded, {2});
      c.dispose();
    });

    test('multipleOpen expansion accumulates', () {
      final c = TomExpandableListFormController(initialExpanded: {0});
      c.expand(2, policy: TomExpansionPolicy.multipleOpen);
      expect(c.expanded, {0, 2});
      c.dispose();
    });

    test('collapse removes just that row', () {
      final c = TomExpandableListFormController(initialExpanded: {0, 1});
      c.collapse(0);
      expect(c.expanded, {1});
      c.dispose();
    });

    test('collapseAll clears every row', () {
      final c = TomExpandableListFormController(initialExpanded: {0, 1, 2});
      c.collapseAll();
      expect(c.expanded, isEmpty);
      c.dispose();
    });

    test('notifies on a real change only', () {
      // A no-op collapse that still notified would rebuild every row of the
      // list for nothing, on every stray call.
      final c = TomExpandableListFormController(initialExpanded: {0});
      var notifications = 0;
      c.addListener(() => notifications++);

      c.collapse(5);
      expect(notifications, 0, reason: 'row 5 was never open');

      c.collapseAll();
      expect(notifications, 1);

      c.collapseAll();
      expect(notifications, 1, reason: 'nothing left to collapse');

      c.expand(1);
      expect(notifications, 2);
      c.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Widget
  // -------------------------------------------------------------------------

  group('TomExpandableListForm', () {
    Widget expandable(
      OrderItemListForm list, {
      TomExpansionPolicy? policy,
      TomExpandableListFormController? controller,
      Set<int>? initialExpanded,
      Future<bool> Function(int, OrderItemForm, bool)? onBeforeChange,
      void Function(Set<int>)? onExpansionChanged,
      Widget Function(BuildContext, TomListForm<OrderItem, OrderItemForm>)?
      headerBuilder,
      Widget Function(BuildContext, TomListForm<OrderItem, OrderItemForm>)?
      footerBuilder,
      Widget Function(BuildContext, TomListForm<OrderItem, OrderItemForm>)?
      toolbarBuilder,
      Widget Function(BuildContext)? emptyBuilder,
      Widget Function(BuildContext, int)? rowSeparatorBuilder,
      bool reorderable = false,
      void Function(int, int)? onReorder,
    }) => TomExpandableListForm<OrderItem, OrderItemForm>(
      listForm: list,
      summaryBuilder: _summary,
      bodyBuilder: _body,
      policy: policy,
      controller: controller,
      initialExpanded: initialExpanded,
      onBeforeChange: onBeforeChange,
      onExpansionChanged: onExpansionChanged,
      headerBuilder: headerBuilder,
      footerBuilder: footerBuilder,
      toolbarBuilder: toolbarBuilder,
      emptyBuilder: emptyBuilder,
      rowSeparatorBuilder: rowSeparatorBuilder,
      reorderable: reorderable,
      onReorder: onReorder,
    );

    testWidgets('every row shows its summary and no body when collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(_app(expandable(_listWith(['A', 'B']))));

      expect(find.text('sum-0:A'), findsOneWidget);
      expect(find.text('sum-1:B'), findsOneWidget);
      expect(find.textContaining('body-'), findsNothing);
    });

    testWidgets('tapping a summary opens that row', (tester) async {
      await tester.pumpWidget(_app(expandable(_listWith(['A', 'B']))));

      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();

      expect(find.text('body-0'), findsOneWidget);
      expect(find.text('body-1'), findsNothing);
    });

    testWidgets('tapping an open summary closes it again', (tester) async {
      await tester.pumpWidget(_app(expandable(_listWith(['A']))));

      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();
      expect(find.text('body-0'), findsOneWidget);

      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();
      expect(find.text('body-0'), findsNothing);
    });

    testWidgets('the body renders below its summary', (tester) async {
      await tester.pumpWidget(_app(expandable(_listWith(['A', 'B']))));
      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('body-0')).dy,
        greaterThan(tester.getTopLeft(find.text('sum-0:A')).dy),
      );
      expect(
        tester.getTopLeft(find.text('sum-1:B')).dy,
        greaterThan(tester.getTopLeft(find.text('body-0')).dy),
      );
    });

    testWidgets('initialExpanded opens a row on the very first build', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(expandable(_listWith(['A', 'B']), initialExpanded: {1})),
      );

      expect(find.text('body-1'), findsOneWidget);
      expect(find.text('body-0'), findsNothing);
    });

    testWidgets('singleOpen is the default and closes the previous row', (
      tester,
    ) async {
      await tester.pumpWidget(_app(expandable(_listWith(['A', 'B']))));

      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sum-1:B'));
      await tester.pumpAndSettle();

      expect(find.text('body-1'), findsOneWidget);
      expect(find.text('body-0'), findsNothing);
    });

    testWidgets('multipleOpen keeps both rows open', (tester) async {
      await tester.pumpWidget(
        _app(
          expandable(
            _listWith(['A', 'B']),
            policy: TomExpansionPolicy.multipleOpen,
          ),
        ),
      );

      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sum-1:B'));
      await tester.pumpAndSettle();

      expect(find.text('body-0'), findsOneWidget);
      expect(find.text('body-1'), findsOneWidget);
    });

    testWidgets('the row builders receive the list\'s own sub-form', (
      tester,
    ) async {
      final list = _listWith(['A']);
      final seen = <OrderItemForm>[];
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: list,
            initialExpanded: const {0},
            summaryBuilder: (ctx, i, f) {
              seen.add(f);
              return Text('sum-$i');
            },
            bodyBuilder: (ctx, i, f) {
              seen.add(f);
              return Text('body-$i');
            },
          ),
        ),
      );

      expect(seen, isNotEmpty);
      expect(seen.every((f) => identical(f, list[0])), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('TomExpandableListForm external control', () {
    testWidgets('an external controller drives expansion', (tester) async {
      final controller = TomExpandableListFormController();
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A', 'B']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            controller: controller,
          ),
        ),
      );

      controller.expand(1);
      await tester.pump();

      expect(find.text('body-1'), findsOneWidget);
    });

    testWidgets('collapseAll closes the open row', (tester) async {
      // The canonical post-save gesture: return the user to the read-only
      // summary view without them tapping anything.
      final controller = TomExpandableListFormController(initialExpanded: {0});
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            controller: controller,
          ),
        ),
      );
      expect(find.text('body-0'), findsOneWidget);

      controller.collapseAll();
      await tester.pump();

      expect(find.text('body-0'), findsNothing);
    });

    testWidgets('programmatic expansion bypasses the veto by design', (
      tester,
    ) async {
      // `controller.expand` is documented as the code-driven path — it must
      // not be blocked by a veto meant for user taps, or "open the row I just
      // added" would fail exactly when the row is empty and invalid.
      final controller = TomExpandableListFormController();
      var vetoCalls = 0;
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            controller: controller,
            onBeforeChange: (_, _, _) async {
              vetoCalls++;
              return false;
            },
          ),
        ),
      );

      controller.expand(0);
      await tester.pump();

      expect(find.text('body-0'), findsOneWidget);
      expect(vetoCalls, 0);
    });

    testWidgets('onExpansionChanged reports the post-change set', (
      tester,
    ) async {
      final seen = <Set<int>>[];
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A', 'B']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            onExpansionChanged: seen.add,
          ),
        ),
      );

      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sum-1:B'));
      await tester.pumpAndSettle();

      expect(seen, [
        {0},
        {1},
      ]);
    });

    testWidgets('a host-supplied controller outlives the widget', (
      tester,
    ) async {
      // The widget only owns the controller it created itself. Disposing a
      // borrowed one would break any host that reuses it across screens.
      final controller = TomExpandableListFormController();
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            controller: controller,
          ),
        ),
      );

      await tester.pumpWidget(_app(const SizedBox.shrink()));

      expect(() => controller.expand(0), returnsNormally);
      controller.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('TomExpandableListForm veto', () {
    testWidgets('refusing an open leaves the row shut', (tester) async {
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            onBeforeChange: (_, _, _) async => false,
          ),
        ),
      );

      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();

      expect(find.text('body-0'), findsNothing);
    });

    testWidgets('refusing a close leaves the row open', (tester) async {
      var allowOpen = true;
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            onBeforeChange: (_, _, willOpen) async =>
                willOpen ? allowOpen : false,
          ),
        ),
      );

      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();
      expect(find.text('body-0'), findsOneWidget);

      allowOpen = false;
      await tester.tap(find.text('sum-0:A'));
      await tester.pumpAndSettle();
      expect(
        find.text('body-0'),
        findsOneWidget,
        reason: 'the close was refused',
      );
    });

    testWidgets('the veto sees the row and the state it would move to', (
      tester,
    ) async {
      final calls = <List<Object>>[];
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: list,
            summaryBuilder: _summary,
            bodyBuilder: _body,
            onBeforeChange: (i, form, willOpen) async {
              calls.add([i, identical(form, list[i]), willOpen]);
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.text('sum-1:B'));
      await tester.pumpAndSettle();

      expect(calls, [
        [1, true, true],
      ]);
    });

    testWidgets(
      'singleOpen asks the currently-open row before opening another',
      (tester) async {
        // This is the whole point of the pre-collapse veto pass: row 0 is dirty,
        // the user clicks row 1, and row 0 gets to refuse being closed.
        final calls = <List<Object>>[];
        await tester.pumpWidget(
          _app(
            TomExpandableListForm<OrderItem, OrderItemForm>(
              listForm: _listWith(['A', 'B']),
              summaryBuilder: _summary,
              bodyBuilder: _body,
              initialExpanded: const {0},
              onBeforeChange: (i, _, willOpen) async {
                calls.add([i, willOpen]);
                return true;
              },
            ),
          ),
        );

        await tester.tap(find.text('sum-1:B'));
        await tester.pumpAndSettle();

        expect(
          calls,
          [
            [0, false],
            [1, true],
          ],
          reason: 'the implicit collapse is offered before the explicit open',
        );
      },
    );

    testWidgets('a refusal from the open row blocks the new one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A', 'B']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            initialExpanded: const {0},
            // Row 0 refuses to close; row 1 would happily open.
            onBeforeChange: (i, _, willOpen) async => !(i == 0 && !willOpen),
          ),
        ),
      );

      await tester.tap(find.text('sum-1:B'));
      await tester.pumpAndSettle();

      expect(find.text('body-0'), findsOneWidget);
      expect(find.text('body-1'), findsNothing);
    });

    testWidgets('multipleOpen skips the implicit-collapse pass entirely', (
      tester,
    ) async {
      final calls = <List<Object>>[];
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A', 'B']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            policy: TomExpansionPolicy.multipleOpen,
            initialExpanded: const {0},
            onBeforeChange: (i, _, willOpen) async {
              calls.add([i, willOpen]);
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.text('sum-1:B'));
      await tester.pumpAndSettle();

      expect(calls, [
        [1, true],
      ], reason: 'nothing is being closed, so nothing else is consulted');
    });
  });

  // -------------------------------------------------------------------------
  group('TomExpandableListForm composition', () {
    testWidgets('renders header, rows, footer and toolbar in that order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            headerBuilder: (_, _) => const Text('HEADER'),
            footerBuilder: (_, _) => const Text('FOOTER'),
            toolbarBuilder: (_, _) => const Text('TOOLBAR'),
          ),
        ),
      );

      final header = tester.getTopLeft(find.text('HEADER')).dy;
      final row = tester.getTopLeft(find.text('sum-0:A')).dy;
      final footer = tester.getTopLeft(find.text('FOOTER')).dy;
      final toolbar = tester.getTopLeft(find.text('TOOLBAR')).dy;

      expect(header, lessThan(row));
      expect(row, lessThan(footer));
      expect(footer, lessThan(toolbar));
    });

    testWidgets('an empty list shows the empty builder and keeps the chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith([]),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            headerBuilder: (_, _) => const Text('HEADER'),
            toolbarBuilder: (_, _) => const Text('TOOLBAR'),
            emptyBuilder: (_) => const Text('Nothing here'),
          ),
        ),
      );

      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('HEADER'), findsOneWidget);
      expect(find.text('TOOLBAR'), findsOneWidget);
      expect(find.textContaining('sum-'), findsNothing);
    });

    testWidgets('an empty list with no empty builder renders nothing extra', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith([]),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            headerBuilder: (_, _) => const Text('HEADER'),
          ),
        ),
      );

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('separators sit between consecutive rows only', (tester) async {
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A', 'B', 'C']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            rowSeparatorBuilder: (_, i) => Text('sep-$i'),
          ),
        ),
      );

      expect(find.text('sep-0'), findsOneWidget);
      expect(find.text('sep-1'), findsOneWidget);
      expect(find.text('sep-2'), findsNothing);
    });

    testWidgets('separators are dropped in reorderable mode', (tester) async {
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: _listWith(['A', 'B']),
            summaryBuilder: _summary,
            bodyBuilder: _body,
            reorderable: true,
            rowSeparatorBuilder: (_, i) => Text('sep-$i'),
          ),
        ),
      );

      expect(find.textContaining('sep-'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('TomExpandableListForm reordering', () {
    ReorderableListView view(WidgetTester tester) =>
        tester.widget<ReorderableListView>(find.byType(ReorderableListView));

    Widget reorderable(
      OrderItemListForm list, {
      Set<int>? initialExpanded,
      void Function(int, int)? onReorder,
    }) => TomExpandableListForm<OrderItem, OrderItemForm>(
      listForm: list,
      summaryBuilder: _summary,
      bodyBuilder: _body,
      reorderable: true,
      initialExpanded: initialExpanded,
      onReorder: onReorder,
    );

    testWidgets('reorderable renders a ReorderableListView', (tester) async {
      await tester.pumpWidget(_app(reorderable(_listWith(['A', 'B']))));
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('a reorder moves the underlying rows', (tester) async {
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(reorderable(list)));

      view(tester).onReorderItem!(0, 2);
      await tester.pump();

      expect(_formProducts(list), ['B', 'C', 'A']);
    });

    testWidgets('a no-op drop changes nothing and reports nothing', (
      tester,
    ) async {
      final list = _listWith(['A', 'B']);
      final calls = <List<int>>[];
      await tester.pumpWidget(
        _app(reorderable(list, onReorder: (f, t) => calls.add([f, t]))),
      );

      view(tester).onReorderItem!(1, 1);
      await tester.pump();

      expect(_formProducts(list), ['A', 'B']);
      expect(calls, isEmpty);
    });

    testWidgets('the dragged row stays open at its new index', (tester) async {
      // Without the remap the open body would stay pinned to index 0 and so
      // appear under whichever row happened to slide into that slot.
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(reorderable(list, initialExpanded: {0})));
      expect(find.text('body-0'), findsOneWidget);

      view(tester).onReorderItem!(0, 2);
      await tester.pump();

      expect(_formProducts(list), ['B', 'C', 'A']);
      expect(find.text('body-2'), findsOneWidget);
      expect(find.text('body-0'), findsNothing);
    });

    testWidgets('a bystander open row shifts with the rows around it', (
      tester,
    ) async {
      // C is open at index 2; dragging A from 0 to 2 pushes C up to index 1.
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(reorderable(list, initialExpanded: {2})));

      view(tester).onReorderItem!(0, 2);
      await tester.pump();

      expect(_formProducts(list), ['B', 'C', 'A']);
      expect(
        find.text('body-1'),
        findsOneWidget,
        reason: 'C moved from index 2 to index 1 and stays open',
      );
    });

    testWidgets('an upward drag shifts the rows it displaces downward', (
      tester,
    ) async {
      // A is open at index 0; dragging C from 2 to 0 pushes A down to 1.
      final list = _listWith(['A', 'B', 'C']);
      await tester.pumpWidget(_app(reorderable(list, initialExpanded: {0})));

      view(tester).onReorderItem!(2, 0);
      await tester.pump();

      expect(_formProducts(list), ['C', 'A', 'B']);
      expect(find.text('body-1'), findsOneWidget);
      expect(find.text('body-0'), findsNothing);
    });

    testWidgets('onReorder reports the normalised indices', (tester) async {
      final calls = <List<int>>[];
      await tester.pumpWidget(
        _app(
          reorderable(
            _listWith(['A', 'B', 'C']),
            onReorder: (f, t) => calls.add([f, t]),
          ),
        ),
      );

      view(tester).onReorderItem!(2, 0);
      await tester.pump();

      expect(calls, [
        [2, 0],
      ]);
    });
  });

  // -------------------------------------------------------------------------
  group('TomExpandableListForm observation', () {
    testWidgets('an added row appears', (tester) async {
      final list = _listWith(['A']);
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: list,
            summaryBuilder: _summary,
            bodyBuilder: _body,
          ),
        ),
      );

      list.add();
      await tester.pump();

      expect(find.text('sum-1:'), findsOneWidget);
    });

    testWidgets('a removed row disappears', (tester) async {
      final list = _listWith(['A', 'B']);
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: list,
            summaryBuilder: _summary,
            bodyBuilder: _body,
          ),
        ),
      );

      list.removeAt(0);
      await tester.pump();

      expect(find.text('sum-0:B'), findsOneWidget);
      expect(find.textContaining('A'), findsNothing);
    });

    testWidgets('a per-row field edit repaints the summary', (tester) async {
      final list = _listWith(['A']);
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: list,
            summaryBuilder: _summary,
            bodyBuilder: _body,
          ),
        ),
      );

      list[0].product.setValue('Z');
      await tester.pump();
      expect(find.text('sum-0:Z'), findsOneWidget);

      // `setValue` arms the validation debounce; drain it so no timer
      // outlives the test.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the observer is released on dispose', (tester) async {
      final list = _listWith(['A']);
      await tester.pumpWidget(
        _app(
          TomExpandableListForm<OrderItem, OrderItemForm>(
            listForm: list,
            summaryBuilder: _summary,
            bodyBuilder: _body,
          ),
        ),
      );

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      list.add();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
