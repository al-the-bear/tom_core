/// T13 — Currency-symbol regression: the symbol must be a *fixed* widget
/// in the field's prefix/suffix slot, NOT part of the editable controller
/// text, so the user cannot delete it with Backspace / Select-All-Delete.
///
/// Two pre-fix bugs this test pins:
///   1. Material `TomFormCurrencyDoubleInput` initialized its controller
///      with `'$199.99'`, leaving the `$` deletable.
///   2. Cupertino `TomCupertinoFormCurrencyDoubleInput` had the same
///      shape via the same `_formatted()` helper.
///
/// Post-fix expectation:
///   * The TextField's `controller.text` contains digits + separators
///     ONLY — no symbol character anywhere.
///   * The symbol is rendered as a `Text` widget inside the InputDecoration's
///     `prefixIcon` (USD/GBP/JPY → leading) or `suffixIcon` (EUR → trailing).
///   * Clearing the controller text and pumping does not remove the symbol
///     widget (it lives outside the editable area).
library;

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/main.reflection.dart';

// --- Helpers ----------------------------------------------------------------

/// Recursively look for a Text descendant whose data == [needle].
bool _subtreeContainsText(Widget? root, String needle) {
  if (root == null) return false;
  final found = <bool>[false];
  void visit(Widget w) {
    if (found[0]) return;
    if (w is Text && w.data == needle) {
      found[0] = true;
      return;
    }
    if (w is Padding && w.child != null) visit(w.child!);
    if (w is Row) {
      for (final c in w.children) {
        visit(c);
      }
    }
    if (w is SizedBox && w.child != null) visit(w.child!);
  }

  visit(root);
  return found[0];
}

Widget _materialHarness(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: TomFormStyleScope(
              tomId: 'currencyT13Material',
              style: TomFormStyle.material3,
              child: Builder(builder: (_) => child),
            ),
          ),
        ),
      ),
    );

