# Tom Core Server API Reference: Export Module

The rendering and delivery half of reporting: a streaming tabular result in,
a byte stream out in CSV, XLSX or PDF with charts of the result's own rows, the
delivery channels that hand those bytes back to a caller, write them into
storage or send them by email, and the register of stored exports that a
per-owner quota and a retention purge work from.

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
  - [TomChartType](#tomcharttype)
  - [TomTabularChart](#tomtabularchart)
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
  - [TomExportEmailMode](#tomexportemailmode)
  - [TomExportEmailDelivery](#tomexportemaildelivery)
  - [TomExportRecord](#tomexportrecord)
  - [TomExportUsage](#tomexportusage)
  - [TomExportRegister](#tomexportregister)
  - [TomMemoryExportRegister](#tommemoryexportregister)
  - [TomSqlExportRegister](#tomsqlexportregister)
  - [TomExportRecordRow](#tomexportrecordrow)
  - [TomExportUsageRow](#tomexportusagerow)
  - [TomExportQuota](#tomexportquota)
  - [TomExportRetention](#tomexportretention)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/export/tabular_result.dart`,
`lib/src/tomserver/export/tabular_renderer.dart`,
`lib/src/tomserver/export/csv_renderer.dart`,
`lib/src/tomserver/export/xlsx_renderer.dart`,
`lib/src/tomserver/export/pdf_renderer.dart`,
`lib/src/tomserver/export/export_store.dart`,
`lib/src/tomserver/export/blob_export_store.dart`,
`lib/src/tomserver/export/export_service.dart`,
`lib/src/tomserver/export/export_email.dart`,
`lib/src/tomserver/export/export_register.dart`,
`lib/src/tomserver/export/export_register_sql.dart`.

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
left out by default. A section may carry `TomTabularChart`s — bar, line or pie
charts naming its own columns — which the PDF renderer draws below the table,
the XLSX renderer writes as native charts bound to the sheet's cells, and CSV
leaves out.

Formats are a registry rather than a switch. `TomExportFormats` maps a format
id onto a renderer, `TomExportFormats.standard()` builds one holding
`TomCsvRenderer`, `TomXlsxRenderer` and `TomPdfRenderer`, and registering an
existing id replaces it. CSV and XLSX are written front-to-back and hold one
row at a time; PDF cannot, because the file ends with a cross-reference table
of byte offsets into everything before it, so `TomPdfRenderer` reports
`streamsRows` as `false` and states its `rowLimit` rather than discovering it.

Storage is a deliberately narrow contract: put a stream under a key, read it
back, ask whether it is there, delete it, and reclaim a whole prefix. Those
methods are final on `TomExportStore`; a backend implements `doStore`, `doOpen`,
`doExists`, `doDelete` and — when it can — `doDeletePrefix` instead. There is no
listing: enumerating what was stored is the `TomExportRegister`'s, not
storage's. That split is what makes the interface's two promises
hold by construction rather than by each backend remembering them — every key is
validated before any backend sees it, so none can be handed a traversal, and
every backend failure is translated into a `TomExportException` carrying the
`TomExportStoreOperation` key for the operation that failed, so the same failure
reads the same way whichever backend is configured.
`TomDirectoryExportStore` writes to a sibling `<key>~part` file and renames on
success, `TomMemoryExportStore` is the test and development backend, and
`TomBlobExportStore` puts the `file_storage` module's `TomBlobStore` behind the
same contract — every configured blob backend at once. `TomExportService`
is the seam an endpoint calls: `respondWith` for the `apiResponse` channel,
`storeAs` for `fileExport`, and `render` for everything else.
`TomExportEmailDelivery` is the `email` channel: it sends a stored export as a
link or an attachment through the messaging module's `TomMessageOutbox`.

Given a `TomExportRegister`, `storeAs` records every export it stores — owner,
size, media type, time, title — in `TomMemoryExportRegister` or the relational
`TomSqlExportRegister` (table `tom_export`). A `TomExportQuota` caps what one
owner holds, checked before rendering and again after the store, and
`TomExportRetention` deletes exports older than a maximum age, by hand or as a
scheduled job.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomExportException

TomColumnType  (enum)
TomTabularColumn
TomTabularRow
TomTabularSection
TomTabularResult
TomChartType  (enum)
TomTabularChart

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

TomExportEmailMode  (enum)
TomExportEmailDelivery

TomExportRegister  (abstract)
    ├── TomMemoryExportRegister
    └── TomSqlExportRegister
TomExportRecord
TomExportUsage
TomExportRecordRow
TomExportUsageRow
TomExportQuota
TomExportRetention
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
  StackTrace? stack,
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

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `dartType` | `Type` | The Dart type a cell of this column must hold (or `null`). Load-bearing rather than descriptive: `TomTabularSection.ofEntities` derives a candidate type from the field's SQL type family and keeps it only when the declared Dart type can inhabit it, so this is what stops a JSON column typed `text` in the database being exported as anything other than text (final). |
| `naturalWidth` | `int` | How wide a cell of this type renders, in characters — `integer` 11, `decimal` 12, `text` 16, `boolean` 5, `timestamp` 23. Measured against what this package emits, not against the type's range, and used as the width of a column that states none (final). |

### TomTabularColumn

One typed column of a `TomTabularSection`: a machine-facing key, a human-facing
header, a value type and an optional width in characters.

#### Constructors

```dart
TomTabularColumn(
  String name, {
  String? label,
  TomColumnType type = TomColumnType.text,
  int? width,
})
```

Throws `TomExportException` (`export.column.name_empty`) when `name` is empty,
and (`export.column.invalid_width`) when `width` is given but below one — a
count of characters cannot be zero or negative, and 0 hides the column in a
spreadsheet and collapses it on a page. `label` defaults to `name`, so the
common case stays a one-argument call.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The machine-facing key: the query alias or map key this column reads (final). |
| `label` | `String` | The human-facing header text; defaults to `name` (final). |
| `type` | `TomColumnType` | The value type every cell in this column must hold (final). |
| `width` | `int?` | How wide the column should be, **in characters, in every format**; `null` to let the type and label decide. Not a proportion — a sheet has no total width to be a proportion of. CSV ignores it; XLSX writes it as the OOXML column width, whose unit is already a character count; PDF, whose page total is fixed, cannot honour it literally and keeps the *ratio* between columns instead. Must be at least 1 (final). |
| `effectiveWidth` | `int` | *(getter)* The width this column is actually laid out at: `width` when it states one, otherwise the larger of `type.naturalWidth` and the label's length, capped at `maxDerivedWidth`. Both renderers read this rather than `width`, which is what makes an unhinted column mean the same thing in a spreadsheet and on a page. |

#### Static Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `maxDerivedWidth` | `int` | The ceiling on a *derived* width, 40 characters, so that one long heading cannot squeeze every other column off the page. An explicit `width` is never capped: a caller who asks for 200 knows something about the data that this does not. |

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
  List<TomTabularChart> charts = const [],
})
```

Throws `TomExportException` when `columns` is empty
(`export.section.no_columns`) or names the same column twice
(`export.section.duplicate_column`), and checks every chart against the columns
(`TomTabularChart.validateAgainst`, keys `export.chart.*`). `charts` is copied
into an unmodifiable list.

#### Factory Constructors

```dart
factory TomTabularSection.ofRows(
  List<TomTabularColumn> columns,
  Iterable<TomTabularRow> rows, {
  String? title,
  List<TomTabularChart> charts = const [],
})

factory TomTabularSection.ofMaps(
  List<TomTabularColumn> columns,
  Stream<Map<String, Object?>> rows, {
  String? title,
  List<TomTabularChart> charts = const [],
})
```

`ofRows` is the convenience for the small case — a summary table, a test
fixture — where streaming buys nothing. `ofMaps` is the adapter for anything
handing back values by name (a `TomGroupedRow`'s values, decoded JSON, a
driver's row map) and orders each map against `columns` once.

Both take their columns from the caller; **neither infers them from the rows**.
Inference would mean reading the first row to learn the shape, and a first row
is the worst available witness — a `null` cell declares nothing, so a column
would be typed by whichever row arrived first and every later row formatted
under that guess. It is also unavailable: a section's columns must exist before
its stream is subscribed, so an inferring constructor would be the one in the
family that had to be awaited. The same argument governs widths, which
`effectiveWidth` takes from the schema rather than measuring the data. A caller
that wants derived columns has `ofEntities`, which reads a declaration.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ofEntities` | `static TomTabularSection ofEntities<T>(Stream<T> rows, {String? title, List<String>? include, Set<String> exclude = const {}, Map<String, String> titles = const {}, bool includeFileReferences = false, List<TomTabularChart> charts = const []})` | Builds a section whose columns are derived from the reflected entity `T` and whose cells are read off each entity, so there is no hand-written projection to drift from the entity. See below. |

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
| `charts` | `List<TomTabularChart>` | The charts drawn from this section's rows, in output order; unmodifiable, empty by default (final). |

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

### TomChartType

The kinds of chart a `TomTabularChart` draws.

#### Values

| Value | Description |
| ----- | ----------- |
| `bar` | Vertical bars, one group per category, one bar per series. |
| `line` | One line per series across the categories. |
| `pie` | One slice per category, of exactly one series. |

### TomTabularChart

A chart of a section's own rows, drawn beside its table. It names columns of its
section rather than carrying data, so it plots exactly the rows the table shows:
`categoryColumn` labels the points, each of `valueColumns` is one series, and
every row is a point. PDF draws it as vector graphics below the table; XLSX as a
native chart on the section's sheet, bound to the exported cells so a recipient
can restyle it; CSV leaves it out.

#### Constructors

```dart
const TomTabularChart({
  required TomChartType type,
  required String categoryColumn,
  required List<String> valueColumns,
  String? title,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `TomChartType` | What kind of chart (final). |
| `categoryColumn` | `String` | The `TomTabularColumn.name` labelling each point (final). |
| `valueColumns` | `List<String>` | The `TomTabularColumn.name`s of the series — numeric columns, exactly one for a pie (final). |
| `title` | `String?` | The chart's caption, or `null` for none: printed above the chart in a PDF, the chart title in XLSX (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `validateAgainst` | `void validateAgainst(List<TomTabularColumn> columns)` | Throws `TomExportException` unless the chart can be drawn from `columns`: `export.chart.unknown_column` for a category or value column not among them, `export.chart.no_series` for no value column, `export.chart.pie_series` for a pie with other than one, `export.chart.not_numeric` for a series that is not an `integer` or `decimal` column. Called by every `TomTabularSection` constructor. |

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
| `streamsRows` | `bool` | *(getter)* Whether the format renders in memory bounded by one row rather than all; `true` by default. Exposed because it is the one property a caller deciding whether to allow an export of a given size needs. Declaring it `true` promises that a row is not read once the next has been pulled — rows are handed over uncopied — and that output is not held back. |

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
const TomXlsxRenderer({
  int compressionLevel = 6,
  int maxRowsPerSheet = 1048576,
  int maxColumnsPerSheet = 16384,
  int maxPartBytes = 0xFFFFFFFF,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `compressionLevel` | `int` | The deflate level, 0 (store) to 9 (smallest); 6 is zlib's default and the right trade for tabular XML (final). |
| `maxRowsPerSheet` | `int` | Excel's own row limit per worksheet, header included. Exceeding it throws `TomExportException` (`export.xlsx.too_many_rows`) on the row that crosses the line, naming csv as the alternative (final). |
| `maxColumnsPerSheet` | `int` | Excel's own column limit per worksheet. Exceeding it throws `TomExportException` (`export.xlsx.too_many_columns`) before any row is pulled, since the columns are known up front (final). |
| `maxPartBytes` | `int` | The width of the ZIP header fields this writer emits. There is no ZIP64 here, so a size, offset or directory past this would wrap silently rather than fail; `export.xlsx.archive_too_large` names the part and the measure instead (final). |
| `formatId` | `String` | *(getter, override)* `xlsx`. |
| `mediaType` | `String` | *(getter, override)* `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`. |
| `fileExtension` | `String` | *(getter, override)* `xlsx`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `Stream<List<int>> render(TomTabularResult result)` | *(override)* Emits the fixed package parts — content types, relationships, `docProps/core.xml`, `docProps/custom.xml` when there is metadata, the workbook and its styles — then one worksheet part per section as its rows arrive, followed, for a section with charts, by its drawing (the charts anchored right of the table and stacked downwards) and one `xl/charts/` part per chart, its series bound to the sheet's cells by absolute references; then the ZIP central directory. Numbers are numeric cells, booleans `t="b"`, timestamps Excel date serials computed from calendar fields. Every column gets a `<col width>` from its `effectiveWidth` — OOXML's unit is already a character count — rather than only the hinted ones, since Excel's 8.43 default shows an ISO timestamp as `#####`. |

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
  double chartHeight = 180,
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
| `theme` | `pw.ThemeData?` | An optional theme, typically supplying an embedded Unicode font — needed for text outside Latin-1, since the default base-14 Helvetica encodes only WinAnsi. Also the only way to stop `package:pdf`'s `has no Unicode support` diagnostic, which it prints twice per document from inside an `assert` and so never emits in a deployment (final). |
| `compress` | `bool` | Whether to deflate the document's object streams; `false` leaves the text readable in a hex dump (final). |
| `chartHeight` | `double` | How high a chart is drawn, in points (final). |
| `formatId` | `String` | *(getter, override)* `pdf`. |
| `mediaType` | `String` | *(getter, override)* `application/pdf`. |
| `fileExtension` | `String` | *(getter, override)* `pdf`. |
| `streamsRows` | `bool` | *(getter, override)* `false` — the document is laid out whole before any byte can be emitted. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `Stream<List<int>> render(TomTabularResult result)` | *(override)* Pulls and formats every section's rows, lays the document out, and yields it as a single chunk. Each section's charts follow its table, drawn with `package:pdf`'s chart widgets — a `null` cell is no point, a pie slice of zero or less is left out, and a chart of several series has a legend. Numeric columns are right-aligned; every column's `effectiveWidth` becomes its flex factor, so the character counts survive the page fit as a ratio. They are deliberately not converted to points first: flex is scale invariant, so a single conversion factor would cancel exactly across all columns. |

### TomStoredExport

A stored export: what was written, where, and how big it turned out. Returned
by `TomExportStore.store` rather than assembled by the caller, because
`byteCount` is only known once the stream has drained.

#### Constructors

```dart
TomStoredExport({
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
| `storedAt` | `DateTime` | When the write completed, always in UTC — the constructor normalises it, so the three backends agree (final). |
| `location` | `Uri?` | A backend-specific address — a `file:` URI, an object-store URL — useful for a human chasing an export down, but never the thing to read it back with (final). |

### TomExportStoreOperation

The five things an export store does, and how each one reports a failure. The
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
| `deletePrefix` | Removing a whole partition: `TomExportStore.deletePrefix`. Key `export.store.prefix_delete_failed`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `errorKey` | `String` | The `export.store.*` key a failure of this operation carries (final). |
| `message` | `String` | The default user-facing message for that key (final). |

### TomExportStore

Stores and retrieves rendered exports by key. Deliberately not a general file
store: put a stream under a key, read it back, ask whether it is there, delete
it, reclaim a prefix — no metadata to update, no partial reads, and no listing.

The public methods are final, and a backend implements the `do*` hooks beside
them. Both of the interface's guarantees then hold by construction: every key is
validated before any backend sees it, and every failure a backend raises is
translated into a `TomExportException` carrying the operation's key. Leaving
either to the backends is what makes them differ — a guarantee every implementor
must remember is one some implementor does not.

The missing listing is a decision rather than an omission. A listing is a
paginated call over an object store and a scan over a blob table, and neither
answers which export, rendered for whom, is old enough to purge. `TomStoredExport`
is a row, and the deployment that keeps one per export enumerates from there and
The enumeration is `TomExportRegister`'s, which `TomExportService.storeAs` writes
and `TomExportRetention` purges from, deleting key by key — so the purge runs on
every backend, including the ones that cannot prefix-delete. See
`example/export/export_retention.dart`.

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
| `open` | `Stream<List<int>> open(String key)` | Reads the export stored under `key`; throws `TomExportException` when the key holds nothing, rather than disguising a missing export as an empty file. Validates the key, dispatches to `doOpen`, and reports any other failure as `export.store.read_failed`. A transfer that breaks partway still delivers the chunks that arrived and *then* throws — the same contract `TomBlobStore.get` states, for the same reason. |
| `exists` | `Future<bool> exists(String key)` | Whether `key` currently holds an export. Validates the key, dispatches to `doExists`, and reports any failure as `export.store.probe_failed`. |
| `delete` | `Future<bool> delete(String key)` | Deletes `key`, returning whether anything was there to delete. Validates the key, dispatches to `doDelete`, and reports any failure as `export.store.delete_failed`. |
| `deletePrefix` | `Future<int> deletePrefix(String prefix)` | Deletes every export under `prefix`, returning how many went — the reclaim primitive the day partitioning `keyFor` writes exists for. Matched by key **segment**: `2026/07` never reaches `2026/070`. An empty prefix is refused (`export.store.invalid_key`), and a store whose `supportsPrefixDelete` is `false` throws `export.store.prefix_delete_unsupported` naming the backend rather than answering `0`. |
| `doDeletePrefix` | `Future<int> doDeletePrefix(String prefix)` | Implemented by backends declaring the capability; called by `deletePrefix` with a validated, non-empty prefix. The default throws, so a backend that claims the capability and forgets the method fails loudly rather than reporting an empty purge. |
| `doStore` | `Future<TomStoredExport> doStore({required String key, required Stream<List<int>> bytes, required String mediaType})` | Implemented by backends; called by `store` with an already-validated `key`. May fail in its own vocabulary — the caller never sees it. A chunk from `bytes` is borrowed for the duration of the `await`: consume or copy it before asking for the next, never retain it. |
| `doOpen` | `Stream<List<int>> doOpen(String key)` | Implemented by backends; called by `open` with an already-validated `key`. Raising `export.store.not_found` is the one error a backend must produce itself, because only it knows the difference between absent and unreadable. Each chunk belongs to the caller: writable, and aliased with nothing the backend keeps. |
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

Touches no filesystem. `root` is created by the first `store` call, together
with whatever directories that call's key names — one `create(recursive: true)`
covers both. The read paths never create it: `open` on a missing root is
`export.store.not_found`, and `exists` and `delete` answer `false`.

Deferring the creation is what makes a store safe to configure at startup — a
constructor cannot await, so creating the root there would mean a blocking
`createSync` on a possibly slow mount, thrown from a field initialiser on a
store the application may never write to. It also means the root is recreated if
it goes away (a remounted volume, a reaped tmpfs), where a store that made it
once would report itself configured and fail every write after.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `partialSuffix` | `static const String` | The suffix a write stages under before renaming into place, `~part` — hung off `TomBlobStore.auxiliaryMarker`, which `validateKey` cannot admit, so the staging file is unreachable from the key space. With the obvious `<key>.part` it was not: storing `a.csv` overwrote the export held under the valid key `a.csv.part` and then renamed it away. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `root` | `Directory` | The directory every key resolves beneath; created on demand by the first `store`, never by a read (final). |
| `supportsPrefixDelete` | `bool` | *(override)* `true` — keys are paths beneath `root`, so a day partition is a directory and `deletePrefix` removes its tree. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `doStore` | `Future<TomStoredExport> doStore({required String key, required Stream<List<int>> bytes, required String mediaType})` | *(override)* Writes to a sibling `<key>~part` file and renames on success, so a reader sees either the previous export or the complete new one. The rename is inside the guarded region, so a cross-device destination or a name already taken leaves no partial behind; the failure reaches the caller as `export.store.write_failed`. |
| `doOpen` | `Stream<List<int>> doOpen(String key)` | *(override)* Streams the file for `key`; throws `TomExportException` (`export.store.not_found`) when it does not exist. |
| `doExists` | `Future<bool> doExists(String key)` | *(override)* Whether the file for `key` exists. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Deletes the file for `key`, returning `false` when it was not there. |

### TomMemoryExportStore

An export store that keeps its contents in memory, for tests and for a
development server that should not leave files behind. It buffers whole exports
by definition, which is why it is not the default.

Holding the bytes rather than reading them off a disk makes it the only backend
that could hand a caller a reference into its own state, so it is the only one
that has to copy on purpose — on the way in and on the way out.

- **Extends:** `TomExportStore`

#### Constructors

```dart
TomMemoryExportStore()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `keys` | `Iterable<String>` | *(getter)* The keys currently held, in insertion order. |
| `supportsPrefixDelete` | `bool` | *(override)* `true` — it holds its own key space, so a prefix delete is a scan of the keys it has. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `descriptorFor` | `TomStoredExport? descriptorFor(String key)` | The descriptor recorded for `key`, or `null` when it holds nothing. Throws `TomExportException` (`export.store.invalid_key`) for a key the store would not have accepted, rather than answering `null` — `null` means *this valid key holds nothing*. |
| `textOf` | `String textOf(String key)` | The stored bytes for `key` decoded as UTF-8 (malformed input allowed), for tests that assert on content; throws `TomExportException` (`export.store.not_found`) when the key holds nothing, or (`export.store.invalid_key`) when it is not a valid key. |
| `doStore` | `Future<TomStoredExport> doStore({required String key, required Stream<List<int>> bytes, required String mediaType})` | *(override)* Drains `bytes` into a buffer and records the descriptor, publishing neither until the stream completes — so a failed write leaves nothing readable here either. Each chunk is copied as it arrives, so a renderer reusing one scratch buffer stores what it streamed. |
| `doOpen` | `Stream<List<int>> doOpen(String key)` | *(override)* Yields the buffered bytes for `key` as one chunk, copied so the reader owns it rather than a reference into the store; throws `TomExportException` (`export.store.not_found`) when it holds nothing. |
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
| `supportsPrefixDelete` | `bool` | *(override)* Whatever `blobStore` answers. This was `false`, on the argument that widening the blob contract for the export module's retention was the wrong direction; file storage then acquired the same need of its own, and a prefix delete turned out not to be the listing that argument was about — a listing's cost differs by an order of magnitude between backends while looking like a map lookup, where a prefix delete is one operation a backend can perform or refuse, which is what this flag says out loud. |

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
  TomExportRegister? register,
  TomExportQuota? quota,
})
```

`formats` defaults to `TomExportFormats.standard()`. `store` is optional: an
application that only streams exports back through its API never needs one.
`register`, when given, records every export `storeAs` stores; `quota` counts
against it, so a `quota` without a `register` throws `ArgumentError`.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `sanitiseFileName` | `static String sanitiseFileName(String fileName)` | Makes `fileName` safe inside a quoted header parameter: everything outside printable ASCII, plus `"`, `\`, `;` and `/`, becomes `_`, and an empty result becomes `export`. Non-ASCII is transliterated away because `filename=` is a Latin-1 field. The `apiResponse` channel's half of the naming rule; `TomBlobStore.sanitiseKeySegment`, applied by `keyFor`, is the `fileExport` channel's. They keep different characters — a space survives here and becomes `_` there — but accept the same names, so a report name works on both channels or on neither. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `formats` | `TomExportFormats` | The formats this service can produce (final). |
| `store` | `TomExportStore?` | Where `storeAs` writes, when the application has somewhere to write (final). |
| `register` | `TomExportRegister?` | The record of stored exports, or `null` when nothing is recorded (final). |
| `quota` | `TomExportQuota?` | How much one owner may store, or `null` for no limit (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `Stream<List<int>> render(TomTabularResult result, String format)` | Renders `result` as `format` to a byte stream — the primitive both channels are built on, and the one to call when neither fits. The **only** place in this class where a format id becomes bytes: `respondWith` and `storeAs` deliver whatever stream this returns, so an override adding a metric, a trace or a row limit is on every channel's path. An override may wrap, meter or refuse the stream, but should not change which *format* it produces: the channels ask `formats` what a format **is** and this method only what it **produces**. |
| `respondWith` | `Response respondWith(TomTabularResult result, String format, {required String baseName, bool inline = false})` | The `apiResponse` channel: a shelf response whose body is `render`'s stream, with the content type and a `Content-Disposition` naming `baseName` plus the format's extension. Unbuffered and without a `Content-Length`, so shelf falls back to chunked transfer encoding. `inline` switches the disposition from `attachment`, which is worth doing only for PDF. An unknown format throws before a response object exists, rather than as an error on its body. |
| `storeAs` | `Future<TomStoredExport> storeAs(TomTabularResult result, String format, {required String key, String owner = ''})` | The `fileExport` channel: streams `render`'s output into `store` under `key` and returns the descriptor. Throws `TomExportException` (`export.service.no_store`) when no store is configured. With a `register`, records the export under `owner` with the result's title. With a `quota` and a non-empty `owner`, checks the owner's usage before rendering and the stored size after it; a store that does not fit is deleted, its record removed, and refused (`export.quota.count_exceeded`, `export.quota.bytes_exceeded`). A store over a key the owner already holds replaces that export and is counted without it; a refused replacement leaves the key empty, since the store had already written over it. |
| `deleteStored` | `Future<bool> deleteStored(String key)` | Deletes the stored export under `key` and its register record; answers whether the store held it. Throws `TomExportException` (`export.service.no_store`) when no store is configured. |
| `keyFor` | `String keyFor(String baseName, String format, {DateTime? partitionOn})` | A storage key for `baseName` in `format`; with `partitionOn` it is prefixed `yyyy/MM/dd/`, so exports do not accumulate in one unlistable directory and expiry becomes a prefix deletion. `baseName` is the **same report name `respondWith` takes** and is sanitised for the same reason — neither channel should refuse a name the other accepts. The spelling differs because the grammars do (`Q3 sales` downloads as `Q3 sales.csv`, stores as `Q3_sales.csv`); the accepted set does not. The only path structure in the result is the partition, which this method owns, so a `/` in the name is replaced rather than honoured and `../etc/passwd` is defused rather than refused. Throws `TomExportException` (`export.store.invalid_key`) for a name too long to be a key — the one fault not sanitised away, because truncating would give two reports one key and the second export would overwrite the first in silence. |

### TomExportEmailMode

How `TomExportEmailDelivery.send` delivers an export.

#### Values

| Value | Description |
| ----- | ----------- |
| `link` | A link to the export, built by `TomExportEmailDelivery.linkFor`. |
| `attach` | The export's bytes as an attachment. |
| `auto` | An attachment up to `TomExportEmailDelivery.maxAttachmentBytes`, a link beyond it. |

### TomExportEmailDelivery

The `email` channel: sends stored exports by email through a `TomMessageOutbox`.
The export is rendered and stored once (`TomExportService.storeAs`); this class
builds a message about it and queues it, so durability, retry and
one-runner-per-message are the outbox's. An attachment is read back from the
store rather than rendered again — the stored export is what was delivered.

#### Constructors

```dart
TomExportEmailDelivery({
  required TomExportStore store,
  required TomMessageOutbox outbox,
  Uri Function(TomStoredExport export)? linkFor,
  TomRecipient? from,
  int maxAttachmentBytes = defaultMaxAttachmentBytes,
})
```

#### Static Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultMaxAttachmentBytes` | `int` | The largest export `auto` attaches by default: 10 MiB, beneath the limits common mail servers apply to a whole message. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomExportStore` | Where the exports are stored (final). |
| `outbox` | `TomMessageOutbox` | The outbox the messages are queued in (final). |
| `linkFor` | `Uri Function(TomStoredExport export)?` | The address a recipient fetches an export from — the deployment's own download route, a signed URL — or `null` when the deployment serves none, which leaves only attachments (final). |
| `from` | `TomRecipient?` | The default sender, or `null` for the transport's own (final). |
| `maxAttachmentBytes` | `int` | The largest export sent as an attachment; also the ceiling of `attach` (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<TomMessage> send(TomStoredExport export, {required List<TomRecipient> to, required String subject, String text = 'Your export is ready.', String? fileName, TomRecipient? from, TomExportEmailMode mode = TomExportEmailMode.auto})` | Queues an email delivering `export` to `to` and returns the queued message. `text` opens the body; in link mode the link follows it after a blank line. `fileName` names the attachment, by default the last segment of the key; its media type is the export's. `auto` attaches when the export fits `maxAttachmentBytes` or when there is no `linkFor`. Throws `TomExportException` before anything is queued: `export.email.no_recipient` for an empty `to`, `export.email.too_large` for an attachment larger than `maxAttachmentBytes`, `export.email.no_link` when a link is needed and `linkFor` is not set. |

### TomExportRecord

What the register knows about one stored export.

#### Constructors

```dart
TomExportRecord({
  required String key,
  required String owner,
  required String mediaType,
  required int byteCount,
  required DateTime storedAt,
  String? title,
})
```

`storedAt` is normalised to UTC.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The export's storage key (final). |
| `owner` | `String` | Who the export counts against — a user, a tenant, a report job; `''` for an export that belongs to no one, which no quota counts (final). |
| `mediaType` | `String` | The export's media type (final). |
| `byteCount` | `int` | Its size (final). |
| `storedAt` | `DateTime` | When it was stored, in UTC (final). |
| `title` | `String?` | The report's title, when the export was stored with one (final). |

### TomExportUsage

How much an owner holds: `count` exports of `bytes` in total.

#### Constructors

```dart
const TomExportUsage({required int count, required int bytes})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `count` | `int` | How many exports (final). |
| `bytes` | `int` | Their total size (final). |

### TomExportRegister

The record of stored exports: who stored what, how large, and when. The store
holds bytes under keys and cannot list them; the register is the enumeration,
written by `TomExportService.storeAs` beside the bytes, which a quota sums and
the retention purge queries.

- **Extends:** none (abstract)

#### Constructors

```dart
const TomExportRegister()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `record` | `Future<void> record(TomExportRecord record)` | Records `record`, replacing any record under its key. |
| `find` | `Future<TomExportRecord?> find(String key)` | The record under `key`, or `null`. |
| `ownedBy` | `Future<List<TomExportRecord>> ownedBy(String owner)` | `owner`'s exports, newest first. |
| `usageOf` | `Future<TomExportUsage> usageOf(String owner)` | What `owner` holds. |
| `storedBefore` | `Future<List<TomExportRecord>> storedBefore(DateTime before, {int limit = 500})` | Up to `limit` exports stored before `before`, oldest first. |
| `remove` | `Future<bool> remove(String key)` | Removes the record under `key`; answers whether there was one. |

### TomMemoryExportRegister

A `TomExportRegister` in memory: right for tests and a single process whose
store is in memory too, wrong for anything that outlives the process.

- **Extends:** `TomExportRegister`

#### Constructors

```dart
TomMemoryExportRegister()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `record` | `Future<void> record(TomExportRecord record)` | *(override)* Keeps `record` under its key. |
| `find` | `Future<TomExportRecord?> find(String key)` | *(override)* The record under `key`, or `null`. |
| `ownedBy` | `Future<List<TomExportRecord>> ownedBy(String owner)` | *(override)* `owner`'s records, newest first. |
| `usageOf` | `Future<TomExportUsage> usageOf(String owner)` | *(override)* Counts and sums `owner`'s records. |
| `storedBefore` | `Future<List<TomExportRecord>> storedBefore(DateTime before, {int limit = 500})` | *(override)* The records stored before `before`, oldest first, at most `limit`. |
| `remove` | `Future<bool> remove(String key)` | *(override)* Drops the record under `key`. |

### TomSqlExportRegister

The relational `TomExportRegister`: one row per stored export, in the database
the deployment already has. The table (`tom_export` by default) is declared once
as `exportRegisterTable`, keyed by the storage key and indexed on
`(owner, stored_at)` and on `stored_at`.

- **Extends:** `TomExportRegister`

#### Constructors

```dart
TomSqlExportRegister(
  TomDataSource datasource, {
  String table = defaultExportRegisterTable,
  bool createSchema = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | The data source the table lives in (final). |
| `table` | `String` | The register table (final). |
| `createSchema` | `bool` | Whether to create the table on first use; `false` where the migration module owns the schema (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the table if it does not exist (when `createSchema`); idempotent, and called by every operation. |
| `record` | `Future<void> record(TomExportRecord record)` | *(override)* Writes the row, replacing any row under its key; `stored_at` is written as a UTC instant. |
| `find` | `Future<TomExportRecord?> find(String key)` | *(override)* The row under `key`, or `null`. |
| `ownedBy` | `Future<List<TomExportRecord>> ownedBy(String owner)` | *(override)* `owner`'s rows, newest first, then by key. |
| `usageOf` | `Future<TomExportUsage> usageOf(String owner)` | *(override)* One `COUNT(*)` / `SUM(byte_count)` over `owner`'s rows, read back as a `TomExportUsageRow`. |
| `storedBefore` | `Future<List<TomExportRecord>> storedBefore(DateTime before, {int limit = 500})` | *(override)* The rows stored before `before`, oldest first, then by key, at most `limit`. |
| `remove` | `Future<bool> remove(String key)` | *(override)* Deletes the row under `key`; answers whether one was deleted. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the table — for provisioning and tests. |

### TomExportRecordRow

One row of the export register table, as the driver hands it back. Reflected and
`@TomDbTable`-annotated because the data source's row mapper requires both; the
annotation's table values are placeholders, since the real table name is a
constructor argument of `TomSqlExportRegister`.

#### Constructors

```dart
TomExportRecordRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The export's storage key (column `export_key`). |
| `owner` | `String` | Who the export counts against (column `owner`). |
| `mediaType` | `String` | The export's media type (column `media_type`). |
| `byteCount` | `int` | Its size (column `byte_count`). |
| `storedAt` | `String` | When it was stored, as the stored text, parsed as a UTC instant (column `stored_at`). |
| `title` | `String?` | The report's title (column `title`). |

### TomExportUsageRow

The aggregate row `TomSqlExportRegister.usageOf` reads. Reflected and
`@TomDbTable`-annotated for the same reason as `TomExportRecordRow`.

#### Constructors

```dart
TomExportUsageRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `exportCount` | `int` | How many exports (column `export_count`). |
| `exportBytes` | `int` | Their total size (column `export_bytes`). |

### TomExportQuota

How much one owner may hold: at most `maxCount` exports and at most `maxBytes`
in total; `null` leaves that dimension unbounded. Checked by
`TomExportService.storeAs` for an export stored with an owner: the count and the
bytes already held before rendering, so a full owner costs no render; the size
of the new export once it is stored, undoing a store that takes the owner past
`maxBytes`.

#### Constructors

```dart
const TomExportQuota({int? maxCount, int? maxBytes})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxCount` | `int?` | The most exports one owner may hold (final). |
| `maxBytes` | `int?` | The most bytes one owner's exports may total (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `check` | `void check(String owner, TomExportUsage usage, {int addedBytes = 0, bool countingNew = true})` | Throws unless `owner`, holding `usage`, may hold one more export. Before the store `addedBytes` is `0` and the bytes already held must be below `maxBytes`; after it, `addedBytes` is the stored size and the total must not exceed `maxBytes`. `countingNew` is `false` for a store that replaces an export the owner already holds, which adds nothing to the count. Keyed `export.quota.count_exceeded` (parameters `owner`, `count`, `limit`) or `export.quota.bytes_exceeded` (`owner`, `bytes`, `limit`). |

### TomExportRetention

Deletes stored exports older than `maxAge` — the bytes from `store`, the records
from `register`. It works from the register, deleting key by key, so it reaches
every export the service stored whatever the store's backend.

#### Constructors

```dart
TomExportRetention({
  required TomExportStore store,
  required TomExportRegister register,
  required Duration maxAge,
  int batchSize = 500,
})
```

Throws `ArgumentError` when `maxAge` is not positive or `batchSize` is below 1.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomExportStore` | Where the exports are stored (final). |
| `register` | `TomExportRegister` | The record of what was stored when (final). |
| `maxAge` | `Duration` | How long an export is kept (final). |
| `batchSize` | `int` | How many exports one batch deletes (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `purge` | `Future<int> purge({DateTime? now})` | Deletes every export stored before `now` (default: the current time) minus `maxAge`, reading `storedBefore` a batch at a time, and answers how many went. The bytes go before the record, so an interrupted purge leaves a record whose bytes are gone — deleted again, harmlessly, by the next purge — and never bytes no record names. |
| `jobDefinition` | `TomJobDefinition jobDefinition({String name = 'tom.export.purge', TomSchedule? schedule})` | A job running `purge` on `schedule` (default: hourly, a `TomIntervalSchedule`), with a missed window run once, for a `TomScheduler`. Its body holds this retention, so the scheduler must run it in its own isolate with a `TomInlineJobDispatcher`. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultExportRegisterTable` | `String` | The default name of the export register table, `tom_export`. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `exportRegisterTable` | `TomFrameworkTable exportRegisterTable(String table)` | The one declaration of the export register table: `export_key` as the primary key, sized from `TomBlobStore.maxKeyLength`; `owner` (`VARCHAR(191) NOT NULL DEFAULT ''`), `media_type`, `byte_count`, `stored_at` as `DATETIME(6)` and a nullable `title`; indexed on `(owner, stored_at)` for a quota and an owner's listing and on `stored_at` for the purge. Listed by `frameworkOwnedTables` under `exportRegister`. |
| `exportRegisterTableDdl` | `String exportRegisterTableDdl(String table)` | The `CREATE TABLE` statement for the register table, derived from `exportRegisterTable`. For the default name that text is the shipped `example/export/migrations/main/tomcore/[1]-create_tom_export.sql`. |
| `tomFormatCellAsText` | `String tomFormatCellAsText(Object? value)` | The shared text rule for the text-oriented renderers: `null` is empty, a `DateTime` is ISO-8601, a whole `double` drops its trailing `.0` so it does not read as an approximation, and everything else is `toString()`. |
