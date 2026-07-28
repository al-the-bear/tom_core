/// Master Runner for All Tom Core Samples
///
/// This file runs all sample examples from the samples/ folder in sequence.
/// It contains the single reflection import for the entire samples collection.
///
/// To generate the reflection code, run:
/// ```bash
/// dart run build_runner build
/// ```
///
/// Then run this file:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import 'dart:io';

import 'package:timezone/standalone.dart' as tz;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'run_all_samples.reflection.dart';

// Import all sample runners
import 'samples/beanlocator/00_run_all_examples.dart' as beanlocator;
import 'samples/context/00_run_all_examples.dart' as context;
import 'samples/crypto/00_run_all_examples.dart' as crypto;
import 'samples/http_connection/00_run_all_examples.dart' as http_connection;
import 'samples/isolate_pooling/00_run_all_examples.dart' as isolate_pooling;
import 'samples/json/00_run_all_examples.dart' as json;
import 'samples/little_things/00_run_all_examples.dart' as little_things;
import 'samples/logging/00_run_all_examples.dart' as logging;
import 'samples/observable/00_run_all_examples.dart' as observable;
import 'samples/reflection/00_run_all_examples.dart' as reflection;
import 'samples/resources/00_run_all_examples.dart' as resources;
import 'samples/result/00_run_all_examples.dart' as result;
import 'samples/runtime/00_run_all_examples.dart' as runtime;
import 'samples/scheduling/00_run_all_examples.dart' as scheduling;
import 'samples/security/00_run_all_examples.dart' as security;
import 'samples/settings/00_run_all_examples.dart' as settings;
import 'samples/shutdown_cleanup/00_run_all_examples.dart' as shutdown_cleanup;
import 'samples/timezoned/00_run_all_examples.dart' as timezoned;

Future<void> main() async {
  // Initialize reflection - required before any reflection operations
  initializeReflection();

  // Initialize timezone database for timezone-aware examples
  await tz.initializeTimeZone();
  // Trigger TomTimezone lazy init and wait for async completion
  final _ = TomTimezone.timezones;
  await Future.delayed(Duration(milliseconds: 100));

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║           TOM CORE - ALL SAMPLES RUNNER                          ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  final stopwatch = Stopwatch()..start();
  var samplesRun = 0;

  try {
    // 1. Beanlocator samples
    print('\n${'═' * 70}');
    print('BEANLOCATOR SAMPLES');
    print('═' * 70);
    beanlocator.run();
    samplesRun++;

    // 2. Context samples
    print('\n${'═' * 70}');
    print('CONTEXT SAMPLES');
    print('═' * 70);
    await context.run();
    samplesRun++;

    // 3. Crypto samples
    print('\n${'═' * 70}');
    print('CRYPTO SAMPLES');
    print('═' * 70);
    crypto.run();
    samplesRun++;

    // 4. HTTP Connection samples
    print('\n${'═' * 70}');
    print('HTTP CONNECTION SAMPLES');
    print('═' * 70);
    http_connection.run();
    samplesRun++;

    // 5. Isolate Pooling samples
    print('\n${'═' * 70}');
    print('ISOLATE POOLING SAMPLES');
    print('═' * 70);
    await isolate_pooling.run();
    samplesRun++;

    // 6. JSON samples
    print('\n${'═' * 70}');
    print('JSON SAMPLES');
    print('═' * 70);
    json.run();
    samplesRun++;

    // 7. Little Things samples
    print('\n${'═' * 70}');
    print('LITTLE THINGS SAMPLES');
    print('═' * 70);
    await little_things.run();
    samplesRun++;

    // 8. Logging samples
    print('\n${'═' * 70}');
    print('LOGGING SAMPLES');
    print('═' * 70);
    logging.run();
    samplesRun++;

    // 9. Observable samples
    print('\n${'═' * 70}');
    print('OBSERVABLE SAMPLES');
    print('═' * 70);
    await observable.run();
    samplesRun++;

    // 10. Reflection samples
    print('\n${'═' * 70}');
    print('REFLECTION SAMPLES');
    print('═' * 70);
    await reflection.run();
    samplesRun++;

    // 11. Resources samples
    print('\n${'═' * 70}');
    print('RESOURCES SAMPLES');
    print('═' * 70);
    resources.run();
    samplesRun++;

    // 12. Result samples
    print('\n${'═' * 70}');
    print('RESULT SAMPLES');
    print('═' * 70);
    result.run();
    samplesRun++;

    // 13. Runtime samples
    print('\n${'═' * 70}');
    print('RUNTIME SAMPLES');
    print('═' * 70);
    runtime.run();
    samplesRun++;

    // 14. Scheduling samples
    print('\n${'═' * 70}');
    print('SCHEDULING SAMPLES');
    print('═' * 70);
    await scheduling.run();
    samplesRun++;

    // 15. Security samples
    print('\n${'═' * 70}');
    print('SECURITY SAMPLES');
    print('═' * 70);
    security.run();
    samplesRun++;

    // 16. Settings samples
    print('\n${'═' * 70}');
    print('SETTINGS SAMPLES');
    print('═' * 70);
    settings.run();
    samplesRun++;

    // 17. Shutdown Cleanup samples
    print('\n${'═' * 70}');
    print('SHUTDOWN CLEANUP SAMPLES');
    print('═' * 70);
    shutdown_cleanup.run();
    samplesRun++;

    // 18. Timezoned samples
    print('\n${'═' * 70}');
    print('TIMEZONED SAMPLES');
    print('═' * 70);
    await timezoned.run();
    samplesRun++;

  } catch (e, st) {
    print('\n❌ ERROR running samples: $e');
    print(st);
    exit(1);
  }

  stopwatch.stop();

  print('\n${'═' * 70}');
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║           ALL SAMPLES COMPLETED SUCCESSFULLY!                    ║');
  print('╠══════════════════════════════════════════════════════════════════╣');
  print('║  Sample groups run: $samplesRun                                           ║');
  print('║  Total time: ${stopwatch.elapsed.inSeconds}s                                              ║');
  print('╚══════════════════════════════════════════════════════════════════╝');

  exit(0);
}
