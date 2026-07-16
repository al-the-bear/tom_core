/// Runner for all Execution Context examples.
///
/// Run with:
/// ```bash
/// dart run example/tombase/context/00_run_all_examples.dart
/// ```
library;

import '01_basic_context_example.dart' as basic_context;
import '02_context_nesting_example.dart' as context_nesting;
import '03_context_providers_example.dart' as context_providers;
import '04_async_and_zonevalues_example.dart' as async_and_zonevalues;

Future<void> main() async {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║               Tom Execution Context Examples                      ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
  print('');

  basic_context.run();
  context_nesting.run();
  context_providers.run();
  await async_and_zonevalues.run();

  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║                     All Examples Complete!                        ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
}
