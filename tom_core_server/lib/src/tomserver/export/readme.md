# export

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

A tabular result rendered to CSV, XLSX or PDF — with charts of its own rows —
and stored for later retrieval or sent by email, with a register of what was
stored that a per-owner quota and a retention purge work from.

The shape a caller builds is deliberately **not** a spreadsheet or a document:
it is a titled result of typed columns over a **stream** of rows. That is what
lets one description serve three formats, and what keeps a million-row export
from being a million-row list in memory — a renderer that can stream says so
(`streamsRows`), and the row source is consumed once.

Columns are typed rather than stringly, because the type is what a format acts
on: a `TomColumnType.decimal` is right-aligned in a PDF, written as a number in
XLSX so a spreadsheet can sum it, and rendered without a thousands separator in
CSV so a parser can read it back.

## Key types

### The result a caller builds

| Type | What it is |
| ---- | ---------- |
| `TomTabularResult` | A titled document: metadata plus one or more sections. |
| `TomTabularSection` | One table: typed columns over a stream of rows. |
| `TomTabularColumn` · `TomColumnType` | A named, typed column, with a width in characters. |
| `TomTabularRow` | Cell values, positional to the section's columns. |
| `TomTabularSection.ofEntities` · `TomTabularResult.fromEntities` | The same, with the columns derived from a reflected entity — so an export follows the entity rather than being a second declaration of it. |
| `TomTabularChart` · `TomChartType` | A bar, line or pie chart on a section, naming its category and value columns rather than carrying data, so it plots exactly the rows the table shows. PDF draws it below the table, XLSX writes a native chart bound to the sheet's cells, CSV leaves it out. |
| `TomExportException` | The module's error. |

### The renderers

| Type | What it is |
| ---- | ---------- |
| `TomTabularRenderer` | The contract: a format id, a media type, a file extension, and `render`. |
| `TomCsvRenderer` · `TomXlsxRenderer` · `TomPdfRenderer` | The three shipped formats. The XLSX writer builds the zip itself, so the package carries no spreadsheet dependency. CSV has no ceiling; XLSX and PDF state theirs and fail at them rather than emitting a file no reader accepts. |
| `TomExportFormats` | The registry a format is looked up in, and where a deployment registers its own. |

### Delivery and storage

| Type | What it is |
| ---- | ---------- |
| `TomExportService` | Renders and answers: `respondWith` returns the bytes as an HTTP response, `inline` or as a download; `storeAs` stores them, recording the export and checking the owner's quota when it has a register and a quota. |
| `TomExportStore` · `TomStoredExport` | Where a rendered export is kept when it is not answered immediately, and what is known about one. It stores, reads, probes, deletes and reclaims a prefix; it does not enumerate — the register does. |
| `TomDirectoryExportStore` · `TomMemoryExportStore` | The two stores needing no infrastructure. |
| `TomBlobExportStore` | The same over a `TomBlobStore`, so an export lands wherever the deployment's files already live rather than in a second place. |
| `TomExportStoreOperation` | What the caller asked for when a store failed, carrying a stable error key. |
| `TomExportEmailDelivery` · `TomExportEmailMode` | The email channel: a stored export sent as a link or an attachment (or `auto`, by size), queued through the `messaging` module's outbox, which owns the delivery. |

### The register, quota and retention

| Type | What it is |
| ---- | ---------- |
| `TomExportRegister` · `TomExportRecord` · `TomExportUsage` | The record of stored exports — key, owner, size, media type, time, title — which `storeAs` writes; the enumeration the store does not have. |
| `TomMemoryExportRegister` · `TomSqlExportRegister` | In memory, and one row per export in `tom_export` (`exportRegisterTable`, `exportRegisterTableDdl`, `defaultExportRegisterTable`; rows `TomExportRecordRow`, `TomExportUsageRow`), listed by `frameworkOwnedTables`. |
| `TomExportQuota` | How many exports and bytes one owner may hold, checked before rendering and again after the store. |
| `TomExportRetention` | Deletes exports older than a maximum age, bytes and records, by hand (`purge`) or as a scheduled job (`jobDefinition`). |

## Quick start

```dart
import 'dart:convert';

import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final result = TomTabularResult(
    title: 'Invoices',
    sections: [
      TomTabularSection(
        columns: [
          TomTabularColumn('id', type: TomColumnType.integer),
          TomTabularColumn('total', type: TomColumnType.decimal),
        ],
        rows: Stream.fromIterable([
          TomTabularRow([1, 19.99]),
          TomTabularRow([2, 4.50]),
        ]),
      ),
    ],
  );

  // `render` is a stream: a million-row export never becomes a million-row
  // list, and the row source is consumed once.
  final csv = StringBuffer();
  await for (final chunk in TomCsvRenderer().render(result)) {
    csv.write(utf8.decode(chunk));
  }
  print(csv.toString().contains('19.99')); // true
}
```

This is the **lower half** of a reporting element. It renders and delivers; it
does not define reports, and it will not — a report definition names a query, a
projection, a delivery channel and a schedule, and a module that both defined
reports and rendered them would have two reasons to change. When the reporting
half is specified it becomes a module of its own that depends on this one, and
it adapts its envelope onto `TomTabularResult` rather than this module growing
to meet it. `doc/export.md` names the seams it will use and the property that
keeps that adaptation cheap.

See [`doc/export.md`](../../../../doc/export.md) for the full treatment: the
streaming contract, what each format does with a column type and a chart,
deriving columns from an entity, the store seam, the delivery channels, the
register, quota and retention, and the reporting boundary.
`example/export/export_example.dart` runs the rendering and storage surface
without a server, `example/export/export_email.dart` sends a stored export as a
link and as an attachment through the outbox, and
`example/export/export_retention.dart` runs the register, the quota and the
purge. `test/export_test.dart`, `test/export_entities_test.dart`,
`test/export_register_test.dart` and `test/export_register_db_test.dart` cover
the module.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
