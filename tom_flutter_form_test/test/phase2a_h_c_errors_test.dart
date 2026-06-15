/// Round-6 (d) + (e) regressions for Demo H-C (Editable Table):
///   - (d) `TomErrorView` resolves error keys to user-facing text via
///     the resource provider. Two underlying bugs:
///       1. it used to prefix `'error.'` to `errorKey` even though the
///          stock validators already produce `error.<name>` keys, so the
///          field-scoped lookup tried `error.error.required` and never
///          hit;
///       2. its global lookup used `TomCtr.textOrNull('', key)` which
///          builds a `'.<key>'` resource path with a leading dot — that
///          breaks `getObjectFromTree` and always returns null, so even
///          well-defined keys fell through to the raw text.
///     The fix lives in `tom_flutter_ui` (TomErrorView._resolveMessage).
///   - (e) the TomAclBuilder variant of the items list grants the
///     product cell ~2x the previous width so long catalog names are
///     no longer cramped against the qty cell.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/forms/order_item_form.dart';
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

  Future<void> openDemoHC(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo H-C: Editable Order-Items Table'), 200);
    await tester.tap(find.text('Demo H-C: Editable Order-Items Table'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      '(d) TomErrorView resolves cross-field key through the resource provider',
      (tester) async {
    await openDemoHC(tester);
    // Wipe every row so the OrderItemsListForm.validateList rule fires
    // with `error.items.minRequired`.
    final removeButtons = find.widgetWithText(OutlinedButton, 'Remove all');
    expect(removeButtons, findsAtLeastNWidgets(1),
        reason: '"Remove all" must exist in the H-C action bar');
    await tester.ensureVisible(removeButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(removeButtons.first);
    await tester.pumpAndSettle();

    // Trigger validation explicitly so TomErrorView receives the event.
    final validateButtons = find.widgetWithText(OutlinedButton, 'Validate');
    expect(validateButtons, findsAtLeastNWidgets(1));
    await tester.ensureVisible(validateButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(validateButtons.first);
    await tester.pumpAndSettle();

    // The resolved text must appear, and the raw key must NOT.
    expect(find.text('Add at least one item to the order.'),
        findsAtLeastNWidgets(1),
        reason:
            'TomErrorView must resolve `error.items.minRequired` through the '
            'resource provider, not surface the raw key.');
    expect(find.textContaining('error.items.minRequired'), findsNothing,
        reason: 'Raw key must not leak into the user-facing TomErrorView');
  });

  testWidgets(
      '(e) TomAclBuilder.setPSize sizes the product cell to ~2x the qty cell',
      (tester) async {
    // Direct widget test of the round-6 (e) fix: previously the demo
    // wrapped each ACL cell in `SizedBox(width: …)` but the ACL layout
    // engine ignores the inner widget's intrinsic width, so every cell
    // rendered at an equal share of the row regardless of the value.
    // The fix is to size the ACL component itself via `setPSize` on
    // the builder. This test mirrors the demo's column setup with the
    // same product=720, qty=70, price=110 sizes and asserts the
    // rendered RenderBox widths reflect the configured preferred sizes.
    tester.view.physicalSize = const Size(2000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final form = TomScope.withScope('demoHC', () => OrderItemForm());
    final item = OrderItem();
    item.productName | 'Patch review token';
    item.quantity | '4';
    item.unitPrice | '12.00';
    item.notes | '';
    form.bind(item);
    addTearDown(form.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(16),
            child: TomAclBuilder<OrderItemForm>(
              id: 'orderItemRow',
              elementProvider: form,
            )
                .append((f) => f.productName.widget).setPSize(720)
                .append((f) => f.quantity.widget).setPSize(70)
                .append((f) => f.unitPrice.widget).setPSize(110)
                .build(context),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The field widgets are wrapped in a TomFieldWidgetAdapter that
    // exposes the underlying field via `field.tomId`. This is the
    // public, ACL-friendly handle for finding form-field widgets in
    // tests.
    final productAdapter = find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'productName',
    );
    expect(productAdapter, findsOneWidget,
        reason: 'Product field adapter must be in the tree');
    final productBox = tester.renderObject<RenderBox>(productAdapter);

    final qtyAdapter = find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'quantity',
    );
    expect(qtyAdapter, findsOneWidget,
        reason: 'Qty field adapter must be in the tree');
    final qtyBox = tester.renderObject<RenderBox>(qtyAdapter);

    expect(productBox.size.width, greaterThan(qtyBox.size.width * 2),
        reason:
            'Product cell (${productBox.size.width}px) must be at least '
            '2x the qty cell (${qtyBox.size.width}px) — proves '
            'TomAclBuilder.setPSize honours per-component preferred '
            'widths (round-6 e).');
  });
}
