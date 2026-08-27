import 'package:flutter_test/flutter_test.dart';

import '../../example/widget_base/widget_base_nodes_example.dart' as example;

// The nodes example carries its own assertions — scope composition, the four
// authorization layers, and the family each widget reports. Running it here
// keeps it honest: an example that stops matching the code it demonstrates
// fails the suite instead of quietly misleading a reader.
//
// It lives in its own file because it installs two process-wide singletons
// (the resource provider and the TomAuthorization adapter). It restores both,
// but a file of its own means a leak could never be mistaken for a failure of
// some unrelated group.
void main() {
  group('widget_base nodes example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });
}
