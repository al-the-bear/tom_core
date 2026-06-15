import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/forms/forms_example.dart' as example;

void main() {
  group('forms example', () {
    test('runs end to end with its assertions', () {
      expect(example.run(), completes);
    });
  });

  // A handful of direct checks on the pure-logic surfaces the example uses,
  // so a regression there fails here with a precise message rather than only
  // tripping an assert inside the example.
  group('forms pure-logic surfaces', () {
    test('FormFieldFamily picks distinct concrete types per family', () {
      final m = FormFieldFamily.material.stringInput('a', '');
      final c = FormFieldFamily.cupertino.stringInput('a', '');
      expect(FormFieldFamily.material.isCupertino, isFalse);
      expect(FormFieldFamily.cupertino.isCupertino, isTrue);
      expect(m.runtimeType, isNot(c.runtimeType));
    });

    test('StaticSelectableSource returns an unmodifiable snapshot', () async {
      final source = StaticSelectableSource<int>(const [
        SelectableItem(value: 1, label: 'one'),
        SelectableItem(value: 2, label: 'two'),
      ]);
      final items = await source.getItems();
      expect(items, hasLength(2));
      expect(() => items.add(const SelectableItem(value: 3, label: 'x')),
          throwsUnsupportedError);
      expect(source.itemsStream, isNull);
    });

    test('TomFormInspector filters by type and source', () {
      final inspector = TomFormInspector();
      inspector.handleEvent(FormBoundEvent(source: 'f'));
      inspector.handleEvent(
          FieldValueChangedEvent(source: 'f.x', oldValue: 1, newValue: 2));
      expect(inspector.length, 2);
      expect(inspector.ofType<FieldValueChangedEvent>(), hasLength(1));
      expect(inspector.fromSource('f'), hasLength(1));
      inspector.clear();
      expect(inspector.isEmpty, isTrue);
    });

    test('FormValidationError exposes field ids via tomIds', () {
      final start = FormFieldFamily.material.intInput('range.start', 0);
      final end = FormFieldFamily.material.intInput('range.end', 0);
      final error = FormValidationError(
        errorKey: 'error.endBeforeStart',
        fields: [start, end],
      );
      expect(error.tomIds, ['range.start', 'range.end']);
      expect(error.toString(), contains('error.endBeforeStart'));
    });

    test('TomBreakpoint.resolve maps names and rejects unknowns', () {
      expect(TomBreakpoint.resolve('mobile'), TomBreakpoint.mobile);
      expect(TomBreakpoint.resolve('TABLET'), TomBreakpoint.tablet);
      expect(TomBreakpoint.resolve('watch'), isNull);
    });
  });
}
