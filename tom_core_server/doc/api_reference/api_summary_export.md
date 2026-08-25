# Tom Core Server API Reference: Export Module

The rendering and delivery half of reporting: a streaming tabular result in,
a byte stream out in CSV, XLSX or PDF, and the two delivery channels that hand
those bytes back to a caller or write them into storage.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomExportException](#tomexportexception)
  - [TomColumnType](#tomcolumntype)
  - [TomTabularColumn](#tomtabularcolumn)
  - [TomTabularRow](#tomtabularrow)
  - [TomTabularSection](#tomtabularsection)
  - [TomTabularResult](#tomtabularresult)
  - [TomTabularRenderer](#tomtabularrenderer)
  - [TomExportFormats](#tomexportformats)
  - [TomCsvRenderer](#tomcsvrenderer)
  - [TomXlsxRenderer](#tomxlsxrenderer)
  - [TomPdfRenderer](#tompdfrenderer)
  - [TomStoredExport](#tomstoredexport)
  - [TomExportStoreOperation](#tomexportstoreoperation)
  - [TomExportStore](#tomexportstore)
  - [TomDirectoryExportStore](#tomdirectoryexportstore)
  - [TomMemoryExportStore](#tommemoryexportstore)
  - [TomBlobExportStore](#tomblobexportstore)
  - [TomExportService](#tomexportservice)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/export/tabular_result.dart`,
`lib/src/tomserver/export/tabular_renderer.dart`,
`lib/src/tomserver/export/csv_renderer.dart`,
`lib/src/tomserver/export/xlsx_renderer.dart`,
`lib/src/tomserver/export/pdf_renderer.dart`,
`lib/src/tomserver/export/export_store.dart`,
`lib/src/tomserver/export/blob_export_store.dart`,
`lib/src/tomserver/export/export_service.dart`.

The module is three replaceable parts joined by one seam. A **shape** —
`TomTabularResult`, a title, metadata and one or more `TomTabularSection`s of
typed `TomTabularColumn`s over a `Stream<TomTabularRow>` — says what is being
exported, independent of format. A **format** — a `TomTabularRenderer` — turns
that shape into a `Stream<List<int>>`, independent of where the bytes go. A
**destination** — `TomExportService` over a `TomExportStore` — decides where
they go, independent of which format produced them. The seam between all three
is the byte stream, which is why a result larger than the server's heap can
still be exported.

Rows are a stream and cells are positional so that neither the input rows nor
the output document has to be resident. Validation happens at construction:
a result with no sections, a section with no columns, a duplicate or empty
column name all throw `TomExportException` while the caller who built it wrong
is still on the stack. For an export of entities,
`TomTabularSection.ofEntities` and `TomTabularResult.fromEntities` derive the
columns from a reflected entity's `@TomDbColumn` declarations instead of
requiring a hand-written projection, so the export has no second declaration to
drift from; `@TomAudited`-redacted fields and `@TomFileReference` columns are
left out by default.

Formats are a registry rather than a switch. `TomExportFormats` maps a format
id onto a renderer, `TomExportFormats.standard()` builds one holding
`TomCsvRenderer`, `TomXlsxRenderer` and `TomPdfRenderer`, and registering an
existing id replaces it. CSV and XLSX are written front-to-back and hold one
row at a time; PDF cannot, because the file ends with a cross-reference table
of byte offsets into everything before it, so `TomPdfRenderer` reports
`streamsRows` as `false` and states its `rowLimit` rather than discovering it.

Storage is a deliberately narrow four-method contract: put a stream under a
key, read it back, ask whether it is there, delete it. Those four methods are
final on `TomExportStore`; a backend implements `doStore`, `doOpen`, `doExists`
and `doDelete` instead. That split is what makes the interface's two promises
hold by construction rather than by each backend remembering them — every key is
validated before any backend sees it, so none can be handed a traversal, and
every backend failure is translated into a `TomExportException` carrying the
`TomExportStoreOperation` key for the operation that failed, so the same failure
reads the same way whichever backend is configured.
`TomDirectoryExportStore` writes to a sibling `.part` file and renames on
success, `TomMemoryExportStore` is the test and development backend, and
`TomBlobExportStore` puts the `file_storage` module's `TomBlobStore` behind the
same four methods — every configured blob backend at once. `TomExportService`
is the seam an endpoint calls: `respondWith` for the `apiResponse` channel,
`storeAs` for `fileExport`, and `render` for everything else.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomExportException

TomColumnType  (enum)
TomTabularColumn
TomTabularRow
TomTabularSection
TomTabularResult

TomTabularRenderer  (abstract)
    ├── TomCsvRenderer
    ├── TomXlsxRenderer
    └── TomPdfRenderer

TomExportFormats

TomExportStoreOperation  (enum)
TomExportStore  (abstract)
    ├── TomDirectoryExportStore
    ├── TomMemoryExportStore
    └── TomBlobExportStore

TomStoredExport
TomExportService
```

## Classes

### TomExportException

Raised when a result cannot be built, rendered or stored. Not client-visible by
default: an export failure describes server-side document generation, which
tells a caller nothing it can act on.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomExportException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  Object? stack,
  bool clientThrow = false,
})
```

### TomColumnType

The value types a tabular column may hold. The set is the one the query layer
already produces — `TomGroupedRow` maps exactly these five — so an aggregate
result adapts without a lossy conversion and no renderer meets a value it has
no rule for.

#### Values

| Value | Description |
| ----- | ----------- |
| `integer` | A whole number; rendered unquoted, right-aligned, as an XLSX number. Accepts `int`. |
| `decimal` | A fractional number; rendered unquoted, right-aligned, as an XLSX number. Accepts `double`. |
| `text` | Free text; the only type that needs quoting and escaping. Accepts `String`. |
| `boolean` | A truth value; rendered as `true`/`false`, as an XLSX boolean. Accepts `bool`. |
| `timestamp` | A point in time; rendered ISO-8601, as an XLSX date serial. Accepts `DateTime`. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `forValue` | `static TomColumnType? forValue(Object? value)` | The column type matching `value`'s runtime type, or `null` when it has none; used by adapters that infer columns from data rather than being told. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `dartType` | `Type` | The Dart type a cell of this column must hold (or `null`) (final). |

### TomTabularColumn

One typed column of a `TomTabularSection`: a machine-facing key, a human-facing
header, a value type and an optional width hint.

#### Constructors

```dart
TomTabularColumn(
  String name, {
  String? label,
  TomColumnType type = TomColumnType.text,
  int? width,
})
```

Throws `TomExportException` (`export.column.name_empty`) when `name` is empty.
`label` defaults to `name`, so the common case stays a one-argument call.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The machine-facing key: the query alias or map key this column reads (final). |
| `label` | `String` | The human-facing header text; defaults to `name` (final). |
| `type` | `TomColumnType` | The value type every cell in this column must hold (final). |
| `width` | `int?` | An optional presentation width hint in characters — a hint only: CSV ignores it, XLSX turns it into a column width, PDF into a relative column flex (final). |

### TomTabularRow

One row of a `TomTabularSection`: cell values positional to its columns. A
`List<Object?>` per row rather than a map, because rows are the one thing there
are many of.

#### Constructors

```dart
const TomTabularRow(List<Object?> cells)
```

The list is stored as given rather than copied, so callers must not mutate it
after handing it over.

#### Factory Constructors

```dart
factory TomTabularRow.fromMap(
  List<TomTabularColumn> columns,
  Map<String, Object?> values,
)
```

Reads `values` in the order `columns` declares. A missing key yields `null`; a
key no column names is ignored.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `cells` | `List<Object?>` | The cell values, parallel to the section's columns (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `cell` | `Object? cell(int index)` | The value in the column at `index`, or `null` when the row is short — a short row is tolerated so a cosmetic gap does not fail an export. |

### TomTabularSection

One titled table: typed columns over a stream of rows. The stream is
single-subscription and pulled once, in order, by whichever renderer runs.

#### Constructors

```dart
TomTabularSection({
  required List<TomTabularColumn> columns,
  required Stream<TomTabularRow> rows,
  String? title,
})
```

Throws `TomExportException` when `columns` is empty
(`export.section.no_columns`) or names the same column twice
(`export.section.duplicate_column`).

#### Factory Constructors

```dart
factory TomTabularSection.ofRows(
  List<TomTabularColumn> columns,
  Iterable<TomTabularRow> rows, {
  String? title,
})

factory TomTabularSection.ofMaps(
  List<TomTabularColumn> columns,
  Stream<Map<String, Object?>> rows, {
  String? title,
})
```

`ofRows` is the convenience for the small case — a summary table, a test
fixture — where streaming buys nothing. `ofMaps` is the adapter for anything
handing back values by name (a `TomGroupedRow`'s values, decoded JSON, a
driver's row map) and orders each map against `columns` once.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ofEntities` | `static TomTabularSection ofEntities<T>(Stream<T> rows, {String? title, List<String>? include, Set<String> exclude = const {}, Map<String, String> titles = const {}, bool includeFileReferences = false})` | Builds a section whose columns are derived from the reflected entity `T` and whose cells are read off each entity, so there is no hand-written projection to drift from the entity. See below. |

`ofEntities` turns every `@TomDbColumn` field of `T` into a column in
declaration order, keyed by **declared field name** (`createdAt`, not
`created_at`), typed from the field's declared type, and labelled from `titles`
or the field name. Association columns resolved through a join entity are not
columns of this table and are skipped. Rows stay lazy — deriving the columns
reads annotations, not rows, so nothing is pulled until a renderer subscribes —
and cells stay a positional list parallel to the columns.

Two kinds of column are not exported. A field named in `@TomAudited(redact: …)`
is dropped, and `include` cannot reach it: a value declared out of the audit
trail must not exist in a second place either. A `@TomFileReference` column is
dropped because it holds an internal storage key rather than content; pass
`includeFileReferences: true` to export the keys. `include`, when given,
selects the columns and their order but only narrows the exportable set — it
never widens it, so naming a redacted field (`export.entities.redacted_column`)
or, without the flag, a file-reference field
(`export.entities.file_reference_column`) throws. A name in `include`,
`exclude` or `titles` that no field carries throws
(`export.entities.unknown_column`), as does an entity that declares no columns
or is not registered with the reflector
(`export.entities.not_reflected`) and a selection that leaves nothing
(`export.entities.no_columns`).

The column type comes from the annotations' `TomSqlTypeFamily`, but only when
the declared Dart type can actually inhabit the candidate type — a JSON column
is text in the database and a `Map` in Dart, and an explicit `TomDbType` box
can disagree with the field it annotates. Otherwise the column is
`TomColumnType.text`, which every renderer formats through
`tomFormatCellAsText`.

`ofEntities` is bounded to the "these entities, these columns" case. A join, an
aggregate, or a computed or reformatted column keeps `ofRows` / `ofMaps`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `title` | `String?` | An optional table caption; becomes the XLSX sheet name and the PDF heading (final). |
| `columns` | `List<TomTabularColumn>` | The section's typed columns, in output order (final). |
| `rows` | `Stream<TomTabularRow>` | The section's rows — pulled once, in order, by whichever renderer runs (final). |

### TomTabularResult

A complete tabular result: a title, free-form metadata, and one or more
sections. The input every renderer consumes.

#### Constructors

```dart
TomTabularResult({
  required String title,
  required List<TomTabularSection> sections,
  Map<String, String> metadata = const {},
})
```

Throws `TomExportException` (`export.result.no_sections`) when `sections` is
empty. `metadata` is copied into an unmodifiable map.

#### Factory Constructors

```dart
factory TomTabularResult.single({
  required String title,
  required TomTabularSection section,
  Map<String, String> metadata = const {},
})
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fromEntities` | `static TomTabularResult fromEntities<T>(Stream<T> rows, {required String title, String? sectionTitle, Map<String, String> metadata = const {}, List<String>? include, Set<String> exclude = const {}, Map<String, String> titles = const {}, bool includeFileReferences = false})` | A single-section result whose columns are derived from the reflected entity `T`: the declarative counterpart of `single` over `TomTabularSection.ofEntities`, to which `include`, `exclude`, `titles` and `includeFileReferences` are forwarded along with `sectionTitle`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `title` | `String` | The document title: printed as the PDF heading and carried in that document's info dictionary, carried by XLSX as `dc:title` in the workbook's core properties, dropped by CSV, which has nowhere to put it (final). |
| `sections` | `List<TomTabularSection>` | The sections, in output order; one XLSX sheet each (final). |
| `metadata` | `Map<String, String>` | Unmodifiable name/value pairs describing how the result was produced — the filter, the account, the as-of timestamp. Each format puts it where it has room: PDF prints it as a header block, XLSX writes it to the workbook's custom document properties rather than to cells, and CSV drops it (final). |

### TomTabularRenderer

Renders a `TomTabularResult` to a byte stream in one concrete format. Bytes
rather than text because CSV is text, XLSX is a ZIP archive and PDF is binary;
a stream rather than a future so the same renderer feeds a shelf response, a
file sink or a blob upload without any of them waiting for the last row.

- **Extends:** none (abstract)

#### Constructors

```dart
const TomTabularRenderer()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `formatId` | `String` | *(getter)* The short, lowercase format key — `csv`, `xlsx`, `pdf` — that a query parameter carries and `TomExportFormats` registers under. |
| `mediaType` | `String` | *(getter)* The IANA media type to serve or store the output as. |
| `fileExtension` | `String` | *(getter)* The filename extension, without the dot. |
| `streamsRows` | `bool` | *(getter)* Whether the format renders in memory bounded by one row rather than all; `true` by default. Exposed because it is the one property a caller deciding whether to allow an export of a given size needs. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `Stream<List<int>> render(TomTabularResult result)` | Renders `result`, emitting the encoded document as it is produced. The stream is single-subscription, and errors surface on it rather than being thrown from the call. |
| `fileNameFor` | `String fileNameFor(String baseName)` | A filename for `baseName` in this format, with the extension applied. |

### TomExportFormats

The set of formats an application offers, keyed by
`TomTabularRenderer.formatId`. A registry rather than a switch, so an
application can add a format the export service knows nothing about.

#### Constructors

```dart
TomExportFormats()
```

#### Factory Constructors

```dart
factory TomExportFormats.standard()
```

Holds the three shipped formats. Constructed on demand rather than exposed as a
shared instance: a registry is mutable, and a process-wide mutable default is a
race between whichever modules register first.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `formatIds` | `Iterable<String>` | *(getter)* The registered format ids, in registration order. |
| `renderers` | `Iterable<TomTabularRenderer>` | *(getter)* The registered renderers, in registration order. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `void register(TomTabularRenderer renderer)` | Registers `renderer`, replacing any renderer with the same format id — a semicolon CSV for a European locale is still `csv` and should not need a new id. |
| `supports` | `bool supports(String formatId)` | Whether `formatId` is registered. |
| `rendererFor` | `TomTabularRenderer rendererFor(String formatId)` | The renderer for `formatId`; throws `TomExportException` (`export.format.unknown`) naming what is available, rather than returning `null`. |

### TomCsvRenderer

Renders a tabular result as RFC 4180 CSV, one row at a time. The baseline
format: no dependency, no document structure to close, and the fallback when a
richer format is unavailable. Multi-section results are concatenated with a
blank line and the section title between them.

- **Extends:** `TomTabularRenderer`

#### Constructors

```dart
const TomCsvRenderer({
  String fieldSeparator = ',',
  bool byteOrderMark = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `fieldSeparator` | `String` | The character between fields; `;` suits locales that use the comma as a decimal separator (final). |
| `byteOrderMark` | `bool` | Whether to emit a UTF-8 BOM before the first row. On by default, because Excel reads a BOM-less UTF-8 CSV in the system codepage; set `false` for pipelines that parse rather than open the file (final). |
| `formatId` | `String` | *(getter, override)* `csv`. |
| `mediaType` | `String` | *(getter, override)* `text/csv; charset=utf-8`. |
| `fileExtension` | `String` | *(getter, override)* `csv`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `Stream<List<int>> render(TomTabularResult result)` | *(override)* Emits the optional BOM, then per section a header row and one CRLF-terminated line per row. Fields are quoted where RFC 4180 requires. A title, a column label, or a cell whose value is not a `num`, `bool` or `DateTime` is additionally tab-prefixed when it starts `=`, `+`, `-` or `@`, so a spreadsheet does not treat an exported value as a formula. Numbers are exempt by *value* type rather than column type: a tab-prefixed field reads as text, which would cost a negative figure its arithmetic, while a `String` in a numeric column is a tolerated mismatch that still has to be guarded. |

### TomXlsxRenderer

Renders a tabular result as an Office Open XML workbook, one worksheet per
section, written straight to the wire. Inline strings and ZIP data descriptors
keep peak memory at one row of XML plus the deflate window; archive timestamps
are zero so the same result renders byte-identically. Sheet names are
sanitised, truncated to 31 characters and made unique, empty cells are omitted,
and a value whose type does not match its column renders as text rather than
failing. The result's `title` becomes `dc:title` in `docProps/core.xml` and its
`metadata` becomes user-defined properties in `docProps/custom.xml` — the
document properties rather than cells, so the header row stays at row 1
whatever the metadata holds. A result with no usable metadata names gets no
custom-properties part at all.

- **Extends:** `TomTabularRenderer`

#### Constructors

```dart
const TomXlsxRenderer({int compressionLevel = 6})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `compressionLevel` | `int` | The deflate level, 0 (store) to 9 (smallest); 6 is zlib's default and the right trade for tabular XML (final). |
| `formatId` | `String` | *(getter, override)* `xlsx`. |
| `mediaType` | `String` | *(getter, override)* `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`. |
| `fileExtension` | `String` | *(getter, override)* `xlsx`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `Stream<List<int>> render(TomTabularResult result)` | *(override)* Emits the fixed package parts — content types, relationships, `docProps/core.xml`, `docProps/custom.xml` when there is metadata, the workbook and its styles — then one worksheet part per section as its rows arrive, then the ZIP central directory. Numbers are numeric cells, booleans `t="b"`, timestamps Excel date serials computed from calendar fields. |

### TomPdfRenderer

Renders a tabular result as a paginated PDF document: the title, a metadata
block, and one bordered table per section with a repeating header row and a
`n / total` footer. The one format that cannot stream — a PDF ends with a
cross-reference table of byte offsets into everything before it, and column
widths are only known once every cell has been measured — so it states its
limits rather than discovering them.

- **Extends:** `TomTabularRenderer`

#### Constructors

```dart
const TomPdfRenderer({
  PdfPageFormat pageFormat = PdfPageFormat.a4,
  pw.PageOrientation orientation = pw.PageOrientation.portrait,
  int rowLimit = 20000,
  int maxPages = 2000,
  double baseFontSize = 8,
  pw.ThemeData? theme,
  bool compress = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `pageFormat` | `PdfPageFormat` | The paper size; use `PdfPageFormat.letter` for US output (final). |
| `orientation` | `pw.PageOrientation` | Portrait or landscape; landscape is worth it from about eight columns on (final). |
| `rowLimit` | `int` | The largest number of rows, across all sections, this renderer accepts. Exceeding it throws `TomExportException` (`export.pdf.row_limit_exceeded`) on the output stream rather than truncating (final). |
| `maxPages` | `int` | The page ceiling handed to `package:pdf`, whose own default is 20 (final). |
| `baseFontSize` | `double` | The body text size in points; header text is one point larger and bold (final). |
| `theme` | `pw.ThemeData?` | An optional theme, typically supplying an embedded Unicode font — needed for text outside Latin-1, since the default base-14 Helvetica encodes only WinAnsi (final). |
| `compress` | `bool` | Whether to deflate the document's object streams; `false` leaves the text readable in a hex dump (final). |
| `formatId` | `String` | *(getter, override)* `pdf`. |
| `mediaType` | `String` | *(getter, override)* `application/pdf`. |
| `fileExtension` | `String` | *(getter, override)* `pdf`. |
| `streamsRows` | `bool` | *(getter, override)* `false` — the document is laid out whole before any byte can be emitted. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `Stream<List<int>> render(TomTabularResult result)` | *(override)* Pulls and formats every section's rows, lays the document out, and yields it as a single chunk. Numeric columns are right-aligned; a column's `width` hint becomes its flex factor, with 1 for a column that has none. |

### TomStoredExport

A stored export: what was written, where, and how big it turned out. Returned
by `TomExportStore.store` rather than assembled by the caller, because
`byteCount` is only known once the stream has drained.

#### Constructors

```dart
const TomStoredExport({
  required String key,
  required String mediaType,
  required int byteCount,
  required DateTime storedAt,
  Uri? location,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The key the export was stored under, as given to `TomExportStore.store` (final). |
| `mediaType` | `String` | The IANA media type the bytes should be served as (final). |
| `byteCount` | `int` | The number of bytes written (final). |
| `storedAt` | `DateTime` | When the write completed (final). |
| `location` | `Uri?` | A backend-specific address — a `file:` URI, an object-store URL — useful for a human chasing an export down, but never the thing to read it back with (final). |

### TomExportStoreOperation

The four things an export store does, and how each one reports a failure. The
keys are named here rather than spelled at each throw site so that the same
failure of the same operation carries the same key whichever backend is
configured — which is the entire promise `TomExportStore` makes by being an
interface at all.

#### Values

| Value | Description |
| ----- | ----------- |
| `write` | Writing an export: `TomExportStore.store`. Key `export.store.write_failed`. |
| `read` | Reading one back: `TomExportStore.open`. Key `export.store.read_failed`. |
| `probe` | Asking whether one is there: `TomExportStore.exists`. Key `export.store.probe_failed`. |
| `delete` | Removing one: `TomExportStore.delete`. Key `export.store.delete_failed`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `errorKey` | `String` | The `export.store.*` key a failure of this operation carries (final). |
| `message` | `String` | The default user-facing message for that key (final). |

### TomExportStore

Stores and retrieves rendered exports by key. Deliberately not a general file
store: put a stream under a key, read it back, ask whether it is there, delete
it — no directories to list, no metadata to update, no partial reads.

The four public methods are final, and a backend implements the `do*` hooks
beside them. Both of the interface's guarantees then hold by construction: every
key is validated before any backend sees it, and every failure a backend raises
is translated into a `TomExportException` carrying the operation's key. Both
were previously left to each backend to honour, and each honoured a different
subset of them.

- **Extends:** none (abstract)

#### Constructors

```dart
const TomExportStore()
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `validateKey` | `static String validateKey(String key)` | Returns `key` after checking it against `TomBlobStore.isValidKey` — relative, slash-separated, unreserved characters — so no backend can be handed a directory traversal. Throws `TomExportException` (`export.store.invalid_key`) otherwise. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `store` | `Future<TomStoredExport> store({required String key, required Stream<List<int>> bytes, required String mediaType})` | Writes `bytes` under `key`, replacing anything already there. A failed write leaves nothing readable under `key`. Validates the key, dispatches to `doStore`, and reports any failure as `export.store.write_failed`. |
| `open` | `Stream<List<int>> open(String key)` | Reads the export stored under `key`; throws `TomExportException` when the key holds nothing, rather than disguising a missing export as an empty file. Validates the key, dispatches to `doOpen`, and reports any other failure as `export.store.read_failed`. |
| `exists` | `Future<bool> exists(String key)` | Whether `key` currently holds an export. Validates the key, dispatches to `doExists`, and reports any failure as `export.store.probe_failed`. |
| `delete` | `Future<bool> delete(String key)` | Deletes `key`, returning whether anything was there to delete. Validates the key, dispatches to `doDelete`, and reports any failure as `export.store.delete_failed`. |
| `doStore` | `Future<TomStoredExport> doStore({required String key, required Stream<List<int>> bytes, required String mediaType})` | Implemented by backends; called by `store` with an already-validated `key`. May fail in its own vocabulary — the caller never sees it. |
| `doOpen` | `Stream<List<int>> doOpen(String key)` | Implemented by backends; called by `open` with an already-validated `key`. Raising `export.store.not_found` is the one error a backend must produce itself, because only it knows the difference between absent and unreadable. |
| `doExists` | `Future<bool> doExists(String key)` | Implemented by backends; called by `exists` with an already-validated `key`. |
| `doDelete` | `Future<bool> doDelete(String key)` | Implemented by backends; called by `delete` with an already-validated `key`. |

### TomDirectoryExportStore

An export store over a directory tree on the local filesystem — the backend
that needs no infrastructure. Keys become paths beneath `root`, so
`2026/07/sales.xlsx` is a file two directories down.

- **Extends:** `TomExportStore`

#### Constructors

```dart
TomDirectoryExportStore(Directory root)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `root` | `Directory` | The directory every key resolves beneath; created on demand (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `doStore` | `Future<TomStoredExport> doStore({required String key, required Stream<List<int>> bytes, required String mediaType})` | *(override)* Writes to a sibling `.part` file and renames on success, so a reader sees either the previous export or the complete new one. The rename is inside the guarded region, so a cross-device destination or a name already taken leaves no partial behind; the failure reaches the caller as `export.store.write_failed`. |
| `doOpen` | `Stream<List<int>> doOpen(String key)` | *(override)* Streams the file for `key`; throws `TomExportException` (`export.store.not_found`) when it does not exist. |
| `doExists` | `Future<bool> doExists(String key)` | *(override)* Whether the file for `key` exists. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Deletes the file for `key`, returning `false` when it was not there. |

### TomMemoryExportStore

An export store that keeps its contents in memory, for tests and for a
development server that should not leave files behind. It buffers whole exports
by definition, which is why it is not the default.

- **Extends:** `TomExportStore`

#### Constructors

```dart
TomMemoryExportStore()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `keys` | `Iterable<String>` | *(getter)* The keys currently held, in insertion order. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `descriptorFor` | `TomStoredExport? descriptorFor(String key)` | The descriptor recorded for `key`, or `null` when it holds nothing. Throws `TomExportException` (`export.store.invalid_key`) for a key the store would not have accepted, rather than answering `null` — `null` means *this valid key holds nothing*. |
| `textOf` | `String textOf(String key)` | The stored bytes for `key` decoded as UTF-8 (malformed input allowed), for tests that assert on content; throws `TomExportException` (`export.store.not_found`) when the key holds nothing, or (`export.store.invalid_key`) when it is not a valid key. |
| `doStore` | `Future<TomStoredExport> doStore({required String key, required Stream<List<int>> bytes, required String mediaType})` | *(override)* Drains `bytes` into a buffer and records the descriptor, publishing neither until the stream completes — so a failed write leaves nothing readable here either. |
| `doOpen` | `Stream<List<int>> doOpen(String key)` | *(override)* Yields the buffered bytes for `key`; throws `TomExportException` (`export.store.not_found`) when it holds nothing. |
| `doExists` | `Future<bool> doExists(String key)` | *(override)* Whether `key` is held. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Drops the content and descriptor for `key`, returning whether anything was there. |

### TomBlobExportStore

A `TomExportStore` backed by the `file_storage` module's `TomBlobStore`, so an
export can be written to a database, an S3 bucket, a directory or an
application's own backend — chosen in configuration — without the export module
knowing any of them exist.

- **Extends:** `TomExportStore`

#### Constructors

```dart
TomBlobExportStore(TomBlobStore blobStore, {String keyPrefix = ''})
```

Throws `TomExportException` (`export.store.invalid_key`, parameter `keyPrefix`)
when `keyPrefix` is not a usable namespace. The rule is `TomBlobStore`'s —
`isValidKeyPrefix` — because the prefixed key is what a backend has to accept;
the exception type is the export module's, because configuring an export store
should not require catching a storage error to learn the setting is wrong.

#### Factory Constructors

```dart
factory TomBlobExportStore.named(String? name, {String keyPrefix = ''})
```

Wraps the blob store registered under `name`, or the default store when `name`
is `null` — the constructor a configured deployment uses, and so the one a bad
prefix arrives through. It delegates to the unnamed constructor, so the prefix
check applies here too.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `blobStore` | `TomBlobStore` | The blob store the exports are kept in; named `blobStore` because `store` is this interface's write method (final). |
| `keyPrefix` | `String` | The prefix prepended to every key before it reaches `blobStore`, namespacing exports inside a store that holds other things and making a retention rule expressible as a prefix. `''` when there is none. Both halves of the joined key are checked, in the two places each belongs: the caller's key on every call and *before* prefixing, the prefix once at construction (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `doStore` | `Future<TomStoredExport> doStore({required String key, required Stream<List<int>> bytes, required String mediaType})` | *(override)* Puts the stream into the blob store under the prefixed key and returns a descriptor carrying the caller's own key, so it can be passed back to `open`. |
| `doOpen` | `Stream<List<int>> doOpen(String key)` | *(override)* Streams the blob for the prefixed key, translating `storage.blob.not_found` into `TomExportException` (`export.store.not_found`) — the only blob failure it names, because absence is the one thing the base class cannot recognise. Every other storage failure falls through to `open`, which reports it as `export.store.read_failed`. |
| `doExists` | `Future<bool> doExists(String key)` | *(override)* Delegates to the blob store with the prefixed key. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Delegates to the blob store with the prefixed key. |

### TomExportService

The seam an endpoint calls: it knows the registered formats and, optionally,
where stored exports go, so a caller asks for "this result, as `xlsx`" and gets
back either a response or a stored-file reference. Thin on purpose — everything
hard is in the renderers or the store.

#### Constructors

```dart
TomExportService({
  TomExportFormats? formats,
  TomExportStore? store,
})
```

`formats` defaults to `TomExportFormats.standard()`. `store` is optional: an
application that only streams exports back through its API never needs one.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `sanitiseFileName` | `static String sanitiseFileName(String fileName)` | Makes `fileName` safe inside a quoted header parameter: everything outside printable ASCII, plus `"`, `\`, `;` and `/`, becomes `_`, and an empty result becomes `export`. Non-ASCII is transliterated away because `filename=` is a Latin-1 field. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `formats` | `TomExportFormats` | The formats this service can produce (final). |
| `store` | `TomExportStore?` | Where `storeAs` writes, when the application has somewhere to write (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `Stream<List<int>> render(TomTabularResult result, String format)` | Renders `result` as `format` to a byte stream — the primitive both channels are built on, and the one to call when neither fits. |
| `respondWith` | `Response respondWith(TomTabularResult result, String format, {required String baseName, bool inline = false})` | The `apiResponse` channel: a shelf response whose body is the renderer's stream, with the content type and a `Content-Disposition` naming `baseName` plus the format's extension. Unbuffered and without a `Content-Length`, so shelf falls back to chunked transfer encoding. `inline` switches the disposition from `attachment`, which is worth doing only for PDF. |
| `storeAs` | `Future<TomStoredExport> storeAs(TomTabularResult result, String format, {required String key})` | The `fileExport` channel: renders `result` as `format` into `store` under `key` and returns the descriptor. Throws `TomExportException` (`export.service.no_store`) when no store is configured. |
| `keyFor` | `String keyFor(String baseName, String format, {DateTime? partitionOn})` | A validated storage key for `baseName` in `format`; with `partitionOn` it is prefixed `yyyy/MM/dd/`, so exports do not accumulate in one unlistable directory and expiry becomes a prefix deletion. |

## Global Functions and Constants

### Constants

None — this module exposes no top-level constants.

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `tomFormatCellAsText` | `String tomFormatCellAsText(Object? value)` | The shared text rule for the text-oriented renderers: `null` is empty, a `DateTime` is ISO-8601, a whole `double` drops its trailing `.0` so it does not read as an approximation, and everything else is `toString()`. |
