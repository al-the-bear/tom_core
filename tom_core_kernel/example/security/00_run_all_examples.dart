/// Runner for all Security module examples.
///
/// Run with:
/// ```bash
/// dart run example/tombase/security/00_run_all_examples.dart
/// ```
library;

import '01_user_principal_example.dart' as user_principal;
import '02_access_control_example.dart' as access_control;

void main() {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║                   Tom Security Examples                           ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
  print('');

  user_principal.run();
  access_control.run();

  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║                     All Examples Complete!                        ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
}
