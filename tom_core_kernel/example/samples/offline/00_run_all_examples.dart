/// Runs every example of the offline module.
///
/// ```bash
/// dart run --enable-asserts example/samples/offline/00_run_all_examples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_offline_sync_example.dart' as offline_sync;

Future<void> main() async {
  bootstrapSamples();
  await run();
}

Future<void> run() async {
  sampleGroupHeader('Offline');

  await offline_sync.run();
  print('✓ Offline sync examples passed\n');

  sampleGroupFooter('Offline');
}