Widget _cupertinoHarness(Widget child) => CupertinoApp(
      home: CupertinoPageScaffold(
        child: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: TomFormStyleScope(
                tomId: 'currencyT13Cupertino',
                style: TomFormStyle.material3,
                child: Builder(builder: (_) => child),
              ),
            ),
          ),
        ),
      ),
    );

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

  // -------------------------------------------------------------------------
  // Material side
  // -------------------------------------------------------------------------

  group(
      'Material TomFormCurrencyDoubleInput — fixed-symbol prefixText/suffixText',
      () {
    testWidgets('USD: symbol is in InputDecoration.prefixText',
        (tester) async {
      late TomFormCurrencyDoubleInput field;
      TomScope.withScope('curUSD', () {
        field = TomFormCurrencyDoubleInput(
          'priceUSD',
          199.99,
          currencyCode: 'USD',
        );
      });
      addTearDown(field.dispose);

      await tester.pumpWidget(_materialHarness(field.widget));
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));

      // Controller contains amount only — never the symbol.
      expect(tf.controller!.text, isNot(contains(r'$')),
          reason: 'currency symbol must NOT live in the editable text');
      expect(tf.controller!.text, equals('199.99'),
          reason: 'controller holds the formatted amount only');

      // Symbol is the InputDecoration.prefixText (Material's own slot for
      // baseline-aligned, non-editable inline prefix text).
      expect(tf.decoration?.prefixText, equals(r'$'),
          reason: 'USD symbol must land in prefixText (leading)');
      expect(tf.decoration?.suffixText, isNull);
      // Sanity: we are NOT using the prefixIcon path any more.
      expect(tf.decoration?.prefixIcon, isNull,
          reason:
              'switched away from prefixIcon — must not regress to that slot');
    });

    testWidgets('EUR: symbol is in InputDecoration.suffixText',
        (tester) async {
      late TomFormCurrencyDoubleInput field;
      TomScope.withScope('curEUR', () {
        field = TomFormCurrencyDoubleInput(
          'priceEUR',
          199.99,
          currencyCode: 'EUR',
        );
      });
      addTearDown(field.dispose);

      await tester.pumpWidget(_materialHarness(field.widget));
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));

      expect(tf.controller!.text, isNot(contains('€')),
          reason: 'currency symbol must NOT live in the editable text');
      // EUR uses '.' group, ',' decimal: 199,99
      expect(tf.controller!.text, equals('199,99'),
          reason: 'EUR amount uses comma decimal separator');

      expect(tf.decoration?.suffixText, equals('€'),
          reason: 'EUR symbol must land in suffixText (trailing)');
      expect(tf.decoration?.prefixText, isNull);
      expect(tf.decoration?.suffixIcon, isNull,
          reason: 'must not regress to suffixIcon path');
    });

    testWidgets('symbol survives clearing the editable text',
        (tester) async {
      // Pin the bug: with the OLD code path, calling controller.clear()
      // (or Backspace at position 0) would wipe the symbol along with the
      // amount because the symbol was part of controller.text. With the
      // fix the symbol lives in prefixText (InputDecoration metadata),
      // which is independent of the controller.
      late TomFormCurrencyDoubleInput field;
      TomScope.withScope('curClear', () {
        field = TomFormCurrencyDoubleInput(
          'priceClear',
          50.00,
          currencyCode: 'USD',
        );
      });
      addTearDown(field.dispose);

      await tester.pumpWidget(_materialHarness(field.widget));
      await tester.pumpAndSettle();

      final beforeTf = tester.widget<TextField>(find.byType(TextField));
      beforeTf.controller!.clear();
      await tester.pump();

      final afterTf = tester.widget<TextField>(find.byType(TextField));
      expect(afterTf.controller!.text, isEmpty,
          reason: 'sanity: clear() emptied the controller');
      expect(afterTf.decoration?.prefixText, equals(r'$'),
          reason: 'prefixText (the symbol) must persist after a wipe — '
              'it lives outside the controller');
    });
  });

  // -------------------------------------------------------------------------
  // Cupertino side — same three checks against CupertinoTextField.prefix /
  // .suffix.
  // -------------------------------------------------------------------------

  group('Cupertino TomCupertinoFormCurrencyDoubleInput — fixed-symbol slots',
      () {
    testWidgets('USD: symbol is in prefix slot, not in controller text',
        (tester) async {
      late TomCupertinoFormCurrencyDoubleInput field;
      TomScope.withScope('cupCurUSD', () {
        field = TomCupertinoFormCurrencyDoubleInput(
          'cupPriceUSD',
          199.99,
          currencyCode: 'USD',
        );
      });
      addTearDown(field.dispose);

      await tester.pumpWidget(_cupertinoHarness(field.widget));
      await tester.pumpAndSettle();

      final ctf = tester.widget<CupertinoTextField>(
          find.byType(CupertinoTextField));
      expect(ctf.controller!.text, isNot(contains(r'$')),
          reason: 'symbol must NOT live in the controller text');
      expect(ctf.controller!.text, equals('199.99'));
      expect(ctf.prefix, isNotNull,
          reason: 'USD symbol must land in CupertinoTextField.prefix');
      expect(_subtreeContainsText(ctf.prefix, r'$'), isTrue);
    });

    testWidgets('EUR: symbol is in suffix slot (locale convention)',
        (tester) async {
      late TomCupertinoFormCurrencyDoubleInput field;
      TomScope.withScope('cupCurEUR', () {
        field = TomCupertinoFormCurrencyDoubleInput(
          'cupPriceEUR',
          199.99,
          currencyCode: 'EUR',
        );
      });
      addTearDown(field.dispose);

      await tester.pumpWidget(_cupertinoHarness(field.widget));
      await tester.pumpAndSettle();

      final ctf = tester.widget<CupertinoTextField>(
          find.byType(CupertinoTextField));
      expect(ctf.controller!.text, isNot(contains('€')));
      expect(ctf.controller!.text, equals('199,99'));
      expect(ctf.suffix, isNotNull,
          reason: 'EUR symbol must land in CupertinoTextField.suffix');
      expect(_subtreeContainsText(ctf.suffix, '€'), isTrue);
    });
  });
}
