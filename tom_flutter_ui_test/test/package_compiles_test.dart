/// The guard that fails this suite when a file under `lib/` or `test/` does
/// not compile.
///
/// A suite whose imports stop compiling fails to *load*, not to pass: none of
/// its assertions run, nothing turns red, and the passing count just shrinks.
/// This guard runs `dart analyze` in a separate process, so it reports the
/// failure the suites it protects cannot. The check, its reasons and its
/// self-checks live once, in `tool/package_compile_guard.dart`, shared by every
/// package that carries one; this file only names what to analyze.
library;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/package_compile_guard.dart';

void main() {
  group('the package compiles', () {
    final check = PackageCompileCheck(paths: const ['lib', 'test']);

    test(
      'every file under lib/ and test/ compiles',
      () => expect(check.compileErrors(), isNull),
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('the analyzer was read correctly', () {
      expect(check.readingProblem(), isNull);
    });

    test('the analyzer was handed something to analyze', () {
      expect(check.emptyPaths(), isEmpty);
    });
  });
}
