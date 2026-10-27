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
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
///
/// `--enable-asserts` is required, not cosmetic. Every sample states its
/// expected outcome with `assert`, and Dart strips asserts unless the flag is
/// passed — run without it and the samples print the same output and still
/// exit 0 while checking nothing at all. The flag is what turns this runner
/// from a demonstration into a test of the kernel's public surface.
///
/// The process this runner owns is established once, before any module is
/// dispatched, by the `bootstrapSamples()` call at the top of `main()` — the
/// reflection registry and, through `sample_preamble.dart`, the assert guard
/// and the `TomPlatformUtils` implementation whose isolate identity prefixes
/// every framework log line. No module configures any of it, and none has to:
/// the identity in the log header is uniform from the first line to the last.
///
/// The samples are also written to be timezone-independent: they build
/// instants with `DateTime.utc(...)` rather than wall-clock `DateTime(...)`,
/// so the assertions hold on any host. Verified against UTC, Europe/Berlin,
/// Asia/Tokyo, Pacific/Honolulu, Pacific/Kiritimati and Asia/Kathmandu.
library;

import 'dart:io';

import 'sample_bootstrap.dart';

// Import all sample runners
import 'samples/beanlocator/00_run_all_examples.dart' as beanlocator;
import 'samples/context/00_run_all_examples.dart' as context;
import 'samples/crypto/00_run_all_examples.dart' as crypto;
import 'samples/http_connection/00_run_all_examples.dart' as http_connection;
import 'samples/isolate_pooling/00_run_all_examples.dart' as isolate_pooling;
import 'samples/json/00_run_all_examples.dart' as json;
import 'samples/little_things/00_run_all_examples.dart' as little_things;
import 'samples/logging/00_run_all_examples.dart' as logging;
import 'samples/metrics/00_run_all_examples.dart' as metrics;
import 'samples/observable/00_run_all_examples.dart' as observable;
import 'samples/offline/00_run_all_examples.dart' as offline;
import 'samples/preferences/00_run_all_examples.dart' as preferences;
import 'samples/reflection/00_run_all_examples.dart' as reflection;
import 'samples/resources/00_run_all_examples.dart' as resources;
import 'samples/runtime/00_run_all_examples.dart' as runtime;
import 'samples/scheduling/00_run_all_examples.dart' as scheduling;
import 'samples/scope_ids/00_run_all_examples.dart' as scope_ids;
import 'samples/security/00_run_all_examples.dart' as security;
import 'samples/settings/00_run_all_examples.dart' as settings;
import 'samples/shutdown_cleanup/00_run_all_examples.dart' as shutdown_cleanup;
import 'samples/timezoned/00_run_all_examples.dart' as timezoned;

Future<void> main() async {
  // Establish the process before dispatching any module: the assert guard, the
  // platform identity that labels the log lines, and the reflection registry.
  bootstrapSamples();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║           TOM CORE - ALL SAMPLES RUNNER                          ║');
  print(
    '╚══════════════════════════════════════════════════════════════════╝\n',
  );

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
    await http_connection.run();
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
    await logging.run();
    samplesRun++;

    // 9. Metrics samples
    print('\n${'═' * 70}');
    print('METRICS SAMPLES');
    print('═' * 70);
    await metrics.run();
    samplesRun++;

    // 10. Observable samples
    print('\n${'═' * 70}');
    print('OBSERVABLE SAMPLES');
    print('═' * 70);
    await observable.run();
    samplesRun++;

    // 11. Offline samples
    print('\n${'═' * 70}');
    print('OFFLINE SAMPLES');
    print('═' * 70);
    await offline.run();
    samplesRun++;

    // 12. Preferences samples
    print('\n${'═' * 70}');
    print('PREFERENCES SAMPLES');
    print('═' * 70);
    preferences.run();
    samplesRun++;

    // 13. Reflection samples
    print('\n${'═' * 70}');
    print('REFLECTION SAMPLES');
    print('═' * 70);
    await reflection.run();
    samplesRun++;

    // 14. Resources samples
    print('\n${'═' * 70}');
    print('RESOURCES SAMPLES');
    print('═' * 70);
    resources.run();
    samplesRun++;

    // 15. Runtime samples
    print('\n${'═' * 70}');
    print('RUNTIME SAMPLES');
    print('═' * 70);
    runtime.run();
    samplesRun++;

    // 16. Scheduling samples
    print('\n${'═' * 70}');
    print('SCHEDULING SAMPLES');
    print('═' * 70);
    await scheduling.run();
    samplesRun++;

    // 17. Scope IDs samples
    print('\n${'═' * 70}');
    print('SCOPE IDS SAMPLES');
    print('═' * 70);
    scope_ids.run();
    samplesRun++;

    // 18. Security samples
    print('\n${'═' * 70}');
    print('SECURITY SAMPLES');
    print('═' * 70);
    await security.run();
    samplesRun++;

    // 19. Settings samples
    print('\n${'═' * 70}');
    print('SETTINGS SAMPLES');
    print('═' * 70);
    await settings.run();
    samplesRun++;

    // 20. Shutdown Cleanup samples
    print('\n${'═' * 70}');
    print('SHUTDOWN CLEANUP SAMPLES');
    print('═' * 70);
    await shutdown_cleanup.run();
    samplesRun++;

    // 21. Timezoned samples
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
  print(
    '║  Sample groups run: $samplesRun                                           ║',
  );
  print(
    '║  Total time: ${stopwatch.elapsed.inSeconds}s                                              ║',
  );
  print('╚══════════════════════════════════════════════════════════════════╝');

  exit(0);
}
