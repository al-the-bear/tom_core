/// Runner for all Shutdown Cleanup module examples.
///
/// Run with:
/// ```bash
/// dart run example/tombase/shutdown_cleanup/00_run_all_examples.dart
/// ```
library;

import 'dart:io';

import '00_run_all_examples.reflection.dart';
import '01_shutdown_handler_example.dart' as shutdown_handler;
import '02_shutdown_execution_example.dart' as shutdown_execution;

Future<void> main() async {
  // Register reflected targets (e.g. LegacyService used by TomCloseAdaptor in
  // the execution example) before any example runs.
  initializeReflection();

  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║               Tom Shutdown Cleanup Examples                       ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
  print('');

  shutdown_handler.run();
  print('');
  await shutdown_execution.run();

  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║                     All Examples Complete!                        ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');

  exit(0);
}
