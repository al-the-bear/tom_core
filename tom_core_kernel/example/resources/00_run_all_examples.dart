/// Runner for all resources module examples.
///
/// Executes all examples in sequence to demonstrate the complete
/// functionality of the resources module including text resource
/// providers and configuration resource providers.
///
/// Run with:
/// ```bash
/// dart run example/tombase/resources/00_run_all_examples.dart
/// ```
library;

import '01_resource_provider_example.dart' as resource_provider;
import '02_resource_fallback_example.dart' as resource_fallback;

void main() {
  print(
    '╔═══════════════════════════════════════════════════════════════════╗',
  );
  print(
    '║                  Resources Module Examples                        ║',
  );
  print(
    '╚═══════════════════════════════════════════════════════════════════╝',
  );
  print('');

  resource_provider.run();
  resource_fallback.run();

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
