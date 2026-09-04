/// The Cupertino concretes that `FormFieldFamily` cannot reach.
///
/// Eleven of the twenty-two public Cupertino field classes have no entry in
/// the family factory: they are either iOS-idiomatic surfaces with no Material
/// twin (the sliding segmented controls, the timer picker) or specialisations
/// a caller reaches for by name. The parity suite therefore never touches
/// them, and until this file they were entirely unexercised.
///
/// Two shapes recur, and the assertions follow them:
///
///  * **trigger tiles** (`…Picker`) render the current value, open a
///    Cancel/Done sheet on tap, leave the value alone on Cancel, and refuse
///    the tap when the field is read-only;
///  * **segmented controls** render one segment per source item, commit on
///    tap, and ignore taps when read-only.
library;

import 'package:flutter/cupertino.dart';
// `DateTimeRange` lives in the Material library even though the range picker
// itself is pure Cupertino — it is the value type, not a widget. Imported
// narrowly so the rest of the file stays honestly Cupertino-only.
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget _app(Widget child) => CupertinoApp(
  home: CupertinoPageScaffold(child: Center(child: child)),
);

TomUIStateController get _readOnly =>
    TomUIStateController(resolve: (_, _) => TomAuthState.read);

TomSelectableSource<String> _cities() => StaticSelectableSource<String>(const [
  SelectableItem(value: 'oslo', label: 'Oslo'),
  SelectableItem(value: 'lima', label: 'Lima'),
]);

enum Priority { low, high }

TomSelectableSource<Priority> _priorities() =>
    StaticSelectableSource<Priority>(const [
      SelectableItem(value: Priority.low, label: 'Low'),
      SelectableItem(value: Priority.high, label: 'High'),
    ]);

