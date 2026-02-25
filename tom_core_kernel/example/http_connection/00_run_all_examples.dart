/// Examples demonstrating the Tom HTTP Connection module.
///
/// This file runs all http_connection examples in sequence.
///
/// Run with:
/// ```bash
/// dart run example/tombase/http_connection/00_run_all_examples.dart
/// ```
library;

import '01_http_client_example.dart' as http_client;
import '02_connection_config_example.dart' as connection_config;
import '03_retry_policies_example.dart' as retry_policies;

void main() {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║              TOM HTTP CONNECTION EXAMPLES                         ║');
  print('╚═══════════════════════════════════════════════════════════════════╝\n');

  http_client.run();
  connection_config.run();
  retry_policies.run();

  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║              ALL EXAMPLES COMPLETED                               ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
}
