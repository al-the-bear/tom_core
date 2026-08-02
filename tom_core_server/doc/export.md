# Export Module

The rendering engines: a tabular result in, a byte stream out, in CSV, XLSX or
PDF — plus the two delivery channels that stream matters back to a caller or
into storage.

This module is **rendering and delivery only**. It does not model report
definitions, projections, parameters or scheduling; those belong to the
CodeSpecs reporting element, which is deferred and unspecified. What is here is
the part that has to exist under any such model, built so that when the model
arrives it is adapted onto this shape rather than the renderers being rewritten.

## Table of Contents

- [Overview](#overview)
- [The Shape of the Design](#the-shape-of-the-design)
- [The Input: A Tabular Result](#the-input-a-tabular-result)
- [Columns Derived from the Entity](#columns-derived-from-the-entity)
- [The Renderer Contract](#the-renderer-contract)
- [Formats Are a Registry, Not a Switch](#formats-are-a-registry-not-a-switch)
- [Format Choices and Licences](#format-choices-and-licences)
- [CSV](#csv)
- [XLSX](#xlsx)
- [PDF, and Why It Is the One That Does Not Stream](#pdf-and-why-it-is-the-one-that-does-not-stream)
- [Storage: A Deliberately Narrow Seam](#storage-a-deliberately-narrow-seam)
- [Every Backend at Once](#every-backend-at-once)
- [The Two Delivery Channels](#the-two-delivery-channels)
- [Untrusted Text in Three Places](#untrusted-text-in-three-places)
- [Wiring a Server](#wiring-a-server)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomTabularResult` | class | A titled document: metadata plus one or more sections |
| `TomTabularSection` | class | One table: typed columns over a **stream** of rows |
| `TomTabularSection.ofEntities` / `TomTabularResult.fromEntities` | static | The same, with the columns derived from a reflected entity |
| `TomTabularColumn` / `TomColumnType` | class / enum | A named, typed, optionally width-hinted column |
| `TomTabularRow` | class | Cell values positional to the section's columns |
| `TomTabularRenderer` | abstract class | One format: a result in, a byte stream out |
| `TomExportFormats` | class | The formats an application offers, by format id |
| `TomCsvRenderer` | class | RFC 4180 CSV; the baseline that always works |
| `TomXlsxRenderer` | class | Office Open XML, one sheet per section, streaming |
| `TomPdfRenderer` | class | A paginated document for a person to read |
| `TomExportStore` | abstract class | Put a rendered export under a key; read it back |
| `TomDirectoryExportStore` / `TomMemoryExportStore` | classes | Filesystem and in-memory backends |
| `TomBlobExportStore` | class | The same interface over the `file_storage` blob API — every configured backend at once |
| `TomStoredExport` | class | What was stored, where, and how big it turned out |
| `TomExportService` | class | The seam an endpoint calls: respond with, or store, an export |
| `tomFormatCellAsText` | function | The one answer to "how does a value look as text" |
| `TomExportException` | class | The module's base error |

## The Shape of the Design

Three things, each replaceable without touching the other two:

1. **A shape** — `TomTabularResult`. What is being exported, independent of
   format.
2. **A format** — `TomTabularRenderer`. Bytes from that shape, independent of
   where they go.
3. **A destination** — `TomExportService` over `TomExportStore`. Where the bytes
   go, independent of which format produced them.

The seam between all three is `Stream<List<int>>`, and that is the entire reason
the module can export a result larger than the server's heap.

## The Input: A Tabular Result

```dart
final result = TomTabularResult.single(
  title: 'Sales',
  metadata: {'Filter': 'region = EU', 'As of': '2026-07-28'},
  section: TomTabularSection.ofMaps(
    [
      TomTabularColumn('product', label: 'Widget'),
      TomTabularColumn('amount', label: 'Amount', type: TomColumnType.decimal),
      TomTabularColumn('sold_at', label: 'Sold', type: TomColumnType.timestamp),
    ],
    queryRowStream,          // Stream<Map<String, Object?>>
  ),
);
```

Decisions in that shape worth knowing:

- **Rows are a stream, not a list.** An export exists precisely for results too
  large to return inline; a list would put the whole result in memory *before*
  the first byte of output, needing heap for the rows and the document at once.
- **The stream is single-subscription and consumed once.** Rendering the same
  result in two formats needs a result that can build a fresh stream — build one
  per render rather than sharing.
- **Cells are positional.** Rows are the thing there are many of, so a
  `List<Object?>` parallel to the columns is one allocation per row where a
  `Map` would be a hash table plus a re-stored copy of every column name.
  `TomTabularRow.fromMap` (and `TomTabularSection.ofMaps`) exist for callers who
  naturally hold keyed values, and do the ordering once against the columns.
- **A short row is tolerated**, yielding `null` for its trailing columns: a
  cosmetic gap should not fail an export that has been running for a minute.
- **The type set is not chosen freshly.** `int`, `double`, `String`, `bool`,
  `DateTime` is exactly what the query layer's `TomGroupedRow` produces, so an
  aggregate result adapts without a lossy conversion and no renderer meets a
  value it has no rule for.
- **Validation is at construction**: no sections, no columns, a duplicate
  column name or an empty column name all throw `TomExportException` while the
  caller who built it wrong is still on the stack.

`metadata` is the context that makes a downloaded file interpretable months
later — the filter that produced it, who ran it, as of when. Formats that have a
header block (PDF) render it; formats that do not (CSV) ignore it.

## Columns Derived from the Entity

For an export **of entities**, the projection above restates what
`@TomDbColumn` already declares — and the two then drift in both directions: a
column added to the entity never appears in the export, and a type changed on
the entity leaves cells being formatted under a stale `TomColumnType`.
`fromEntities` removes the second declaration:

```dart
final result = TomTabularResult.fromEntities<Task>(
  repository.streamAll(),        // Stream<Task>
  title: 'Open tasks',
  metadata: {'Filter': 'state = open'},
  exclude: {'internalRank'},
  titles: {'dueAt': 'Due'},
);
```

There are no columns in that call. Every `@TomDbColumn` field of `Task` becomes
one, in declaration order, and both properties the tabular shape was designed
around survive: `rows` stays a `Stream` — deriving the columns reads annotations,
not rows, so nothing is pulled until a renderer subscribes — and cells stay a
positional `List` parallel to the columns. A reflected projection that quietly
turned every row into a map would give back exactly the per-row allocation the
type exists to avoid.

**Columns are keyed by declared field name**, not by database column: `createdAt`,
not `created_at`. That is how the audit trail keys its own image, for the same
reason — the column name is a mapping detail a spec author should not have to
know — and `include`, `exclude` and `titles` all use the same key. A name none of
them matches **throws**: a typo that silently drops a column is the drift this
constructor exists to remove.

### Two Kinds of Column That Are Not Exported

| Kind | Default | Why |
| ---- | ------- | --- |
| A field named in `@TomAudited(redact: …)` | **Excluded**, and `include` cannot reach it | Redaction declares that the value must not exist in a *second* place at all. An export is a second place; answering the same question differently here would defeat the declaration |
| A `@TomFileReference` column | **Excluded**; `includeFileReferences: true` exports the keys | The column holds an internal *storage key*, not content. A spreadsheet of them is a small information leak and is useless to the reader either way |

`include` narrows the exportable set and never widens it, so naming a redacted
field or — without the flag — a file column is an error rather than a quiet
override. Which of the two rules applied would otherwise depend on which was
written last.

The alternative for file columns worth naming is exporting a **URL** rather than
a key. That is not derived here, and deliberately: the public URL of a file is
the mount path of the file endpoint plus the deployment's external origin, and
this module knows neither. A guessed URL renders a dead link, which is worse than
a key. An export that needs one builds that column explicitly, which is the
route below.

### What Keeps the Explicit Route

`fromEntities` is bounded to the "these entities, these columns" case — the
majority, and the one a declarative report definition can express. It is not for:

- **a join** — the columns come from several types, and no one of them declares
  the shape;
- **an aggregate** — the columns are expressions (`SUM(amount) AS total`) that no
  entity declares at all. `TomGroupedRow` already produces exactly the five cell
  types, so `TomTabularSection.ofMaps` adapts it without a conversion;
- **a computed or reformatted column** — a storage key turned into a URL, a code
  turned into a label, two fields joined into one.

Those keep `ofRows` / `ofMaps`, which are correct and are not deprecated by this.

### Deriving the Column Type

`TomAnnotationAnalyzer.familyOf` reduces a column's annotations to a
`TomSqlTypeFamily`, and that family maps onto a `TomColumnType` — with one
qualification. The family describes how a value is **stored**; an export cell
holds the **Dart** value the getter returns, and the two diverge: a JSON column
is text in the database and a `Map` in Dart, and an explicit `TomDbType` box can
disagree with the field it annotates. So a family maps to a column type only when
the declared Dart type can actually inhabit it — tested against
`TomColumnType.dartType`, so the rule reuses the existing declaration instead of
introducing a second type table — and otherwise the column is `text`, which every
renderer formats through `tomFormatCellAsText`.

A `TomZonedDate` field is the case that shows this: its storage family is `date`,
but the value is not a `DateTime`, so declaring the column `timestamp` would
describe a cell that can never occur. Being wrong here is cosmetic rather than
fatal — every renderer falls back to text for a value that does not match its
column — but a type that is merely never right is still a type worth not writing.

`familyOf` lives on `TomAnnotationAnalyzer` rather than with either consumer
because the schema-convergence check ([`db_migration.md`](db_migration.md#schema-convergence))
asks the same question of the same annotations, and a second answer would be a
second thing to keep in step.

## The Renderer Contract

```dart
abstract class TomTabularRenderer {
  String get formatId;        // 'csv', 'xlsx', 'pdf'
  String get mediaType;
  String get fileExtension;
  bool get streamsRows => true;
  Stream<List<int>> render(TomTabularResult result);
  String fileNameFor(String baseName) => '$baseName.$fileExtension';
}
```

**Why a byte stream out.** `Future<Uint8List>` would force the whole document
into memory before anything could be done with it. A stream feeds a shelf
response body, a file sink or a blob upload without any of them waiting for the
last row — and makes both delivery channels the *same* code path.

**Why bytes and not text.** CSV is text, XLSX is a ZIP archive, PDF is a binary
document. Typing the abstraction as `String` would make two of three formats
encode-then-decode through it, corrupting them.

**What a renderer may assume**: each section's rows are pulled once, in order, to
completion; cell values match their column type or are `null`; the returned
stream is listened to once. A renderer meeting those may hold one row at a time
— and whether it *does* is a property of the format, published as
`streamsRows`, because it is the one thing a caller deciding *whether to allow*
an export of a given size needs to know.

Errors surface **on the stream**, not thrown from `render`. By the time a row
fails, `render` has long returned.

## Formats Are a Registry, Not a Switch

```dart
final formats = TomExportFormats.standard()   // csv, xlsx, pdf
  ..register(const TomCsvRenderer(fieldSeparator: ';'))   // replaces csv
  ..register(MyFixedWidthRenderer());                     // adds a format
```

An application adds a format — a fixed-width extract a partner insists on, an
internal JSON-lines dump — without the export service knowing about it.
Registering an existing id **replaces**, on purpose: a semicolon CSV for a
European locale is still `csv`, and should not need a new id. An unknown format
throws rather than returning `null`, naming what *is* available.

`TomExportFormats.standard()` is a factory, not a shared constant: a registry is
mutable, and a process-wide mutable default is a race between whichever modules
register first.

## Format Choices and Licences

Every format was assessed against one question — does adopting a package remove
work that is genuinely hard, or does it only remove work that is small and
fully specified? Writing a format *encoder* by hand is a cost to be avoided
where the format is deep; it is the cheaper option where the part being used is
shallow.

| Format | Implementation | Package | Version | Licence | Verdict |
| ------ | -------------- | ------- | ------- | ------- | ------- |
| CSV | hand-written, no dependency | `csv` | 8.0.0 | MIT | **Rejected** |
| XLSX | hand-written, no dependency | `excel` | 4.0.6 | MIT | **Rejected** |
| PDF | `package:pdf` | `pdf` | 3.13.0 (constraint `^3.12.0`) | **Apache-2.0** | **Adopted** |

**`package:csv` — rejected.** `ListToCsvConverter` takes a
`List<List<dynamic>>` and returns a `String`: it materialises both the input
rows and the whole output document, exactly the shape this module exists to
avoid. RFC 4180 quoting is about fifteen lines, and hand-writing it keeps the
must-always-work format free of any dependency that could fail to resolve.

**`package:excel` — rejected, for two independent reasons.** First, it buffers
everything: `createExcel()` → `appendRow()` per row → `encode()` returning the
whole file, with the workbook object graph and the encoded archive resident at
once. Second, it pins `xml <7.0.0`, while `package:pdf` moves to `xml ^7` at
3.13.0 — depending on both would freeze the PDF renderer at 3.12.x
indefinitely. The alternative was not "write a spreadsheet format": the hard
parts of XLSX — a formula engine, styles, charts, shared strings, the entire
reading side — are precisely the parts an export does not use. What is left is
six small XML parts and a ZIP container, and the compression is `dart:io`'s
`ZLibEncoder`.

**`package:pdf` — adopted.** Here the calculus inverts. Paginating a table means
knowing how wide a string is in a given font at a given size: font metrics, line
breaking, and a layout pass that can split a row across a page boundary. That is
the whole hard part of a PDF writer, none of it is specific to this module, and
writing it again is exactly the format-encoder work to avoid. The package is
pure Dart with no native or Flutter part, so it runs in a plain server isolate.

The constraint is `pdf: ^3.12.0` rather than `^3.13.0` deliberately: the caret
range spans 3.12.x (SDK ≥ 2.19) and 3.13.x (SDK ≥ 3.12), so a machine on an
older SDK still resolves the package instead of failing `pub get`.

## CSV

The baseline: no dependency, no document structure to close, no failure mode
more interesting than a quoting bug. It is what everything else is compared
against and what an application falls back to when a richer format is
unavailable.

RFC 4180, with two settlements:

- **CRLF line endings**, as the RFC requires. Every consumer accepts them; Excel
  on Windows is unhappy without them.
- **A UTF-8 BOM by default.** Excel reads a BOM-less UTF-8 CSV in the system
  codepage and mangles every non-ASCII character. The BOM is the difference
  between a file that opens correctly on double-click and one that needs an
  import wizard. Set `byteOrderMark: false` for pipelines that parse rather than
  open.

Multi-section results are concatenated with a blank line and the section title
between them. CSV has no notion of a sheet, so this is a convention rather than a
format feature — a multi-section result is better served by XLSX, and this
behaviour exists so that asking for CSV anyway produces something rather than an
error.

## XLSX

An `.xlsx` is a ZIP archive of XML parts, which makes it the one office format
producible strictly front-to-back — and so the rich format that keeps
`streamsRows` `true`. Two standard techniques remove every reason to buffer:

- **Inline strings** (`t="inlineStr"`) rather than a shared-strings table. A
  shared-strings table has to be written *before* the sheets that index into it,
  which means knowing every string in the document before emitting the first
  row. Inline strings cost some size and save the entire result.
- **ZIP data descriptors** (general-purpose bit 3). A local file header normally
  carries the entry's CRC and sizes, unknown until the entry is finished; bit 3
  says the three values follow the data instead, so each part is written as it is
  compressed. Every mainstream reader, Excel included, supports this.

Peak memory is one row of XML plus the deflate window, whatever the row count.

Details that make the output actually open:

- **Sheet names are sanitised.** Excel rejects a workbook whose sheet names
  collide, exceed 31 characters or contain `: \ / ? * [ ]` — a section titled
  `Q1/Q2 comparison` would otherwise produce a file that will not open. Names are
  cleaned, truncated and made unique with a ` (2)` suffix.
- **Typed cells, not text.** Numbers are numeric, booleans are `t="b"`,
  timestamps are Excel date serials (days since 1899-12-30, computed from
  calendar fields so the value is independent of the process time zone).
- **An empty cell is omitted**, which is how SpreadsheetML spells blank. Writing
  an empty `<c>` would create a cell that exists, changing what a `COUNTA` over
  the column returns.
- **A value whose type does not match its column renders as text** rather than
  failing. A surprising value in a cell is recoverable; a failure on the last row
  of a long report is not.
- **Timestamps in the archive are zero**, so the same result renders to
  byte-identical output — which is what makes the archive assertable in tests.

## PDF, and Why It Is the One That Does Not Stream

A PDF ends with a cross-reference table of byte offsets into everything before
it, so no conforming writer can emit the first page before the last object is
placed. On top of that, a table's column widths are only known once every cell
sharing the column has been measured. Both facts point the same way, and neither
is a property of the library: **PDF is a random-access document format**, and
rendering one costs memory proportional to the result.

So `streamsRows` is `false` here, and the renderer *states* its limits rather
than discovering them:

| Knob | Default | Meaning |
| ---- | ------- | ------- |
| `rowLimit` | 20 000 | Rows accepted across all sections; exceeding it **fails** |
| `maxPages` | 2 000 | Raises `package:pdf`'s own 20-page default, which exists for invoices |
| `pageFormat` / `orientation` | A4 / portrait | Landscape is worth it from roughly eight columns |
| `baseFontSize` | 8 | Header text is one point larger and bold |
| `theme` | *unset* | Where an embedded Unicode font goes |
| `compress` | `true` | `false` makes the text readable in a hex dump |

`rowLimit` fails rather than truncating. A silently shortened report is a wrong
report that looks right; the error names the limit and points at CSV and XLSX,
which have no such ceiling.

The configuration surface intentionally exposes `package:pdf`'s own types
(`PdfPageFormat`, `pw.PageOrientation`, `pw.ThemeData`). Wrapping them would
mean re-declaring an enum and a theme model to gain nothing but a second name
for each — and would make supplying a font, the one thing an application really
needs to do here, harder than it is.

**Text outside Latin-1.** The default is the PDF base-14 Helvetica, which no
file has to embed but which can only encode WinAnsi. Greek, Cyrillic or CJK text
needs a real font: build a `pw.ThemeData` over an embedded TTF and pass it as
`theme`. This is left to the application because a Unicode font is a
megabyte-scale asset and which one is right is a deployment's decision.

## Storage: A Deliberately Narrow Seam

`TomExportStore` is explicitly **not** a general file store — the `file_storage`
module is (see [`file_storage.md`](file_storage.md)). It is the narrowest
interface an export needs:

```dart
abstract class TomExportStore {
  Future<TomStoredExport> store({required String key,
                                 required Stream<List<int>> bytes,
                                 required String mediaType});
  Stream<List<int>> open(String key);
  Future<bool> exists(String key);
  Future<bool> delete(String key);
  static String validateKey(String key);
}
```

No directories to list, no metadata to update, no partial reads. Keeping it that
narrow is what made `TomBlobExportStore` four delegating methods when the blob
storage arrived (see [Every Backend at Once](#every-backend-at-once)); nothing
that renders or delivers an export changed.

**Worked example.** `advanced_ops_server` renders a weekly report into the *same*
`tom_blob` pair that holds an item attachment, separated only by a key prefix —
the seam in practice. `test/ops_live_test.dart` reads the stored bytes back out
of the database through `open(key)` rather than through
`TomStoredExport.location`, which is the retrieval the narrow interface actually
offers: a database-backed store has no address to publish, so its `location` is
legitimately `null`. See
[`README_advanced_14_operations.md`](../../tom_core_samples/README_advanced_14_operations.md).

Properties that are load-bearing rather than incidental:

- **Streams on both sides.** An export large enough to be worth storing is large
  enough that holding it and its copy at once is the failure. `store` takes the
  renderer's stream directly, so a result flows from the database to the disk
  without ever being whole in memory.
- **A failed write leaves nothing readable.** `TomDirectoryExportStore` writes to
  a sibling `.part` file and renames on success — a rename within one filesystem
  is atomic, so a reader sees either the previous export or the complete new one,
  never the half that had been flushed when the query died on its last row. The
  partial is deleted and the error is wrapped as `export.store.write_failed`.
- **`open` on a missing key throws.** A caller reading an export it holds a
  reference to and finding it gone has hit a real fault — an unexpected expiry, a
  store it is not pointed at — and an empty stream would disguise that as an
  empty file.
- **Keys are validated centrally.** Relative, slash-separated, unreserved
  characters only, no `.`/`..` segments. The obvious backend maps keys onto
  paths, so a key of `../../etc/passwd` would be a directory traversal handed to
  whatever built the key from a report title. Validating in `TomExportStore`
  means every backend gets the check, including ones written later.

`TomMemoryExportStore` is the test and development backend. It buffers whole
exports by definition, which is why it is not the default; it exposes `keys`,
`descriptorFor` and `textOf` so a test can assert on content without touching a
filesystem.

## Every Backend at Once

`TomBlobExportStore` puts the `file_storage` module's `TomBlobStore` behind the
four methods above, so an export can be written to a database table, an S3
bucket, a directory or an application's own backend — chosen in configuration —
without the export module knowing any of them exist.

```dart
// The blob store named in configuration, or the default one.
final store = TomBlobExportStore.named('archive', keyPrefix: 'exports');
```

Two things it does rather than delegate:

- **`keyPrefix` namespaces the exports** inside a store that holds other things,
  and makes a retention rule expressible as a prefix. The key recorded in the
  returned `TomStoredExport` is still the caller's — an export whose key could
  not be passed back to `open` would be a trap — and validation happens *before*
  prefixing, so a traversal cannot be smuggled in relative to the prefix.
- **`storage.blob.not_found` is translated to `export.store.not_found`.** A
  caller of this module catches `TomExportException` and should not have to
  learn a second error vocabulary because of which backend was configured.

## The Two Delivery Channels

`TomExportService` is what an endpoint actually calls. It is a thin object on
purpose — everything hard is in the renderers or the store; what is left is the
part that would otherwise be copied into every endpoint that exports something.

| Channel | Method | Result |
| ------- | ------ | ------ |
| `apiResponse` | `respondWith(result, format, baseName:, inline:)` | A shelf `Response` streaming the document |
| `fileExport` | `storeAs(result, format, key:)` | A `TomStoredExport` descriptor |
| *(neither)* | `render(result, format)` | The raw byte stream, for everything else |

**The response is unbuffered and carries no `Content-Length`.** A CSV of a
million rows starts arriving at the client while the query is still running, and
the server's memory does not know the difference between that and ten rows. The
length is not known until the last row, and the only alternative to omitting it
is buffering the document to measure it; shelf falls back to chunked transfer
encoding.

`inline: true` switches the `Content-Disposition` from `attachment`, and is
worth it only for PDF — the one of the three a browser can display itself.

`keyFor(baseName, format, partitionOn: DateTime.now())` produces
`2026/07/28/sales.xlsx`. Exports accumulate, and a flat directory of them becomes
unlistable long before it becomes large; partitioning by day is the cheap fix
that also makes expiry a matter of deleting a prefix.

`storeAs` without a configured store throws `export.service.no_store`. The store
is optional because an application that only streams exports back through its API
never needs one, and requiring it would force a filesystem decision on a
deployment with no use for it.

**The third channel named in the specification, `email`, is deliberately absent
from this module.** An emailed export is a message with an attachment, which is
the `messaging` module's subject; it composes by rendering to bytes or to the
store and attaching the result. Inventing a third path here would duplicate the
outbox's retry and delivery semantics — the one thing that module exists to own.

## Untrusted Text in Three Places

A report's title, its column labels and its cell values all originate with a
user, and all three end up somewhere that interprets them:

| Where | Risk | Defence |
| ----- | ---- | ------- |
| A CSV cell | A leading `=`, `+`, `-` or `@` is a **formula** to a spreadsheet — an exported value becoming code on the machine that opens the file | Quoted *and* prefixed with a tab. Quoting alone does not stop it; the tab does, and is stripped on display |
| A `Content-Disposition` filename | A `"` or a newline ends the parameter and starts another header — the download equivalent of an injection | `TomExportService.sanitiseFileName` replaces everything outside printable ASCII, plus `" \ ; /`, with `_`; an empty result becomes `export` |
| An XLSX sheet name or cell | A `/` or `[` produces a workbook Excel refuses to open; a `<` breaks the XML | Sheet names sanitised and made unique; all text XML-escaped |

`filename=` is a Latin-1 field, so non-ASCII is transliterated away rather than
escaped. A caller needing the original name in full should add its own
`filename*=UTF-8''…` parameter.

## Wiring a Server

```dart
final exports = TomExportService(
  store: TomDirectoryExportStore(Directory('/var/lib/app/exports')),
);

// apiResponse — stream it straight back.
Response salesCsv(Request request) => exports.respondWith(
      buildSalesResult(),
      request.url.queryParameters['format'] ?? 'csv',
      baseName: 'sales',
    );

// fileExport — render it into storage and keep the reference.
final stored = await exports.storeAs(
  buildSalesResult(),
  'xlsx',
  key: exports.keyFor('sales', 'xlsx', partitionOn: DateTime.now()),
);
```

Both calls take the same result and the same format id; the only difference is
where the bytes go.

## Core Components

- **`TomTabularResult` / `TomTabularSection` / `TomTabularColumn` /
  `TomTabularRow` / `TomColumnType`** — the streaming tabular shape the
  renderers consume.
- **`TomTabularResult.fromEntities` / `TomTabularSection.ofEntities`** — the
  same shape with its columns derived from a reflected entity, so the export
  has no second declaration to drift from.
- **`TomTabularRenderer` / `TomExportFormats` / `tomFormatCellAsText`** — the
  format abstraction, its open registry, and the shared text rule.
- **`TomCsvRenderer` / `TomXlsxRenderer` / `TomPdfRenderer`** — the three shipped
  formats.
- **`TomExportStore` / `TomDirectoryExportStore` / `TomMemoryExportStore` /
  `TomBlobExportStore` / `TomStoredExport`** — the storage seam, its two own
  backends, and the adaptor onto the `file_storage` module's backends.
- **`TomExportService`** — the `apiResponse` and `fileExport` channels.
- **`TomExportException`** — the module's base error.

## Not Yet Implemented

- **Charts.** The specification names series and axes; two of the three formats
  cannot express a chart at all, so a chart model would be a field only the PDF
  renderer ever read. When charts are specified they belong *beside*
  `TomTabularResult`, not inside it.
- **The report-result envelope, report definitions, projections and
  scheduling.** The reporting element is deferred and its specification
  unwritten. `TomTabularResult` is deliberately the minimal shape the renderers
  need, so the envelope is adapted onto it later rather than the renderers being
  rebuilt around it.
- **The `email` delivery channel**, which composes out of this module and the
  `messaging` module rather than living in either alone.
- **Expiry and quota for stored exports.** `delete` exists and nothing calls it;
  how long an export is worth keeping is a deployment's decision.

## Dependencies

- `tom_core_kernel` — `TomHeader` (the two response headers), `TomServerException`
  by way of `TomExportException`.
- The `file_storage` module — `TomBlobStore` and its registry, used only by
  `TomBlobExportStore`; the rest of the module does not know it exists.
- The `object_persistence` module — `TomAnnotationAnalyzer` and
  `TomColumnInformation`, read only by the reflected projection.
- The `audit` module — `TomAuditTrail.policyFor`, so that the fields a trail
  redacts are the fields an export omits. Consulting the same declaration is the
  point; a second redaction list here would be a second thing to get wrong.
- `pdf` (Apache-2.0) — the PDF document model and its layout engine.
- `shelf` — the `Response` returned by the `apiResponse` channel.
- `path` — key-to-path joining in `TomDirectoryExportStore`.
- `dart:io` — `ZLibEncoder` for the XLSX archive; `File` / `Directory` for the
  filesystem store.
