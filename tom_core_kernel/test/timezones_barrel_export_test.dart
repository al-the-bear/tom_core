/// The guard that keeps the timezone setup functions reachable from the
/// package barrel.
///
/// `tomSetupTimezones` is not a convenience. On web the database is fetched
/// over the network, there is no synchronous load path, and `TomTimezone`
/// throws on every access until the fetch has completed — so an application
/// that cannot call this function cannot use the module at all. Four documents
/// instruct web startup to call it.
///
/// It was nonetheless unreachable: `timezones.dart` pulled the
/// platform-conditional implementation in with an `import`, which brings names
/// into the importing library without passing them on, so nothing crossed the
/// barrel. Native callers never noticed, because there the synchronous
/// lazy-init makes the call optional; the break was invisible everywhere except
/// the one platform where the call is mandatory.
///
/// That is the shape worth guarding: a public symbol whose absence only shows
/// up on a platform the test suite does not run on. So the check is made
/// compile-time rather than conditional — this file imports **nothing but the
/// barrel** and names both functions, so removing the re-export does not
/// produce a failing assertion, it produces a file that will not compile, on
/// every platform, immediately.
///
/// The first test exists to keep that property true. The guard's entire
/// strength is the import list, and an import list is exactly the kind of thing
/// a later edit widens without meaning anything by it: add one relative import
/// into `lib/src/`, and this file still passes while proving nothing. So it
/// reads its own source and asserts the import list is still just the barrel.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// This file's own path, read back to check how it imports.
const _ownPath = 'test/timezones_barrel_export_test.dart';

/// The only import this file may have into the package under test.
const _barrelImport = "import 'package:tom_core_kernel/tom_core_kernel.dart';";

void main() {
  group('timezone setup functions are part of the public surface', () {
    test('this file reaches the package only through the barrel', () {
      final source = File(_ownPath);
      expect(
        source.existsSync(),
        isTrue,
        reason:
            'the guard reads its own source; if this file moved, $_ownPath '
            'must move with it',
      );

      final packageImports = [
        for (final line in source.readAsLinesSync())
          if (RegExp(r"^\s*(import|export)\s+'").hasMatch(line) &&
              line.contains('tom_core_kernel'))
            line.trim(),
      ];

      // Non-vacuity: if this came back empty the check below would pass while
      // testing nothing at all.
      expect(packageImports, isNotEmpty);
      expect(
        packageImports,
        equals([_barrelImport]),
        reason:
            'the compile-time guard below only proves the barrel exports these '
            'functions while the barrel is the only way this file can see them',
      );
    });

    test('tomSetupTimezones is callable through the barrel', () async {
      // Naming it is what this asserts. The value it answers with is the
      // number of zones loaded, pinned against the database in
      // `timezones_test.dart`; from here, where the only import is the barrel,
      // what can be said is that it is a population — a fixed status value
      // would not clear a hundred.
      expect(await tomSetupTimezones(), greaterThan(100));
    });

    test('tomSetupTimezonesSync is callable through the barrel', () {
      // Native only. On web this same call throws by design, which is the
      // reason the asynchronous one has to be reachable.
      expect(tomSetupTimezonesSync(), greaterThan(100));
    });

    test('a lookup succeeds once setup has run', () {
      // The pair is only worth exporting if it leaves the module usable, which
      // is the state a web application reaches after awaiting the setup call.
      final tokyo = TomTimezone.fromName('Asia/Tokyo');
      expect(tokyo, isNotNull);
      expect(tokyo!.timezone, equals('Asia/Tokyo'));
    });
  });
}
