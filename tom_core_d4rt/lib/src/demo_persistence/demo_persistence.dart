/// Reflected persistence demo entity for the d4rt tool.
///
/// This is the first reflected surface the d4rt tool ships. The tool bootstraps
/// `tomReflector`'s registry at boot (via the generated `initializeReflection()`
/// — see `reflection_root.dart`), so a d4rt script can `tomReflector.reflectType`
/// a real type and drive the reflection-backed server surfaces
/// (`TomAnnotationAnalyzer.analysePersistentType`, the datasource row mapper, the
/// endpoint pipeline's `getClassMethodMetadata`). Before this existed the
/// registry was empty and *every* `reflectType()` threw, so none of those
/// surfaces could run from a script (the gap RCL7 closes, per RCJ9).
///
/// The entity deliberately mirrors `tom_core_server`'s test
/// `FixtureTaskRecord` shape — a nullable surrogate key plus typed nullable
/// columns — so it exercises the same annotation-analyzer and CRUD code paths.
/// It lives under `lib/` (not a test fixture) because the reflection and bridge
/// generators only follow the `lib/` import graph: a test-only type would never
/// be captured into the AOT `bin/d4rt_test` the replay suite runs.
///
/// `tom_core_server` is *imported, not exported*: this library declares only the
/// two demo types, so the d4rt bridge generator bridges just them and does not
/// re-bridge the whole server barrel (already bridged by its own module).
library;

import 'package:tom_core_server/tom_core_server.dart';

/// A reflected task record for the d4rt demo persistence surface.
///
/// `@tomReflector` registers it with `tomReflector`; `@TomDbTable` /
/// `@TomEntityId` / `@TomDbColumn` supply the persistence metadata the
/// annotation analyzer and datasource mapper read by mirror. It maps to the
/// `d4rt_demo_task` table in the `d4rt_demo` data source.
@tomReflector
@TomDbTable(
  datasource: 'd4rt_demo',
  table: 'd4rt_demo_task',
  primaryKeyField: 'id',
)
class D4rtDemoTaskRecord {
  /// Surrogate primary key — `null` until first persisted, then the
  /// database-assigned value. `isReadOnly` keeps it out of the generated
  /// INSERT/UPDATE column lists.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// A plain string column.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// An int column, to cover integer binding and row mapping.
  @TomDbColumn(columnName: 'priority')
  int? priority;

  /// A bool column, to cover the Dart `bool` → MariaDB `TINYINT(1)` translation.
  @TomDbColumn(columnName: 'done')
  bool? done;
}

/// The datasource-backed repository for [D4rtDemoTaskRecord].
///
/// Extends [TomSqlDatasourceRepository] directly (no `@tomReflector`: it is
/// constructed with `new`, never through a mirror) and inherits every CRUD /
/// query method. Its constructor first resolves the entity's persistence
/// metadata by reflection — which now succeeds because the tool bootstraps the
/// registry — and *then* looks up the `d4rt_demo` data source, throwing only if
/// that data source has not been registered.
class D4rtDemoTaskRepository
    extends TomSqlDatasourceRepository<D4rtDemoTaskRecord, int> {}

/// The reflected endpoint contract for the d4rt demo (RCL9).
///
/// Mirrors `tom_core_server`'s test `FixtureApiService`: a `@tomService`
/// **interface** whose abstract methods carry the `@TomEndpoint` /
/// `@TomPublicAccess` annotations the endpoint router reads via
/// [TomEndpointRouting.getClassMethodMetadata]. It exists so a d4rt script can
/// drive the reflection-bound routing surface (`scanClasses`,
/// `getClassMethodMetadata`, `initializeRouter`) against a real reflected
/// annotated pipeline — the gap RCL9 closes now that RCL7 seeds `tomReflector`.
///
/// The endpoint annotations must sit on the service *interface* (not the
/// implementation): `getClassMethodMetadata` reads them from the service type,
/// and `findServiceInstance` resolves the body only through a `@tomComponent`
/// whose superinterface *is* the service — so the two roles are separate types.
@tomReflector
@tomService
abstract class D4rtDemoApiService {
  /// Public liveness probe. `@TomPublicAccess` makes `checkAccess(null)` grant
  /// access without a principal, so the route serves an anonymous request.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/d4rt_demo/health',
    produces: TomMimeType.json,
    logRequests: true,
  )
  Future<Map<String, Object>> health();

  /// An endpoint with **no** access annotation, so `metadata.access` is null and
  /// `checkAccess` falls back to the global protection default.
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/d4rt_demo/unguarded',
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> unguarded();
}

/// The reflected `@tomComponent` implementation of [D4rtDemoApiService].
///
/// The endpoint pipeline invokes these bodies on the instance registered with
/// the bean locator; `initializeRouter` resolves this component for the
/// [D4rtDemoApiService] interface because its superinterface is the service.
@tomReflector
@tomComponent
class D4rtDemoApiServer implements D4rtDemoApiService {
  @override
  Future<Map<String, Object>> health() async =>
      <String, Object>{'status': 'ok', 'app': 'd4rt_demo'};

  @override
  Future<Map<String, Object>> unguarded() async =>
      <String, Object>{'guarded': false};
}
