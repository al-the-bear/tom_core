/// TCCA17 — the numeric typed fields: int, double, range and duration.
///
/// These are the widgets most forms are actually built from, and none of them
/// had a test. The assertions below are organised around the four things a
/// typed field is *for*, because those are the things a refactor breaks:
///
///  * **parse / format round-trip** — the widget renders a `T` as text and
///    reads text back as a `T`. Both halves have to agree, or a value survives
///    a rebuild only by luck.
///  * **out-of-range handling** — every numeric field here deliberately
///    *stores* an out-of-range value and reports it through validation rather
///    than silently clamping. That is a decision, documented in the sources,
///    and it is invisible unless a test pins it. Slider-shaped fields are the
///    exception: the widget cannot produce an out-of-range value, so they clamp
///    for display only.
///  * **validation triggering** — `minValue` / `maxValue` desugar into
///    prepended `Validators.min` / `Validators.max`; the field is not simply
///    annotated with bounds, it grows rules.
///  * **`set()` / `reset()`** — the baseline semantics TCCA15 pinned, checked
///    here per concrete type.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_double_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_duration_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_int_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_int_list_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_range_fields.dart';
import 'package:tom_flutter_ui/src/forms/selection/static_selectable_source.dart';
import 'package:tom_flutter_ui/src/forms/selection/tom_selectable_source.dart';
import 'package:tom_flutter_ui/src/forms/validation/validation_result.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _app(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

TomUIStateController get _readOnly =>
    TomUIStateController(resolve: (_, _) => TomAuthState.read);

/// The field's fast-validation debounce is 300 ms; anything shorter leaves a
/// live timer behind at teardown.
Future<void> _drainDebounce(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 700));

