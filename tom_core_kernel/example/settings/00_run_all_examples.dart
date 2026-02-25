/// Runner for all Settings module examples.
///
/// Run with:
/// ```bash
/// dart run example/tombase/settings/00_run_all_examples.dart
/// ```
library;

import '01_client_authorization_example.dart' as client_authorization;

void main() {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║                   Tom Settings Examples                           ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
  print('');

  client_authorization.run();

  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║                     All Examples Complete!                        ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
}
