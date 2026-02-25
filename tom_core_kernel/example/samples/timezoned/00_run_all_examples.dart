/// Timezoned Examples Runner
///
/// This file runs all timezoned examples in sequence.
///
/// To run this file:
/// ```bash
/// dart run example/samples/tombase/timezoned/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import 'package:timezone/standalone.dart' as tz;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../run_all_samples.reflection.dart';

// Import all example files
import '01_timezone_basics_example.dart' as timezone_basics;
import '02_zoned_datetime_example.dart' as zoned_datetime;
import '03_zoned_date_time_example.dart' as zoned_date_time;
import '04_timezone_conversion_example.dart' as timezone_conversion;
import '05_serialization_example.dart' as serialization;

/// Standalone entry point for running timezoned examples.
Future<void> main() async {
  initializeReflection();
  await tz.initializeTimeZone();
  final _ = TomTimezone.timezones;
  await Future.delayed(Duration(milliseconds: 100));
  await run();
}

/// Run all timezoned examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom Timezoned System Samples                        ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  // Run all examples
  timezone_basics.run();
  zoned_datetime.run();
  zoned_date_time.run();
  timezone_conversion.run();
  serialization.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
