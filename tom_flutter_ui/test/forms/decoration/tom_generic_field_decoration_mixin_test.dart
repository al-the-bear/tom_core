/// The label and description anatomy of [TomGenericFieldDecorationMixin].
///
/// The mixin is applied *on top of* a field base that already resolves
/// `labelText` — `TomFormStringField` and `TomFormStringListField` both do.
/// A mixin member shadows the superclass member, so for as long as the mixin
/// declared `String? get labelText => null` every field that did not repeat
/// the getter on its own concrete class silently rendered no label: the
/// constructor accepted `labelTextOverride`, the resource lookup ran, and the
/// result went nowhere. Twenty field families worked around it by re-declaring
/// the getter per class; the six fields below did not, and were blank.
///
/// The mixin now declares both members abstract, so the superclass
/// implementation is the one that runs and a field with no implementation at
/// all fails to compile. These tests pin that: every source-backed selection
/// field must render the label and description it was given.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: SizedBox(width: 400, child: child))),
);

/// The source resolves through a `Future`, so the first frame renders an
/// empty item list. One extra pump settles it.
Future<void> _pumpLoaded(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(_app(child));
  await tester.pump();
}

StaticSelectableSource<String> _industries() =>
    StaticSelectableSource<String>([
      const SelectableItem(value: 'tech', label: 'Technology'),
      const SelectableItem(value: 'finance', label: 'Finance'),
    ]);

void main() {
  group('TomGenericFieldDecorationMixin — label anatomy', () {
    // Each entry builds one field carrying the same override pair, so the
    // assertion is identical and the table is the specification: these are
    // the fields that must not lose their label to the mixin.
    final fields = <String, TomField<Object> Function()>{
      'TomFormStringFilterChips': () => TomFormStringFilterChips(
        'filterChips',
        const [],
        source: _industries(),
        labelTextOverride: 'Industries',
        descriptionTextOverride: 'Pick any number',
      ),
      'TomFormStringMultiCheckbox': () => TomFormStringMultiCheckbox(
        'multiCheckbox',
        const [],
        source: _industries(),
        labelTextOverride: 'Industries',
        descriptionTextOverride: 'Pick any number',
      ),
      'TomFormStringSegmented': () => TomFormStringSegmented(
        'segmented',
        'tech',
        source: _industries(),
        labelTextOverride: 'Industries',
        descriptionTextOverride: 'Pick any number',
      ),
      'TomFormStringRadioGroup': () => TomFormStringRadioGroup(
        'radioGroup',
        'tech',
        source: _industries(),
        labelTextOverride: 'Industries',
        descriptionTextOverride: 'Pick any number',
      ),
      'TomFormStringChoiceChips': () => TomFormStringChoiceChips(
        'choiceChips',
        'tech',
        source: _industries(),
        labelTextOverride: 'Industries',
        descriptionTextOverride: 'Pick any number',
      ),
    };

    for (final entry in fields.entries) {
      testWidgets('${entry.key} renders its labelTextOverride', (tester) async {
        final field = entry.value();
        addTearDown(field.dispose);
        await _pumpLoaded(tester, field.widget);

        expect(
          find.text('Industries'),
          findsOneWidget,
          reason: '${entry.key} must render the label it was given',
        );
        expect(
          find.text('Pick any number'),
          findsOneWidget,
          reason: '${entry.key} must render the description it was given',
        );
      });
    }

    testWidgets('the label reaches the widget through the base getter, not a '
        'per-class copy', (tester) async {
      // TomFormStringListField resolves labelText on the abstract base; the
      // concrete class does not repeat it. Reading it back off the field and
      // finding it in the tree is what proves the mixin no longer shadows it.
      final field = TomFormStringFilterChips(
        'filterChips',
        const [],
        source: _industries(),
        labelTextOverride: 'Industries',
      );
      addTearDown(field.dispose);

      expect(field.labelText, 'Industries');
      await _pumpLoaded(tester, field.widget);
      expect(find.text('Industries'), findsOneWidget);
    });
  });
}
