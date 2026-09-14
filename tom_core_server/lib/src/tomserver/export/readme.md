# export

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

A tabular result rendered to CSV, XLSX or PDF, and stored for later retrieval.

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
| `TomExportException` | The module's error. |

### The renderers

| Type | What it is |
| ---- | ---------- |
| `TomTabularRenderer` | The contract: a format id, a media type, a file extension, and `render`. |
| `TomCsvRenderer` · `TomXlsxRenderer` · `TomPdfRenderer` | The three shipped formats. The XLSX writer builds the zip itself, so the package carries no spreadsheet dependency. |
| `TomExportFormats` | The registry a format is looked up in, and where a deployment registers its own. |

### Delivery and storage

| Type | What it is |
| ---- | ---------- |
| `TomExportService` | Renders and answers: `respondWith` returns the bytes as an HTTP response, `inline` or as a download. |
| `TomExportStore` · `TomStoredExport` | Where a rendered export is kept when it is not answered immediately, and what is known about one. |
| `TomDirectoryExportStore` · `TomMemoryExportStore` | The two stores needing no infrastructure. |
| `TomBlobExportStore` | The same over a `TomBlobStore`, so an export lands wherever the deployment's files already live rather than in a second place. |
| `TomExportStoreOperation` | What the caller asked for when a store failed, carrying a stable error key. |

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
streaming contract, what each format does with a column type, deriving columns
from an entity, the store seam, and the reporting boundary. `example/export/export_example.dart` runs
the whole surface without a server, and `test/export_test.dart` and
`test/export_entities_test.dart` cover it.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
