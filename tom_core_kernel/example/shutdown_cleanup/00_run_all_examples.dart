/// Runner for all Shutdown Cleanup module examples.
///
/// Run with:
/// ```bash
/// dart run example/tombase/shutdown_cleanup/00_run_all_examples.dart
/// ```
library;

import 'dart:io';

import '01_shutdown_handler_example.dart' as shutdown_handler;

void main() {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║               Tom Shutdown Cleanup Examples                       ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
  print('');

  shutdown_handler.run();

  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║                     All Examples Complete!                        ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');

  exit(0);
}
