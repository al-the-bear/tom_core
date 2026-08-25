/// Executable example for the export module of `tom_core_server`.
///
/// Demonstrates the rendering engines end to end without a database, a browser
/// or a filesystem the run does not clean up: the streaming tabular shape the
/// renderers consume, the same shape with its columns derived from a reflected
/// entity instead of written out, the one abstraction all three formats
/// implement, the registry that keeps the format set open, what each format
/// does with the same result, the storage seam and its adaptor onto the
/// framework's blob store, and the two delivery channels an endpoint actually
/// calls.
///
/// The thing to watch for is what is *absent*: at no point is a whole result or
/// a whole document held. Step 3 proves it — bytes arrive while rows are still
/// being produced. Nor is a second declaration of the column set: step 5
/// renders the same file from `@TomDbColumn` and compares it byte for byte.
///
/// Run with `dart run example/export/export_example.dart`. Every step checks
/// its own result and the run fails when one does not hold, so a green run is a
/// verification and not just a transcript. `test/export_test.dart` runs this
/// file under that exact command and requires it to exit 0, which is what keeps
/// the checks honest once nobody runs the example by hand.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

// The reflected entity step 5 derives its columns from, and the generated
// reflection that makes those annotations readable at run time. The root is
// `example/example_reflection.dart`, shared with the other two examples that
// need a reflector — see its header for why there is one and not three.
import '../example_reflection.reflection.dart';
import 'export_entities.dart';

// ignore_for_file: avoid_print

/// Throws unless [ok] holds, naming the expectation that failed.
///
/// Deliberately not `assert`: `dart run` leaves assertions **disabled** — that
/// is what its `--enable-asserts` flag is for — so an `assert` here compiles
/// out under the very command this file's header gives. An example whose
/// checks vanish under its own documented invocation is worse than one with no
/// checks at all, because it still prints a plausible transcript and still
/// exits 0 while every expectation in it is violated. A plain `if`/`throw`
/// holds however the file is run.
void check(bool ok, String expectation) {
  if (!ok) throw StateError('export example failed: $expectation');
}

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

/// The same two rows as [salesResult], as the entity that declares their shape.
///
/// Every value matches, because step 5 renders both and compares the bytes: a
/// difference here would make that comparison fail for a reason that has
/// nothing to do with the projection. The three fields the hand-written columns
/// have no counterpart for are populated on purpose — a column that leaked into
/// the export would then be visible in it, where a `null` one would render as
/// an empty cell and hide the leak.
Stream<ExampleSaleRecord> sales() => Stream.fromIterable([
  ExampleSaleRecord()
    ..id = 1
    ..product = 'Widget'
    ..amount = 19.5
    ..sold = DateTime(2026, 7, 1)
    ..active = true
    ..internalRank = 'A2'
    ..receipt = 'sales/receipt/1.pdf',
  ExampleSaleRecord()
    ..id = 2
    ..product = 'Gadget, large'
    ..amount = 4.0
    ..sold = DateTime(2026, 7, 2, 14, 30)
    ..active = false
    ..internalRank = 'B1'
    ..receipt = 'sales/receipt/2.pdf',
]);

