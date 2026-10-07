/// Pins the error keys of the data-source driver scan: a `@TomDatasourceDriver`
/// class that cannot be built, or that is not a data source, found either while
/// scanning or when a data source is created from an already-registered driver.
///
/// A key is the contract a caller, a log search or a translation table is
/// written against. One that no test names is a failure mode nobody checks:
/// its raise site can be deleted, reworded into a different key, or swallowed
/// by a broader catch, and every suite stays green. These four are startup
/// failures — the server cannot open its databases — so the key is most of
/// what an operator has to go on.
///
/// Every input here is a driver class no real deployment ships, and that is the
/// reason this file installs its own reflection data instead of adding the
/// classes to the shared fixture. The scan visits every annotated class, and it
/// stops at the first bad one: a broken driver in the shared fixture would make
/// `createDatasourceOf` fail for every suite that opens a data source. Here the
/// driver is a [ScriptedClassMirror], which describes a class whose constructor
/// throws or returns something other than a [TomDataSource] — and the scan and
/// the factory that read it are the real ones.
///
/// The driver registry is process-wide and filled once, by the first scan that
/// completes. The two scan failures leave it empty — their driver is the only
/// candidate, and it is refused before anything is registered — so they come
/// first; the two creation failures then register a driver and fail on the
/// next construction.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/scripted_datasource.dart';
import 'fixtures/scripted_reflection.dart';

/// Completes with a [TomServerException] whose key is exactly [key].
Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

/// A driver for [type] whose constructions answer from [construct].
ScriptedClassMirror _driver(String type, Object Function() construct) =>
    ScriptedClassMirror(
      'ScriptedDriver',
      metadata: [TomDatasourceDriver(type)],
      construct: construct,
    );

void main() {
  group('the driver scan', () {
    test('a driver whose constructor throws', () {
      installReflectedClasses([
        _driver('throws_on_scan', () => throw StateError('no driver today')),
      ]);
      expect(
        () => TomDataSource.createDatasourceOf('throws_on_scan'),
        _throwsKey(
          'tom_datasource.initialize_datasource_types.driver_instantiation_failed',
        ),
      );
    });

    test('a driver that is not a data source', () {
      installReflectedClasses([_driver('not_a_datasource', Object.new)]);
      expect(
        () => TomDataSource.createDatasourceOf('not_a_datasource'),
        _throwsKey(
          'tom_datasource.initialize_datasource_types.invalid_driver_not_implementing_datasource',
        ),
      );
    });
  });

  group('createDatasourceOf a registered driver', () {
    // Builds a data source until [failNext] is set, then answers with it once.
    // The first creation registers the driver (if no earlier test has) and
    // succeeds; the second is the one under test.
    Object Function()? failNext;
    Object construct() {
      final failure = failNext;
      if (failure == null) return ScriptedDataSource();
      failNext = null;
      return failure();
    }

    setUpAll(() => installReflectedClasses([_driver('scripted', construct)]));

    test('whose constructor now throws', () {
      expect(TomDataSource.createDatasourceOf('scripted'), isNotNull);
      failNext = () => throw StateError('the second construction fails');
      expect(
        () => TomDataSource.createDatasourceOf('scripted'),
        _throwsKey(
          'tom_datasource.create_datasource_of.driver_instantiation_failed',
        ),
      );
    });

    // A factory constructor can do this: it returns a data-source subtype on
    // one call and an instance of its own, non-data-source class on another.
    test('whose constructor now returns something else', () {
      expect(TomDataSource.createDatasourceOf('scripted'), isNotNull);
      failNext = () => Object();
      expect(
        () => TomDataSource.createDatasourceOf('scripted'),
        _throwsKey(
          'tom_datasource.create_datasource_of.invalid_driver_not_implementing_datasource',
        ),
      );
    });
  });
}
