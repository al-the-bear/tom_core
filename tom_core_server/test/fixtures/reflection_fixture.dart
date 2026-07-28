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

  /// An endpoint whose *invocation* is itself the auditable act (CE-LG).
  ///
  /// Endpoint auditing is declared rather than automatic — most endpoint calls
  /// are reads, and which of them matter is a domain judgement — so this is the
  /// fixture that proves `@TomAudited` on a method reaches the trail. Its
  /// unannotated sibling [unguarded] proves the converse.
  @TomAudited()
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/audited',
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> auditedAction();
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

  @override
  Future<Map<String, Object>> auditedAction() async =>
      <String, Object>{'audited': true};
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

/// A reflected entity carrying a **redacted** column, for the CE-LG audit
/// surface.
///
/// `@TomAudited(redact: ...)` is the declaration that keeps a value out of the
/// audit trail entirely. The trail is privileged storage — a C-4 column grade
/// hides a value from the caller, not from the auditor — so redaction exists
/// for values that must not exist in a *second* place at all: password hashes,
/// access tokens, keys. The record still shows that `secret` changed; only its
/// values are withheld.
@tomReflector
@TomAudited(redact: ['secret'])
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_secret',
  primaryKeyField: 'id',
)
class FixtureSecretRecord {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// An ordinary column, recorded in the clear.
  @TomDbColumn(columnName: 'label')
  String? label;

  /// The redacted column: audited as *changed*, never as a value.
  @TomDbColumn(columnName: 'secret')
  String? secret;
}

/// The MariaDB-backed repository for [FixtureSecretRecord].
class FixtureSecretRepository
    extends TomSqlDatasourceRepository<FixtureSecretRecord, int> {}

/// A reflected entity with two **file-reference** columns (CSFS1).
///
/// A `@TomFileReference` column holds a storage *key*; the bytes live in a blob
/// store. Two columns rather than one, because the interesting behaviour is in
/// how they differ:
///
/// - `attachment` is an ordinary file column that **cascades** — replacing or
///   deleting the row must take its blob with it;
/// - `secretAttachment` carries an `authKey`, so the C-4 grade governs it. It
///   is the column that proves a masked file column refuses a download by name
///   instead of reporting "no file", and that a masked round-trip cannot orphan
///   a live blob. It also sets `cascadeDelete: false`, so the "leave the bytes
///   alone" opt-out is exercised rather than merely declared.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_document',
  primaryKeyField: 'id',
)
class FixtureDocumentRecord {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// An ordinary column, so a save that touches no file still has work to do.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// The cascading file column: holds the storage key of the attached file.
  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'fixture/attachment')
  String? attachment;

  /// A C-4 graded, non-cascading file column.
  @TomDbColumn(
    columnName: 'secret_attachment',
    authKey: 'fixture.document.secret_attachment',
  )
  @TomFileReference(keyPrefix: 'fixture/secret', cascadeDelete: false)
  String? secretAttachment;
}

/// The MariaDB-backed repository for [FixtureDocumentRecord].
class FixtureDocumentRepository
    extends TomSqlDatasourceRepository<FixtureDocumentRecord, int> {}

/// A reflected entity whose file columns cover the three exposure cases the
/// HTTP file endpoint has to tell apart (CSFSB1).
///
/// Separate from [FixtureDocumentRecord] rather than folded into it, for two
/// reasons. It has no table in `test_database.dart` and needs none — the
/// endpoint suite drives an in-memory repository, so only the *annotations* are
/// read — and leaving the older entity untouched is itself the assertion that
/// `exposed:` defaults closed: an entity written before HTTP exposure existed
/// must not have become reachable when the field was added.
///
/// - [poster] is plainly exposed: the slot `fixture_file_slot/<id>/poster`;
/// - [gradedPoster] is exposed *and* carries an `authKey`, so it is the column
///   that proves exposure decides only *which* column a slot names — the C-4
///   grade still decides whether the caller may have it;
/// - [internalNotes] is exposed to nobody, and is unreachable by name.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_file_slot',
  primaryKeyField: 'id',
)
class FixtureFileSlotRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// An ordinary column, so the entity is more than its files.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// The plainly exposed file column.
  @TomDbColumn(columnName: 'poster')
  @TomFileReference(keyPrefix: 'fixture/poster', exposed: true)
  String? poster;

  /// An exposed file column that is also C-4 graded.
  @TomDbColumn(
    columnName: 'graded_poster',
    authKey: 'fixture.file_slot.graded_poster',
  )
  @TomFileReference(keyPrefix: 'fixture/graded', exposed: true)
  String? gradedPoster;

  /// A file column that is *not* exposed, and so has no slot at all.
  @TomDbColumn(columnName: 'internal_notes')
  @TomFileReference(keyPrefix: 'fixture/internal')
  String? internalNotes;
}

