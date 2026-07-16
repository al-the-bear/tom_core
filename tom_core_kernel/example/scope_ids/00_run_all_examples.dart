/// Runner for all Scope IDs module examples.
///
/// Run with:
/// ```bash
/// dart run example/scope_ids/00_run_all_examples.dart
/// ```
library;

import '01_scope_basics_example.dart' as scope_basics;
import '02_inscope_builder_example.dart' as inscope_builder;
import '03_scope_mixin_example.dart' as scope_mixin;

void main() {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║                    Tom Scope IDs Examples                         ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
  print('');

  scope_basics.run();
  inscope_builder.run();
  scope_mixin.run();

  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║                     All Examples Complete!                        ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
}
