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
    test('TomFormFieldFamily picks distinct concrete types per family', () {
      final m = TomFormFieldFamily.material.stringInput('a', '');
      final c = TomFormFieldFamily.cupertino.stringInput('a', '');
      expect(TomFormFieldFamily.material.isCupertino, isFalse);
      expect(TomFormFieldFamily.cupertino.isCupertino, isTrue);
      expect(m.runtimeType, isNot(c.runtimeType));
    });

    test(
      'TomStaticSelectableSource returns an unmodifiable snapshot',
      () async {
        final source = TomStaticSelectableSource<int>(const [
          TomSelectableItem(value: 1, label: 'one'),
          TomSelectableItem(value: 2, label: 'two'),
        ]);
        final items = await source.getItems();
        expect(items, hasLength(2));
        expect(
          () => items.add(const TomSelectableItem(value: 3, label: 'x')),
          throwsUnsupportedError,
        );
        expect(source.itemsStream, isNull);
      },
    );

    test('TomFormInspector filters by type and source', () {
      final inspector = TomFormInspector();
      inspector.handleEvent(TomFormBoundEvent(source: 'f'));
      inspector.handleEvent(
        TomFieldValueChangedEvent(source: 'f.x', oldValue: 1, newValue: 2),
      );
      expect(inspector.length, 2);
      expect(inspector.ofType<TomFieldValueChangedEvent>(), hasLength(1));
      expect(inspector.fromSource('f'), hasLength(1));
      inspector.clear();
      expect(inspector.isEmpty, isTrue);
    });

    test('TomFormValidationError exposes field ids via tomIds', () {
      final start = TomFormFieldFamily.material.intInput('range.start', 0);
      final end = TomFormFieldFamily.material.intInput('range.end', 0);
      final error = TomFormValidationError(
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
