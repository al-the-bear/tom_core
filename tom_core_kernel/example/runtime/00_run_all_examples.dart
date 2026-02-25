/// Runner for all runtime module examples.
///
/// Executes all examples in sequence to demonstrate the complete
/// functionality of the runtime module including platform detection,
/// environment configuration, and platform utilities.
///
/// Run with:
/// ```bash
/// dart run example/tombase/runtime/00_run_all_examples.dart
/// ```
library;

import '01_platform_detection_example.dart' as platform_detection;
import '02_environment_platform_example.dart' as environment_platform;
import '03_initialization_sequence_example.dart' as initialization_sequence;

void main() {
  print(
    '╔═══════════════════════════════════════════════════════════════════╗',
  );
  print(
    '║                    Runtime Module Examples                        ║',
  );
  print(
    '╚═══════════════════════════════════════════════════════════════════╝',
  );
  print('');

  platform_detection.run();
  environment_platform.run();
  initialization_sequence.run();

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
