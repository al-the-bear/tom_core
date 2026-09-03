/// Widget-level reproductions for the two reported list-form bugs.
///
///   (a) H-A — clicking a different row in the master pane should swap
///       the detail pane to that row's sub-form.
///   (b) H-D — deleting a row from inside a nested items list and then
///       discarding (at any level) should restore the deleted rows.
///
/// These tests open the actual demo screens through normal navigation so
/// any UI plumbing issue (observer not subscribed, ListenableBuilder
/// pinned to a stale form, etc.) shows up exactly the way the user sees it.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase_hd_state.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  setUp(() {
    // H-D and H-E share top-level mutable singletons. Reset so each test
    // sees a fresh customer.
    phaseHdCustomer = _freshCustomer();
  });

  Future<void> openDemo(WidgetTester tester, String tile) async {
    tester.view.physicalSize = const Size(2400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text(tile),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
  }

  testWidgets('(a) H-A — tapping a different row swaps the detail pane to that '
      'row\'s sub-form (scoped to scaffold A)', (tester) async {
    await openDemo(tester, 'Demo H-A: Master-Detail Customer Editor');

    // Demo H-A renders TWO master-detail scaffolds bound to the same
    // customer list. Scaffold A (left) starts with no selection;
    // Scaffold B (right) preselects row 0. We exercise scaffold A
    // explicitly by:
    //   1. locating Scaffold A's frame (a `Card` with the label text
    //      "Scaffold A — no preselection"),
    //   2. tapping a master row INSIDE that frame,
    //   3. asserting that a TextField INSIDE that same frame now holds
    //      the chosen row's fullName.
    // This way the assertion can never accidentally match scaffold B's
    // detail pane (which has its own separate selection observable).

    final scaffoldAFrame = find
        .ancestor(
          of: find.text('Scaffold A — no preselection'),
          matching: find.byType(Card),
        )
        .first;
    expect(scaffoldAFrame, findsOneWidget);

    // Before any tap, scaffold A's detail pane is the empty placeholder —
    // there should be NO filled TextField inside scaffold A's frame.
    final tfInsideAInitial = tester
        .widgetList<TextField>(
          find.descendant(of: scaffoldAFrame, matching: find.byType(TextField)),
        )
        .where((tf) => tf.controller != null && tf.controller!.text.isNotEmpty)
        .toList();
    expect(
      tfInsideAInitial,
      isEmpty,
      reason:
          'Scaffold A starts with no selection so no detail '
          'TextField is rendered yet',
    );

    // Pick a non-empty master row title inside scaffold A.
    final aTiles = tester
        .widgetList<ListTile>(
          find.descendant(of: scaffoldAFrame, matching: find.byType(ListTile)),
        )
        .toList();
    expect(aTiles, isNotEmpty);
    String? targetName;
    for (final tile in aTiles) {
      final title = tile.title;
      if (title is! Text) continue;
      final txt = title.data ?? '';
      if (txt.isEmpty || txt == '(unnamed)') continue;
      targetName = txt;
      break;
    }
    expect(
      targetName,
      isNotNull,
      reason: 'Scaffold A master pane must list at least one named row',
    );

    // Tap that row INSIDE scaffold A (not the same name in scaffold B).
    await tester.tap(
      find
          .descendant(of: scaffoldAFrame, matching: find.text(targetName!))
          .first,
    );
    await tester.pumpAndSettle();

    // After the tap, scaffold A's detail pane must render a TextField
    // whose controller holds the tapped row's fullName.
    final tfInsideAAfter = tester
        .widgetList<TextField>(
          find.descendant(of: scaffoldAFrame, matching: find.byType(TextField)),
        )
        .where((tf) => tf.controller?.text == targetName)
        .toList();
    expect(
      tfInsideAAfter,
      isNotEmpty,
      reason:
          'Scaffold A\'s detail pane must render a TextField '
          'holding the tapped row\'s fullName ("$targetName")',
    );
  });

  testWidgets(
    '(a\') H-A — on scaffold B, tapping a different row swaps the detail '
    'pane to that row\'s sub-form',
    (tester) async {
      await openDemo(tester, 'Demo H-A: Master-Detail Customer Editor');

      final scaffoldBFrame = find
          .ancestor(
            of: find.text('Scaffold B — preselects row 0'),
            matching: find.byType(Card),
          )
          .first;
      expect(scaffoldBFrame, findsOneWidget);

      // Scaffold B's preselect runs in a postFrameCallback — pumpAndSettle
      // (already done by openDemo) lets it complete.
      final tfInBInitial = tester
          .widgetList<TextField>(
            find.descendant(
              of: scaffoldBFrame,
              matching: find.byType(TextField),
            ),
          )
          .where(
            (tf) => tf.controller != null && tf.controller!.text.isNotEmpty,
          )
          .toList();
      expect(
        tfInBInitial,
        isNotEmpty,
        reason:
            'Scaffold B preselects row 0 so its detail pane must '
            'render at least one filled TextField',
      );
      final initialName = tfInBInitial.first.controller!.text;

      // Pick a row inside scaffold B's master pane whose title differs
      // from the currently rendered detail.
      final bTiles = tester
          .widgetList<ListTile>(
            find.descendant(
              of: scaffoldBFrame,
              matching: find.byType(ListTile),
            ),
          )
          .toList();
      String? targetName;
      for (final tile in bTiles) {
        final title = tile.title;
        if (title is! Text) continue;
        final txt = title.data ?? '';
        if (txt.isEmpty || txt == '(unnamed)' || txt == initialName) continue;
        targetName = txt;
        break;
      }
      expect(
        targetName,
        isNotNull,
        reason:
            'Scaffold B master pane must list at least two distinct '
            'named rows',
      );

      final masterTapFinder = find
          .descendant(of: scaffoldBFrame, matching: find.text(targetName!))
          .first;
      await tester.tap(masterTapFinder);
      await tester.pumpAndSettle();

      // Scaffold B's detail pane now holds the new fullName.
      final tfInBAfter = tester
          .widgetList<TextField>(
            find.descendant(
              of: scaffoldBFrame,
              matching: find.byType(TextField),
            ),
          )
          .where((tf) => tf.controller?.text == targetName)
          .toList();
      expect(
        tfInBAfter,
        isNotEmpty,
        reason:
            'Scaffold B\'s detail pane must swap to the new row\'s '
            'fullName ("$targetName") after tap',
      );
    },
  );

  testWidgets(
    '(b) H-D — removing an items row inside an order then "Discard" on '
    'the order restores the removed rows',
    (tester) async {
      await openDemo(tester, 'Demo H-D: Customer Form (master-detail)');

      // The orders master pane lists ORD-1001 and ORD-1002. Tap order 0 to
      // open its detail pane (already preselected? No — H-D doesn't pass
      // initialSelectedIndex, so we tap explicitly).
      await tester.tap(find.text('ORD-1001'));
      await tester.pumpAndSettle();

      // Confirm the items header reads "Items (3)" — the seeded ORD-1001
      // has three items.
      expect(
        find.text('Items (3)'),
        findsOneWidget,
        reason: 'order 0 starts with 3 seeded items',
      );

      // Remove one item using the per-row delete IconButton.
      final deleteButtons = find.widgetWithIcon(
        IconButton,
        Icons.delete_outline,
      );
      expect(deleteButtons, findsAtLeastNWidgets(1));
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(
        find.text('Items (2)'),
        findsOneWidget,
        reason:
            'after deleting one row, the items header should read '
            '"Items (2)"',
      );

      // Click the order's "Discard" button (in the OrderDetailPane). The
      // button sits inside the OrderDetailPane's own SingleChildScrollView
      // (the SizedBox(height: 560) constrains it) so the button may be
      // scrolled out of view — ensureVisible scrolls it in before tap.
      final discardBtns = find.widgetWithText(OutlinedButton, 'Discard');
      expect(discardBtns, findsAtLeastNWidgets(1));
      await tester.ensureVisible(discardBtns.first);
      await tester.pumpAndSettle();
      await tester.tap(discardBtns.first);
      await tester.pumpAndSettle();

      // After Discard the order's items list must restore to 3 rows.
      expect(
        find.text('Items (3)'),
        findsOneWidget,
        reason: 'after Discard, the items list must restore to 3 rows',
      );
    },
  );

  testWidgets(
    '(b\') H-D — removing an items row + "Discard all" on the customer '
    'restores the removed rows',
    (tester) async {
      await openDemo(tester, 'Demo H-D: Customer Form (master-detail)');

      await tester.tap(find.text('ORD-1001'));
      await tester.pumpAndSettle();
      expect(find.text('Items (3)'), findsOneWidget);

      final deleteButtons = find.widgetWithIcon(
        IconButton,
        Icons.delete_outline,
      );
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();
      expect(find.text('Items (2)'), findsOneWidget);

      // Click "Discard all" on the root customer form.
      final discardAll = find.widgetWithText(OutlinedButton, 'Discard all');
      expect(discardAll, findsOneWidget);
      await tester.tap(discardAll);
      await tester.pumpAndSettle();

      expect(
        find.text('Items (3)'),
        findsOneWidget,
        reason:
            'after "Discard all" the order\'s items list must restore '
            'to 3 rows',
      );
    },
  );
}

