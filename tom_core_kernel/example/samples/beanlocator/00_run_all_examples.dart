/// Beanlocator Examples Runner
///
/// This file runs all beanlocator examples in sequence.
///
/// To run this file:
/// ```bash
/// dart run example/samples/beanlocator/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import '../../run_all_samples.reflection.dart';

// Import all example files
import '01_initialization_sequence_example.dart' as init_sequence;
import '02_bean_dependency_patterns_example.dart' as bean_patterns;
import '03_named_beans_example.dart' as named_beans;
import '04_interface_and_type_registration_example.dart' as type_registration;
import '05_annotation_based_beans_example.dart' as annotation_beans;
import '06_type_and_environment_registration_example.dart' as type_env_registration;

/// Standalone entry point for running beanlocator examples.
void main() {
  initializeReflection();
  run();
}

/// Run all beanlocator examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom Beanlocator System Samples                      ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  // Run all examples
  init_sequence.run();
  bean_patterns.run();
  named_beans.run();
  type_registration.run();
  annotation_beans.run();
  type_env_registration.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
