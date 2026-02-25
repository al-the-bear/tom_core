/// Timezoned Examples Runner
///
/// This file runs all timezoned examples in sequence.
/// The timezone database is initialized explicitly before running examples.
///
/// To run this file:
/// ```bash
/// dart run example/tombase/timezoned/00_run_all_examples.dart
/// ```
library;

import 'package:timezone/standalone.dart' as tz;
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Import all example files
import '01_timezone_basics_example.dart' as timezone_basics;
import '02_zoned_datetime_example.dart' as zoned_datetime;
import '03_serialization_example.dart' as serialization;
import '04_dst_handling_example.dart' as dst_handling;
import '05_timezone_lookup_example.dart' as timezone_lookup;
import '06_practical_patterns_example.dart' as practical;

Future<void> main() async {
  // Initialize timezone database before running examples
  await tz.initializeTimeZone();
  
  // Access TomTimezone.timezones to trigger lazy initialization
  // and populate the internal cache
  final _ = TomTimezone.timezones;
  
  // Wait for the async initialization to complete
  await Future.delayed(Duration(milliseconds: 100));
  
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║               Tom Timezoned System Examples                      ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  // Run all examples
  timezone_basics.run();
  zoned_datetime.run();
  serialization.run();
  dst_handling.run();
  timezone_lookup.run();
  practical.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Examples Complete!                        ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
