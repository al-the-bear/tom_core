/// Unit tests for module-owned forms logic that the demo/widget suites never
/// exercise:
///
///   * `phase2aLookupProductPrice` — the exact-name catalog lookup that backs
///     the product-price auto-fill.
///   * `OrderItemForm._priceSync` — picking a known catalog product mirrors its
///     price into `unitPrice`; a free-form entry leaves the price untouched.
///   * `OrderItemForm.computedTotal` / `OrderItemHDForm.computedTotal` — the
///     quantity × unit-price product, parse-fail-tolerant (non-numeric → 0).
///   * `OrderHDForm.totalAmount` — the per-row sum across the bound items list,
///     including a row whose price/qty can't be parsed.
///   * The error keys the forms' validators produce — the shared decimal
///     validator behind `unitPrice`, and `ValidationForm`'s username pattern,
///     async username-taken check and website URL pattern.
///
/// Like `tom_list_form_test.dart`, these construct real `TomForm` subclasses,
/// so reflection must be initialised through the app's generated
/// `main.reflection.dart`. Forms are built inside a `TomScope` so their
/// basePaths resolve; resources are loaded so field construction stays quiet.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/forms/customer_hd_form.dart';
import 'package:tom_flutter_form_test/forms/order_item_form.dart';
import 'package:tom_flutter_form_test/forms/validation_form.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase2a_state.dart';
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

  group('phase2aLookupProductPrice — exact-name catalog lookup', () {
    test('returns the catalog price for a known product', () {
      expect(phase2aLookupProductPrice('Brass gear (small)'), 4.20);
      expect(phase2aLookupProductPrice('Mainspring assembly'), 58.50);
    });

    test('returns null for a name not in the catalog', () {
      expect(phase2aLookupProductPrice('Flux capacitor'), isNull);
      expect(phase2aLookupProductPrice(''), isNull);
    });

    test('a zero-priced catalog entry resolves to 0.0, not null', () {
      // "Conference badge" is priced 0.00 — the lookup must distinguish a
      // genuine 0 price from a catalog miss (null).
      expect(phase2aLookupProductPrice('Conference badge'), 0.0);
    });

    test('preserves a negative catalog price (e.g. a fee credit)', () {
      expect(phase2aLookupProductPrice('Restocking fee'), -25.00);
    });
  });

  group('OrderItemForm._priceSync — product → unit-price auto-fill', () {
    test('selecting a known product mirrors its price into unitPrice', () {
      final form = TomScope.withScope('priceSyncTest', () => OrderItemForm());
      expect(form.unitPrice.get(), '0.00', reason: 'seed price before pick');
      form.productName.setValue('Brass gear (small)');
      expect(
        form.unitPrice.get(),
        '4.20',
        reason: 'catalog hit must auto-fill the formatted price',
      );
      form.dispose();
    });

    test('a free-form (non-catalog) product leaves unitPrice untouched', () {
      final form = TomScope.withScope('priceSyncTest', () => OrderItemForm());
      form.unitPrice.setValue('9.99');
      form.productName.setValue('Bespoke widget not in catalog');
      expect(
        form.unitPrice.get(),
        '9.99',
        reason: 'a catalog miss must not overwrite a user-entered price',
      );
      form.dispose();
    });

    test('a zero-priced catalog product still auto-fills 0.00', () {
      final form = TomScope.withScope('priceSyncTest', () => OrderItemForm());
      form.unitPrice.setValue('5.00');
      form.productName.setValue('Conference badge');
      expect(
        form.unitPrice.get(),
        '0.00',
        reason:
            'a genuine 0.00 catalog price must overwrite, not be '
            'treated as a miss',
      );
      form.dispose();
    });
  });

  group('OrderItemForm.computedTotal — qty × price', () {
    OrderItemForm makeItemForm() =>
        TomScope.withScope('totalTest', () => OrderItemForm());

    test('multiplies parsed quantity and unit price', () {
      final form = makeItemForm();
      form.quantity.setValue('3');
      form.unitPrice.setValue('4.50');
      expect(form.computedTotal, 13.5);
      form.dispose();
    });

    test('non-numeric quantity yields 0', () {
      final form = makeItemForm();
      form.quantity.setValue('two');
      form.unitPrice.setValue('4.50');
      expect(form.computedTotal, 0.0);
      form.dispose();
    });

    test('non-numeric price yields 0', () {
      final form = makeItemForm();
      form.quantity.setValue('3');
      form.unitPrice.setValue('free');
      expect(form.computedTotal, 0.0);
      form.dispose();
    });
  });

  group('OrderItemHDForm.computedTotal — qty × price', () {
    OrderItemHDForm makeItemForm() =>
        TomScope.withScope('hdTotalTest', () => OrderItemHDForm());

    test('multiplies parsed quantity and unit price', () {
      final form = makeItemForm();
      form.quantity.setValue('4');
      form.unitPrice.setValue('2.25');
      expect(form.computedTotal, 9.0);
      form.dispose();
    });

    test('non-numeric inputs yield 0', () {
      final form = makeItemForm();
      form.quantity.setValue('x');
      form.unitPrice.setValue('y');
      expect(form.computedTotal, 0.0);
      form.dispose();
    });
  });

  group('OrderHDForm.totalAmount — per-row sum across the bound items', () {
    OrderHD makeOrder(List<OrderItemHD> items) {
      final o = OrderHD();
      o.orderId | 'ORD-T1';
      o.orderDate | '2026-06-25';
      for (final i in items) {
        o.items.add(i);
      }
      return o;
    }

    OrderItemHD item(String qty, String price) {
      final i = OrderItemHD();
      i.productName | 'p';
      i.quantity | qty;
      i.unitPrice | price;
      return i;
    }

    test('sums computedTotal over every bound row', () {
      final form = TomScope.withScope('totalAmountTest', () => OrderHDForm());
      form.bind(makeOrder([item('2', '5.00'), item('3', '4.50')]));
      // 2×5.00 + 3×4.50 = 10 + 13.5
      expect(form.totalAmount, 23.5);
      form.dispose();
    });

    test('a row that cannot be parsed contributes 0 to the sum', () {
      final form = TomScope.withScope('totalAmountTest', () => OrderHDForm());
      form.bind(makeOrder([item('2', '5.00'), item('oops', '9.99')]));
      // 2×5.00 + (unparseable → 0) = 10.0
      expect(form.totalAmount, 10.0);
      form.dispose();
    });

    test('an empty order totals 0', () {
      final form = TomScope.withScope('totalAmountTest', () => OrderHDForm());
      form.bind(makeOrder([]));
      expect(form.totalAmount, 0.0);
      form.dispose();
    });
  });

  // The error keys these forms produce are their contract with the resource
  // file: a key that drifts silently falls back to raw text. Each case below
  // runs the real field's validator chain and asserts the exact key.
  group('OrderItemForm.unitPrice — decimal validator error keys', () {
    Future<ValidationResult> validatePrice(String text) async {
      final form = TomScope.withScope('priceKeyTest', () => OrderItemForm());
      addTearDown(form.dispose);
      form.unitPrice.set(text);
      return form.unitPrice.validate();
    }

    test('non-numeric text reports error.invalidDecimal', () async {
      final r = await validatePrice('abc');
      expect((r as ValidationError).errorKey, 'error.invalidDecimal');
    });

    test('a negative price reports error.mustBeNonNegative', () async {
      final r = await validatePrice('-1.50');
      expect((r as ValidationError).errorKey, 'error.mustBeNonNegative');
    });

    test('a non-negative decimal validates clean', () async {
      expect(await validatePrice('4.20'), isA<ValidationSuccess>());
    });
  });

  group('ValidationForm — field error keys', () {
    ValidationForm makeForm() {
      final form = TomScope.withScope('validationKeyTest', ValidationForm.new);
      addTearDown(form.dispose);
      return form;
    }

    test('username with a disallowed character reports '
        'error.usernamePattern', () async {
      final form = makeForm();
      // Long enough for minLength(3), so the pattern is the first failure.
      form.username.set('jane!');
      final r = await form.username.validate();
      expect((r as ValidationError).errorKey, 'error.usernamePattern');
    });

    test('username starting with "admin" reports error.usernameTaken from '
        'the slow validator', () async {
      final form = makeForm();
      // Passes every fast validator, so only the async check can reject it.
      form.username.set('admin_jane');
      final r = await form.username.validate();
      expect((r as ValidationError).errorKey, 'error.usernameTaken');
    });

    test('a malformed website reports error.invalidUrl', () async {
      final form = makeForm();
      form.website.set('not a url');
      final r = await form.website.validate();
      expect((r as ValidationError).errorKey, 'error.invalidUrl');
    });
  });
}
