/// Examples demonstrating the Tom Bean Locator System.
///
/// This file runs all beanlocator examples in sequence.
///
/// Examples cover:
/// 1. Initialization sequence (runtime + bean context setup)
/// 2. Bean dependency patterns (declaring dependencies with TomBean)
/// 3. Named beans (registering and resolving by name)
/// 4. Type & environment registration (withType, installByEnvironment)
///
/// Note: Platform and environment details are in the runtime module.
/// See example/tombase/runtime/ for those examples.
///
/// Run with:
/// ```bash
/// dart run example/tombase/beanlocator/00_run_all_examples.dart
/// ```
library;

import '01_initialization_sequence_example.dart' as initialization;
import '02_bean_dependency_patterns_example.dart' as dependency_patterns;
import '03_named_beans_example.dart' as named_beans;
import '04_type_and_environment_registration_example.dart'
    as type_and_environment;

void main() {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║              TOM BEAN LOCATOR EXAMPLES                            ║');
  print('╚═══════════════════════════════════════════════════════════════════╝\n');

  initialization.run();
  dependency_patterns.run();
  named_beans.run();
  type_and_environment.run();

  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║              ALL EXAMPLES COMPLETED                               ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
}
