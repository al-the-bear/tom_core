// Run All Examples
//
// Runs every todo_domain example in-process to verify they execute correctly,
// reporting a pass/fail tally and exiting non-zero on any failure. This turns
// the example/ tree into a headless smoke test (todo_domain is pure Dart).
//
// Run with: dart run example/run_all_examples.dart
//
// This is the hand-run entry point. `test/examples_test.dart` runs the same set
// under `dart test`, because reporting failure with exit(1) makes this file
// uncallable from a test. Adding an example means listing it in both — the
// second listing is what keeps it from silently going unguarded.

import 'dart:io';

import 'assign_and_complete_example.dart' as assign_and_complete;
import 'build_hierarchy_example.dart' as build_hierarchy;
import 'enum_round_trip_example.dart' as enum_round_trip;

void main() {
  // initializeReflection() is idempotent, so each example calling it again is
  // harmless when they run back-to-back here.
  final examples = <String, void Function()>{
    'build_hierarchy_example': build_hierarchy.main,
    'enum_round_trip_example': enum_round_trip.main,
    'assign_and_complete_example': assign_and_complete.main,
  };

  print('=' * 60);
  print('Running all todo_domain examples');
  print('=' * 60);

  var passed = 0;
  final failures = <String, String>{};

  for (final entry in examples.entries) {
    stdout.write('\nRunning: ${entry.key}... ');
    try {
      entry.value();
      print('✓ PASSED');
      passed++;
    } catch (e, stack) {
      print('✗ FAILED');
      failures[entry.key] = '$e\n$stack';
    }
  }

  print('\n${'=' * 60}');
  print('Results: $passed passed, ${failures.length} failed');
  print('=' * 60);

  if (failures.isNotEmpty) {
    print('\nFailures:');
    for (final entry in failures.entries) {
      print('\n--- ${entry.key} ---');
      print(entry.value);
    }
    exit(1);
  }

  print('\nAll examples passed!');
}
