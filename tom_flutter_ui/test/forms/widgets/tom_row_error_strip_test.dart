/// Behavioural coverage for `TomRowErrorStrip`.
///
/// The strip is a *derived* widget: it renders nothing of its own state and
/// everything from `form.fieldsWithErrors`. That makes three things worth
/// pinning, and they are the three that a reader cannot infer from the render
/// method alone:
///
///   * **It is safe to include unconditionally.** A row with no errors must
///     collapse to nothing, not to an empty coloured band — which is what lets
///     hosts drop it into every `ExpansionTile` without a conditional.
///
///   * **It repaints from the form, not from the host.** Validation results
///     arrive asynchronously (the field debounce), long after the host's build
///     returned. The strip subscribes to `form.changes` itself; if that
///     subscription were missing, errors would appear only when something
///     *else* happened to rebuild the row.
///
///   * **The subscription follows the form.** A row form swapped in via
///     `didUpdateWidget` must be the one listened to afterwards — otherwise a
///     recycled row silently stops updating.
///
/// The messages are asserted through `resolvedLabel` / `resolvedErrorMessage`,
/// which here fall back to the field id and the raw error key because the test
/// binds no resources. That fallback is the point: the strip must stay legible
/// when a translation is missing rather than rendering a blank bullet.
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

/// Binds a form to an item carrying the given values, so the fields start from
/// a known baseline rather than from their declared defaults.
TwoRequiredFieldsForm _boundForm({
  String product = 'A',
  String quantity = '1',
}) {
  final item = OrderItem();
  item.product | product;
  item.quantity | quantity;
  return TwoRequiredFieldsForm()..bind(item);
}

