import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget _wrap(Widget child, {TomFormStyle? style}) {
  return MaterialApp(
    home: Scaffold(
      body: style != null
          ? TomFormStyleScope(style: style, child: child)
          : child,
    ),
  );
}

TomSelectableSource<String> _threeOptions() => StaticSelectableSource([
      const SelectableItem(value: 'a', label: 'Apple'),
      const SelectableItem(value: 'b', label: 'Banana'),
      const SelectableItem(value: 'c', label: 'Cherry'),
    ]);

void main() {
  // -------------------------------------------------------------------------
  // TomFormBoolField family
  // -------------------------------------------------------------------------

  group('TomFormBoolCheckbox', () {
    test('initial value and setValue round-trip', () {
      final field = TomFormBoolCheckbox('accept', false);
      expect(field.get(), isFalse);
      field.setValue(true);
      expect(field.get(), isTrue);
      expect(field.isDirty, isTrue);
    });

    testWidgets('renders a Checkbox mirroring the value', (tester) async {
      final field = TomFormBoolCheckbox(
        'accept',
        true,
        labelTextOverride: 'Accept',
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isTrue);
      expect(find.text('Accept'), findsOneWidget);
    });

    testWidgets('tapping toggles value', (tester) async {
      final field = TomFormBoolCheckbox('accept', false);
      await tester.pumpWidget(_wrap(field.widget));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(field.get(), isTrue);
      field.dispose();
    });
  });

  group('TomFormBoolSwitch', () {
    test('setValue updates observable', () {
      final field = TomFormBoolSwitch('notify', false);
      field.setValue(true);
      expect(field.get(), isTrue);
    });

    testWidgets('renders Material Switch', (tester) async {
      final field = TomFormBoolSwitch(
        'notify',
        false,
        labelTextOverride: 'Notify',
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('TomFormBoolToggle', () {
    test('on/off label overrides', () {
      final field = TomFormBoolToggle(
        'mode',
        true,
        onLabelOverride: 'Enabled',
        offLabelOverride: 'Disabled',
      );
      expect(field.onLabel, 'Enabled');
      expect(field.offLabel, 'Disabled');
    });

    testWidgets('renders a two-segment SegmentedButton', (tester) async {
      final field = TomFormBoolToggle(
        'mode',
        true,
        onLabelOverride: 'On',
        offLabelOverride: 'Off',
        labelTextOverride: 'Mode',
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // TomFormStringField single-select concretes
  // -------------------------------------------------------------------------

  group('TomFormStringSegmented', () {
    test('setValue updates value', () {
      final field = TomFormStringSegmented(
        'fruit',
        'a',
        source: _threeOptions(),
      );
      field.setValue('b');
      expect(field.get(), 'b');
    });

    testWidgets('renders SegmentedButton with source items', (tester) async {
      final field = TomFormStringSegmented(
        'fruit',
        'a',
        source: _threeOptions(),
        labelTextOverride: 'Fruit',
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Cherry'), findsOneWidget);
    });
  });

  group('TomFormStringRadioGroup', () {
    testWidgets('renders one Radio per item', (tester) async {
      final field = TomFormStringRadioGroup(
        'fruit',
        'a',
        source: _threeOptions(),
        labelTextOverride: 'Fruit',
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(Radio<String>), findsNWidgets(3));
    });

    testWidgets('tapping a row sets the value', (tester) async {
      final field = TomFormStringRadioGroup(
        'fruit',
        'a',
        source: _threeOptions(),
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Banana'));
      await tester.pump();

      expect(field.get(), 'b');
      field.dispose();
    });
  });

  group('TomFormStringChoiceChips', () {
    testWidgets('renders ChoiceChip per item with correct selection',
        (tester) async {
      final field = TomFormStringChoiceChips(
        'fruit',
        'b',
        source: _threeOptions(),
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      final chips =
          tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.length, 3);
      // Banana chip is selected.
      final bananaChip = chips.firstWhere((c) {
        final label = c.label;
        return label is Text && label.data == 'Banana';
      });
      expect(bananaChip.selected, isTrue);
    });

    testWidgets('tapping a chip selects it', (tester) async {
      final field = TomFormStringChoiceChips(
        'fruit',
        'a',
        source: _threeOptions(),
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cherry'));
      await tester.pump();

      expect(field.get(), 'c');
      field.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // TomFormStringListField — multi-select
  // -------------------------------------------------------------------------

  group('TomFormStringFilterChips', () {
    test('toggleItem adds and removes values', () {
      final field = TomFormStringFilterChips(
        'fruits',
        const [],
        source: _threeOptions(),
      );
      field.toggleItem('a', true);
      field.toggleItem('b', true);
      expect(field.get(), ['a', 'b']);

      field.toggleItem('a', false);
      expect(field.get(), ['b']);
    });

    test('toggleItem true is idempotent', () {
      final field = TomFormStringFilterChips(
        'fruits',
        const ['a'],
        source: _threeOptions(),
      );
      field.toggleItem('a', true);
      expect(field.get(), ['a']);
    });

    testWidgets('renders FilterChip per item', (tester) async {
      final field = TomFormStringFilterChips(
        'fruits',
        const ['a'],
        source: _threeOptions(),
        labelTextOverride: 'Fruits',
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(FilterChip), findsNWidgets(3));
    });

    testWidgets('tapping a chip adds it to selection', (tester) async {
      final field = TomFormStringFilterChips(
        'fruits',
        const [],
        source: _threeOptions(),
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Banana'));
      await tester.pump();
      expect(field.get(), ['b']);

      await tester.tap(find.text('Cherry'));
      await tester.pump();
      expect(field.get(), ['b', 'c']);
      field.dispose();
    });
  });

  group('TomFormStringMultiCheckbox', () {
    test('toggleItem produces a fresh list', () {
      final field = TomFormStringMultiCheckbox(
        'fruits',
        const ['a'],
        source: _threeOptions(),
      );
      final before = field.get();
      field.toggleItem('b', true);
      final after = field.get();
      expect(after, ['a', 'b']);
      expect(identical(before, after), isFalse);
    });

    testWidgets('renders one Checkbox per item with correct state',
        (tester) async {
      final field = TomFormStringMultiCheckbox(
        'fruits',
        const ['a', 'c'],
        source: _threeOptions(),
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      final boxes =
          tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes.length, 3);
      // Apple checked, Banana unchecked, Cherry checked (in source order).
      expect(boxes[0].value, isTrue);
      expect(boxes[1].value, isFalse);
      expect(boxes[2].value, isTrue);
    });

    testWidgets('tapping a row toggles selection', (tester) async {
      final field = TomFormStringMultiCheckbox(
        'fruits',
        const [],
        source: _threeOptions(),
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Banana'));
      await tester.pump();
      expect(field.get(), ['b']);

      await tester.tap(find.text('Banana'));
      await tester.pump();
      expect(field.get(), isEmpty);
      field.dispose();
    });
  });
}