/// A reflected entity covering every case the reflected export projection has
/// to decide (CSEXC5).
///
/// One entity rather than several, because the interesting property is that a
/// *single* declaration answers all of them at once:
///
/// - [id], [title], [amount], [done] and [createdAt] cover all five
///   `TomColumnType`s, so the derived types can be asserted without a second
///   fixture per type;
/// - [secret] is named in `@TomAudited(redact:)` — the value that must not
///   exist in a second place, and an export is a second place;
/// - [attachment] is a `@TomFileReference`, holding an internal storage key
///   rather than content;
/// - [tag] is a `TomZonedDate`, whose *storage* family is `date` but whose Dart
///   value is not a `DateTime` — the case that proves the derivation falls back
///   to text when the declared Dart type cannot inhabit the candidate type.
///
/// It maps to no table in `test_database.dart` and needs none: only the
/// annotations are read.
@tomReflector
@TomAudited(redact: ['secret'])
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_export',
  primaryKeyField: 'id',
)
class FixtureExportRecord {
  /// Surrogate primary key — derives `TomColumnType.integer`.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// A text column — derives `TomColumnType.text`.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// A fractional column — derives `TomColumnType.decimal`.
  @TomDbColumn(columnName: 'amount')
  double? amount;

  /// A truth column — derives `TomColumnType.boolean`.
  @TomDbColumn(columnName: 'done')
  bool? done;

  /// A point in time — derives `TomColumnType.timestamp`.
  @TomDbColumn(columnName: 'created_at')
  DateTime? createdAt;

  /// A date whose Dart value is not a `DateTime` — derives text.
  @TomDbColumn(columnName: 'tag_day')
  TomZonedDate? tagDay;

  /// The redacted column: never exported.
  @TomDbColumn(columnName: 'secret')
  String? secret;

  /// The file-reference column: holds a storage key, not content.
  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'fixture/export')
  String? attachment;
}

/// [FixtureExportRecord] **after a column was added** — the second half of the
/// drift assertion (CSEXC5).
///
/// The point of deriving export columns from reflection is that adding a column
/// to an entity adds it to the export with no other edit. That claim needs two
/// entity versions to be testable at all, and an entity cannot grow a field at
/// run time — so this is that version: identical to [FixtureExportRecord] but
/// for [owner]. A test asserting the derived column sets differ by exactly
/// `owner`, with no export-side change between them, is what makes the claim an
/// assertion rather than a comment.
@tomReflector
@TomAudited(redact: ['secret'])
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_export_v2',
  primaryKeyField: 'id',
)
class FixtureExportRecordV2 {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// A text column.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// A fractional column.
  @TomDbColumn(columnName: 'amount')
  double? amount;

  /// A truth column.
  @TomDbColumn(columnName: 'done')
  bool? done;

  /// A point in time.
  @TomDbColumn(columnName: 'created_at')
  DateTime? createdAt;

  /// A date whose Dart value is not a `DateTime`.
  @TomDbColumn(columnName: 'tag_day')
  TomZonedDate? tagDay;

  /// The redacted column.
  @TomDbColumn(columnName: 'secret')
  String? secret;

  /// The file-reference column.
  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'fixture/export')
  String? attachment;

  /// **The added column** — the whole point of this second version.
  @TomDbColumn(columnName: 'owner')
  String? owner;
}

/// A reflected entity that has **declared itself out** of the audit trail.
///
/// The escape hatch for high-volume machine-written tables (sessions, job runs)
/// whose mutations are noise rather than history. It is a declaration rather
/// than a call-site flag precisely so that its absence is auditable too — this
/// fixture exists to prove the reflector resolves it.
@tomReflector
@TomAudited(enabled: false)
class FixtureUnauditedRecord {
  /// An ordinary field; the type is never persisted, only reflected.
  String? note;
}
