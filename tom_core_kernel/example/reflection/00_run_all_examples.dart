/// Reflection Examples Runner
///
/// This file runs all reflection examples in sequence.
/// It contains the single reflection import for the build system.
///
/// To generate the reflection code, run:
/// ```bash
/// dart run build_runner build
/// ```
///
/// Then run this file:
/// ```bash
/// dart run example/tombase/reflection/00_run_all_examples.dart
/// ```
library;

import 'package:timezone/standalone.dart' as tz;
import 'package:tom_core_kernel/tom_core_kernel.dart';
import '00_run_all_examples.reflection.dart';

// Import all example files
import '01_basic_reflection_example.dart' as basic;
import '02_nested_objects_example.dart' as nested;
import '03_collections_example.dart' as collections;
import '04_datetime_types_example.dart' as datetime;
import '05_tomclass_integration_example.dart' as tomclass;
import '06_advanced_reflection_example.dart' as advanced;

Future<void> main() async {
  // Initialize reflection - required before any reflection operations
  initializeReflection();
  
  // Initialize timezone database for datetime examples
  await tz.initializeTimeZone();
  // Trigger TomTimezone lazy init and wait for async completion
  final _ = TomTimezone.timezones;
  await Future.delayed(Duration(milliseconds: 100));
  
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom Reflection System Examples                      ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  // Run all examples
  basic.run();
  nested.run();
  collections.run();
  datetime.run();
  tomclass.run();
  advanced.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Examples Complete!                        ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
