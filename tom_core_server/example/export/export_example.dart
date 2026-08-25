/// Executable example for the export module of `tom_core_server`.
///
/// Demonstrates the rendering engines end to end without a database, a browser
/// or a filesystem the run does not clean up: the streaming tabular shape the
/// renderers consume, the one abstraction all three formats implement, the
/// registry that keeps the format set open, what each format does with the same
/// result, the storage seam and its adaptor onto the framework's blob store,
/// and the two delivery channels an endpoint actually calls.
///
/// The thing to watch for is what is *absent*: at no point is a whole result or
/// a whole document held. Step 3 proves it — bytes arrive while rows are still
/// being produced.
///
/// Run with `dart run example/export/export_example.dart`.
/// The same behaviour is covered by `test/export_test.dart`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_server/tom_core_server.dart';

// ignore_for_file: avoid_print

/// The columns every step below renders, typed as the query layer types them.
List<TomTabularColumn> columns() => [
  TomTabularColumn('product', label: 'Product', width: 24),
  TomTabularColumn('amount', label: 'Amount', type: TomColumnType.decimal),
  TomTabularColumn('sold', label: 'Sold', type: TomColumnType.timestamp),
  TomTabularColumn('active', label: 'Active', type: TomColumnType.boolean),
];

/// A small result. A real one differs only in where its row stream comes from.
TomTabularResult salesResult() => TomTabularResult.single(
  title: 'Sales',
  metadata: {'Filter': 'region = EU', 'As of': '2026-07-28'},
  section: TomTabularSection.ofMaps(
    columns(),
    Stream.fromIterable([
      {
        'product': 'Widget',
        'amount': 19.5,
        'sold': DateTime(2026, 7, 1),
        'active': true,
      },
      {
        'product': 'Gadget, large',
        'amount': 4.0,
        'sold': DateTime(2026, 7, 2, 14, 30),
        'active': false,
      },
    ]),
    title: 'Regions',
  ),
);

