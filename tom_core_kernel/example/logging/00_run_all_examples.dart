/// Runner for all logging module examples.
///
/// Executes all examples in sequence to demonstrate the complete
/// functionality of the logging module including basic logging,
/// log level configuration, log formatting options, and the kernel-owned
/// isolate / remote logging surface.
///
/// Run with (assertions on, so example self-checks fire):
/// ```bash
/// dart run --enable-asserts example/logging/00_run_all_examples.dart
/// ```
library;

import '01_basic_logging_example.dart' as basic_logging;
import '02_log_levels_example.dart' as log_levels;
import '03_log_formatting_example.dart' as log_formatting;
import '04_isolate_and_remote_logging_example.dart' as isolate_remote_logging;

Future<void> main() async {
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
  await isolate_remote_logging.run();

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
