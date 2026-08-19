/// Preferences Examples Runner
///
/// This file runs all preferences examples in sequence.
///
/// To run this file:
/// ```bash
/// dart run --enable-asserts example/samples/preferences/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

// Import all example files
import '01_preference_codec_example.dart' as codec;
import '02_preference_contract_example.dart' as contract;

/// Standalone entry point for running preferences examples.
void main() {
  // The codec resolves reflected preference values through the reflector, so
  // the reflection registry has to exist before example 4 of the codec file.
  bootstrapSamples();
  run();
}

/// Run all preferences examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('Running Preferences Examples...\n');
  print('=' * 60);

  print('\n01: Preference Codec Example');
  print('-' * 40);
  codec.run();
  print('✓ Preference codec examples passed\n');

  print('\n02: Preference Contract Example');
  print('-' * 40);
  contract.run();
  print('✓ Preference contract examples passed\n');

  print('=' * 60);
  print('All preferences examples completed successfully!');
}
