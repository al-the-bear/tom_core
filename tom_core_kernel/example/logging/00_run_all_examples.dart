/// Runner for all logging module examples.
///
/// Executes all examples in sequence to demonstrate the complete
/// functionality of the logging module including basic logging,
/// log level configuration, and log formatting options.
///
/// Run with:
/// ```bash
/// dart run example/tombase/logging/00_run_all_examples.dart
/// ```
library;

import '01_basic_logging_example.dart' as basic_logging;
import '02_log_levels_example.dart' as log_levels;
import '03_log_formatting_example.dart' as log_formatting;

void main() {
  print(
    '╔═══════════════════════════════════════════════════════════════════╗',
  );
  print(
    '║                   Logging Module Examples                         ║',
  );
  print(
    '╚═══════════════════════════════════════════════════════════════════╝',
  );
  print('');

  basic_logging.run();
  log_levels.run();
  log_formatting.run();

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