TextField _textFieldAt(WidgetTester tester, int index) =>
    tester.widgetList<TextField>(find.byType(TextField)).elementAt(index);

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  // =========================================================================
  // TomFormIntInput
  // =========================================================================

  group('TomFormIntInput', () {
    test('min and max desugar into prepended validators', () async {
      final field = TomFormIntInput('qty', 5, minValue: 1, maxValue: 10);
      expect(field.validators, hasLength(2));

      field.setValue(0);
      final low = await field.validate();
      expect(low, isA<ValidationError>());
      expect((low as ValidationError).errorKey, 'error.min');
      expect(low.params, {'min': 1});

      field.setValue(11);
      final high = await field.validate();
      expect((high as ValidationError).errorKey, 'error.max');

      field.setValue(7);
      expect(await field.validate(), isA<ValidationSuccess>());
    });

    test('a field with no bounds grows no validators', () {
      expect(TomFormIntInput('qty', 5).validators, isEmpty);
    });

    test('reset returns to the initial value and a pristine state', () async {
      final field = TomFormIntInput('qty', 5, minValue: 1);
      field.setValue(9);
      expect(field.isDirty, isTrue);

      field.reset();
      expect(field.get(), 5);
      expect(field.isDirty, isFalse);
      expect(field.validationState, isA<ValidationPristine>());
    });

    test('commit moves the baseline rather than the value', () {
      final field = TomFormIntInput('qty', 5);
      field.setValue(9);
      field.commit();
      expect(field.get(), 9);
      expect(field.isDirty, isFalse);

      field.reset();
      expect(field.get(), 9, reason: 'reset falls back to the new baseline');
    });

    testWidgets('renders the bound value and writes typed digits back',
        (tester) async {
      final field = TomFormIntInput('qty', 5);
      await tester.pumpWidget(_app(field.widget));

      expect(find.text('5'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '42');
      expect(field.get(), 42);
      await _drainDebounce(tester);
    });

    testWidgets('a programmatic write reaches the text box', (tester) async {
      final field = TomFormIntInput('qty', 5);
      await tester.pumpWidget(_app(field.widget));

      field.setValue(77);
      await tester.pump();
      expect(_textFieldAt(tester, 0).controller!.text, '77');
      await _drainDebounce(tester);
    });

    testWidgets('an out-of-range entry is stored, not clamped', (tester) async {
      final field = TomFormIntInput('qty', 5, maxValue: 10);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '99');
      expect(field.get(), 99,
          reason: 'the user must see their typo to be able to fix it');
      expect(await field.validate(), isA<ValidationError>());
      await _drainDebounce(tester);
    });

    testWidgets('unparseable input leaves the last good value', (tester) async {
      final field = TomFormIntInput('qty', 5);
      await tester.pumpWidget(_app(field.widget));

      // The formatter allows only `-?\d*`, so '-' alone reaches `_onChanged`
      // and must not be read as a number.
      await tester.enterText(find.byType(TextField), '-');
      expect(field.get(), 5);
      await _drainDebounce(tester);
    });

    testWidgets('a read-only field is disabled and rejects input',
        (tester) async {
      final field = TomFormIntInput('qty', 5, uiStateController: _readOnly);
      await tester.pumpWidget(_app(field.widget));

      final textField = _textFieldAt(tester, 0);
      expect(textField.enabled, isFalse);
      expect(textField.onChanged, isNull);
    });

    testWidgets('the label comes from the resource bundle', (tester) async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'qty.label': 'Quantity'}),
      );
      final field = TomFormIntInput('qty', 5);
      expect(field.labelText, 'Quantity');

      await tester.pumpWidget(_app(field.widget));
      expect(find.text('Quantity'), findsOneWidget);
    });
  });

  // =========================================================================
  // TomFormIntSlider
  // =========================================================================

  group('TomFormIntSlider', () {
    test('the slider bounds double as the field bounds', () {
      final field = TomFormIntSlider('level', 3, min: 0, max: 10);
      expect(field.minValue, 0);
      expect(field.maxValue, 10);
      expect(field.validators, hasLength(2));
    });

    test('rejects a degenerate range', () {
      expect(() => TomFormIntSlider('level', 0, min: 5, max: 5),
          throwsA(isA<AssertionError>()));
    });

    testWidgets('divisions default to the span and the label shows the value',
        (tester) async {
      final field = TomFormIntSlider('level', 3, min: 0, max: 10);
      await tester.pumpWidget(_app(field.widget));

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.divisions, 10);
      expect(slider.label, '3');
      expect(slider.value, 3.0);
    });

    testWidgets('showValueLabel false drops the thumb label', (tester) async {
      final field =
          TomFormIntSlider('level', 3, min: 0, max: 10, showValueLabel: false);
      await tester.pumpWidget(_app(field.widget));
      expect(tester.widget<Slider>(find.byType(Slider)).label, isNull);
    });

    testWidgets('a value outside the range is clamped for display only',
        (tester) async {
      final field = TomFormIntSlider('level', 3, min: 0, max: 10);
      field.setValue(50);
      await tester.pumpWidget(_app(field.widget));

      expect(tester.widget<Slider>(find.byType(Slider)).value, 10.0,
          reason: 'the Slider asserts on out-of-range values');
      expect(field.get(), 50, reason: 'the field itself keeps the real value');
      await _drainDebounce(tester);
    });

    testWidgets('dragging rounds to an int', (tester) async {
      final field = TomFormIntSlider('level', 0, min: 0, max: 10);
      await tester.pumpWidget(_app(field.widget));

      tester.widget<Slider>(find.byType(Slider)).onChanged!(4.6);
      await tester.pump();
      expect(field.get(), 5);
      await _drainDebounce(tester);
    });

    testWidgets('a read-only field has no onChanged', (tester) async {
      final field = TomFormIntSlider('level', 3,
          min: 0, max: 10, uiStateController: _readOnly);
      await tester.pumpWidget(_app(field.widget));
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    });
  });

  // =========================================================================
  // TomFormIntStepper
  // =========================================================================

  group('TomFormIntStepper', () {
    testWidgets('the plus button advances by the step', (tester) async {
      final field = TomFormIntStepper('count', 4, step: 3);
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(field.get(), 7);
      expect(find.text('7'), findsOneWidget);
      await _drainDebounce(tester);
    });

    testWidgets('the minus button retreats by the step', (tester) async {
      final field = TomFormIntStepper('count', 4, step: 3);
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(field.get(), 1);
      await _drainDebounce(tester);
    });

    testWidgets('a bound disables the button that would overshoot it',
        (tester) async {
      final field =
          TomFormIntStepper('count', 9, step: 2, minValue: 0, maxValue: 10);
      await tester.pumpWidget(_app(field.widget));

      final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
      expect(buttons.first.onPressed, isNotNull, reason: '9 - 2 >= 0');
      expect(buttons.last.onPressed, isNull, reason: '9 + 2 > 10');
    });

    testWidgets('an unbounded stepper never disables a button',
        (tester) async {
      final field = TomFormIntStepper('count', 0);
      await tester.pumpWidget(_app(field.widget));

      for (final b in tester.widgetList<IconButton>(find.byType(IconButton))) {
        expect(b.onPressed, isNotNull);
      }
    });

    testWidgets('a read-only field disables both buttons', (tester) async {
      final field = TomFormIntStepper('count', 4, uiStateController: _readOnly);
      await tester.pumpWidget(_app(field.widget));

      for (final b in tester.widgetList<IconButton>(find.byType(IconButton))) {
        expect(b.onPressed, isNull);
      }
    });
  });

  // =========================================================================
  // TomFormDoubleInput
  // =========================================================================

  group('TomFormDoubleInput', () {
    testWidgets('decimals fix the rendered precision', (tester) async {
      final field = TomFormDoubleInput('rate', 1.5, decimals: 3);
      await tester.pumpWidget(_app(field.widget));
      expect(_textFieldAt(tester, 0).controller!.text, '1.500');
    });

    testWidgets('without decimals the value renders verbatim', (tester) async {
      final field = TomFormDoubleInput('rate', 1.5);
      await tester.pumpWidget(_app(field.widget));
      expect(_textFieldAt(tester, 0).controller!.text, '1.5');
    });

    testWidgets('typed text parses back into the bound double',
        (tester) async {
      final field = TomFormDoubleInput('rate', 1.5);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '2.25');
      expect(field.get(), 2.25);
      await _drainDebounce(tester);
    });

    testWidgets('a bare decimal point leaves the last good value',
        (tester) async {
      final field = TomFormDoubleInput('rate', 1.5);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '.');
      expect(field.get(), 1.5);
      await _drainDebounce(tester);
    });

    test('bounds desugar into validators here too', () async {
      final field =
          TomFormDoubleInput('rate', 0.5, minValue: 0.0, maxValue: 1.0);
      field.setValue(1.5);
      final result = await field.validate();
      expect((result as ValidationError).errorKey, 'error.max');
    });
  });

  // =========================================================================
  // CurrencyFormatProfile — the pure formatting core
  // =========================================================================

  group('CurrencyFormatProfile', () {
    test('an explicit code wins over the locale', () {
      final p = CurrencyFormatProfile.resolve(locale: 'de_DE', code: 'JPY');
      expect(p.symbol, '¥');
    });

    test('the region segment drives the currency', () {
      expect(CurrencyFormatProfile.resolve(locale: 'de_DE').symbol, '€');
      expect(CurrencyFormatProfile.resolve(locale: 'en_GB').symbol, '£');
      expect(CurrencyFormatProfile.resolve(locale: 'ja_JP').symbol, '¥');
      expect(CurrencyFormatProfile.resolve(locale: 'en_US').symbol, r'$');
    });

    test('a hyphenated tag is normalised like an underscored one', () {
      expect(CurrencyFormatProfile.resolve(locale: 'de-DE').symbol, '€');
    });

    test('a language-only tag falls back to the language table', () {
      expect(CurrencyFormatProfile.resolve(locale: 'fr').symbol, '€');
      expect(CurrencyFormatProfile.resolve(locale: 'ja').symbol, '¥');
    });

    test('an unknown locale falls back to USD', () {
      expect(CurrencyFormatProfile.resolve(locale: 'xx_XX').symbol, r'$');
      expect(CurrencyFormatProfile.resolve().symbol, r'$');
    });

    test('USD groups thousands and leads with the symbol', () {
      final p = CurrencyFormatProfile.resolve(code: 'USD');
      expect(p.format(1234567.5), r'$1,234,567.50');
      expect(p.format(-12.3), r'$-12.30');
    });

    test('EUR trails the symbol and swaps the separators', () {
      final p = CurrencyFormatProfile.resolve(code: 'EUR');
      expect(p.format(1234.5), '1.234,50 €');
    });

    test('JPY carries no decimals at all', () {
      final p = CurrencyFormatProfile.resolve(code: 'JPY');
      expect(p.format(1234.9), '¥1,235');
    });

    test('parse is the inverse of format for every profile', () {
      for (final code in const ['USD', 'EUR', 'GBP']) {
        final p = CurrencyFormatProfile.resolve(code: code);
        expect(p.parse(p.format(9876.54)), closeTo(9876.54, 1e-9),
            reason: '$code must round-trip');
      }
    });

    test('parse tolerates a typed-in symbol and rejects nonsense', () {
      final p = CurrencyFormatProfile.resolve(code: 'USD');
      expect(p.parse(r'$1,000.25'), 1000.25);
      expect(p.parse(''), isNull);
      expect(p.parse('abc'), isNull);
    });
  });

  // =========================================================================
  // TomFormCurrencyDoubleInput
  // =========================================================================

  group('TomFormCurrencyDoubleInput', () {
    testWidgets('a leading-symbol currency uses prefixText', (tester) async {
      final field =
          TomFormCurrencyDoubleInput('amount', 1234.5, currencyCode: 'USD');
      expect(field.symbolIsLeading, isTrue);

      await tester.pumpWidget(_app(field.widget));
      final decoration = _textFieldAt(tester, 0).decoration!;
      expect(decoration.prefixText, r'$');
      expect(decoration.suffixText, isNull);
      expect(_textFieldAt(tester, 0).controller!.text, '1,234.50',
          reason: 'the symbol lives outside the editable text');
    });

    testWidgets('a trailing-symbol currency uses suffixText', (tester) async {
      final field =
          TomFormCurrencyDoubleInput('amount', 1234.5, currencyCode: 'EUR');
      expect(field.symbolIsLeading, isFalse);

      await tester.pumpWidget(_app(field.widget));
      final decoration = _textFieldAt(tester, 0).decoration!;
      expect(decoration.suffixText, '€');
      expect(decoration.prefixText, isNull);
      expect(_textFieldAt(tester, 0).controller!.text, '1.234,50');
    });

    testWidgets('typing a grouped amount parses back into the double',
        (tester) async {
      final field =
          TomFormCurrencyDoubleInput('amount', 0, currencyCode: 'USD');
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '2,500.75');
      expect(field.get(), 2500.75);
      await _drainDebounce(tester);
    });

    testWidgets('unparseable input leaves the last good value',
        (tester) async {
      final field =
          TomFormCurrencyDoubleInput('amount', 42.0, currencyCode: 'USD');
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), 'abc');
      expect(field.get(), 42.0);
      await _drainDebounce(tester);
    });
  });

  // =========================================================================
  // TomFormPercentDoubleInput
  // =========================================================================

  group('TomFormPercentDoubleInput', () {
    test('the field is fixed to the 0..1 fraction range', () {
      final field = TomFormPercentDoubleInput('share', 0.25);
      expect(field.minValue, 0.0);
      expect(field.maxValue, 1.0);
    });

    testWidgets('a fraction is displayed as a percent with a % suffix',
        (tester) async {
      final field = TomFormPercentDoubleInput('share', 0.1234, decimals: 2);
      await tester.pumpWidget(_app(field.widget));

      expect(_textFieldAt(tester, 0).controller!.text, '12.34');
      expect(_textFieldAt(tester, 0).decoration!.suffixText, '%');
    });

    testWidgets('a typed percent is stored as a fraction', (tester) async {
      final field = TomFormPercentDoubleInput('share', 0.0);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '75');
      expect(field.get(), closeTo(0.75, 1e-9));
      await _drainDebounce(tester);
    });

    testWidgets('over 100 % is stored and reported, not clamped',
        (tester) async {
      final field = TomFormPercentDoubleInput('share', 0.0);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField), '150');
      expect(field.get(), closeTo(1.5, 1e-9));
      expect(await field.validate(), isA<ValidationError>());
      await _drainDebounce(tester);
    });
  });

  // =========================================================================
  // TomFormDoubleSlider
  // =========================================================================

  group('TomFormDoubleSlider', () {
    testWidgets('the thumb label honours valueLabelDecimals', (tester) async {
      final field = TomFormDoubleSlider('gain', 0.5,
          min: 0, max: 1, valueLabelDecimals: 3);
      await tester.pumpWidget(_app(field.widget));
      expect(tester.widget<Slider>(find.byType(Slider)).label, '0.500');
    });

    testWidgets('an out-of-range value is clamped for display only',
        (tester) async {
      final field = TomFormDoubleSlider('gain', 0.5, min: 0, max: 1);
      field.setValue(4.0);
      await tester.pumpWidget(_app(field.widget));

      expect(tester.widget<Slider>(find.byType(Slider)).value, 1.0);
      expect(field.get(), 4.0);
      await _drainDebounce(tester);
    });

    testWidgets('dragging writes the raw double through', (tester) async {
      final field = TomFormDoubleSlider('gain', 0.0, min: 0, max: 1);
      await tester.pumpWidget(_app(field.widget));

      tester.widget<Slider>(find.byType(Slider)).onChanged!(0.42);
      await tester.pump();
      expect(field.get(), 0.42);
      await _drainDebounce(tester);
    });
  });

  // =========================================================================
  // NumRange
  // =========================================================================

  group('NumRange', () {
    test('equality is by endpoints so observers see real movement only', () {
      expect(const NumRange<int>(1, 5), const NumRange<int>(1, 5));
      expect(const NumRange<int>(1, 5).hashCode,
          const NumRange<int>(1, 5).hashCode);
      expect(const NumRange<int>(1, 5), isNot(const NumRange<int>(1, 6)));
    });

    test('the type parameter is part of the identity', () {
      expect(const NumRange<int>(1, 5) == const NumRange<double>(1, 5), isFalse,
          reason: 'an int range and a double range are different values');
    });

    test('toString renders the pair', () {
      expect(const NumRange<int>(1, 5).toString(), '(1, 5)');
    });
  });

  // =========================================================================
  // TomFormIntRangeSlider
  // =========================================================================

  group('TomFormIntRangeSlider', () {
    test('rejects a degenerate range', () {
      expect(
        () => TomFormIntRangeSlider('band', const NumRange<int>(1, 2),
            min: 5, max: 5),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('renders both endpoints and defaults divisions to the span',
        (tester) async {
      final field = TomFormIntRangeSlider('band', const NumRange<int>(2, 8),
          min: 0, max: 10);
      await tester.pumpWidget(_app(field.widget));

      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      expect(slider.values, const RangeValues(2, 8));
      expect(slider.divisions, 10);
      expect(slider.labels, const RangeLabels('2', '8'));
    });

    testWidgets('endpoints outside the range are clamped for display',
        (tester) async {
      final field = TomFormIntRangeSlider('band', const NumRange<int>(-5, 50),
          min: 0, max: 10);
      await tester.pumpWidget(_app(field.widget));

      expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).values,
          const RangeValues(0, 10));
      expect(field.get(), const NumRange<int>(-5, 50));
    });

    testWidgets('dragging rounds both endpoints to ints', (tester) async {
      final field = TomFormIntRangeSlider('band', const NumRange<int>(2, 8),
          min: 0, max: 10);
      await tester.pumpWidget(_app(field.widget));

      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
        const RangeValues(3.4, 7.6),
      );
      await tester.pump();
      expect(field.get(), const NumRange<int>(3, 8));
      await _drainDebounce(tester);
    });

    testWidgets('a read-only field has no onChanged', (tester) async {
      final field = TomFormIntRangeSlider('band', const NumRange<int>(2, 8),
          min: 0, max: 10, uiStateController: _readOnly);
      await tester.pumpWidget(_app(field.widget));
      expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged,
          isNull);
    });
  });

  // =========================================================================
  // TomFormDoubleRangeSlider
  // =========================================================================

  group('TomFormDoubleRangeSlider', () {
    testWidgets('labels honour valueLabelDecimals', (tester) async {
      final field = TomFormDoubleRangeSlider(
        'band',
        const NumRange<double>(0.25, 0.75),
        min: 0,
        max: 1,
        valueLabelDecimals: 1,
      );
      await tester.pumpWidget(_app(field.widget));

      expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).labels,
          const RangeLabels('0.3', '0.8'));
    });

    testWidgets('dragging writes the raw doubles through', (tester) async {
      final field = TomFormDoubleRangeSlider(
        'band',
        const NumRange<double>(0.25, 0.75),
        min: 0,
        max: 1,
      );
      await tester.pumpWidget(_app(field.widget));

      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
        const RangeValues(0.1, 0.9),
      );
      await tester.pump();
      expect(field.get(), const NumRange<double>(0.1, 0.9));
      await _drainDebounce(tester);
    });
  });

  // =========================================================================
  // TomFormDurationInput
  // =========================================================================

  group('TomFormDurationInput', () {
    testWidgets('seeds an hours box and a zero-padded minutes box',
        (tester) async {
      final field = TomFormDurationInput(
          'span', const Duration(hours: 2, minutes: 5));
      await tester.pumpWidget(_app(field.widget));

      expect(_textFieldAt(tester, 0).controller!.text, '2');
      expect(_textFieldAt(tester, 1).controller!.text, '05');
    });

    testWidgets('hours accumulate past a day rather than wrapping',
        (tester) async {
      final field =
          TomFormDurationInput('span', const Duration(days: 1, hours: 3));
      await tester.pumpWidget(_app(field.widget));
      expect(_textFieldAt(tester, 0).controller!.text, '27');
    });

    testWidgets('editing a segment recomposes the whole Duration',
        (tester) async {
      final field = TomFormDurationInput(
          'span', const Duration(hours: 2, minutes: 5));
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField).at(1), '45');
      expect(field.get(), const Duration(hours: 2, minutes: 45));
      await _drainDebounce(tester);
    });

    testWidgets('minutes above 59 clamp — the widget cannot express them',
        (tester) async {
      final field = TomFormDurationInput('span', Duration.zero);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField).at(1), '99');
      expect(field.get(), const Duration(minutes: 59));
      await _drainDebounce(tester);
    });

    testWidgets('hours clamp at maxHours', (tester) async {
      final field = TomFormDurationInput('span', Duration.zero, maxHours: 8);
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField).at(0), '20');
      expect(field.get(), const Duration(hours: 8));
      await _drainDebounce(tester);
    });

    testWidgets('an emptied segment reads as zero', (tester) async {
      final field = TomFormDurationInput(
          'span', const Duration(hours: 2, minutes: 5));
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(TextField).at(0), '');
      expect(field.get(), const Duration(minutes: 5));
      await _drainDebounce(tester);
    });

    testWidgets('a programmatic write reaches both boxes', (tester) async {
      final field = TomFormDurationInput('span', Duration.zero);
      await tester.pumpWidget(_app(field.widget));

      field.setValue(const Duration(hours: 4, minutes: 7));
      await tester.pump();
      expect(_textFieldAt(tester, 0).controller!.text, '4');
      expect(_textFieldAt(tester, 1).controller!.text, '07');
      await _drainDebounce(tester);
    });

    testWidgets('a read-only field disables both segments', (tester) async {
      final field = TomFormDurationInput('span', Duration.zero,
          uiStateController: _readOnly);
      await tester.pumpWidget(_app(field.widget));

      expect(_textFieldAt(tester, 0).enabled, isFalse);
      expect(_textFieldAt(tester, 1).enabled, isFalse);
    });
  });

  // =========================================================================
  // TomFormIntFilterChips
  // =========================================================================

  group('TomFormIntFilterChips', () {
    TomSelectableSource<int> years() => StaticSelectableSource<int>(const [
          SelectableItem(value: 2023, label: '2023'),
          SelectableItem(value: 2024, label: '2024'),
          SelectableItem(value: 2025, label: '2025'),
        ]);

    test('toggleItem allocates a fresh list so change detection fires', () {
      final field =
          TomFormIntFilterChips('years', const [2023], source: years());
      final before = field.get();

      field.toggleItem(2024, true);
      expect(field.get(), [2023, 2024]);
      expect(identical(field.get(), before), isFalse);

      field.toggleItem(2023, false);
      expect(field.get(), [2024]);
    });

    test('toggleItem is idempotent in both directions', () {
      final field =
          TomFormIntFilterChips('years', const [2023], source: years());
      field.toggleItem(2023, true);
      expect(field.get(), [2023]);
      field.toggleItem(2099, false);
      expect(field.get(), [2023]);
    });

    testWidgets('renders one chip per item with the right selection',
        (tester) async {
      final field =
          TomFormIntFilterChips('years', const [2024], source: years());
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      expect(chips, hasLength(3));
      expect(chips.map((c) => c.selected), [false, true, false]);
    });

    testWidgets('tapping a chip toggles it into the selection',
        (tester) async {
      final field =
          TomFormIntFilterChips('years', const [], source: years());
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2025'));
      await tester.pump();
      expect(field.get(), [2025]);
      await _drainDebounce(tester);
    });

    testWidgets('a selection the source no longer offers is pruned',
        (tester) async {
      final field = TomFormIntFilterChips(
        'years',
        const [2024, 1999],
        source: years(),
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      expect(field.get(), [2024]);
      await _drainDebounce(tester);
    });

    testWidgets('a read-only field renders chips that cannot be selected',
        (tester) async {
      final field = TomFormIntFilterChips('years', const [],
          source: years(), uiStateController: _readOnly);
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      for (final c in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
        expect(c.onSelected, isNull);
      }
    });
  });
}
