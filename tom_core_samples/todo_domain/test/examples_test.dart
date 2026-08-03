/// Runs every `example/` program as part of the test suite.
///
/// The examples are the package's executable documentation, so a broken one is
/// a broken document. `example/run_all_examples.dart` already executes them
/// back-to-back, but nothing invoked it — and because it reports failure with
/// `exit(1)` it cannot be called in-process either. So an example that stopped
/// compiling stayed broken until someone happened to run `dart analyze` in this
/// package by hand. This file closes that gap: the imports below make a
/// non-compiling example fail the suite, and calling each `main()` makes a
/// throwing one fail it too.
///
/// This lives in its own test file deliberately. `package:test` gives each file
/// its own isolate, so the global resource bundle the enum example installs
/// cannot leak into `todo_domain_test.dart`.
@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:todo_domain/todo_domain.dart';

import '../example/assign_and_complete_example.dart' as assign_and_complete;
import '../example/build_hierarchy_example.dart' as build_hierarchy;
import '../example/enum_round_trip_example.dart' as enum_round_trip;

void main() {
  // Idempotent, and each example calls it again anyway — done once here so the
  // first example is not the one paying for it.
  setUpAll(initializeReflection);

  group('examples run', () {
    // The examples are documentation: they print their results rather than
    // asserting them, so "it completed without throwing" is the whole contract.
    // Their output is captured so a passing suite stays readable; on failure the
    // exception carries the diagnosis, not the printed lines.
    void expectRuns(String name, void Function() example) {
      test(name, () {
        runZoned(example, zoneSpecification: ZoneSpecification(
          print: (_, __, ___, ____) {},
        ));
      });
    }

    expectRuns('build_hierarchy_example', build_hierarchy.main);
    expectRuns('enum_round_trip_example', enum_round_trip.main);
    expectRuns('assign_and_complete_example', assign_and_complete.main);
  });
}
