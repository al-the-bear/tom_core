/// Runner for all JSON module examples.
///
/// Executes all examples in sequence to demonstrate the complete
/// functionality of the json module including serialization,
/// pretty printing, map merging, and tree navigation.
///
/// Run with:
/// ```bash
/// dart run example/tombase/json/00_run_all_examples.dart
/// ```
library;

import '01_json_serialization_example.dart' as json_serialization;
import '02_json_navigation_example.dart' as json_navigation;

void main() {
  print(
    '╔═══════════════════════════════════════════════════════════════════╗',
  );
  print(
    '║                    JSON Module Examples                           ║',
  );
  print(
    '╚═══════════════════════════════════════════════════════════════════╝',
  );
  print('');

  json_serialization.run();
  json_navigation.run();

  print(
    '╔═══════════════════════════════════════════════════════════════════╗',
  );
  print(
    '║                    All Examples Complete                          ║',
  );
  print(
    '╚═══════════════════════════════════════════════════════════════════╝',
  );
}