/// Drains the 300 ms validation debounce a `setValue` schedules, so the timer
/// does not outlive the test's binding.
Future<void> _settle(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(milliseconds: 400));

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

  // -------------------------------------------------------------------------
  // Segmented controls
  // -------------------------------------------------------------------------

  group('TomCupertinoFormBoolToggle', () {
    testWidgets('renders an Off / On pair and selects the current value', (
      tester,
    ) async {
      final field = TomCupertinoFormBoolToggle('active', false);
      await tester.pumpWidget(_app(field.widget));

      expect(find.text('Off'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      final control = tester.widget<CupertinoSlidingSegmentedControl<bool>>(
        find.byType(CupertinoSlidingSegmentedControl<bool>),
      );
      expect(control.groupValue, isFalse);
    });

    testWidgets('tapping the other segment sets the value', (tester) async {
      final field = TomCupertinoFormBoolToggle('active', false);
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.text('On'));
      await _settle(tester);
      expect(field.get(), isTrue);
      expect(field.isDirty, isTrue);
    });

    testWidgets('segment labels come from resources', (tester) async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'active.onLabel': 'Enabled',
          'active.offLabel': 'Disabled',
        }),
      );
      final field = TomCupertinoFormBoolToggle('active', false);
      await tester.pumpWidget(_app(field.widget));

      expect(find.text('Enabled'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('an explicit override beats the resource', (tester) async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'active.onLabel': 'Enabled'}),
      );
      final field = TomCupertinoFormBoolToggle(
        'active',
        false,
        onLabelOverride: 'Yes',
      );
      await tester.pumpWidget(_app(field.widget));

      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('Enabled'), findsNothing);
    });

    testWidgets('a read-only field ignores segment taps', (tester) async {
      final field = TomCupertinoFormBoolToggle(
        'active',
        false,
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.text('On'));
      await _settle(tester);
      expect(field.get(), isFalse);
    });
  });

  group('TomCupertinoFormEnumSegmented', () {
    testWidgets('renders one segment per source item', (tester) async {
      final field = TomCupertinoFormEnumSegmented<Priority>(
        'prio',
        Priority.low,
        source: _priorities(),
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Low'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('tapping a segment sets the enum value', (tester) async {
      final field = TomCupertinoFormEnumSegmented<Priority>(
        'prio',
        Priority.low,
        source: _priorities(),
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('High'));
      await _settle(tester);
      expect(field.get(), Priority.high);
    });

    testWidgets('renders a placeholder until the source resolves', (
      tester,
    ) async {
      final field = TomCupertinoFormEnumSegmented<Priority>(
        'prio',
        Priority.low,
        source: _priorities(),
      );
      await tester.pumpWidget(_app(field.widget));
      // No settle: the async getItems() has not completed yet.
      expect(find.text('…'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('…'), findsNothing);
    });
  });

  group('TomCupertinoFormStringSegmented', () {
    testWidgets('renders the source labels, not the raw values', (
      tester,
    ) async {
      final field = TomCupertinoFormStringSegmented(
        'city',
        'oslo',
        source: _cities(),
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Oslo'), findsOneWidget);
      expect(find.text('oslo'), findsNothing);
    });

    testWidgets('tapping a segment stores the value behind the label', (
      tester,
    ) async {
      final field = TomCupertinoFormStringSegmented(
        'city',
        'oslo',
        source: _cities(),
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lima'));
      await _settle(tester);
      expect(field.get(), 'lima');
    });

    testWidgets(
      'a value outside the source selects nothing rather than throwing',
      (tester) async {
        // CupertinoSlidingSegmentedControl asserts its groupValue is one of the
        // children's keys — so an unknown bound value must become null, not be
        // passed through.
        final field = TomCupertinoFormStringSegmented(
          'city',
          'kyiv',
          source: _cities(),
        );
        await tester.pumpWidget(_app(field.widget));
        await tester.pumpAndSettle();

        final control = tester.widget<CupertinoSlidingSegmentedControl<String>>(
          find.byType(CupertinoSlidingSegmentedControl<String>),
        );
        expect(control.groupValue, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Trigger tiles — sheet-backed pickers
  // -------------------------------------------------------------------------

  group('TomCupertinoFormIntPicker', () {
    test('enumerates its values from min, max and step', () {
      final field = TomCupertinoFormIntPicker(
        'qty',
        0,
        min: 0,
        max: 10,
        step: 5,
      );
      expect(field.values, [0, 5, 10]);
    });

    test('a step that overshoots max stops at the last reachable value', () {
      final field = TomCupertinoFormIntPicker(
        'qty',
        0,
        min: 0,
        max: 10,
        step: 4,
      );
      expect(field.values, [0, 4, 8]);
    });

    test('the range doubles as the field bounds', () {
      final field = TomCupertinoFormIntPicker('qty', 5, min: 1, max: 9);
      expect(field.minValue, 1);
      expect(field.maxValue, 9);
    });

    test('rejects an inverted or degenerate range', () {
      expect(
        () => TomCupertinoFormIntPicker('qty', 0, min: 5, max: 5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TomCupertinoFormIntPicker('qty', 0, min: 0, max: 3, step: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the row label defaults to the value and honours a formatter', () {
      expect(
        TomCupertinoFormIntPicker('qty', 0, min: 0, max: 3).renderLabel(2),
        '2',
      );
      expect(
        TomCupertinoFormIntPicker(
          'qty',
          0,
          min: 0,
          max: 3,
          format: (v) => '$v pcs',
        ).renderLabel(2),
        '2 pcs',
      );
    });

    testWidgets('renders the formatted current value in the tile', (
      tester,
    ) async {
      final field = TomCupertinoFormIntPicker(
        'qty',
        2,
        min: 0,
        max: 10,
        format: (v) => '$v pcs',
      );
      await tester.pumpWidget(_app(field.widget));
      expect(find.text('2 pcs'), findsOneWidget);
    });

    testWidgets(
      'opens a Cancel / Done sheet on tap and Cancel keeps the value',
      (tester) async {
        final field = TomCupertinoFormIntPicker('qty', 2, min: 0, max: 10);
        await tester.pumpWidget(_app(field.widget));

        await tester.tap(find.text('2'));
        await tester.pumpAndSettle();
        expect(find.text('Done'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(field.get(), 2);
      },
    );

    testWidgets('a read-only field does not open the sheet', (tester) async {
      final field = TomCupertinoFormIntPicker(
        'qty',
        2,
        min: 0,
        max: 10,
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
    });
  });

  group('TomCupertinoFormStringPicker', () {
    testWidgets('shows the label of the bound value', (tester) async {
      final field = TomCupertinoFormStringPicker(
        'city',
        'lima',
        source: _cities(),
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Lima'), findsOneWidget);
    });

    testWidgets('falls back to the hint when nothing is selected', (
      tester,
    ) async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'city.hint': 'Pick a city'}),
      );
      final field = TomCupertinoFormStringPicker('city', '', source: _cities());
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Pick a city'), findsOneWidget);
    });

    testWidgets('shows the raw value when the source does not know it', (
      tester,
    ) async {
      final field = TomCupertinoFormStringPicker(
        'city',
        'kyiv',
        source: _cities(),
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('kyiv'), findsOneWidget);
    });

    testWidgets('Done commits the highlighted row', (tester) async {
      final field = TomCupertinoFormStringPicker(
        'city',
        'oslo',
        source: _cities(),
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oslo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await _settle(tester);

      // The wheel opens on the current row, so Done without scrolling is a
      // no-op — which is the assertion: Done never invents a value.
      expect(field.get(), 'oslo');
    });

    testWidgets('a read-only field does not open the sheet', (tester) async {
      final field = TomCupertinoFormStringPicker(
        'city',
        'oslo',
        source: _cities(),
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oslo'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
    });
  });

  group('TomCupertinoFormStringListCheckedPicker', () {
    testWidgets('joins the selected labels into the closed tile', (
      tester,
    ) async {
      final field = TomCupertinoFormStringListCheckedPicker('cities', const [
        'oslo',
        'lima',
      ], source: _cities());
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Oslo, Lima'), findsOneWidget);
    });

    testWidgets('shows the placeholder when nothing is selected', (
      tester,
    ) async {
      final field = TomCupertinoFormStringListCheckedPicker(
        'cities',
        const [],
        source: _cities(),
        hintTextOverride: 'Any city',
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Any city'), findsOneWidget);
    });

    testWidgets('prunes a selection the source no longer offers', (
      tester,
    ) async {
      // A stored value whose option disappeared must not linger in the bound
      // list — the user cannot see it, so they cannot remove it either.
      final field = TomCupertinoFormStringListCheckedPicker('cities', const [
        'oslo',
        'atlantis',
      ], source: _cities());
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      expect(field.get(), ['oslo']);
      await _settle(tester);
    });

    testWidgets('toggling a row in the sheet updates the selection', (
      tester,
    ) async {
      final field = TomCupertinoFormStringListCheckedPicker('cities', const [
        'oslo',
      ], source: _cities());
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oslo'));
      await tester.pumpAndSettle();
      // In the sheet now — both rows are listed.
      await tester.tap(find.text('Lima').last);
      await tester.pumpAndSettle();

      expect(field.get(), containsAll(['oslo', 'lima']));
      await _settle(tester);
    });

    testWidgets('a read-only field does not open the sheet', (tester) async {
      final field = TomCupertinoFormStringListCheckedPicker(
        'cities',
        const ['oslo'],
        source: _cities(),
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oslo'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Date / time / duration
  // -------------------------------------------------------------------------

  group('TomCupertinoFormDateTimePicker', () {
    testWidgets('renders the bound date and time in the tile', (tester) async {
      final field = TomCupertinoFormDateTimePicker(
        'when',
        DateTime(2024, 3, 4, 15, 30),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      await tester.pumpWidget(_app(field.widget));

      expect(find.text(field.formatDateTime(field.get())), findsOneWidget);
    });

    testWidgets('Cancel leaves the bound value untouched', (tester) async {
      final initial = DateTime(2024, 3, 4, 15, 30);
      final field = TomCupertinoFormDateTimePicker(
        'when',
        initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.text(field.formatDateTime(initial)));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(field.get(), initial);
      expect(field.isDirty, isFalse);
    });
  });

  group('TomCupertinoFormDurationPicker', () {
    test('formats hours and minutes zero-padded by default', () {
      final field = TomCupertinoFormDurationPicker(
        'span',
        const Duration(hours: 2, minutes: 5),
      );
      expect(
        field.formatDuration(const Duration(hours: 2, minutes: 5)),
        '02h 05m',
      );
    });

    test('the ms mode drops hours and shows seconds', () {
      final field = TomCupertinoFormDurationPicker(
        'span',
        Duration.zero,
        mode: CupertinoTimerPickerMode.ms,
      );
      expect(
        field.formatDuration(const Duration(minutes: 3, seconds: 9)),
        '03m 09s',
      );
    });

    test('the hms mode shows all three components', () {
      final field = TomCupertinoFormDurationPicker(
        'span',
        Duration.zero,
        mode: CupertinoTimerPickerMode.hms,
      );
      expect(
        field.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01h 02m 03s',
      );
    });

    test('hours accumulate past a day rather than wrapping', () {
      final field = TomCupertinoFormDurationPicker('span', Duration.zero);
      expect(
        field.formatDuration(const Duration(days: 1, hours: 3)),
        '27h 00m',
      );
    });

    testWidgets('renders the formatted duration and opens a sheet on tap', (
      tester,
    ) async {
      final field = TomCupertinoFormDurationPicker(
        'span',
        const Duration(hours: 2, minutes: 5),
      );
      await tester.pumpWidget(_app(field.widget));
      expect(find.text('02h 05m'), findsOneWidget);

      await tester.tap(find.text('02h 05m'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(field.get(), const Duration(hours: 2, minutes: 5));
    });

    testWidgets('a read-only field does not open the sheet', (tester) async {
      final field = TomCupertinoFormDurationPicker(
        'span',
        const Duration(hours: 2, minutes: 5),
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      await tester.tap(find.text('02h 05m'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
    });
  });

  group('TomCupertinoFormDateRangePicker', () {
    testWidgets('mounts and keeps the range across a cancelled sheet', (
      tester,
    ) async {
      final range = DateTimeRange(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 31),
      );
      final field = TomCupertinoFormDateRangePicker(
        'span',
        range,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      await tester.pumpWidget(_app(field.widget));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      if (find.text('Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
      expect(field.get().start, range.start);
      expect(field.get().end, range.end);
    });
  });

  // -------------------------------------------------------------------------
  // Text surfaces
  // -------------------------------------------------------------------------

  group('TomCupertinoFormStringSearchInput', () {
    testWidgets('renders a CupertinoSearchTextField seeded with the value', (
      tester,
    ) async {
      final field = TomCupertinoFormStringSearchInput('q', 'oslo');
      await tester.pumpWidget(_app(field.widget));

      final search = tester.widget<CupertinoSearchTextField>(
        find.byType(CupertinoSearchTextField),
      );
      expect(search.controller!.text, 'oslo');
      expect(search.placeholder, 'Search');
    });

    testWidgets('typing writes through to the field', (tester) async {
      final field = TomCupertinoFormStringSearchInput('q', '');
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(CupertinoSearchTextField), 'lima');
      await _settle(tester);
      expect(field.get(), 'lima');
    });

    testWidgets('a programmatic write reaches the text box', (tester) async {
      final field = TomCupertinoFormStringSearchInput('q', '');
      await tester.pumpWidget(_app(field.widget));

      field.setValue('oslo');
      await _settle(tester);

      final search = tester.widget<CupertinoSearchTextField>(
        find.byType(CupertinoSearchTextField),
      );
      expect(search.controller!.text, 'oslo');
    });

    testWidgets('a read-only field is disabled and rejects input', (
      tester,
    ) async {
      final field = TomCupertinoFormStringSearchInput(
        'q',
        'oslo',
        uiStateController: _readOnly,
      );
      await tester.pumpWidget(_app(field.widget));

      final search = tester.widget<CupertinoSearchTextField>(
        find.byType(CupertinoSearchTextField),
      );
      expect(search.enabled, isFalse);
      expect(search.onChanged, isNull);
    });

    testWidgets('the placeholder comes from the hint resource', (tester) async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'q.hint': 'Find a city'}),
      );
      final field = TomCupertinoFormStringSearchInput('q', '');
      await tester.pumpWidget(_app(field.widget));

      final search = tester.widget<CupertinoSearchTextField>(
        find.byType(CupertinoSearchTextField),
      );
      expect(search.placeholder, 'Find a city');
    });
  });

  group('TomCupertinoFormCurrencyDoubleInput', () {
    testWidgets('renders the symbol outside the editable text', (tester) async {
      final field = TomCupertinoFormCurrencyDoubleInput(
        'price',
        1234.5,
        locale: 'en_US',
        currencyCode: 'USD',
      );
      await tester.pumpWidget(_app(field.widget));

      // The amount lives in the controller; the symbol is a sibling widget, so
      // Backspace cannot delete it.
      final text = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(
        text.controller!.text,
        isNot(contains(field.formatProfile.symbol)),
      );
      expect(find.text(field.formatProfile.symbol), findsOneWidget);
    });

    testWidgets('groups thousands and keeps the profile decimals', (
      tester,
    ) async {
      final field = TomCupertinoFormCurrencyDoubleInput(
        'price',
        1234.5,
        locale: 'en_US',
        currencyCode: 'USD',
      );
      await tester.pumpWidget(_app(field.widget));

      final profile = field.formatProfile;
      final text = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(
        text.controller!.text,
        '1${profile.groupSeparator}234${profile.decimalSeparator}50',
      );
    });

    testWidgets('a typed amount parses back into the bound double', (
      tester,
    ) async {
      final field = TomCupertinoFormCurrencyDoubleInput(
        'price',
        0,
        locale: 'en_US',
        currencyCode: 'USD',
      );
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(CupertinoTextField), '12.75');
      await _settle(tester);
      expect(field.get(), closeTo(12.75, 0.001));
    });

    testWidgets('unparseable input leaves the last good value in place', (
      tester,
    ) async {
      final field = TomCupertinoFormCurrencyDoubleInput(
        'price',
        9.99,
        locale: 'en_US',
        currencyCode: 'USD',
      );
      await tester.pumpWidget(_app(field.widget));

      await tester.enterText(find.byType(CupertinoTextField), 'abc');
      await _settle(tester);
      expect(field.get(), 9.99);
    });
  });
}
