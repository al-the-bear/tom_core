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
- [What a Width Means](#what-a-width-means)
- [Columns Derived from the Entity](#columns-derived-from-the-entity)
  - [Two Kinds of Column That Are Not Exported](#two-kinds-of-column-that-are-not-exported)
  - [What Keeps the Explicit Route](#what-keeps-the-explicit-route)
  - [Deriving the Column Type](#deriving-the-column-type)
- [The Renderer Contract](#the-renderer-contract)
- [Formats Are a Registry, Not a Switch](#formats-are-a-registry-not-a-switch)
- [Format Choices and Licences](#format-choices-and-licences)
- [CSV](#csv)
- [XLSX](#xlsx)
  - [The XLSX ceilings](#the-xlsx-ceilings)
- [PDF, and Why It Is the One That Does Not Stream](#pdf-and-why-it-is-the-one-that-does-not-stream)
- [Storage: A Deliberately Narrow Seam](#storage-a-deliberately-narrow-seam)
- [Every Backend at Once](#every-backend-at-once)
- [The Two Delivery Channels](#the-two-delivery-channels)
- [Untrusted Text in Four Places](#untrusted-text-in-four-places)
- [Wiring a Server](#wiring-a-server)
- [Verification](#verification)
- [Core Components](#core-components)
- [Retention](#retention)
- [The Reporting Half This Is The Lower Half Of](#the-reporting-half-this-is-the-lower-half-of)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomTabularResult` | class | A titled document: metadata plus one or more sections |
| `TomTabularSection` | class | One table: typed columns over a **stream** of rows |
| `TomTabularSection.ofEntities` / `TomTabularResult.fromEntities` | static | The same, with the columns derived from a reflected entity |
| `TomTabularColumn` / `TomColumnType` | class / enum | A named, typed column, with a width in characters |
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
| `TomExportStoreOperation` | enum | What the caller asked for when a store failed — `write` / `read` / `probe` / `delete` / `deletePrefix`, each carrying a stable `export.store.*` error key (`export.store.write_failed`, `read_failed`, `probe_failed`, `delete_failed`, `export.store.prefix_delete_failed`), so the same failure reads the same whichever backend is configured |
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
later — the filter that produced it, who ran it, as of when. Each format puts it
where it has room: PDF prints it as a header block above the first table, XLSX
writes it to the workbook's custom document properties, and CSV, which has
neither, drops it.

XLSX keeps it out of the cells deliberately. A header block above the table
would push the header row down by however many metadata entries there happened
to be, so a consumer reading the sheet as a table would find its columns at a
row number that varies with the metadata — and being machine-readable is the
reason to ask for a spreadsheet at all. `title` is carried the same way, as
`dc:title` in the workbook's core properties; the PDF both prints it and stores
it in the document info dictionary.

## What a Width Means

`TomTabularColumn.width` is **a count of characters, in every format**, and that
is the whole of the contract. A caller states 24 because a product name runs to
about twenty-four characters — a fact about the *data*, equally true of the
spreadsheet and of the page.

It is deliberately **not** a proportion. A proportion cannot be stated in a
spreadsheet at all, because a sheet has no total width to be a proportion *of*;
OOXML's `<col width>` unit is itself a character count, so the number goes
through as it stands. A page does have a fixed total, so the PDF cannot honour
24 literally. What it honours instead is the **ratio**: a column asking for 24
beside one asking for 12 gets twice the room, whatever the paper size, which is
the most of an absolute request a page can keep.

The characters are not converted to points on the way. The conversion would be a
single factor applied to every column, and `pw.FlexColumnWidth` is scale
invariant, so it cancels exactly — arithmetic that changes no output while
implying a precision the estimate cannot deliver.

**A column that states no width still has one.** `effectiveWidth` is the width
both renderers actually read: the stated `width`, or else the larger of the
type's `naturalWidth` and the label's length, capped at
`TomTabularColumn.maxDerivedWidth` (40) so that one long heading cannot squeeze
the rest of the table off the page. An explicit width is never capped — a caller
asking for 200 knows something this does not.

| Type | `naturalWidth` | Because |
| ---- | -------------- | ------- |
| `integer` | 11 | A signed 32-bit value written out |
| `decimal` | 12 | The same with a point and a place |
| `text` | 16 | A default, not a measurement; free text has no width |
| `boolean` | 5 | `false` |
| `timestamp` | 23 | `2026-07-01T00:00:00.000` |

These are measured against what this package *emits*, not against the type's
range, which is why they live on `TomColumnType` as a constructor argument:
adding a type means deciding its width, rather than falling through a default
somewhere else.

The derived width comes from the **schema and never from the rows**. XLSX is
written a row at a time, so nothing has measured the data by the time `<cols>`
must be emitted — the same constraint that stops the PDF streaming, met from the
other end.

Both halves of this rule earn their keep. Before it, the stated case and the
unstated case meant different things in each format: PDF gave an unhinted column
a flex of 1 against hints in the twenties, and XLSX left it at Excel's 8.43
default, which shows an ISO timestamp as `#####`. The module's own example is
what that looked like — a `product` column at 24 took seven eighths of the
table, `Amount` came down the remaining strip as `A`, `m`, `ou`, `nt`, and
twenty rows needed four pages. They need one.

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

**Worked example.** Step 5 of `example/export/export_example.dart` renders the
sales report of step 4 a second time, from a stream of `ExampleSaleRecord`
instead of a written-out column list, and compares the two files **byte for
byte**. That equality is this section's claim stated as something that can fail:
the entity is field for field the hand-written projection, so a type or an order
changed in one place and not the other breaks the run. The step also shows what
deriving does *not* remove — the entity declares the schema, not the
presentation, so the derived header carries field names until `titles` supplies
the headings, and only then are the two files identical.

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

In all three of those cases the caller writes its columns out, and that is the
only alternative to `ofEntities` the module offers: **columns are declared or
derived from a schema, never inferred from the rows.** Inference would have to
read the first row to learn the shape, and a first row is the worst available
witness — a `null` cell declares nothing, so the column would be typed by
whichever row happened to arrive first and every later row formatted under that
guess. It is also unavailable, because a section's columns must exist before its
stream is subscribed; an inferring constructor would be the only one in the
family that had to be awaited. This is the same rule as the one governing widths
below, arrived at from the other end.

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

**What `streamsRows: true` promises**, in the two forms it can be broken:

- **A row is not read once the next has been pulled.** `TomTabularRow` stores
  the caller's list rather than copying it, so a caller is free to reuse a
  buffer between rows; a renderer that keeps a row to read later — a one-row
  sliding window is enough — reads something else by then.
- **Output is not held back.** Bytes leave as the rows arrive, so the last row
  is followed by a constant tail (a closing tag, a central directory) rather
  than by the whole document.

Neither is visible in a content test, so the suite bounds both directly: fifty
thousand rows through CSV and XLSX, with rows that throw when read after the
source has moved past them, and a count of how much output was still unsent when
the source drained. PDF is the control — it is the renderer that fails the
second one on purpose.

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

### The XLSX ceilings

Streaming removes the memory ceiling, not every ceiling. Three remain, and like
the PDF renderer's `rowLimit` this writer **states them and fails at them**:

| Knob | Default | What it is |
| ---- | ------- | ---------- |
| `maxRowsPerSheet` | 1 048 576 | Excel's own row limit per worksheet, header included |
| `maxColumnsPerSheet` | 16 384 | Excel's own column limit per worksheet |
| `maxPartBytes` | 4 294 967 295 | The width of the ZIP header fields this writer emits |

The first two are the reader's limits, not this writer's: a sheet past either
renders perfectly here and Excel refuses to open it. `export.xlsx.too_many_rows`
is raised on the row that crosses the line; `export.xlsx.too_many_columns`
before any row is pulled, since the columns are known up front and a result that
cannot fit should not cost the query first.

The third is this writer's. Sizes, offsets and the entry count go into the ZIP
structures as 32-bit fields, and there is no ZIP64 here — so a part past 4 GiB
would not fail, it would **wrap**: the field would hold the value modulo 4 GiB,
the reader would believe it, and a run that reported success would have produced
a corrupt workbook. `export.xlsx.archive_too_large` is raised the moment a
measure would not fit, naming which part and which measure. ZIP64 is the other
answer and is a larger one — a second set of headers, an extra-field record per
entry and its own end-of-central-directory pair — and at that size the
recommendation in the message is the better product anyway.

All three messages name **csv** as the alternative, because it genuinely has
none of these limits.

## PDF, and Why It Is the One That Does Not Stream

A PDF ends with a cross-reference table of byte offsets into everything before
it, so no conforming writer can emit the first page before the last object is
placed. On top of that, how many pages there are — a number the footer prints on
the first of them — is only known once every row has been laid out. Both facts
point the same way, and neither is a property of the library: **PDF is a
random-access document format**, and rendering one costs memory proportional to
the result.

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
report that looks right; the error names the limit and points at CSV, which has
no ceiling at all, and at XLSX, whose ceilings are two orders of magnitude
higher (below).

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

**The default prints a warning, and it is a developer-only one.** Rendering with
it emits `Helvetica has no Unicode support …` on stdout, twice per document —
once for the body face and once for the bold header face. It looks like a leak
into a server's log stream, and it is not one, for a reason worth stating
because it is not guessable: `package:pdf` emits the line from a bare `print`
**inside an `assert`**. Assertions are compiled out of a `dart compile exe`
binary and of `dart run` without `--enable-asserts`, so the line reaches test
runs and assert-enabled runs and nothing else. A deployment sees none of it.

That also settles how to stop it in the runs where it *does* appear, and rules
out the obvious answer. It is not a logger call, so there is no level to raise
and no scope to narrow; the only interception point is the surrounding zone's
`print` handler, which would mean matching the library's own message text and
would swallow every other print the render makes. It is also easy to get wrong
in a way that looks right: the font is created while the page is laid out, in
`addPage`, not while the document is serialised, so a zone around
`document.save()` — the natural place for it — suppresses nothing. A working
one has to enclose the whole build. The supported way is the one
the knob already exists for: pass a `theme` with an embedded font and no base-14
face is created, so nothing warns. Suppressing it any other way would suppress
the answer to a question this module decided deliberately.

`test/export_test.dart` pins both halves of that — the diagnostic under
assertions, the silence without them — because the paragraph above is a claim
about a third-party library, and a claim like that rots quietly.

## Storage: A Deliberately Narrow Seam

`TomExportStore` is explicitly **not** a general file store — the `file_storage`
module is (see [`file_storage.md`](file_storage.md)). It is the narrowest
interface an export needs:

```dart
abstract class TomExportStore {
  // What a caller calls. Each one validates the key, dispatches to the hook
  // beside it, and reports any failure as a TomExportException (see below).
  Future<TomStoredExport> store({required String key,
                                 required Stream<List<int>> bytes,
                                 required String mediaType}) { /* → doStore */ }
  Stream<List<int>> open(String key) { /* → doOpen */ }
  Future<bool> exists(String key) { /* → doExists */ }
  Future<bool> delete(String key) { /* → doDelete */ }

  // What a backend implements. Each receives an already-validated key and may
  // fail in its own vocabulary.
  Future<TomStoredExport> doStore({required String key,
                                   required Stream<List<int>> bytes,
                                   required String mediaType});
  Stream<List<int>> doOpen(String key);
  Future<bool> doExists(String key);
  Future<bool> doDelete(String key);

  static String validateKey(String key);
}
```

No directories to list, no metadata to update, no partial reads. Keeping it that
narrow is what made `TomBlobExportStore` four delegating methods when the blob
storage arrived (see [Every Backend at Once](#every-backend-at-once)); nothing
that renders or delivers an export changed.

The split into a final public method and a `do*` hook is what makes the two
guarantees below hold *by construction* rather than by every backend remembering
to honour them — which, before the split, three backends each honoured a
different subset of.

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
  a sibling `<key>~part` file and renames on success — a rename within one
  filesystem is atomic, so a reader sees either the previous export or the
  complete new one, never the half that had been flushed when the query died on
  its last row. The partial is deleted and the error is wrapped as
  `export.store.write_failed`. The `~` is doing work: it is the one character
  `TomBlobStore.isValidKey` cannot produce, so the staging file is unreachable
  from the key space. Spelled `<key>.part` it was not — `a.csv.part` is a key a
  caller may legitimately choose, and storing `a.csv` overwrote that caller's
  export with a half-written stream and then renamed it away.
- **`open` on a missing key throws.** A caller reading an export it holds a
  reference to and finding it gone has hit a real fault — an unexpected expiry, a
  store it is not pointed at — and an empty stream would disguise that as an
  empty file.
- **A directory store is configured before it is a directory.**
  `TomDirectoryExportStore(root)` touches no filesystem; `root` is created by the
  first `store`, along with whatever directories that call's key names. A
  constructor cannot await, so creating it there would mean a blocking
  `createSync` on a possibly slow mount, thrown from a field initialiser on a
  store the application may never write to — and a root created once is just as
  gone when a volume is remounted or a tmpfs reaped, where the lazy one comes
  back. The read paths never create it: `open` is `export.store.not_found`,
  `exists` and `delete` are `false`. Asking a store whether it holds something is
  a question, and a question should not leave a directory behind.
- **A chunk belongs to whoever did not produce it.** What `open` yields is the
  reader's own — writable, and aliased with nothing the backend keeps, so a
  consumer decoding in place cannot edit the stored export. What `store` is
  handed is borrowed for the duration of the `await` — copied before the next
  chunk is requested, so a renderer refilling one scratch buffer stores what it
  streamed rather than that buffer's last state once per chunk. A backend over a
  file or a blob gets both for free; `TomMemoryExportStore` holds the bytes it
  serves, so it is the only one that copies on purpose. The copy is deliberately
  not an unmodifiable view, which would be cheaper but would make an in-place
  consumer throw on the backend the tests use and work on every backend they
  deploy to.
- **Keys are validated centrally.** Relative, slash-separated, unreserved
  characters only, no `.`/`..` segments. The obvious backend maps keys onto
  paths, so a key of `../../etc/passwd` would be a directory traversal handed to
  whatever built the key from a report title. `TomExportStore` validates before
  dispatching to any `do*` hook, so every backend gets the check — including ones
  written later, and including ones that map keys onto something other than
  paths and might not think to.
- **Every failure arrives as a `TomExportException`.** The four public methods
  translate whatever a backend raises — a `FileSystemException`, a
  `TomStorageException`, a `StateError` from a source stream that died — into
  the key naming the operation that failed: `write_failed`, `read_failed`,
  `probe_failed` or `delete_failed`, with the original in `rootException`. So
  the same failure of the same operation carries the same key whichever backend
  is configured, which is the whole reason for the interface to exist. The
  module's own exceptions pass through untouched: a caller catching
  `export.store.invalid_key` keeps catching it rather than meeting the name of
  whichever operation happened to refuse the key.

`TomMemoryExportStore` is the test and development backend. It buffers whole
exports by definition, which is why it is not the default; it exposes `keys`,
`descriptorFor` and `textOf` so a test can assert on content without touching a
filesystem. Those two accessors validate their key like the four store methods
do, because a backend that accepts keys the production backends reject is one a
test can pass on and a deployment fail on. The copying above is the same
principle in the other direction: the development backend must not *diverge*
from production, whether by being laxer about what it accepts or stricter about
what it hands back.

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
  not be passed back to `open` would be a trap. Both halves of the joined key
  are checked, in the two places each belongs: the caller's key on every call
  and *before* prefixing, so a traversal cannot be smuggled in relative to the
  prefix; the prefix itself once, at construction, where the failure names the
  misconfigured setting rather than a derived key nobody wrote. A prefix must be
  a valid key in its own right — `..`, `/exports` and `exports/` are all refused
  with `export.store.invalid_key`, the last because the join supplies the
  separator and `exports/` would yield `exports//sales.csv`.
- **`storage.blob.not_found` is translated to `export.store.not_found`.** It is
  the only blob failure this adaptor names, because it is the only one it knows
  something about that `TomExportStore` does not: a blob store reports absence
  as an error, and absence has to become `not_found` rather than the generic
  `read_failed`. Every *other* storage failure — a permission error, an S3
  timeout — falls through to the base class, which translates it like any other.
  A caller of this module catches `TomExportException` and never has to learn a
  second error vocabulary because of which backend was configured.

## The Two Delivery Channels

`TomExportService` is what an endpoint actually calls. It is a thin object on
purpose — everything hard is in the renderers or the store; what is left is the
part that would otherwise be copied into every endpoint that exports something.

| Channel | Method | Result |
| ------- | ------ | ------ |
| `apiResponse` | `respondWith(result, format, baseName:, inline:)` | A shelf `Response` streaming the document |
| `fileExport` | `storeAs(result, format, key:)` | A `TomStoredExport` descriptor |
| *(neither)* | `render(result, format)` | The raw byte stream, for everything else |

**`render` is the one place a format id becomes bytes**, and the two channels
deliver whatever stream it returns. That is what makes it an extension point
rather than a convenience: a subclass that overrides it to add a metric, a trace
or a row limit is on every channel's path, not only on the path of the callers
who invoke it explicitly — which is the rarest of the three.

An override may wrap, meter or refuse the stream. It should not change *which
format* it produces. The channels ask the registry what a format **is** — its
media type, its file extension — and ask `render` only what it **produces**, so
a substituted format would go out under the original's labels. Splitting the
question that way is also what lets an unknown format fail before a `Response`
object exists, rather than as an error on a body already being written.

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
that also makes expiry a matter of deleting a prefix — see
[Retention](#retention) for the call that does it and who runs it.

**`keyFor` takes the same report name `respondWith` does, and sanitises it for
the same reason.** A report is named by a person, so `Q3 sales` is the ordinary
case; a channel that refuses a name the other serves is an asymmetry a caller
discovers on whichever channel they reach second. The two *spellings* differ,
and must — a `Content-Disposition` filename is a Latin-1 quoted string and a
storage key is a relative path of unreserved characters, so the space survives
on one side and becomes `_` on the other. What is the same is which names are
**accepted**, which is the property a caller can act on.

The only path structure in a key is the partition, which `keyFor` owns: a `/` in
a name is replaced, not honoured, so `Sales / Returns` is one file rather than
two directories and `../etc/passwd` is defused by having nothing left to
traverse with. That is a different defence from `TomExportStore.validateKey`,
which still *refuses* — deliberately, because a key is assembled by code and a
malformed one is a bug, while a name comes from a person and mangling it beats
rejecting it.

One fault is not sanitised away: a name too long to be a key throws
`export.store.invalid_key`. Truncating would give two different reports the same
key, and the second export would overwrite the first with nothing reported
anywhere — a refusal the caller can see beats a collision it cannot.

`storeAs` without a configured store throws `export.service.no_store`. The store
is optional because an application that only streams exports back through its API
never needs one, and requiring it would force a filesystem decision on a
deployment with no use for it.

**The third channel named in the specification, `email`, is deliberately absent
from this module.** An emailed export is a message with an attachment, which is
the `messaging` module's subject; it composes by rendering to bytes or to the
store and attaching the result. Inventing a third path here would duplicate the
outbox's retry and delivery semantics — the one thing that module exists to own.

`example/export/export_email.dart` is that composition, run end to end: store
the export, then send it either as a **link** (the message carries the key, the
store keeps the bytes) or as an **attachment** (the bytes ride along, read back
from the store rather than rendered a second time). The two are not
interchangeable — an attachment is a copy per recipient and the first thing a
mail server refuses on size, while a link needs a recipient who can reach the
store. Delivery is `TomMessageOutbox.send`, so retry, backoff and
at-most-one-runner-per-message are the outbox's and not a second implementation
here. Neither module learns about the other: the twenty lines that join them
live in the application, which is what the example is.

## Untrusted Text in Four Places

A report's name, its title, its column labels and its cell values all originate
with a user, and all of them end up somewhere that interprets them:

| Where | Risk | Defence |
| ----- | ---- | ------- |
| A CSV title, column label, or cell holding a non-numeric value | A leading `=`, `+`, `-` or `@` is a **formula** to a spreadsheet — an exported value becoming code on the machine that opens the file | Quoted *and* prefixed with a tab. Quoting alone does not stop it; the tab does, and is stripped on display |
| A `Content-Disposition` filename | A `"` or a newline ends the parameter and starts another header — the download equivalent of an injection | `TomExportService.sanitiseFileName` replaces everything outside printable ASCII, plus `" \ ; /`, with `_`; an empty result becomes `export` |
| A storage key built from a report name | A `/` or a `..` is a directory the caller never asked for, and in the obvious backend a path outside the export root | `TomBlobStore.sanitiseKeySegment`, applied by `keyFor`, keeps only `A-Za-z0-9._-` and so cannot emit a separator; an empty result becomes `export` too |
| An XLSX sheet name or cell | A `/` or `[` produces a workbook Excel refuses to open; a `<` breaks the XML | Sheet names sanitised and made unique; all text XML-escaped |

**The CSV formula guard applies to the value's runtime type, not the column's
declared type.** A guarded field is quoted and tab-prefixed, and a spreadsheet
reads that as *text* — so guarding a number is not free: totals stop summing,
sorting turns lexical, and the value still looks right on screen. `null`, `num`,
`bool` and `DateTime` are therefore exempt, because `tomFormatCellAsText`
formats each of them into a literal and a `-` in front of a number is a minus
sign, never an operator. Every other value reaches `toString()`, whose output is
whatever the object chose to return, and is guarded.

Testing the *value* rather than the column matters because a `String` landing in
a numeric column is a mismatch the renderers tolerate rather than reject: a
column-type test would emit `=1+1` from an integer column unguarded — the exact
payload the guard exists to stop. Section titles and column labels are always
guarded; they are caller-supplied strings, as untrusted as any cell.

`filename=` is a Latin-1 field, so non-ASCII is transliterated away rather than
escaped. A caller needing the original name in full should add its own
`filename*=UTF-8''…` parameter.

## Wiring a Server

```dart
final exports = TomExportService(
  store: TomDirectoryExportStore(Directory('/var/lib/app/exports')),
);

// One report name, both channels. Written as a constant on purpose: two
// literals that happen to differ is how the two channels' naming rules drifted
// apart without anything noticing.
const reportName = 'Q3 sales';

// apiResponse — stream it straight back.
Response salesCsv(Request request) => exports.respondWith(
      buildSalesResult(),
      request.url.queryParameters['format'] ?? 'csv',
      baseName: reportName, // downloads as "Q3 sales.csv"
    );

// fileExport — render it into storage and keep the reference.
final stored = await exports.storeAs(
  buildSalesResult(),
  'xlsx',
  // stores as 2026/07/28/Q3_sales.xlsx
  key: exports.keyFor(reportName, 'xlsx', partitionOn: DateTime.now()),
);
```

Both calls take the same result, the same format id and the same report name;
the only difference is where the bytes go — and, because the two grammars
differ, how the name is spelled once it gets there.

## Verification

Two suites, split by which of the module's two routes into a column set they
cover, and one example that runs both.

`test/export_test.dart` covers the explicit route and everything downstream of
it: the tabular shape's construction guards, the single meaning of a width, the
format registry including an application format plugged in from outside, and
each renderer against its own format's rules — CSV's quoting, formula
neutralisation and CRLF; the XLSX archive's parts, relationships, cell types and
document properties; the PDF's pagination. Then the storage seam — both own
backends and the blob adaptor, against one shared error contract — the two
delivery channels, and the file-name and key grammars that differ between them.
The streaming claim is asserted rather than described: bytes are required to
reach the output *before* the row stream closes.

`TomBlobExportStore` is covered there and not in `test/file_storage_test.dart`,
which is worth saying because it spent its life in the neighbour's suite. It is
declared in `lib/src/tomserver/export/` and it is this module's class — the
dependency arrow runs export → `file_storage`, and the adaptor is the arrowhead.
Its group covers its own four methods, its prefix validation and its translation
of every backend failure into the export vocabulary: one class's unit tests, not
a claim about two modules agreeing. So it sits beside the two backends it is
interchangeable with, immediately before the contract group that drives all
three. What held it next door was that the failing-backend fixture driving the
translation happened to be declared there — fixture convenience, which left a
reader auditing this module's coverage concluding the adaptor was untested. The
claim that genuinely *is* about the two modules agreeing — that an export key and
a blob key are one grammar in two vocabularies — stays in
`test/file_storage_test.dart`, where the grammar is defined. And
`TomBlobStore.sanitiseKeySegment`, a `file_storage` symbol, is tested here for
the mirror-image reason: `TomExportService.keyFor` applies it and then hands the
result to `validateKey`, so it is tested where it would break.

`test/export_entities_test.dart` covers the derived route, and holds the one
claim no single run can make. Drift needs two versions of an entity that differ
by exactly one column, so the suite derives from both — with no export-side edit
between them — and shows the added column reaching the rendered bytes. It also
covers what a live run can only sample: the type derivation including the
`TomZonedDate` fallback to text, the keying by declared field name, both
exclusion rules in both directions, and the two properties the tabular type was
designed around — rows pulled one at a time, cells positional.

`example/export/export_example.dart` is the readable path through all of it, in
fourteen numbered steps: the tabular shape and its stream, the derived column
set of step 5, the renderer contract, what each format makes of one result, the
registry, storage across all three backends at once, and both delivery channels.
Its entity lives beside it in `example/export/export_entities.dart`, because a
type the reflection generator captures cannot also live in a file that imports
the generator's output; it is registered in `example/example_reflection.dart`,
the example suite's shared reflection root.

```bash
dart run example/export/export_example.dart
```

`test/export_test.dart` runs it under precisely that command and requires it to
exit 0 having reported all fourteen steps, and requires the file to keep stating
its expectations through the shared `example/_support/check.dart` — see
[A green run is a verification](../README.md#a-green-example-run-is-a-verification)
for why that helper **throws** rather than asserting.

That the helper fails the run rather than narrating it is the third guard, and
the one neither test above can make: both are satisfied by a `check` that merely
printed. It lives in `test/examples_test.dart`, once for the whole example
suite, because every example shares one definition and checking it per example
would be one test of one function, repeated.

`example/export/export_email.dart` is the second export example, in six steps:
the two halves configured without knowing each other, the store, the link shape,
the attachment read back from the store, the outbox delivering it, and the
export still in the store afterwards. It is spawned by `test/examples_test.dart`
with the rest, and its step count is recorded there — an added step that nobody
listed is a surface nothing checks.

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

## Retention

Stored exports accumulate. The day partitioning `keyFor` writes is what makes
reclaiming them cheap, and `TomExportStore.deletePrefix` is the call that does
it:

```dart
// Everything exported on 8 July, in one call.
final removed = await store.deletePrefix('2026/07/08');
```

**The prefix is matched by key segment, never by characters.** `2026/07` removes
`2026/07` and everything beneath it, and never `2026/070`. A string prefix that
can reach a sibling is an ordinary convenience everywhere except in a delete,
where it is how a month's retention takes the next month with it. An empty
prefix is refused for the same reason: it names every export there is, and a
configuration value that turned out empty should not empty the store.

**Not every backend can do it, and each says which it is.**
`supportsPrefixDelete` is the question to ask at wire-up:

| Backend | Prefix delete | Why |
| ------- | ------------- | --- |
| `TomDirectoryExportStore` | yes | keys are paths; a partition is a directory |
| `TomMemoryExportStore` | yes | it holds its own key space |
| `TomBlobExportStore` | **no** | `TomBlobStore` offers no enumeration, and a prefix delete cannot be built from `delete` alone |

Calling it on a store that cannot throws
`export.store.prefix_delete_unsupported`, naming the backend. Answering `0`
instead would make "the purge found nothing" and "this backend cannot purge" the
same answer, and the deployment would learn the difference from a disk filling
up. A backend that *claims* the capability and forgets the method gets the same
refusal rather than an empty purge, because the base class's implementation
throws rather than returning zero.

**A blob-backed deployment keeps its own record.** The descriptor `store`
returns carries the key, the media type, the size and the time; a system that
stores exports for later retrieval almost always has a row per export already,
and deletes by key from it. That is a database question rather than a storage
one, which is why the blob contract is not widened to answer it: a listing over
an object store is a paginated call with a cost the caller has to understand,
and file storage has no other caller asking for one.

**The schedule is the deployment's.** Nothing here runs on a timer. A nightly
purge belongs in the back-office tier, beside the other passes that tidy up
after the day — the scheduling module already provides the machinery, and a
second copy of it here would give this module two reasons to change. What this
module owes such a job is the partition layout it created and the call that
reclaims one, and both are above.

## The Reporting Half This Is The Lower Half Of

This module renders and delivers. It does not define reports: there is no type
that names a query, a projection, a delivery channel and a schedule in one
place, which is what an application would actually configure. That half is
**in scope for the framework and not written**, and when it is written it is a
module of its own that depends on this one — not an extension of it. A module
that both defined reports and rendered them would have two reasons to change,
and the reason a report definition changes (a new parameter, a new schedule)
has nothing to do with the reason a renderer does (a format's own rules).

What that module will need from this one already exists, and is the reason the
deferral is safe rather than merely convenient:

| The reporting module needs | This module already offers |
| -------------------------- | -------------------------- |
| a shape to put its result in | `TomTabularResult` — a title, one or more sections, and a `metadata` map for the report's name, its parameters and when it ran |
| a way to build that shape from a query it ran | `TomTabularSection.ofMaps` (a `TomGroupedRow`'s `values` feed it directly), `ofRows`, or `ofEntities` when the report is over one entity |
| a document, in a format a definition names | `TomExportFormats.rendererFor(id)` — with its media type and file extension available *without* rendering, which is what a schedule needs to name a stored file |
| delivery with no request in sight | `TomExportService.storeAs` and `keyFor`; neither takes a `Request`, so a scheduled run is not a special case |
| a schedule | the [scheduling](scheduling.md) module. A reporting module runs on the existing scheduled-work machinery rather than growing its own |

**The property the deferral rests on is that `TomTabularRenderer.render` takes
the result and nothing else.** A second parameter — a report definition, a
locale, a chart set — would mean every renderer changes on the day the envelope
lands, including one an application registered itself, and that is exactly the
rebuild the deferral was chosen to avoid. It is held by tests rather than by
intention: `export_test.dart` asserts the contract's signature, asserts that
each shipped renderer declares it, and renders a result built the way an
envelope will build one — sections from a query this module knows nothing about,
metadata filled with a report's own identity — through all three formats.

So an envelope is adapted onto `TomTabularResult`; `TomTabularResult` is not
adapted to an envelope.

## Not Yet Implemented

- **Charts, and they wait on the envelope below.** The specification names
  series and axes; two of the three formats cannot express a chart at all, so a
  chart model would be a field only the PDF renderer ever read. When charts are
  specified they belong *beside* `TomTabularResult`, not inside it.

  The order is the decision. A chart is a projection of a **report** result, not
  of a tabular one, so its shape follows from the report envelope — which is the
  next entry in this list and is itself unspecified. Specifying a chart model
  first would mean guessing what carries it, and a model built on a guess is how
  a field ends up with exactly one reader.

  Nothing is prepared for charts on purpose, and that includes the things their
  absence might look like an oversight in: there is no chart field on
  `TomTabularResult`, no capability flag beside `streamsRows`, and no way for a
  renderer to declare that it cannot draw one. Each of those would be a
  declaration *about a shape that does not exist* — the same mistake as the model
  itself, one layer down.

  An application that needs charts before the envelope does is not blocked.
  `TomExportFormats` is an open registry: register a renderer that draws them
  under its own format id, or replace a shipped one, and the module neither
  knows nor needs to. That is the same seam
  [Formats Are a Registry, Not a Switch](#formats-are-a-registry-not-a-switch)
  is about, and it is why waiting costs a caller nothing.
- **The report-result envelope, report definitions, projections and
  scheduling.** The reporting element is deferred and its specification
  unwritten. `TomTabularResult` is deliberately the minimal shape the renderers
  need, so the envelope is adapted onto it later rather than the renderers being
  rebuilt around it. What that means concretely is
  [The Reporting Half This Is The Lower Half Of](#the-reporting-half-this-is-the-lower-half-of).
- **The `email` delivery channel**, which composes out of this module and the
  `messaging` module rather than living in either alone — worked end to end in
  `example/export/export_email.dart`, and deliberately not a third method on
  `TomExportService`.
- **A purge on a schedule, and quota.** `TomExportStore.deletePrefix` reclaims a
  day partition in one call, and nothing in this module runs it on a timer:
  *how long* an export is worth keeping is a deployment's decision, and *when*
  the pass runs belongs with its other nightly work. There is no quota either —
  nothing refuses a write because an account has stored too much. See
  [Retention](#retention).

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | 7 of 8 files | `Future`, `Stream` |
| `dart:convert` | dart | `csv_renderer.dart`, `export_store.dart`, `xlsx_renderer.dart` | `utf8` |
| `dart:io` | dart | `export_store.dart`, `xlsx_renderer.dart` | `ZLibEncoder` for the XLSX archive; `File` / `Directory` for the filesystem store |
| `dart:typed_data` | dart | `export_store.dart`, `xlsx_renderer.dart` | `Uint32List`, `Uint8List` |
| `path` | package | `export_store.dart` | key-to-path joining in `TomDirectoryExportStore` |
| `pdf` | package | `pdf_renderer.dart` | the PDF document model and its layout engine |
| `shelf` | package | `export_service.dart` | the `Response` returned by the `apiResponse` channel |
| `tom_core_kernel` | package | `export_service.dart` | `TomHeader` (the two response headers), `TomServerException` by way of `TomExportException` |
| [audit](audit.md) | module | `tabular_result.dart` | `TomAuditTrail.policyFor`, so that the fields a trail redacts are the fields an export omits. Consulting the same declaration is the point; a second redaction list here would be a second thing to get wrong |
| [datasources](datasources.md) | module | `tabular_result.dart` | `TomSqlTypeFamily` |
| [file_storage](file_storage.md) | module | `blob_export_store.dart`, `export_service.dart`, `export_store.dart` | `TomBlobStore` and its registry, used only by `TomBlobExportStore`; the rest of the module does not know it exists |
| [little_things](little_things.md) | module | `tabular_result.dart` | `TomServerException` |
| [object_persistence](object_persistence.md) | module | `tabular_result.dart` | `TomAnnotationAnalyzer` and `TomColumnInformation`, read only by the reflected projection |