/// Build a fresh [CustomerHD] mirroring `phaseHdCustomer`'s seed data so
/// each test gets a clean baseline (the demo's top-level mutable
/// singleton is shared otherwise).
CustomerHD _freshCustomer() {
  final c = CustomerHD();
  c.fullName | 'Ada Lovelace';
  c.email | 'ada@analytical.example';
  c.phone | '+44 20 7946 0958';
  c.billLine1 | '1 Analytical Way';
  c.billLine2 | 'Suite 42';
  c.billCity | 'London';
  c.billState | 'England';
  c.billZip | 'EC1A 1BB';
  c.billCountry | 'United Kingdom';
  c.shippingAddresses.add(
    _addr(
      'Main Office',
      '1 Analytical Way',
      'Suite 42',
      'London',
      'England',
      'EC1A 1BB',
      'United Kingdom',
    ),
  );
  c.shippingAddresses.add(
    _addr(
      'Warehouse',
      '7 Engine Works',
      '',
      'Manchester',
      'England',
      'M1 2JL',
      'United Kingdom',
    ),
  );
  c.orders.add(
    _order('ORD-1001', '2026-01-15', 'Main Office', [
      _item('Difference Engine pinion', '12', '34.50', 'Brass; lot #B-117'),
      _item('Punched-card deck (1000 pk)', '3', '49.00', 'Hollerith'),
      _item('Lubricating oil (1L)', '5', '6.75', ''),
    ]),
  );
  c.orders.add(
    _order('ORD-1002', '2026-02-28', 'Warehouse', [
      _item('Bearing block', '4', '18.75', ''),
      _item('Mainspring assembly', '1', '58.50', 'Replacement unit'),
    ]),
  );
  return c;
}

ShippingAddressHD _addr(
  String label,
  String l1,
  String l2,
  String city,
  String state,
  String zip,
  String country,
) {
  final a = ShippingAddressHD();
  a.label | label;
  a.line1 | l1;
  a.line2 | l2;
  a.city | city;
  a.stateRegion | state;
  a.zipCode | zip;
  a.country | country;
  return a;
}

OrderHD _order(
  String id,
  String date,
  String shipping,
  List<OrderItemHD> items,
) {
  final o = OrderHD();
  o.orderId | id;
  o.orderDate | date;
  o.shippingLabel | shipping;
  for (final i in items) {
    o.items.add(i);
  }
  return o;
}

OrderItemHD _item(String name, String qty, String price, String notes) {
  final i = OrderItemHD();
  i.productName | name;
  i.quantity | qty;
  i.unitPrice | price;
  i.notes | notes;
  return i;
}
