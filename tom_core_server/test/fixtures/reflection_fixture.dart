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

/// A reflected entity with a file-reference column on a **row-scoped** table
/// (CSEXD2).
///
/// [FixtureDocumentRecord] declares no `@TomDbScope`, so every file test written
/// against it exercises C-4 (may this principal see this *column*) with C-3 (may
/// this principal see this *row*) switched off. This entity is the other half.
/// It is separate rather than an added annotation on the document fixture,
/// because an unscoped entity is the case the existing suite needs: adding a
/// scope there would make every one of those tests depend on a principal being
/// in the zone, and would delete the coverage that a file column works when no
/// scope is declared at all.
///
/// The scope is `owner` on [ownerId], the simplest resolver that discriminates:
/// `principal.id` must equal the row's `owner_id`. A file slot is addressed as
/// `<table>/<id>/<column>` with the id supplied by the caller, so this scope is
/// the only thing between a guessed id and another principal's document.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_scoped_document',
  primaryKeyField: 'id',
)
@TomDbScope(field: 'owner_id', scope: 'owner')
class FixtureScopedDocumentRecord {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// The scope field: the principal id that may see this row.
  @TomDbColumn(columnName: 'owner_id')
  int? ownerId;

  /// An ordinary column, so a scoped row is more than its file.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// The file column under scope. Exposed, so the same row is reachable through
  /// the HTTP file endpoint and the endpoint's status mapping can be asserted
  /// against it.
  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'fixture/scoped', exposed: true)
  String? attachment;
}

/// The MariaDB-backed repository for [FixtureScopedDocumentRecord].
class FixtureScopedDocumentRepository
    extends TomSqlDatasourceRepository<FixtureScopedDocumentRecord, int> {}

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

/// A reflected entity whose two file columns collide on a name (CSEXD3).
///
/// This is the shape `TomFileSlots._assertUnambiguous` exists to reject, built
/// so that the *consequence* of not rejecting it is visible and not merely
/// asserted about. A slot serves its column by handing the column's **declared**
/// name to the repository, and the repository resolves a file field by declared
/// name **or** mapped column name, first match wins in declaration order. So:
///
/// - [notes] is closed (`exposed:` defaults to `false`) and is *mapped* to the
///   column name `dossier`;
/// - [dossier] is exposed, and its *declared* name is `dossier`.
///
/// The exposed column would therefore publish the slot
/// `fixture_ambiguous_slot/<id>/public_dossier` and ask the repository for the
/// field `dossier` — which [notes], declared first, answers to. The published
/// column would serve the closed column's bytes: an exposure by accident, which
/// is precisely what the `exposed: false` default is supposed to make
/// impossible.
///
/// It maps to no table in `test_database.dart` and needs none — registration
/// fails before any row is ever read.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_ambiguous_slot',
  primaryKeyField: 'id',
)
class FixtureAmbiguousSlotRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// The closed column — declared *first*, so it is the one a lookup by the
  /// colliding name finds.
  @TomDbColumn(columnName: 'dossier')
  @TomFileReference(keyPrefix: 'fixture/ambiguous/closed')
  String? notes;

  /// The exposed column, whose declared name is the closed column's mapped one.
  @TomDbColumn(columnName: 'public_dossier')
  @TomFileReference(keyPrefix: 'fixture/ambiguous/open', exposed: true)
  String? dossier;
}

/// A reflected entity that holds an exposed file column but declares no
/// `@TomDbTable` (CSEXD3).
///
/// A slot is addressed as `<table>/<id>/<column>` and the table name comes from
/// the mapping, so an unmapped entity has no name to be addressed by. The
/// endpoint says so at wire-up time rather than resolving to something arbitrary
/// — the entity has no persistent identity at all, so `exposed: true` on it is a
/// declaration that cannot be honoured, not one to be honoured approximately.
///
/// Deliberately carries no `@TomDbColumn`: an entity with no table has no
/// persistent columns by definition, and annotating them would only assert that
/// two annotations disagree rather than that one is missing.
@tomReflector
class FixtureUnmappedFileRecord {
  /// Would-be identity, mapped by nothing.
  int? id;

