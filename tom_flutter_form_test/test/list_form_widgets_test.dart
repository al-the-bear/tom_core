/// Direct widget-level coverage for the list-form widget family.
///
/// `tom_list_form_test.dart` exercises the model layer (`TomListForm`
/// add/remove/move/discard/validate). The reproduction tests in
/// `list_form_repro_test.dart` and `list_form_widget_repro_test.dart`
/// pin down the H-A row-swap bug and the H-D nested-discard chain.
///
/// This file fills the remaining gap: it instantiates each list-form
/// widget (`TomInlineListForm`, `TomMasterDetailListForm`,
/// `TomListFormToolbar`) with a small custom host so the widgets are
/// exercised without going through the full demo app. Each test is
/// scoped to one widget's contract.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/forms/order_form.dart';
import 'package:tom_flutter_form_test/forms/order_item_form.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase2a_state.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr =
        await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Order makeOrder({int items = 2}) {
    final o = Order();
    o.orderNumber | 'TEST-1';
    o.customer | 'Test Customer';
    for (var i = 0; i < items; i++) {
      final it = OrderItem();
      it.productName | 'Item ${String.fromCharCode(65 + i)}';
      it.quantity | '${i + 1}';
      it.unitPrice | '${(i + 1) * 1.5}';
      o.items.add(it);
    }
    return o;
  }

  OrderForm makeBound({int items = 2}) {
    final form =
        TomScope.withScope('listFormWidgetTest', () => OrderForm());
    form.bind(makeOrder(items: items));
    return form;
  }

  /// Standard host: MaterialApp + a sized Scaffold body. The forms
  /// were already constructed inside a `TomScope.withScope` block so
  /// they carry their own scope; the widgets under test don't pass
  /// `tomId` so they don't need one either.
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: child,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // TomInlineListForm
  // -------------------------------------------------------------------------

  group('TomInlineListForm', () {
    testWidgets('renders one row per list entry', (tester) async {
      final form = makeBound(items: 3);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          rowBuilder: (ctx, i, rowForm) =>
              Text('row-$i:${rowForm.productName.get()}'),
        ),
      ));

      expect(find.text('row-0:Item A'), findsOneWidget);
      expect(find.text('row-1:Item B'), findsOneWidget);
      expect(find.text('row-2:Item C'), findsOneWidget);
    });

    testWidgets('rebuilds when a row is added or removed', (tester) async {
      final form = makeBound(items: 2);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          rowBuilder: (ctx, i, rowForm) => Text('r-$i'),
        ),
      ));

      expect(find.text('r-0'), findsOneWidget);
      expect(find.text('r-1'), findsOneWidget);
      expect(find.text('r-2'), findsNothing);

      // Mutate the model — the inline list must observe & rebuild.
      form.items.add();
      await tester.pumpAndSettle();
      expect(find.text('r-2'), findsOneWidget,
          reason: 'add() must trigger an inline-list rebuild');

      form.items.removeAt(0);
      await tester.pumpAndSettle();
      // After removal indices shift down — the third row (was r-2) is
      // now at index 1.
      expect(find.text('r-0'), findsOneWidget);
      expect(find.text('r-1'), findsOneWidget);
      expect(find.text('r-2'), findsNothing);
    });

    testWidgets('renders emptyBuilder when the list is empty', (tester) async {
      final form = makeBound(items: 0);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          rowBuilder: (ctx, i, rowForm) => Text('row-$i'),
          emptyBuilder: (_) => const Text('no items yet'),
        ),
      ));

      expect(find.text('no items yet'), findsOneWidget);
      expect(find.text('row-0'), findsNothing);

      form.items.add();
      await tester.pumpAndSettle();
      expect(find.text('no items yet'), findsNothing,
          reason: 'empty placeholder must disappear once a row exists');
      expect(find.text('row-0'), findsOneWidget);
    });

    testWidgets(
        'showRowMoveButtons renders per-row arrows that move rows in place',
        (tester) async {
      // Bug (c): inline lists without a master pane need per-row move
      // buttons because there is no selection-driven toolbar host.
      final form = makeBound(items: 3);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          showRowMoveButtons: true,
          rowBuilder: (ctx, i, rowForm) =>
              Text('row-$i:${rowForm.productName.get()}'),
        ),
      ));
      await tester.pumpAndSettle();

      // Three rows, three pairs of move buttons → six buttons total.
      // Each row gets one Move up + one Move down (button enabled or
      // disabled depending on position).
      final moveUpFinder =
          find.widgetWithIcon(IconButton, Icons.arrow_upward);
      final moveDownFinder =
          find.widgetWithIcon(IconButton, Icons.arrow_downward);
      expect(moveUpFinder, findsNWidgets(3));
      expect(moveDownFinder, findsNWidgets(3));

      // Row 0's "Move up" must be disabled (no row above).
      final firstMoveUp =
          tester.widget<IconButton>(moveUpFinder.first);
      expect(firstMoveUp.onPressed, isNull,
          reason: 'first row has no row above — Move up must be disabled');

      // Last row's "Move down" must be disabled (no row below).
      final lastMoveDown =
          tester.widget<IconButton>(moveDownFinder.last);
      expect(lastMoveDown.onPressed, isNull,
          reason: 'last row has no row below — Move down must be disabled');

      // Tap the second row's "Move up" → row order becomes B, A, C.
      await tester.tap(moveUpFinder.at(1));
      await tester.pumpAndSettle();
      expect(find.text('row-0:Item B'), findsOneWidget);
      expect(find.text('row-1:Item A'), findsOneWidget);
      expect(find.text('row-2:Item C'), findsOneWidget);
    });

    testWidgets(
        'rowMoveButtonsPosition.leading puts arrows before row body',
        (tester) async {
      final form = makeBound(items: 2);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          showRowMoveButtons: true,
          rowMoveButtonsPosition: TomRowMoveButtonsPosition.leading,
          rowBuilder: (ctx, i, rowForm) =>
              Text('body-$i', key: ValueKey('body-$i')),
        ),
      ));
      await tester.pumpAndSettle();

      // The pair of Move buttons must come before the row body in the
      // first row's Row.children. We assert by global position: a Move
      // up icon button must be left of body-0 on the screen.
      final upX = tester
          .getTopLeft(
              find.widgetWithIcon(IconButton, Icons.arrow_upward).first)
          .dx;
      final bodyX =
          tester.getTopLeft(find.byKey(const ValueKey('body-0'))).dx;
      expect(upX, lessThan(bodyX),
          reason:
              'leading position must place the move buttons left of the row body');
    });

    testWidgets(
        'rowMoveButtonsPosition.trailing (default) puts arrows after row body',
        (tester) async {
      final form = makeBound(items: 2);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          showRowMoveButtons: true,
          rowBuilder: (ctx, i, rowForm) =>
              Text('body-$i', key: ValueKey('body-$i')),
        ),
      ));
      await tester.pumpAndSettle();

      final upX = tester
          .getTopLeft(
              find.widgetWithIcon(IconButton, Icons.arrow_upward).first)
          .dx;
      final bodyX =
          tester.getTopLeft(find.byKey(const ValueKey('body-0'))).dx;
      expect(upX, greaterThan(bodyX),
          reason:
              'trailing (default) must place the move buttons right of the row body');
    });

    testWidgets('showRowMoveButtons defaults to false (no extra buttons)',
        (tester) async {
      final form = makeBound(items: 3);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          rowBuilder: (ctx, i, rowForm) => Text('row-$i'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithIcon(IconButton, Icons.arrow_upward),
          findsNothing,
          reason: 'opt-in only — no per-row arrows appear by default');
      expect(find.widgetWithIcon(IconButton, Icons.arrow_downward),
          findsNothing);
    });

    testWidgets('header / footer / toolbar all render', (tester) async {
      final form = makeBound(items: 1);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          rowBuilder: (ctx, i, rowForm) => Text('row-$i'),
          headerBuilder: (_, _) => const Text('HEADER'),
          footerBuilder: (_, _) => const Text('FOOTER'),
          toolbarBuilder: (_, _) => const Text('TOOLBAR'),
        ),
      ));

      expect(find.text('HEADER'), findsOneWidget);
      expect(find.text('row-0'), findsOneWidget);
      expect(find.text('FOOTER'), findsOneWidget);
      expect(find.text('TOOLBAR'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // TomMasterDetailListForm
  // -------------------------------------------------------------------------

  group('TomMasterDetailListForm', () {
    testWidgets('initialSelectedIndex pre-renders the detail pane',
        (tester) async {
      final form = makeBound(items: 2);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomMasterDetailListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          initialSelectedIndex: 0,
          masterBuilder: (ctx, list, sel, selectIndex) {
            return Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  ListTile(
                    title: Text('master-$i:${list[i].productName.get()}'),
                    selected: sel == i,
                    onTap: () => selectIndex(i),
                  ),
              ],
            );
          },
          detailBuilder: (ctx, i, rowForm) =>
              Text('detail-$i:${rowForm.productName.get()}'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('detail-0:Item A'), findsOneWidget,
          reason: 'initialSelectedIndex must drive the first detail render');
    });

    testWidgets('tapping a master row swaps the detail pane', (tester) async {
      final form = makeBound(items: 3);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomMasterDetailListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          initialSelectedIndex: 0,
          // The guard would pop a Save/Discard/Cancel dialog when isDirty —
          // disable it so the test exercises pure selection mechanics.
          guardUnsavedSelectionChange: false,
          masterBuilder: (ctx, list, sel, selectIndex) {
            return Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  ListTile(
                    key: ValueKey('master-$i'),
                    title: Text('master-$i'),
                    selected: sel == i,
                    onTap: () => selectIndex(i),
                  ),
              ],
            );
          },
          detailBuilder: (ctx, i, rowForm) =>
              Text('detail:${rowForm.productName.get()}'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('detail:Item A'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('master-2')));
      await tester.pumpAndSettle();

      expect(find.text('detail:Item C'), findsOneWidget,
          reason: 'master tap must swap the detail pane to the new row');
      expect(find.text('detail:Item A'), findsNothing,
          reason: 'previous detail must be replaced');
    });

    testWidgets(
        'draggableSplitter widens / narrows the master pane on horizontal drag',
        (tester) async {
      // Bug (b): the gap between the master and detail panes must be
      // optionally draggable. With draggableSplitter: true a horizontal
      // drag on the gap region should resize the master pane within
      // the [min, max] range.
      final form = makeBound(items: 2);
      addTearDown(form.dispose);

      const startWidth = 220.0;
      await tester.pumpWidget(host(
        TomMasterDetailListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          masterPaneWidth: startWidth,
          gap: 16,
          draggableSplitter: true,
          minMasterPaneWidth: 100,
          maxMasterPaneWidth: 400,
          masterBuilder: (ctx, list, sel, selectIndex) =>
              const ColoredBox(
                  key: ValueKey('master-pane'),
                  color: Color(0xFFEEEEEE)),
          detailBuilder: (ctx, i, rowForm) => const Text('detail'),
          emptyDetailBuilder: (_) => const Text('empty'),
        ),
      ));
      await tester.pumpAndSettle();

      final masterFinder = find.byKey(const ValueKey('master-pane'));
      final initialWidth = tester.getSize(masterFinder).width;
      expect(initialWidth, startWidth,
          reason: 'master pane must start at masterPaneWidth');

      // Find the splitter handle — the GestureDetector is sized exactly
      // `gap` (16) wide and is the only one in this widget subtree.
      final gestureFinder = find.descendant(
        of: find.byType(TomMasterDetailListForm<OrderItem, OrderItemForm>),
        matching: find.byType(GestureDetector),
      );
      expect(gestureFinder, findsOneWidget,
          reason: 'draggable splitter must expose a GestureDetector');

      // Drag the splitter +60px to the right.
      await tester.drag(gestureFinder, const Offset(60, 0));
      await tester.pumpAndSettle();
      final widerWidth = tester.getSize(masterFinder).width;
      expect(widerWidth, closeTo(startWidth + 60, 0.1),
          reason: 'rightward drag must widen the master pane by the drag delta');

      // Drag the splitter back -120px → narrower than the start.
      await tester.drag(gestureFinder, const Offset(-120, 0));
      await tester.pumpAndSettle();
      final narrowerWidth = tester.getSize(masterFinder).width;
      expect(narrowerWidth, closeTo(startWidth - 60, 0.1),
          reason: 'leftward drag must narrow the master pane');
    });

    testWidgets(
        'draggableSplitter clamps the master pane to [min, max]',
        (tester) async {
      final form = makeBound(items: 2);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomMasterDetailListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          masterPaneWidth: 200,
          gap: 16,
          draggableSplitter: true,
          minMasterPaneWidth: 150,
          maxMasterPaneWidth: 300,
          masterBuilder: (ctx, list, sel, selectIndex) =>
              const ColoredBox(
                  key: ValueKey('master-pane'),
                  color: Color(0xFFEEEEEE)),
          detailBuilder: (ctx, i, rowForm) => const Text('detail'),
          emptyDetailBuilder: (_) => const Text('empty'),
        ),
      ));
      await tester.pumpAndSettle();

      final masterFinder = find.byKey(const ValueKey('master-pane'));
      final gestureFinder = find.descendant(
        of: find.byType(TomMasterDetailListForm<OrderItem, OrderItemForm>),
        matching: find.byType(GestureDetector),
      );

      // Try to drag way past the max → must clamp to 300.
      await tester.drag(gestureFinder, const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(tester.getSize(masterFinder).width, 300,
          reason: 'rightward over-drag must clamp to maxMasterPaneWidth');

      // Now drag way past the min → must clamp to 150.
      await tester.drag(gestureFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(tester.getSize(masterFinder).width, 150,
          reason: 'leftward over-drag must clamp to minMasterPaneWidth');
    });

    testWidgets(
        'draggableSplitter defaults to false (no GestureDetector in the gap)',
        (tester) async {
      final form = makeBound(items: 1);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomMasterDetailListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          masterBuilder: (ctx, list, sel, selectIndex) =>
              const SizedBox.shrink(),
          detailBuilder: (ctx, i, rowForm) => const Text('detail'),
          emptyDetailBuilder: (_) => const Text('empty'),
        ),
      ));
      await tester.pumpAndSettle();

      final gestureInWidget = find.descendant(
        of: find.byType(TomMasterDetailListForm<OrderItem, OrderItemForm>),
        matching: find.byType(GestureDetector),
      );
      expect(gestureInWidget, findsNothing,
          reason:
              'opt-in only — without draggableSplitter the gap is a plain SizedBox');
    });

    testWidgets('emptyDetailBuilder renders when list is empty',
        (tester) async {
      final form = makeBound(items: 0);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomMasterDetailListForm<OrderItem, OrderItemForm>(
          listForm: form.items,
          masterBuilder: (ctx, list, sel, selectIndex) =>
              Text('master.length=${list.length}'),
          detailBuilder: (ctx, i, rowForm) =>
              const Text('should-not-render'),
          emptyDetailBuilder: (_) => const Text('detail-empty'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('detail-empty'), findsOneWidget);
      expect(find.text('should-not-render'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // TomListFormToolbar
  // -------------------------------------------------------------------------

  group('TomListFormToolbar', () {
    testWidgets('Add button appends a row and reports the new selection',
        (tester) async {
      final form = makeBound(items: 1);
      addTearDown(form.dispose);
      int? lastSelection = -1;

      await tester.pumpWidget(host(
        TomListFormToolbar<OrderItem, OrderItemForm>(
          listForm: form.items,
          selectedIndex: null,
          onSelectionChanged: (i) async => lastSelection = i,
        ),
      ));
      await tester.pumpAndSettle();

      // Find the Add button by its tooltip-default 'Add' label.
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(form.items.length, 2,
          reason: 'Add button must call listForm.add()');
      expect(lastSelection, 1,
          reason: 'onSelectionChanged must report the new last index');
    });

    testWidgets('Remove respects beforeRemove veto', (tester) async {
      final form = makeBound(items: 2);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomListFormToolbar<OrderItem, OrderItemForm>(
          listForm: form.items,
          selectedIndex: 0,
          beforeRemove: (i) async => false, // always veto
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(form.items.length, 2,
          reason: 'beforeRemove returning false must cancel the remove');
    });

    testWidgets('Remove with no selection is disabled', (tester) async {
      final form = makeBound(items: 2);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomListFormToolbar<OrderItem, OrderItemForm>(
          listForm: form.items,
          selectedIndex: null,
        ),
      ));
      await tester.pumpAndSettle();

      final removeBtn =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Remove'));
      expect(removeBtn.onPressed, isNull,
          reason: 'Remove must be disabled when selectedIndex is null');
    });

    testWidgets(
        'Move-up and Move-down share an inner Row so they wrap as a unit',
        (tester) async {
      // Bug (a) refinement: the move arrows must always sit next to each
      // other. The toolbar bundles them inside a single inner Row inside
      // the outer Wrap, so the Wrap treats the pair as one atomic child
      // and only breaks the pair onto a new line as a unit when there's
      // not enough horizontal space — never separating one arrow from
      // the other.
      final form = makeBound(items: 3);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomListFormToolbar<OrderItem, OrderItemForm>(
          listForm: form.items,
          selectedIndex: 1,
        ),
      ));
      await tester.pumpAndSettle();

      // Single outer Wrap holding all toolbar children.
      final wraps = find.descendant(
        of: find.byType(TomListFormToolbar<OrderItem, OrderItemForm>),
        matching: find.byType(Wrap),
      );
      expect(wraps, findsOneWidget,
          reason:
              'Toolbar must render a single Wrap so children flow inline when there is room');

      final moveUpFinder = find.byTooltip('Move up');
      final moveDownFinder = find.byTooltip('Move down');
      final addBtnFinder = find.widgetWithText(FilledButton, 'Add');
      expect(addBtnFinder, findsOneWidget);
      expect(moveUpFinder, findsOneWidget);
      expect(moveDownFinder, findsOneWidget);

      Element nearestRowAncestor(Finder f) {
        final element = tester.element(f);
        Element? row;
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget is Row) {
            row = ancestor;
            return false;
          }
          return true;
        });
        expect(row, isNotNull,
            reason: 'Expected the move arrows to be nested in a Row');
        return row!;
      }

      final upRow = nearestRowAncestor(moveUpFinder);
      final downRow = nearestRowAncestor(moveDownFinder);
      expect(identical(upRow, downRow), isTrue,
          reason: 'Move-up and Move-down must share an immediate Row ancestor');

      // Add must NOT be inside that same inner Row.
      bool addInsideMoveRow = false;
      tester.element(addBtnFinder).visitAncestorElements((ancestor) {
        if (identical(ancestor, upRow)) {
          addInsideMoveRow = true;
          return false;
        }
        return true;
      });
      expect(addInsideMoveRow, isFalse,
          reason: 'Add must live outside the inner move-buttons Row');
    });

    testWidgets(
        'still renders a single Wrap when only one action group is visible',
        (tester) async {
      // Backwards-compat: hosts that hide either group keep the original
      // inline layout.
      final form = makeBound(items: 3);
      addTearDown(form.dispose);

      await tester.pumpWidget(host(
        TomListFormToolbar<OrderItem, OrderItemForm>(
          listForm: form.items,
          selectedIndex: 1,
          showMoveUp: false,
          showMoveDown: false,
        ),
      ));
      await tester.pumpAndSettle();

      final wraps = find.descendant(
        of: find.byType(TomListFormToolbar<OrderItem, OrderItemForm>),
        matching: find.byType(Wrap),
      );
      expect(wraps, findsOneWidget,
          reason:
              'Only the Add/Remove group is visible — the toolbar must render a single Wrap');

      // No move buttons → no inner move-buttons Row should exist.
      expect(find.byTooltip('Move up'), findsNothing);
      expect(find.byTooltip('Move down'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Validation cascade
  // -------------------------------------------------------------------------

  group('validation cascade — sub-row → list → parent form', () {
    test('a row with a required-field error blocks parent.save', () async {
      final form = makeBound(items: 1);
      addTearDown(form.dispose);

      // Clear a required field on the only row.
      form.items[0].productName.setValue('');
      // Sanity: the parent considers itself dirty after the edit.
      expect(form.isDirty, isTrue);

      final saved = await form.save();
      expect(saved, isFalse,
          reason: 'parent.save must propagate sub-row validation failure');
    });

    test('OrderItemsListForm.validateList enforces the min-required rule',
        () async {
      final form = makeBound(items: 1);
      addTearDown(form.dispose);

      form.items.removeAt(0);
      expect(form.items.length, 0);

      final saved = await form.save();
      expect(saved, isFalse,
          reason: 'an empty items list must fail validateList()');
    });

    test('a valid edit through the row form lets parent.save succeed',
        () async {
      final form = makeBound(items: 1);
      addTearDown(form.dispose);

      form.items[0].productName.setValue('Renamed');
      form.items[0].quantity.setValue('5');
      form.items[0].unitPrice.setValue('9.99');

      final saved = await form.save();
      expect(saved, isTrue,
          reason: 'all rows valid + non-empty list → save succeeds');
      // Writeback into the binding.
      expect(form.currentBinding!.items[0].productName.get(), 'Renamed');
      expect(form.currentBinding!.items[0].quantity.get(), '5');
    });
  });

  // -------------------------------------------------------------------------
  // Discard cascade
  // -------------------------------------------------------------------------

  group('discard cascade', () {
    test('field-level edit on a row is rolled back by row.discard()', () {
      final form = makeBound(items: 1);
      addTearDown(form.dispose);

      final original = form.items[0].productName.get();
      form.items[0].productName.setValue('overwritten');
      expect(form.items[0].productName.get(), 'overwritten');

      form.items[0].discard();
      expect(form.items[0].productName.get(), original,
          reason: 'row.discard() must restore the row\'s field values');
    });

    test('list-level add is rolled back by list.discard()', () {
      final form = makeBound(items: 1);
      addTearDown(form.dispose);

      form.items.add();
      expect(form.items.length, 2);

      form.items.discard();
      expect(form.items.length, 1,
          reason: 'list.discard() must drop rows added since last save');
    });

    test('parent form.discard() rolls back both list structure and field edits',
        () {
      final form = makeBound(items: 2);
      addTearDown(form.dispose);
      final originalCustomer = form.customer.get();
      final originalFirstName = form.items[0].productName.get();

      form.customer.setValue('NEW CUSTOMER');
      form.items[0].productName.setValue('NEW PRODUCT');
      form.items.add(); // length now 3
      expect(form.items.length, 3);

      form.discard();
      expect(form.customer.get(), originalCustomer,
          reason: 'parent.discard() must restore parent fields');
      expect(form.items.length, 2,
          reason: 'parent.discard() must restore list structure');
      expect(form.items[0].productName.get(), originalFirstName,
          reason: 'parent.discard() must restore row field values');
    });
  });
}
