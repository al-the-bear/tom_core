/// Reflection bootstrap fixture for the `tom_core_server` test suite.
///
/// `dart test` runs every test *file* in its own isolate, and the reflected
/// surfaces of the server (the endpoint pipeline, `TomArgs.fillFromArgs`, the
/// health route) all construct `ClassMirror`/`InstanceMirror` — which throws
/// "Reflection has not been initialized" until [initializeReflection] has been
/// called. This file is the reflection *root*: the generator
/// (`reflection_generation.sh` → `test/fixtures/reflection_fixture.reflection.dart`)
/// follows its import graph and emits an `initializeReflection()` that captures
/// these fixture types (and the transitively-reached server barrel). A test that
/// wants the reflected pipeline calls that generated function in `setUpAll`.
///
/// The fixture deliberately mirrors the codebase's endpoint convention: a
/// `@tomService` **interface** declares the endpoint contract (the annotations
/// the router reads via `getClassMethodMetadata`) and a `@tomComponent`
/// **implementation** carries the invoked bodies. A single self-referential
/// class does not work — `findServiceInstance` resolves an implementation only
/// by a component whose superclass/superinterface is the service type, so the
/// two roles must be separate types.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// Entry point required by the reflection generator: it only processes a root
/// that declares `main()`, and captures the types reachable from it. The body
/// is intentionally empty — the file exists to be the reflection root, never to
/// be run.
void main() {}

/// The fixture API contract the endpoint router reflects over.
///
/// The `@TomEndpoint` / `@TomPublicAccess` annotations live here, on the
/// abstract methods, because `getClassMethodMetadata` reads them from the
/// service *interface*; the implementation only supplies the method bodies the
/// pipeline invokes.
@tomReflector
@tomService
abstract class FixtureApiService {
  /// Public liveness probe — `@TomPublicAccess` makes `checkAccess(null)` grant
  /// access without a principal, so the route serves an anonymous request.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/health',
    produces: TomMimeType.json,
    logRequests: true,
  )
  Future<Map<String, Object>> health();

  /// An endpoint with **no** access annotation, so `metadata.access` is null and
  /// `checkAccess` falls back to the global protection default — the second
  /// `checkAccess` branch under test.
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/unguarded',
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> unguarded();
}

/// Live implementation of [FixtureApiService]; the pipeline invokes these
/// bodies on the instance registered with the bean locator.
@tomReflector
@tomComponent
class FixtureApiServer implements FixtureApiService {
  @override
  Future<Map<String, Object>> health() async =>
      <String, Object>{'status': 'ok', 'app': 'fixture'};

  @override
  Future<Map<String, Object>> unguarded() async =>
      <String, Object>{'guarded': false};
}

/// A reflected configuration object for exercising [TomArgs.fillFromArgs]: its
/// public fields are assigned by name from parsed `key=value` arguments.
@tomReflector
class FixtureServerConfig {
  /// Assigned from `name=<value>` (stays a String).
  String name = '';

  /// Assigned from `port=<value>` (coerced to int by the arg parser).
  int port = 0;

  /// Assigned from a bare `verbose` flag (recorded as `"true"`, coerced to bool).
  bool verbose = false;
}

/// A reflected persistence entity for the DB-backed test surfaces (RCK13).
///
/// Mirrors the sample's `@TomDbTable` / `@TomEntityId` / `@TomDbColumn` record
/// shape (a nullable surrogate key that is `null` before the first insert, plus
/// typed nullable columns) so the CRUD/query paths of
/// [TomSqlDatasourceRepository] can be exercised against a real MariaDB. It maps
/// to the `fixture_task` table in the `tom_core_server_test` data source that
/// `test_database.dart` provisions and tears down per run. The type is
/// `@tomReflector` because the data source's row mapper and the annotation
/// analyzer resolve it by mirror.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_task',
  primaryKeyField: 'id',
)
class FixtureTaskRecord {
  /// Surrogate primary key — `null` until first persisted, then the
  /// database-assigned AUTO_INCREMENT value. `isReadOnly` keeps it out of the
  /// generated INSERT/UPDATE column lists.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// A plain string column.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// An int column, to cover integer binding and row mapping.
  @TomDbColumn(columnName: 'priority')
  int? priority;

  /// A bool column, to cover the Dart `bool` → MariaDB `TINYINT(1)` (`1`/`0`)
  /// bind translation (bug §72) end-to-end.
  @TomDbColumn(columnName: 'done')
  bool? done;
}

/// The MariaDB-backed repository for [FixtureTaskRecord].
///
/// Extends [TomSqlDatasourceRepository] directly (no `@tomReflector`): it is
/// constructed with `new`, never through a mirror, and inherits every
/// CRUD/query method. Its constructor resolves the entity's persistence
/// metadata and looks up the `tom_core_server_test` data source, so it must be
/// created only *after* `test_database.dart` has registered that data source.
class FixtureTaskRepository
    extends TomSqlDatasourceRepository<FixtureTaskRecord, int> {}