Future<void> run() async {
  // 1. The input is a *shape*, not a format. Rows are a stream because an
  //    export exists precisely for the results too large to return inline: a
  //    list would need heap for every row and the rendered document at once.
  //    Cells are positional to the columns — at a million rows, one list per
  //    row rather than one hash table is the whole memory budget.
  final result = salesResult();
  print(
    '1. result                    : ${result.title}, '
    '${result.sections.length} section(s), '
    '${result.sections.first.columns.length} columns',
  );
  assert(result.metadata['Filter'] == 'region = EU');

  // 2. One abstraction, three formats. Each renderer answers the same four
  //    questions and returns the same kind of stream, which is what makes the
  //    delivery channels below indifferent to which one ran.
  final formats = TomExportFormats.standard();
  for (final renderer in formats.renderers) {
    print(
      '2. ${renderer.formatId.padRight(5)} '
      '${renderer.fileNameFor('sales').padRight(10)} '
      'streams=${renderer.streamsRows}  ${renderer.mediaType}',
    );
  }
  assert(formats.formatIds.toSet().containsAll({'csv', 'xlsx', 'pdf'}));

  // 3. Streaming, demonstrated rather than asserted in prose. Rows are fed one
  //    at a time and the first bytes are already out before the row stream is
  //    closed — so peak memory is a row, not a result.
  final rows = StreamController<TomTabularRow>();
  final chunks = <int>[];
  final done = const TomCsvRenderer(byteOrderMark: false)
      .render(
        TomTabularResult.single(
          title: 'Live',
          section: TomTabularSection(columns: columns(), rows: rows.stream),
        ),
      )
      .listen(chunks.addAll)
      .asFuture<void>();

  rows.add(const TomTabularRow(['Widget', 1.0, null, true]));
  await Future<void>.delayed(Duration.zero);
  print('3. bytes out before close    : ${chunks.length}');
  assert(chunks.isNotEmpty);
  await rows.close();
  await done;

  // 4. CSV is the baseline: no dependency, RFC 4180, CRLF, and a UTF-8 BOM by
  //    default because Excel reads a BOM-less UTF-8 file in the system codepage
  //    and mangles every non-ASCII character in it.
  //
  //    A result is built per render from here on: its rows are a
  //    single-subscription stream, so rendering the same one twice would ask a
  //    consumed stream for rows it no longer has.
  final csv = utf8.decode(await collect(formats, salesResult(), 'csv'));
  print(
    '4. csv                       : '
    '${csv.replaceAll('\r\n', ' | ').trim()}',
  );
  //    A comma inside a value is quoted, not escaped away.
  assert(csv.contains('"Gadget, large"'));

  // 5. A cell beginning `=`, `+`, `-` or `@` is a *formula* to a spreadsheet:
  //    an exported value someone else supplied becoming code on the machine
  //    that opens the file. Quoting alone does not stop it; a leading tab does,
  //    and is stripped on display.
  //
  //    The guard tests the value's runtime type, not the column's declared
  //    type. A tab-prefixed field reads as *text*, so guarding a number would
  //    cost every negative figure its arithmetic — `-7` below stays bare. And
  //    a `String` reaching a numeric column is a tolerated mismatch, so the
  //    `=1+1` here is guarded whatever column it was declared under.
  final injected = await collect(
    formats,
    TomTabularResult.single(
      title: 'Injection',
      section: TomTabularSection.ofRows(
        [
          TomTabularColumn('note'),
          TomTabularColumn('delta', type: TomColumnType.integer),
        ],
        [
          const TomTabularRow(['=1+1', -7]),
        ],
      ),
    ),
    'csv',
  );
  final injectedText = utf8.decode(injected);
  print(
    '5. formula neutralised       : '
    '${injectedText.contains('"\t=1+1",-7')}',
  );
  assert(injectedText.contains('"\t=1+1",-7'));

  // 6. XLSX is a ZIP of XML parts, which is the one office format producible
  //    strictly front-to-back — inline strings instead of a shared-strings
  //    table, and ZIP data descriptors instead of up-front CRCs. Hence
  //    streamsRows stays true for the rich format too.
  final xlsx = await collect(formats, salesResult(), 'xlsx');
  print(
    '6. xlsx bytes                : ${xlsx.length} '
    '(starts with "PK": ${xlsx[0] == 0x50 && xlsx[1] == 0x4B})',
  );
  assert(xlsx[0] == 0x50 && xlsx[1] == 0x4B);

  // 7. PDF is the exception, and says so. Its file structure ends with a table
  //    of byte offsets into everything before it, so no conforming writer can
  //    emit the first page before placing the last object. The renderer states
  //    its ceiling rather than discovering it — and *fails* at the limit, since
  //    a silently shortened report is a wrong report that looks right.
  final pdf = await collect(formats, salesResult(), 'pdf');
  print(
    '7. pdf bytes                 : ${pdf.length} '
    '(streams rows: ${formats.rendererFor('pdf').streamsRows})',
  );
  assert(utf8.decode(pdf.take(5).toList()) == '%PDF-');

  try {
    await const TomPdfRenderer(rowLimit: 1).render(salesResult()).drain<void>();
  } on TomExportException catch (e) {
    print(
      '   over the row limit        : ${e.key} '
      '-> use ${e.parameters?['formats']}',
    );
    assert(e.key == 'export.pdf.row_limit_exceeded');
  }

  // 8. The registry is open. An application adds the fixed-width extract a
  //    partner insists on without the export service learning about it, and
  //    re-registering an id *replaces* — a semicolon CSV for a European locale
  //    is still `csv`, and should not need a new name.
  formats.register(const TomCsvRenderer(fieldSeparator: ';'));
  final semicolons = utf8.decode(await collect(formats, salesResult(), 'csv'));
  print('8. re-registered csv         : ${semicolons.split('\r\n').first}');
  assert(semicolons.contains('Product;Amount'));

  try {
    formats.rendererFor('ods');
  } on TomExportException catch (e) {
    print(
      '   unknown format            : ${e.key} '
      '(have ${e.parameters?['available']})',
    );
    assert(e.key == 'export.format.unknown');
  }

  // 9. Storage is deliberately the narrowest interface an export needs — put a
  //    stream under a key, read it back, ask, delete. That narrowness is what
  //    lets `TomBlobExportStore` put every `file_storage` backend behind the
  //    same four methods, in four delegating lines, without anything that
  //    renders or delivers an export knowing which backend ran. The two own
  //    backends below remain because an export module that works with no
  //    storage configured at all is worth the hundred lines.
  final store = TomMemoryExportStore();
  final service = TomExportService(store: store);

  final key = service.keyFor(
    'sales',
    'csv',
    partitionOn: DateTime(2026, 7, 28),
  );
  final stored = await service.storeAs(salesResult(), 'csv', key: key);
  print(
    '9. stored                    : ${stored.key} '
    '(${stored.byteCount} bytes, ${stored.mediaType})',
  );
  assert(stored.key == '2026/07/28/sales.csv');
  assert(await store.exists(key));

  // A key becomes a path in the obvious backend, so one built from a report
  // title is a directory traversal waiting to happen. The check lives on the
  // interface, so every backend gets it — including ones written later.
  try {
    TomExportStore.validateKey('../../etc/passwd');
  } on TomExportException catch (e) {
    print('   traversal rejected        : ${e.key}');
    assert(e.key == 'export.store.invalid_key');
  }

  // 10. The apiResponse channel: the renderer's stream *is* the response body.
  //     No Content-Length, because the length is not known until the last row
  //     and the only alternative to omitting it is buffering the document to
  //     measure it. A million-row CSV starts arriving while the query runs.
  final response = service.respondWith(
    salesResult(),
    'xlsx',
    baseName: 'Q3 sales',
  );
  print('10. content-type             : ${response.headers['content-type']}');
  print(
    '    disposition             : '
    '${response.headers['content-disposition']}',
  );
  print('    content-length          : ${response.headers['content-length']}');
  assert(response.headers['content-length'] == null);

  // 11. A file name reaches that header from a report title, which reaches it
  //     from a user. A quote or a newline in it would end the parameter and
  //     start another header — the download equivalent of an injection.
  print(
    '11. sanitised               : '
    '"${TomExportService.sanitiseFileName('a".csv\r\nX-Evil: 1')}"',
  );
  assert(
    !TomExportService.sanitiseFileName('a".csv\r\nX-Evil: 1').contains('"'),
  );

  // 12. Storing without a configured store is a *configuration* error and says
  //     so. The store is optional because a server that only streams exports
  //     back through its API never needs one, and requiring it would force a
  //     filesystem decision on a deployment with no use for it.
  try {
    await TomExportService().storeAs(salesResult(), 'csv', key: 'sales.csv');
  } on TomExportException catch (e) {
    print('12. no store configured     : ${e.key}');
    assert(e.key == 'export.service.no_store');
  }
}

/// Renders [result] as [format] and gathers the bytes — for printing only.
///
/// Collecting is what an example does and what a server must not: every path
/// in the module is a stream precisely so the whole document never exists.
Future<List<int>> collect(
  TomExportFormats formats,
  TomTabularResult result,
  String format,
) async {
  final bytes = <int>[];
  await for (final chunk in formats.rendererFor(format).render(result)) {
    bytes.addAll(chunk);
  }
  return bytes;
}

Future<void> main() async {
  await run();
}
