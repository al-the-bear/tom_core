/// Observable Examples Runner
///
/// This file runs all observable examples in sequence.
///
/// To run this file:
/// ```bash
/// dart run --enable-asserts example/samples/observable/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import 'package:timezone/standalone.dart' as tz;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../run_all_samples.reflection.dart';

// Import all example files
import '01_tom_object_basics.dart' as tom_object;
import '02_observer_pattern.dart' as observer;
import '03_tom_class.dart' as tom_class;
import '04_tom_list.dart' as tom_list;
import '05_tom_map.dart' as tom_map;
import '06_timezone_types.dart' as timezone_types;
import '07_list_reset_lifecycle.dart' as list_reset_lifecycle;
import '08_observable_enum.dart' as observable_enum;

/// Standalone entry point for running observable examples.
Future<void> main() async {
  initializeReflection();
  await tz.initializeTimeZone();
  final _ = TomTimezone.timezones;
  await Future.delayed(Duration(milliseconds: 100));
  await run();
}

/// Run all observable examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom Observable System Samples                       ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  // Run all examples
  tom_object.run();
  observer.run();
  tom_class.run();
  tom_list.run();
  tom_map.run();
  timezone_types.run();
  list_reset_lifecycle.run();
  observable_enum.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
