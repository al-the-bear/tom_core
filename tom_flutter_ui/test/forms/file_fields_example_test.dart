import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/forms/file_fields_example.dart' as example;

void main() {
  group('file fields example', () {
    test('runs end to end with its assertions', () {
      expect(example.run(), completes);
    });
  });

  // The example leaves the registry clean; a leak here would make every other
  // test that asserts "no picker registered" order-dependent.
  group('file fields example hygiene', () {
    test('clears the picker registry when it is done', () async {
      await example.run();
      expect(TomFilePickerRegistry.hasPicker, isFalse);
    });
  });
}
