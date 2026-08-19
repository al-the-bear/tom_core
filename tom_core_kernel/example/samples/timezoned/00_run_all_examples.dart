/// Timezoned Examples Runner
///
/// This file runs all timezoned examples in sequence.
///
/// To run this file:
/// ```bash
/// dart run --enable-asserts example/samples/timezoned/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

// Import all example files
import '01_timezone_basics_example.dart' as timezone_basics;
import '02_zoned_datetime_example.dart' as zoned_datetime;
import '03_zoned_date_time_example.dart' as zoned_date_time;
import '04_timezone_conversion_example.dart' as timezone_conversion;
import '05_serialization_example.dart' as serialization;
import '06_serialization_validation_example.dart' as serialization_validation;
import '07_dst_handling_example.dart' as dst_handling;
import '08_timezone_lookup_example.dart' as timezone_lookup;
import '09_practical_patterns_example.dart' as practical_patterns;

/// Standalone entry point for running timezoned examples.
Future<void> main() async {
  bootstrapSamples();
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
  serialization_validation.run();
  dst_handling.run();
  timezone_lookup.run();
  practical_patterns.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
