/// Runner for all little_things module examples.
///
/// Executes all examples in sequence to demonstrate the complete
/// functionality of the little_things module including utility functions,
/// zone helpers, checked execution, and stack trace utilities.
///
/// Run with:
/// ```bash
/// dart run example/tombase/little_things/00_run_all_examples.dart
/// ```
library;

import '01_utility_functions_example.dart' as utility_functions;
import '02_zone_helpers_example.dart' as zone_helpers;
import '03_formatting_and_exceptions_example.dart' as formatting_and_exceptions;

Future<void> main() async {
  print(
    '╔═══════════════════════════════════════════════════════════════════╗',
  );
  print(
    '║                Little Things Module Examples                      ║',
  );
  print(
    '╚═══════════════════════════════════════════════════════════════════╝',
  );
  print('');

  utility_functions.run();
  zone_helpers.run();
  await formatting_and_exceptions.run();

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