/// The declared field names of a section's columns, in output order.
List<String> names(TomTabularSection section) => [
  for (final column in section.columns) column.name,
];

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
  check(
    result.metadata['Filter'] == 'region = EU',
    'metadata travels with the result',
  );

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
  check(
    formats.formatIds.toSet().containsAll({'csv', 'xlsx', 'pdf'}),
    'the standard registry ships csv, xlsx and pdf',
  );

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
  check(chunks.isNotEmpty, 'bytes are out before the row stream is closed');
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
  check(csv.contains('"Gadget, large"'), 'a comma in a value is quoted');

  // 5. The same file, with no second declaration. `columns()` at the top of
  //    this file restates what `ExampleSaleRecord` already says in
  //    `@TomDbColumn`, and two declarations drift both ways: a column added to
  //    the entity never reaches the export, and a type changed on it leaves
  //    cells formatted under a stale `TomColumnType`. `fromEntities` reads the
  //    column set off the annotations instead — so this step renders the same
  //    two rows from a stream of *entities* and compares the output with step
  //    4's, which is the claim in one equality rather than in a paragraph.
  //
  //    What no single run can show is the drift itself, since an entity cannot
  //    grow a field while the program is running:
  //    `test/export_entities_test.dart` derives from two versions of one entity
  //    that differ by exactly one column, with no export-side edit between them.
  //
  //    Deriving reads annotations rather than rows, so a section's columns
  //    exist before anything subscribes — which is what keeps this a
  //    constructor and not a `Future`, and is the same reason the module refuses
  //    to infer columns from a first row.
  var pulled = 0;
  final derivedSection = TomTabularSection.ofEntities<ExampleSaleRecord>(
    sales().map((record) {
      pulled++;
      return record;
    }),
    exclude: {'id'},
  );
  print('5. derived columns           : ${names(derivedSection).join(', ')}');
  check(pulled == 0, 'deriving the columns pulls no rows');
  //    Compared against `columns()` rather than against a written-out list,
  //    because "the hand-written projection is redundant" is exactly the claim,
  //    and a list here would be a third declaration to keep in step.
  check(
    names(derivedSection).join() == columns().map((c) => c.name).join(),
    'the derived column set is the hand-written one',
  );
  check(
    derivedSection.columns.map((c) => c.type).join() ==
        columns().map((c) => c.type).join(),
    'and each column is typed from the field it was derived from',
  );
  //    `id` left by `exclude`, keyed by declared field name — `id`, never the
  //    `id` column; the two happen to agree here and `createdAt`/`created_at`
  //    would not. `internalRank` and `receipt` left without being named, under
  //    the two rules below.
  check(
    !names(derivedSection).contains('internalRank') &&
        !names(derivedSection).contains('receipt'),
    'a redacted field and a file reference are absent by default',
  );

  //    Both defaults are "not exported", and there the resemblance stops.
  //    Redaction is a declaration that the value must not exist in a second
  //    place at all, and an export is a second place — so `include` cannot
  //    reach the field, and asking is an error rather than a quiet override.
  var redactedKey = '';
  try {
    TomTabularSection.ofEntities<ExampleSaleRecord>(
      const Stream.empty(),
      include: ['product', 'internalRank'],
    );
  } on TomExportException catch (e) {
    redactedKey = e.key;
    print('   asking for a redacted field: ${e.key}');
  }
  check(
    redactedKey == 'export.entities.redacted_column',
    'a redacted field cannot be exported by naming it',
  );

  //    A file column is merely default-closed: it holds a storage *key* rather
  //    than content, which is a small leak and useless to most readers — but an
  //    audience with a use for the keys gets them by asking. Opening that rule
  //    does not open the other one.
  final withFiles = TomTabularSection.ofEntities<ExampleSaleRecord>(
    const Stream.empty(),
    exclude: {'id'},
    includeFileReferences: true,
  );
  print('   with file references      : ${names(withFiles).join(', ')}');
  check(
    names(withFiles).contains('receipt') &&
        !names(withFiles).contains('internalRank'),
    'the file rule opens on request and the redaction rule does not',
  );

  //    The entity declares the schema and not the presentation, so the derived
  //    header carries field names where step 4 carried headings. Every data row
  //    is already identical; `titles` supplies the headings, and then the whole
  //    file is.
  final derivedCsv = utf8.decode(
    await collect(
      formats,
      TomTabularResult.single(
        title: 'Sales',
        section: TomTabularSection.ofEntities<ExampleSaleRecord>(
          sales(),
          exclude: {'id'},
        ),
      ),
      'csv',
    ),
  );
  //    Everything after the header line, which is where the headings live.
  String body(String file) => file.split('\r\n').skip(1).join('\r\n');
  check(
    body(derivedCsv) == body(csv),
    'the derived rows are the hand-written rows, byte for byte',
  );
  final titledCsv = utf8.decode(
    await collect(
      formats,
      TomTabularResult.fromEntities<ExampleSaleRecord>(
        sales(),
        title: 'Sales',
        sectionTitle: 'Regions',
        metadata: {'Filter': 'region = EU', 'As of': '2026-07-28'},
        exclude: {'id'},
        titles: {
          'product': 'Product',
          'amount': 'Amount',
          'sold': 'Sold',
          'active': 'Active',
        },
      ),
      'csv',
    ),
  );
  print(
    '   derived vs step 4 csv     : '
    'rows ${body(derivedCsv) == body(csv)}, '
    'file ${derivedCsv == csv} -> with titles ${titledCsv == csv}',
  );
  check(titledCsv == csv, 'the derived export is the hand-written export');

  // 6. A cell beginning `=`, `+`, `-` or `@` is a *formula* to a spreadsheet:
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
    '6. formula neutralised       : '
    '${injectedText.contains('"\t=1+1",-7')}',
  );
  check(
    injectedText.contains('"\t=1+1",-7'),
    'a formula is tab-guarded and a negative number is not',
  );

  // 7. XLSX is a ZIP of XML parts, which is the one office format producible
  //    strictly front-to-back — inline strings instead of a shared-strings
  //    table, and ZIP data descriptors instead of up-front CRCs. Hence
  //    streamsRows stays true for the rich format too.
  final xlsx = await collect(formats, salesResult(), 'xlsx');
  print(
    '7. xlsx bytes                : ${xlsx.length} '
    '(starts with "PK": ${xlsx[0] == 0x50 && xlsx[1] == 0x4B})',
  );
  check(xlsx[0] == 0x50 && xlsx[1] == 0x4B, 'the xlsx output is a ZIP');

  // 8. PDF is the exception, and says so. Its file structure ends with a table
  //    of byte offsets into everything before it, so no conforming writer can
  //    emit the first page before placing the last object. The renderer states
  //    its ceiling rather than discovering it — and *fails* at the limit, since
  //    a silently shortened report is a wrong report that looks right.
  final pdf = await collect(formats, salesResult(), 'pdf');
  print(
    '8. pdf bytes                 : ${pdf.length} '
    '(streams rows: ${formats.rendererFor('pdf').streamsRows})',
  );
  check(
    utf8.decode(pdf.take(5).toList()) == '%PDF-',
    'the pdf output carries the PDF signature',
  );

  //    A width is a count of characters, in every format — the one unit that
  //    says something about the data rather than about one output. Only
  //    `product` above states one; the rest are sized from their type, which is
  //    why an ISO timestamp gets 23 and a `true`/`false` column gets its
  //    label's 6.
  //
  //    A page's total width is fixed, so the PDF cannot give a column its
  //    literal 24 characters; what it keeps is the *ratio*. Which is exactly
  //    why these numbers must not be read as proportions to begin with: doing
  //    that made this very example print `product` across seven eighths of the
  //    table and send `Amount` down the margin as `A`, `m`, `ou`, `nt`.
  print(
    '   column widths (chars)     : '
    '${columns().map((c) => '${c.label}=${c.effectiveWidth}').join(' ')}',
  );
  check(columns()[0].effectiveWidth == 24, 'a stated width is kept');
  check(
    columns()[2].effectiveWidth == 23,
    'an unstated width is inferred from the column type',
  );

  var rowLimitKey = '';
  try {
    await const TomPdfRenderer(rowLimit: 1).render(salesResult()).drain<void>();
  } on TomExportException catch (e) {
    rowLimitKey = e.key;
    print(
      '   over the row limit        : ${e.key} '
      '-> use ${e.parameters?['formats']}',
    );
  }
  // Outside the `catch`, so that *not throwing* fails too — a silently
  // shortened report is the failure this limit exists to prevent.
  check(
    rowLimitKey == 'export.pdf.row_limit_exceeded',
    'the pdf renderer refuses a result past its row limit',
  );

  // 9. The registry is open. An application adds the fixed-width extract a
  //    partner insists on without the export service learning about it, and
  //    re-registering an id *replaces* — a semicolon CSV for a European locale
  //    is still `csv`, and should not need a new name.
  formats.register(const TomCsvRenderer(fieldSeparator: ';'));
  final semicolons = utf8.decode(await collect(formats, salesResult(), 'csv'));
  print('9. re-registered csv         : ${semicolons.split('\r\n').first}');
  check(
    semicolons.contains('Product;Amount'),
    're-registering an id replaces the renderer under it',
  );

  var unknownFormatKey = '';
  try {
    formats.rendererFor('ods');
  } on TomExportException catch (e) {
    unknownFormatKey = e.key;
    print(
      '   unknown format            : ${e.key} '
      '(have ${e.parameters?['available']})',
    );
  }
  check(
    unknownFormatKey == 'export.format.unknown',
    'an unregistered format id is refused by name',
  );

  // 10. Storage is deliberately the narrowest interface an export needs — put
  //     a stream under a key, read it back, ask, delete. That narrowness is
  //     what lets `TomBlobExportStore` put every `file_storage` backend behind
  //     the same four methods, in four delegating lines, without anything that
  //     renders or delivers an export knowing which backend ran. The module's
  //     two own backends remain because an export module that works with no
  //     storage configured at all is worth the hundred lines. Step 11 runs one
  //     export through all three.
  final store = TomMemoryExportStore();
  final service = TomExportService(store: store);

  // One report name, used for *both* channels below. Reports are named by
  // people, so `Q3 sales` is the ordinary case and not the awkward one — and an
  // example that quietly passed `sales` here and `Q3 sales` to `respondWith`
  // would demonstrate nothing about whether the two agree.
  const reportName = 'Q3 sales';

  final key = service.keyFor(
    reportName,
    'csv',
    partitionOn: DateTime(2026, 7, 28),
  );
  final stored = await service.storeAs(salesResult(), 'csv', key: key);
  print(
    '10. stored                   : ${stored.key} '
    '(${stored.byteCount} bytes, ${stored.mediaType})',
  );
  check(
    stored.key == '2026/07/28/Q3_sales.csv',
    'a partitioned key is a date path and a sanitised name',
  );
  check(await store.exists(key), 'the stored export is there under its key');

  // A key becomes a path in the obvious backend, so one built from a report
  // title is a directory traversal waiting to happen. Two defences, and the
  // difference between them is the point: `keyFor` *neutralises* a name,
  // because refusing one that `respondWith` would serve happily is an
  // asymmetry a caller trips over; `validateKey` still *refuses* a key,
  // because a key is assembled by code and a malformed one is a bug. The check
  // lives on the interface, so every backend gets it — including ones written
  // later.
  print(
    '    traversal neutralised    : '
    '${service.keyFor('../../etc/passwd', 'csv')}',
  );
  check(
    service.keyFor('../../etc/passwd', 'csv') == '.._.._etc_passwd.csv',
    'a traversal in a report name is neutralised rather than refused',
  );
  var invalidKeyKey = '';
  try {
    TomExportStore.validateKey('../../etc/passwd');
  } on TomExportException catch (e) {
    invalidKeyKey = e.key;
    print('    traversal rejected       : ${e.key}');
  }
  check(
    invalidKeyKey == 'export.store.invalid_key',
    'a traversal in an assembled key is refused',
  );

  // 11. The seam, run rather than described. One rendered report under one
  //     key, through three backends — the module's own two and the adaptor
  //     that stands in for every `file_storage` backend there is. The service
  //     is constructed the same way each time and nothing above this line
  //     changes, which is the whole of what the narrow interface buys.
  //
  //     (`example/file_storage/` reaches the same adaptor from the other side:
  //     raw bytes through the blob API, no renderer and no service. Here the
  //     point is that the *service* cannot tell which backend it was given.)
  //
  //     The directory store is handed a path that does not exist: it is
  //     configured before it is a directory, and the first `store` creates the
  //     root and the key's `2026/07/28` together. That matters because the
  //     alternative — create the root at construction — makes configuring an
  //     export store a filesystem write, which a config parse has no business
  //     doing.
  final blobs = TomMemoryBlobStore();
  final scratch = Directory.systemTemp.createTempSync('tom_export_example_');
  final exportRoot = Directory('${scratch.path}/exports');
  try {
    print('11. one export, three stores :');
    check(
      !exportRoot.existsSync(),
      'the directory store is configured before its root exists',
    );
    for (final backend in <TomExportStore>[
      TomMemoryExportStore(),
      TomDirectoryExportStore(exportRoot),
      TomBlobExportStore(blobs, keyPrefix: 'exports'),
    ]) {
      final written = await TomExportService(
        store: backend,
      ).storeAs(salesResult(), 'csv', key: key);
      final read = await backend.open(key).expand((chunk) => chunk).toList();
      print(
        '    ${backend.runtimeType.toString().padRight(24)}'
        // The location's *scheme*, not the URI: one is this machine's own
        // path. What differs across backends is whether an address is offered
        // at all — a store with none legitimately reports null.
        '${written.byteCount} bytes, reads back ${read.length}, '
        'location ${written.location?.scheme ?? '(none)'}',
      );
      check(written.key == key, '$backend records the key it was given');
      check(
        read.length == written.byteCount,
        '$backend reads back what it counted',
      );
      check(await backend.exists(key), '$backend holds the export it wrote');
    }

    //     What the directory store made of the key while the loop was not
    //     looking: the slashes in `2026/07/28/…` are real directories, so a
    //     retention rule can be a `find`, and two reports from the same day
    //     land beside each other rather than in one flat pile of names.
    check(
      File('${exportRoot.path}/$key').existsSync(),
      'the key becomes a path under a root the first store created',
    );

    //     The prefix is the one thing that does not travel back — which is why
    //     the loop above could check one key against all three. It exists
    //     because an export store is usually pointed at a bucket holding other
    //     things, and namespacing them makes a retention rule expressible as a
    //     prefix. The blob store therefore sees `exports/…` while the
    //     `TomStoredExport` records what the caller passed: reporting the
    //     prefixed key would hand back something `open` does not accept.
    print('    key in the blob store    : ${blobs.keys.single}');
    check(
      blobs.keys.single == 'exports/$key',
      'the prefix reaches the blob store and nothing else does',
    );
    check(
      await blobs.exists('exports/$key'),
      'the prefixed key is the one the blob store answers for',
    );
  } finally {
    scratch.deleteSync(recursive: true);
  }

  // 12. The apiResponse channel: the renderer's stream *is* the response body.
  //     No Content-Length, because the length is not known until the last row
  //     and the only alternative to omitting it is buffering the document to
  //     measure it. A million-row CSV starts arriving while the query runs.
  final response = service.respondWith(
    salesResult(),
    'xlsx',
    baseName: reportName,
  );
  print('12. content-type             : ${response.headers['content-type']}');
  print(
    '    disposition              : '
    '${response.headers['content-disposition']}',
  );
  print('    content-length           : ${response.headers['content-length']}');
  check(
    response.headers['content-length'] == null,
    'no Content-Length, because measuring it would mean buffering',
  );

  //     The same name on both channels, spelled two ways and refused by
  //     neither. A `Content-Disposition` filename is a Latin-1 quoted string
  //     and a storage key is a relative path of unreserved characters, so the
  //     space survives on one side and becomes `_` on the other. What must not
  //     differ is which names are *accepted* — `keyFor` used to throw on this
  //     one while `respondWith` served it.
  check(
    response.headers['content-disposition']!.contains('"Q3 sales.xlsx"'),
    'the space survives into the download name',
  );
  check(
    service.keyFor(reportName, 'xlsx') == 'Q3_sales.xlsx',
    'and the same name is accepted as a key, spelled with an underscore',
  );

  // 13. A file name reaches that header from a report title, which reaches it
  //     from a user. A quote or a newline in it would end the parameter and
  //     start another header — the download equivalent of an injection.
  print(
    '13. sanitised                : '
    '"${TomExportService.sanitiseFileName('a".csv\r\nX-Evil: 1')}"',
  );
  check(
    !TomExportService.sanitiseFileName('a".csv\r\nX-Evil: 1').contains('"'),
    'a quote cannot close the filename parameter',
  );

  // 14. Storing without a configured store is a *configuration* error and says
  //     so. The store is optional because a server that only streams exports
  //     back through its API never needs one, and requiring it would force a
  //     filesystem decision on a deployment with no use for it.
  var noStoreKey = '';
  try {
    await TomExportService().storeAs(salesResult(), 'csv', key: 'sales.csv');
  } on TomExportException catch (e) {
    noStoreKey = e.key;
    print('14. no store configured      : ${e.key}');
  }
  check(
    noStoreKey == 'export.service.no_store',
    'storing with no store configured names the configuration fault',
  );
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
  // Reflection first: step 5 derives its columns from `@TomDbColumn`, so
  // `ofEntities` throws "Reflection has not been initialized" without this. It
  // is what any deployment does at start-up, and it is the derived route's only
  // prerequisite — no database, and nothing read off a row.
  initializeReflection();
  await run();
}