/// Drives a field into an error state the way the user does — a value change
/// followed by the debounce the field arms in `setValue`.
Future<void> _breakField(WidgetTester tester, TomField<String> field) async {
  field.setValue('');
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _strip() => find.byType(TomRowErrorStrip);

Column _column(WidgetTester tester) => tester.widget<Column>(
  find.descendant(of: _strip(), matching: find.byType(Column)),
);

List<String> _lines(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: _strip(), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .toList();

void main() {
  setUpAll(initializeReflection);

  // -------------------------------------------------------------------------
  group('TomRowErrorStrip rendering', () {
    testWidgets('a row without errors collapses to nothing', (tester) async {
      final form = _boundForm();

      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));

      expect(_lines(tester), isEmpty);
      expect(
        find.descendant(of: _strip(), matching: find.byType(Container)),
        findsNothing,
        reason: 'no coloured band is painted for a clean row',
      );
    });

    testWidgets('one error reads in the singular', (tester) async {
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));

      await _breakField(tester, form.product);

      expect(find.text('Row has 1 validation error:'), findsOneWidget);
    });

    testWidgets('two errors read in the plural', (tester) async {
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));

      await _breakField(tester, form.product);
      await _breakField(tester, form.quantity);

      expect(find.text('Row has 2 validation errors:'), findsOneWidget);
    });

    testWidgets('each failing field gets its own bullet line', (tester) async {
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));

      await _breakField(tester, form.product);
      await _breakField(tester, form.quantity);

      expect(
        _lines(tester),
        containsAll(<String>[
          '• product: error.required',
          '• quantity: error.required',
        ]),
      );
    });

    testWidgets('an unresolved label falls back to the field id', (
      tester,
    ) async {
      // Without this fallback a missing translation would render "• : …",
      // leaving the user unable to tell which field is at fault.
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));

      await _breakField(tester, form.product);

      expect(find.text('• product: error.required'), findsOneWidget);
    });

    testWidgets('a clean field is not listed', (tester) async {
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));

      await _breakField(tester, form.product);

      expect(find.text('• quantity: error.required'), findsNothing);
    });

    testWidgets('the band is full width and error-coloured', (tester) async {
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));
      await _breakField(tester, form.product);

      final container = tester.widget<Container>(
        find.descendant(of: _strip(), matching: find.byType(Container)),
      );

      expect(container.constraints?.maxWidth, double.infinity);
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.border,
        isNotNull,
        reason: 'the strip is fenced top and bottom',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TomRowErrorStrip alignment', () {
    testWidgets('defaults to start alignment on both axes', (tester) async {
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));
      await _breakField(tester, form.product);

      expect(_column(tester).crossAxisAlignment, CrossAxisAlignment.start);
      expect(
        tester.widget<Text>(find.text('• product: error.required')).textAlign,
        TextAlign.start,
      );
    });

    testWidgets('centre alignment moves both the column and the text', (
      tester,
    ) async {
      final form = _boundForm();
      await tester.pumpWidget(
        _app(
          TomRowErrorStrip(
            form: form,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
        ),
      );
      await _breakField(tester, form.product);

      expect(_column(tester).crossAxisAlignment, CrossAxisAlignment.center);
      expect(
        tester.widget<Text>(find.text('• product: error.required')).textAlign,
        TextAlign.center,
      );
    });

    testWidgets('an alignment change from the host takes effect without a '
        'listenable', (tester) async {
      // The alignment is a plain constructor argument, so the only thing that
      // can deliver a change is `didUpdateWidget` — worth pinning because the
      // widget is otherwise entirely notifier-driven.
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));
      await _breakField(tester, form.product);
      expect(_column(tester).crossAxisAlignment, CrossAxisAlignment.start);

      await tester.pumpWidget(
        _app(
          TomRowErrorStrip(
            form: form,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
        ),
      );
      await tester.pump();

      expect(_column(tester).crossAxisAlignment, CrossAxisAlignment.center);
    });
  });

  // -------------------------------------------------------------------------
  group('TomRowErrorStrip subscription', () {
    testWidgets('an error appearing after the host build shows up', (
      tester,
    ) async {
      // Nothing rebuilds the host here; the repaint can only come from the
      // strip's own subscription to `form.changes`.
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));
      expect(_lines(tester), isEmpty);

      await _breakField(tester, form.product);

      expect(find.text('Row has 1 validation error:'), findsOneWidget);
    });

    testWidgets('a fixed field drops off the strip', (tester) async {
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));
      await _breakField(tester, form.product);
      expect(find.text('• product: error.required'), findsOneWidget);

      form.product.setValue('B');
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        _lines(tester),
        isEmpty,
        reason: 'the strip collapses again once the row is valid',
      );
    });

    testWidgets('the subscription follows a swapped-in form', (tester) async {
      final first = _boundForm(product: 'A');
      final second = _boundForm(product: 'B');
      await tester.pumpWidget(
        _app(TomRowErrorStrip(key: const ValueKey('strip'), form: first)),
      );

      await tester.pumpWidget(
        _app(TomRowErrorStrip(key: const ValueKey('strip'), form: second)),
      );
      await _breakField(tester, second.product);

      expect(find.text('Row has 1 validation error:'), findsOneWidget);
    });

    testWidgets('the old form no longer drives the strip after a swap', (
      tester,
    ) async {
      final first = _boundForm(product: 'A');
      final second = _boundForm(product: 'B');
      await tester.pumpWidget(
        _app(TomRowErrorStrip(key: const ValueKey('strip'), form: first)),
      );
      await tester.pumpWidget(
        _app(TomRowErrorStrip(key: const ValueKey('strip'), form: second)),
      );

      await _breakField(tester, first.product);

      expect(
        _lines(tester),
        isEmpty,
        reason: 'errors on the detached form are not this row\'s business',
      );
    });

    testWidgets('a form outliving the strip fires without throwing', (
      tester,
    ) async {
      final form = _boundForm();
      await tester.pumpWidget(_app(TomRowErrorStrip(form: form)));

      await tester.pumpWidget(_app(const SizedBox.shrink()));

      expect(() => form.product.setValue(''), returnsNormally);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