  /// An exposed file column on an entity that has nowhere to live.
  @TomFileReference(keyPrefix: 'fixture/unmapped', exposed: true)
  String? attachment;
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

/// A reflected entity whose columns are `DECIMAL` (CSEXE1).
///
/// `DECIMAL` is the correct SQL type for money — it is exact where `DOUBLE` is
/// approximate — so this is the shape an ordinary business entity has, not an
/// exotic one. It is nonetheless the shape no fixture had: every other entity
/// here stores fractional values in a column the driver already converts, which
/// is why the driver's `NEWDECIMAL` gap stayed invisible on the entity-mapping
/// paths long after it was found and fixed for grouped rows.
///
/// The two numeric columns are deliberately different declarations over the
/// same SQL family:
///
/// - [amount] is `DECIMAL(10,2)` read into a Dart `double` — the money case;
/// - [quantity] is `DECIMAL(10,0)` read into a Dart `int` — the exact-integer
///   case, which is legitimate (`DECIMAL(n,0)` *is* an integer type, and wide
///   identifiers are often declared that way) and must therefore not be
///   rejected merely for being `DECIMAL`.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_amount',
  primaryKeyField: 'id',
)
class FixtureAmountRecord {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// A plain string column, so the entity has a non-numeric field to assert
  /// against and the failure can be localised to the numeric ones.
  @TomDbColumn(columnName: 'label')
  String? label;

  /// The money column: `DECIMAL(10,2)` bound to a Dart `double`.
  @TomDbColumn(columnName: 'amount')
  double? amount;

  /// The exact-integer column: `DECIMAL(10,0)` bound to a Dart `int`.
  @TomDbColumn(columnName: 'quantity')
  int? quantity;
}

/// The MariaDB-backed repository for [FixtureAmountRecord].
class FixtureAmountRepository
    extends TomSqlDatasourceRepository<FixtureAmountRecord, int> {}

/// A **table-less reflected result holder** with a `double` field (CSEXE1).
///
/// Carries no `@TomDbTable` and no `@TomDbColumn`, so the row mapper populates
/// it by matching *declared field names* against result-column names — the
/// third of the four entity-mapping variants, and the one an aggregate query
/// naturally lands on. `SUM(amount)` over a `DECIMAL` column is itself
/// `NEWDECIMAL`, so this type reaches the same driver gap by a different route
/// than [FixtureAmountRecord] does.
@tomReflector
class FixtureAmountSummary {
  /// The aggregate, projected as `total`.
  double? total;

  /// A row count projected as `entries`, so the holder covers an `int` field
  /// on the same path.
  int? entries;
}

/// A [TomClass]-shaped result holder with a `double` member (CSEXE1).
///
/// The first two entity-mapping variants map a [TomClass] by its *observable
/// members* rather than by reflected fields, and they are reached only by a
/// [TomClass] result type — which no fixture previously provided. Without this
/// type those two `typedColByName<double>` call sites are unreachable from any
/// test, and a fix to them would be unverifiable.
///
/// The members are the **non-nullable** observables deliberately. `TomObject<T>`
/// reports its element type as declared, so a `TomNDouble` answers `double?` —
/// which the mapper's `case double:` never matches, making it reject *every*
/// nullable observable member (a `TomNString` over a plain `VARCHAR` included).
/// That is a real defect but a different one, with nothing to do with
/// `DECIMAL`; it is tracked as CSEXF1. Using `TomDouble`/`TomInt` here keeps
/// this fixture pointed at the driver gap it exists to expose.
@tomReflector
class FixtureAmountObservable extends TomClass {
  /// The fractional member, matched to a result column named `amount`.
  final amount = TomDouble(0);

  /// An integer member, matched to a result column named `quantity`.
  final quantity = TomInt(0);
}
