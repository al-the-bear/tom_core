import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// The PDF renderer's knobs are `package:pdf`'s own types — see doc/export.md
// on why that library is a declared part of the renderer's surface.
import 'package:pdf/widgets.dart' show PageOrientation;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Export-rendering tests: the tabular envelope, three renderers, two channels.
///
/// Every assertion here is made on the **bytes that leave the renderer**, not
/// on an intermediate model. That is deliberate: the whole point of this module
/// is that a spreadsheet opens and a PDF renders, and those are properties of
/// the encoded file. So the XLSX tests unzip the archive and read its XML back,
/// and the PDF tests read the document structure out of the byte stream.
///
/// The other recurring theme is that streaming is *asserted*, not assumed. A
/// renderer that quietly collected every row would pass every content test and
/// fail the only requirement that made this module necessary, so the tests that
/// matter most feed rows through a controller and check that output appears
/// before the input is closed.

// =============================================================================
// FIXTURES
// =============================================================================

/// The columns used by most tests: one of every type.
List<TomTabularColumn> _columns() => [
      TomTabularColumn('id', label: 'ID', type: TomColumnType.integer),
      TomTabularColumn('name', label: 'Name'),
      TomTabularColumn('amount', label: 'Amount', type: TomColumnType.decimal),
      TomTabularColumn('active', label: 'Active', type: TomColumnType.boolean),
      TomTabularColumn('at', label: 'At', type: TomColumnType.timestamp),
    ];

/// A two-row result over [_columns].
TomTabularResult _sampleResult({String title = 'Sales', String? section}) =>
    TomTabularResult.single(
      title: title,
      section: TomTabularSection.ofRows(
        _columns(),
        [
          TomTabularRow([
            1,
            'Widget',
            9.5,
            true,
            DateTime.utc(2026, 7, 28),
          ]),
          TomTabularRow([
            2,
            'Gadget, large',
            12.0,
            false,
            DateTime.utc(2026, 7, 28, 14, 30),
          ]),
        ],
        title: section,
      ),
      metadata: {'Filter': 'region = EU'},
    );

/// Collects a renderer's byte stream into one buffer.
Future<Uint8List> _collect(Stream<List<int>> bytes) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in bytes) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

/// Renders [result] as [format] and returns the bytes.
Future<Uint8List> _render(TomTabularResult result, String format) =>
    _collect(TomExportFormats.standard().rendererFor(format).render(result));

/// Renders [result] as CSV and returns the text, BOM stripped.
Future<String> _renderCsv(
  TomTabularResult result, {
  TomCsvRenderer renderer = const TomCsvRenderer(),
}) async {
  final bytes = await _collect(renderer.render(result));
  final text = utf8.decode(bytes);
  return text.startsWith('﻿') ? text.substring(1) : text;
}

// =============================================================================
// A MINIMAL ZIP READER
// =============================================================================

/// Reads back the archive [TomXlsxRenderer] writes.
///
/// Written here rather than taken from `package:archive` because the archive
/// this has to read is the one under test: a reader that shares code with the
/// writer would agree with it about a mistake. Thirty lines of central-directory
/// parsing is a cheap independent witness.
class _ZipReader {
  _ZipReader(this.bytes);

  final Uint8List bytes;

  int _u16(int at) => bytes[at] | bytes[at + 1] << 8;
  int _u32(int at) =>
      bytes[at] | bytes[at + 1] << 8 | bytes[at + 2] << 16 | bytes[at + 3] << 24;

  /// Every entry's name mapped to its decompressed content.
  Map<String, String> read() {
    final eocd = _findEndOfCentralDirectory();
    final count = _u16(eocd + 10);
    var at = _u32(eocd + 16);
    final entries = <String, String>{};
    for (var i = 0; i < count; i++) {
      expect(_u32(at), 0x02014b50, reason: 'central directory signature');
      final method = _u16(at + 10);
      final compressedSize = _u32(at + 20);
      final uncompressedSize = _u32(at + 24);
      final nameLength = _u16(at + 28);
      final extraLength = _u16(at + 30);
      final commentLength = _u16(at + 32);
      final localOffset = _u32(at + 42);
      final name = utf8.decode(bytes.sublist(at + 46, at + 46 + nameLength));

      expect(_u32(localOffset), 0x04034b50, reason: 'local header signature');
      final dataAt = localOffset +
          30 +
          _u16(localOffset + 26) +
          _u16(localOffset + 28);
      final raw = bytes.sublist(dataAt, dataAt + compressedSize);
      final content = method == 0 ? raw : ZLibDecoder(raw: true).convert(raw);
      expect(content.length, uncompressedSize, reason: '$name size');
      entries[name] = utf8.decode(content);
      at += 46 + nameLength + extraLength + commentLength;
    }
    return entries;
  }

  int _findEndOfCentralDirectory() {
    for (var at = bytes.length - 22; at >= 0; at--) {
      if (_u32(at) == 0x06054b50) return at;
    }
    fail('no end-of-central-directory record');
  }
}

void main() {
  // ===========================================================================
  // THE TABULAR ENVELOPE
  // ===========================================================================

  group('TomTabularResult (the shape renderers consume)', () {
    test('a section without columns is rejected at construction', () {
      expect(
        () => TomTabularSection(columns: [], rows: const Stream.empty()),
        throwsA(isA<TomExportException>()),
      );
    });

    test('a section naming the same column twice is rejected', () {
      expect(
        () => TomTabularSection(
          columns: [TomTabularColumn('a'), TomTabularColumn('a')],
          rows: const Stream.empty(),
        ),
        throwsA(isA<TomExportException>()),
      );
    });

    test('a column with an empty name is rejected', () {
      expect(() => TomTabularColumn(''), throwsA(isA<TomExportException>()));
    });

    test('a result without sections is rejected', () {
      expect(
        () => TomTabularResult(title: 'x', sections: []),
        throwsA(isA<TomExportException>()),
      );
    });

    test('a column label defaults to its name', () {
      expect(TomTabularColumn('total').label, 'total');
    });

    test('fromMap orders values by the columns, not by the map', () {
      final columns = [
        TomTabularColumn('b'),
        TomTabularColumn('a'),
      ];
      final row = TomTabularRow.fromMap(columns, {'a': 'A', 'b': 'B'});
      expect(row.cells, ['B', 'A']);
    });

    test('fromMap ignores keys no column names', () {
      final row = TomTabularRow.fromMap(
        [TomTabularColumn('a')],
        {'a': 1, 'unused': 2},
      );
      expect(row.cells, [1]);
    });

    test('a short row reads null past its end rather than throwing', () {
      expect(const TomTabularRow(['only']).cell(3), isNull);
    });

    test('metadata is unmodifiable once the result exists', () {
      final result = _sampleResult();
      expect(() => result.metadata['x'] = 'y', throwsUnsupportedError);
    });

    test('column types cover exactly what the query layer produces', () {
      expect(TomColumnType.forValue(1), TomColumnType.integer);
      expect(TomColumnType.forValue(1.5), TomColumnType.decimal);
      expect(TomColumnType.forValue('s'), TomColumnType.text);
      expect(TomColumnType.forValue(true), TomColumnType.boolean);
      expect(TomColumnType.forValue(DateTime.now()), TomColumnType.timestamp);
      expect(TomColumnType.forValue(<int>[]), isNull);
    });

    test('ofMaps adapts a stream of keyed rows', () async {
      final section = TomTabularSection.ofMaps(
        [TomTabularColumn('a'), TomTabularColumn('b')],
        Stream.fromIterable([
          {'b': '2', 'a': '1'},
        ]),
      );
      final rows = await section.rows.toList();
      expect(rows.single.cells, ['1', '2']);
    });
  });

  // ===========================================================================
  // THE FORMAT REGISTRY
  // ===========================================================================

  group('TomExportFormats', () {
    test('the standard registry ships csv, xlsx and pdf', () {
      expect(TomExportFormats.standard().formatIds, ['csv', 'xlsx', 'pdf']);
    });

    test('an unknown format fails with the available ones named', () {
      expect(
        () => TomExportFormats.standard().rendererFor('doc'),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.parameters?['available'],
            'available',
            contains('csv'),
          ),
        ),
      );
    });

    test('registering the same id again replaces the renderer', () {
      final formats = TomExportFormats.standard()
        ..register(const TomCsvRenderer(fieldSeparator: ';'));
      final renderer = formats.rendererFor('csv') as TomCsvRenderer;
      expect(renderer.fieldSeparator, ';');
      expect(formats.formatIds.length, 3);
    });

    test('each standard registry is a fresh one, not a shared mutable', () {
      TomExportFormats.standard().register(const _JsonLinesRenderer());
      expect(TomExportFormats.standard().supports('jsonl'), isFalse);
    });

    test('an application format plugs in without the module knowing it', () {
      final formats = TomExportFormats.standard()
        ..register(const _JsonLinesRenderer());
      expect(formats.supports('jsonl'), isTrue);
      expect(formats.rendererFor('jsonl').fileNameFor('a'), 'a.jsonl');
    });
  });

  // ===========================================================================
  // CSV
  // ===========================================================================

  group('TomCsvRenderer', () {
    test('emits a UTF-8 BOM by default, so Excel reads it as UTF-8', () async {
      final bytes = await _render(_sampleResult(), 'csv');
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    });

    test('the BOM can be turned off for machine consumers', () async {
      final bytes =
          await _collect(const TomCsvRenderer(byteOrderMark: false)
              .render(_sampleResult()));
      expect(bytes[0], isNot(0xEF));
    });

    test('the header row carries labels, not names', () async {
      final text = await _renderCsv(_sampleResult());
      expect(text.split('\r\n').first, 'ID,Name,Amount,Active,At');
    });

    test('rows are CRLF-terminated, as RFC 4180 requires', () async {
      final text = await _renderCsv(_sampleResult());
      expect(text.endsWith('\r\n'), isTrue);
      expect(text.split('\r\n').length, 4); // header, 2 rows, trailing empty
    });

    test('a value containing the separator is quoted', () async {
      final text = await _renderCsv(_sampleResult());
      expect(text, contains('"Gadget, large"'));
    });

    test('an embedded quote is doubled', () async {
      final text = await _renderCsv(
        TomTabularResult.single(
          title: 't',
          section: TomTabularSection.ofRows(
            [TomTabularColumn('a')],
            [
              const TomTabularRow(['say "hi"']),
            ],
          ),
        ),
      );
      expect(text, contains('"say ""hi"""'));
    });

    test('an embedded newline is quoted rather than breaking the row',
        () async {
      final text = await _renderCsv(
        TomTabularResult.single(
          title: 't',
          section: TomTabularSection.ofRows(
            [TomTabularColumn('a')],
            [
              const TomTabularRow(['one\ntwo']),
            ],
          ),
        ),
      );
      expect(text, contains('"one\ntwo"'));
    });

    test('a leading = is neutralised, so an export cannot inject a formula',
        () async {
      final text = await _renderCsv(
        TomTabularResult.single(
          title: 't',
          section: TomTabularSection.ofRows(
            [TomTabularColumn('a')],
            [
              const TomTabularRow(['=1+1']),
              const TomTabularRow(['+x']),
              const TomTabularRow(['-y']),
              const TomTabularRow(['@z']),
            ],
          ),
        ),
      );
      expect(text, contains('"\t=1+1"'));
      expect(text, contains('"\t+x"'));
      expect(text, contains('"\t-y"'));
      expect(text, contains('"\t@z"'));
    });

    test('a whole double loses its .0 so it does not read as approximate',
        () async {
      final text = await _renderCsv(_sampleResult());
      expect(text, contains(',12,'));
      expect(text, contains(',9.5,'));
    });

    test('a timestamp renders ISO-8601 and null renders empty', () async {
      final text = await _renderCsv(
        TomTabularResult.single(
          title: 't',
          section: TomTabularSection.ofRows(
            [
              TomTabularColumn('at', type: TomColumnType.timestamp),
              TomTabularColumn('none'),
            ],
            [
              TomTabularRow([DateTime.utc(2026, 7, 28, 14, 30), null]),
            ],
          ),
        ),
      );
      expect(text, contains('2026-07-28T14:30:00.000Z,\r\n'));
    });

    test('a European separator is honoured, including in the quoting rule',
        () async {
      final text = await _renderCsv(
        TomTabularResult.single(
          title: 't',
          section: TomTabularSection.ofRows(
            [TomTabularColumn('a'), TomTabularColumn('b')],
            [
              const TomTabularRow(['x;y', 'plain,comma']),
            ],
          ),
        ),
        renderer: const TomCsvRenderer(fieldSeparator: ';'),
      );
      expect(text, contains('"x;y";plain,comma'));
    });

    test('multiple sections are separated by a blank line and a title',
        () async {
      final text = await _renderCsv(
        TomTabularResult(
          title: 'two',
          sections: [
            TomTabularSection.ofRows(
              [TomTabularColumn('a')],
              [const TomTabularRow(['1'])],
              title: 'First',
            ),
            TomTabularSection.ofRows(
              [TomTabularColumn('b')],
              [const TomTabularRow(['2'])],
              title: 'Second',
            ),
          ],
        ),
      );
      expect(text, 'First\r\na\r\n1\r\n\r\nSecond\r\nb\r\n2\r\n');
    });

    test('rows reach the output before the source stream closes', () async {
      final rows = StreamController<TomTabularRow>();
      final chunks = <int>[];
      final done = const TomCsvRenderer(byteOrderMark: false)
          .render(
            TomTabularResult.single(
              title: 't',
              section: TomTabularSection(
                columns: [TomTabularColumn('a')],
                rows: rows.stream,
              ),
            ),
          )
          .listen(chunks.addAll)
          .asFuture<void>();

      rows.add(const TomTabularRow(['first']));
      await Future<void>.delayed(Duration.zero);
      expect(
        utf8.decode(chunks),
        'a\r\nfirst\r\n',
        reason: 'the first row must be encoded before the last one exists',
      );

      rows.add(const TomTabularRow(['second']));
      await rows.close();
      await done;
      expect(utf8.decode(chunks), 'a\r\nfirst\r\nsecond\r\n');
    });
  });

  // ===========================================================================
  // XLSX
  // ===========================================================================

  group('TomXlsxRenderer (archive structure)', () {
    late Map<String, String> parts;

    setUpAll(() async {
      parts = _ZipReader(await _render(_sampleResult(), 'xlsx')).read();
    });

    test('the archive holds exactly the parts Excel requires', () {
      expect(
        parts.keys,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'xl/workbook.xml',
          'xl/_rels/workbook.xml.rels',
          'xl/styles.xml',
          'xl/worksheets/sheet1.xml',
        ]),
      );
    });

    test('every sheet part is declared in [Content_Types].xml', () {
      expect(
        parts['[Content_Types].xml'],
        contains('PartName="/xl/worksheets/sheet1.xml"'),
      );
    });

    test('the workbook relationship points at the sheet by id', () {
      expect(parts['xl/workbook.xml'], contains('r:id="rId1"'));
      expect(
        parts['xl/_rels/workbook.xml.rels'],
        contains('Id="rId1" Type="'),
      );
    });

    test('the header row is bold via the style index, not inline markup', () {
      expect(parts['xl/worksheets/sheet1.xml'], contains('s="1" t="inlineStr"'));
    });

    test('text cells are inline strings, so no shared table is needed', () {
      expect(
        parts['xl/worksheets/sheet1.xml'],
        contains('<is><t xml:space="preserve">Gadget, large</t></is>'),
      );
    });

    test('numbers are numeric cells, not text', () {
      expect(parts['xl/worksheets/sheet1.xml'], contains('<c r="A2"><v>1</v>'));
      expect(parts['xl/worksheets/sheet1.xml'], contains('<v>9.5</v>'));
    });

    test('a boolean is a boolean cell', () {
      expect(parts['xl/worksheets/sheet1.xml'], contains('t="b"><v>1</v>'));
      expect(parts['xl/worksheets/sheet1.xml'], contains('t="b"><v>0</v>'));
    });

    test('a date becomes the 1900-system serial with the date style', () {
      expect(
        parts['xl/worksheets/sheet1.xml'],
        contains('s="2"><v>46231</v>'),
      );
    });

    test('a time of day becomes the fractional part of the serial', () {
      expect(
        parts['xl/worksheets/sheet1.xml'],
        contains('s="2"><v>46231.6041666667</v>'),
      );
    });
  });

  group('TomXlsxRenderer (cells and sheets)', () {
    test('a null cell is omitted so COUNTA does not count it', () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('a'), TomTabularColumn('b')],
              [
                const TomTabularRow([null, 'x']),
              ],
            ),
          ),
          'xlsx',
        ),
      ).read();
      final sheet = parts['xl/worksheets/sheet1.xml']!;
      expect(sheet, contains('<row r="2"><c r="B2"'));
      expect(sheet, isNot(contains('r="A2"')));
    });

    test('a value of the wrong type renders as text rather than failing',
        () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('n', type: TomColumnType.integer)],
              [
                const TomTabularRow(['not a number']),
              ],
            ),
          ),
          'xlsx',
        ),
      ).read();
      expect(parts['xl/worksheets/sheet1.xml'], contains('not a number'));
    });

    test('markup in a value is escaped, not injected', () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('a')],
              [
                const TomTabularRow(['<b>&"x"</b>']),
              ],
            ),
          ),
          'xlsx',
        ),
      ).read();
      expect(
        parts['xl/worksheets/sheet1.xml'],
        contains('&lt;b&gt;&amp;&quot;x&quot;&lt;/b&gt;'),
      );
    });

    test('a control character XML cannot carry is dropped, not escaped',
        () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('a')],
              [
                const TomTabularRow(['a bc']),
              ],
            ),
          ),
          'xlsx',
        ),
      ).read();
      expect(parts['xl/worksheets/sheet1.xml'], contains('>abc<'));
    });

    test('a column width hint becomes a column definition', () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('a', width: 30)],
              [const TomTabularRow(['x'])],
            ),
          ),
          'xlsx',
        ),
      ).read();
      expect(
        parts['xl/worksheets/sheet1.xml'],
        contains('<col min="1" max="1" width="30" customWidth="1"/>'),
      );
    });

    test('references pass Z into AA, so wide results stay addressable',
        () async {
      final columns = [
        for (var i = 0; i < 28; i++) TomTabularColumn('c$i'),
      ];
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              columns,
              [TomTabularRow(List<String>.filled(28, 'x'))],
            ),
          ),
          'xlsx',
        ),
      ).read();
      final sheet = parts['xl/worksheets/sheet1.xml']!;
      expect(sheet, contains('r="Z1"'));
      expect(sheet, contains('r="AA1"'));
      expect(sheet, contains('r="AB1"'));
    });

    test('each section becomes its own sheet', () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult(
            title: 'two',
            sections: [
              TomTabularSection.ofRows(
                [TomTabularColumn('a')],
                [const TomTabularRow(['1'])],
                title: 'First',
              ),
              TomTabularSection.ofRows(
                [TomTabularColumn('b')],
                [const TomTabularRow(['2'])],
                title: 'Second',
              ),
            ],
          ),
          'xlsx',
        ),
      ).read();
      expect(parts.containsKey('xl/worksheets/sheet2.xml'), isTrue);
      expect(parts['xl/workbook.xml'], contains('name="First"'));
      expect(parts['xl/workbook.xml'], contains('name="Second"'));
    });

    test('a sheet name Excel would reject is sanitised', () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('a')],
              [const TomTabularRow(['1'])],
              title: 'Q1/Q2 [draft]',
            ),
          ),
          'xlsx',
        ),
      ).read();
      expect(parts['xl/workbook.xml'], contains('name="Q1 Q2  draft"'));
    });

    test('a sheet name over 31 characters is truncated', () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('a')],
              [const TomTabularRow(['1'])],
              title: 'A' * 40,
            ),
          ),
          'xlsx',
        ),
      ).read();
      expect(parts['xl/workbook.xml'], contains('name="${'A' * 31}"'));
    });

    test('colliding sheet names are made unique', () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult(
            title: 'dup',
            sections: [
              for (var i = 0; i < 2; i++)
                TomTabularSection.ofRows(
                  [TomTabularColumn('a')],
                  [const TomTabularRow(['1'])],
                  title: 'Same',
                ),
            ],
          ),
          'xlsx',
        ),
      ).read();
      expect(parts['xl/workbook.xml'], contains('name="Same"'));
      expect(parts['xl/workbook.xml'], contains('name="Same (2)"'));
    });

    test('an untitled section still gets a sheet name', () async {
      final parts = _ZipReader(await _render(_sampleResult(), 'xlsx')).read();
      expect(parts['xl/workbook.xml'], contains('name="Sheet1"'));
    });

    test('the same result renders to identical bytes on two runs', () async {
      final first = await _render(_sampleResult(), 'xlsx');
      final second = await _render(_sampleResult(), 'xlsx');
      expect(first, orderedEquals(second));
    });

    test('uncompressed output is readable too, for the CPU-bound case',
        () async {
      final parts = _ZipReader(
        await _collect(
          const TomXlsxRenderer(compressionLevel: 0).render(_sampleResult()),
        ),
      ).read();
      expect(parts['xl/worksheets/sheet1.xml'], contains('Widget'));
    });

    test('bytes are emitted before the row stream closes', () async {
      final rows = StreamController<TomTabularRow>();
      var emitted = 0;
      final done = const TomXlsxRenderer()
          .render(
            TomTabularResult.single(
              title: 't',
              section: TomTabularSection(
                columns: [TomTabularColumn('a')],
                rows: rows.stream,
              ),
            ),
          )
          .listen((chunk) => emitted += chunk.length)
          .asFuture<void>();

      rows.add(const TomTabularRow(['x']));
      await Future<void>.delayed(Duration.zero);
      expect(emitted, greaterThan(0));

      await rows.close();
      await done;
    });
  });

  // ===========================================================================
  // PDF
  // ===========================================================================

  group('TomPdfRenderer', () {
    test('declares itself as the format that cannot stream rows', () {
      const renderer = TomPdfRenderer();
      expect(renderer.streamsRows, isFalse);
      expect(renderer.mediaType, 'application/pdf');
      expect(renderer.fileNameFor('report'), 'report.pdf');
    });

    test('produces a document with a PDF header and trailer', () async {
      final bytes = await _render(_sampleResult(), 'pdf');
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(
        latin1.decode(bytes.sublist(bytes.length - 8), allowInvalid: true),
        contains('%%EOF'),
      );
    });

    // The content-stream assertions below look for single words. A PDF places
    // each word with its own `Td` offset, so a phrase never appears as one
    // literal — asserting on `'region = EU'` would fail on a document that
    // renders it perfectly.
    test('the title, metadata and cell values reach the page', () async {
      final bytes = await _collect(
        const TomPdfRenderer(compress: false).render(_sampleResult()),
      );
      final text = latin1.decode(bytes, allowInvalid: true);
      expect(text, contains('(Sales)'));
      expect(text, contains('(Filter:)'));
      expect(text, contains('(EU)'));
      expect(text, contains('(Widget)'));
      expect(text, contains('(Amount)'));
    });

    test('a section title is printed above its table', () async {
      final bytes = await _collect(
        const TomPdfRenderer(compress: false)
            .render(_sampleResult(section: 'Regions')),
      );
      expect(
        latin1.decode(bytes, allowInvalid: true),
        contains('(Regions)'),
      );
    });

    test('a result beyond the row limit fails instead of being truncated',
        () async {
      final result = TomTabularResult.single(
        title: 'big',
        section: TomTabularSection.ofRows(
          [TomTabularColumn('a')],
          [for (var i = 0; i < 5; i++) TomTabularRow(['$i'])],
        ),
      );
      expect(
        _collect(const TomPdfRenderer(rowLimit: 3).render(result)),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.parameters?['formats'],
            'suggested formats',
            contains('csv'),
          ),
        ),
      );
    });

    test('the row limit counts across sections, not per section', () async {
      final result = TomTabularResult(
        title: 'big',
        sections: [
          for (var s = 0; s < 2; s++)
            TomTabularSection.ofRows(
              [TomTabularColumn('a')],
              [for (var i = 0; i < 2; i++) TomTabularRow(['$i'])],
            ),
        ],
      );
      expect(
        _collect(const TomPdfRenderer(rowLimit: 3).render(result)),
        throwsA(isA<TomExportException>()),
      );
    });

    test('a result long enough to paginate does not hit the page ceiling',
        () async {
      final result = TomTabularResult.single(
        title: 'long',
        section: TomTabularSection.ofRows(
          [TomTabularColumn('a'), TomTabularColumn('b')],
          [
            for (var i = 0; i < 400; i++) TomTabularRow(['row $i', 'value $i']),
          ],
        ),
      );
      final bytes = await _collect(const TomPdfRenderer().render(result));
      expect(bytes.length, greaterThan(1000));
    });

    test('landscape output is produced without error', () async {
      final bytes = await _collect(
        const TomPdfRenderer(orientation: PageOrientation.landscape)
            .render(_sampleResult()),
      );
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });

  // ===========================================================================
  // STORAGE
  // ===========================================================================

  group('TomExportStore.validateKey', () {
    test('accepts a relative, partitioned key', () {
      expect(
        TomExportStore.validateKey('2026/07/28/sales.csv'),
        '2026/07/28/sales.csv',
      );
    });

    test('rejects the traversals a key built from user input could carry', () {
      for (final key in [
        '',
        '/absolute.csv',
        'trailing/',
        '../escape.csv',
        'a/../b.csv',
        'a//b.csv',
        r'windows\path.csv',
        'space in name.csv',
        'quote".csv',
      ]) {
        expect(
          () => TomExportStore.validateKey(key),
          throwsA(isA<TomExportException>()),
          reason: 'key "$key" must be rejected',
        );
      }
    });
  });

  group('TomDirectoryExportStore', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('tom_export_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('stores a rendered export and reports its size', () async {
      final store = TomDirectoryExportStore(root);
      final bytes = await _render(_sampleResult(), 'csv');
      final stored = await store.store(
        key: 'sales.csv',
        bytes: Stream.value(bytes),
        mediaType: 'text/csv',
      );
      expect(stored.byteCount, bytes.length);
      expect(stored.location, isNotNull);
      expect(File('${root.path}/sales.csv').existsSync(), isTrue);
    });

    test('a partitioned key creates the directories it names', () async {
      final store = TomDirectoryExportStore(root);
      await store.store(
        key: '2026/07/28/sales.csv',
        bytes: Stream.value(utf8.encode('a,b\n')),
        mediaType: 'text/csv',
      );
      expect(File('${root.path}/2026/07/28/sales.csv').existsSync(), isTrue);
    });

    test('what was written is what is read back', () async {
      final store = TomDirectoryExportStore(root);
      await store.store(
        key: 'a.csv',
        bytes: Stream.value(utf8.encode('x,y\r\n1,2\r\n')),
        mediaType: 'text/csv',
      );
      expect(utf8.decode(await _collect(store.open('a.csv'))), 'x,y\r\n1,2\r\n');
    });

    test('a failed write leaves nothing readable under the key', () async {
      final store = TomDirectoryExportStore(root);
      await expectLater(
        store.store(
          key: 'broken.csv',
          bytes: _failingHalfway(),
          mediaType: 'text/csv',
        ),
        throwsA(isA<TomExportException>()),
      );
      expect(await store.exists('broken.csv'), isFalse);
      expect(File('${root.path}/broken.csv.part').existsSync(), isFalse);
    });

    test('storing the same key again replaces the previous export', () async {
      final store = TomDirectoryExportStore(root);
      await store.store(
        key: 'a.csv',
        bytes: Stream.value(utf8.encode('old')),
        mediaType: 'text/csv',
      );
      await store.store(
        key: 'a.csv',
        bytes: Stream.value(utf8.encode('new')),
        mediaType: 'text/csv',
      );
      expect(utf8.decode(await _collect(store.open('a.csv'))), 'new');
    });

    test('reading a key that holds nothing is an error, not an empty file',
        () {
      expect(
        _collect(TomDirectoryExportStore(root).open('missing.csv')),
        throwsA(isA<TomExportException>()),
      );
    });

    test('delete reports whether there was anything to delete', () async {
      final store = TomDirectoryExportStore(root);
      await store.store(
        key: 'a.csv',
        bytes: Stream.value(utf8.encode('x')),
        mediaType: 'text/csv',
      );
      expect(await store.delete('a.csv'), isTrue);
      expect(await store.delete('a.csv'), isFalse);
    });

    test('a traversal key never reaches the filesystem', () async {
      expect(
        TomDirectoryExportStore(root).store(
          key: '../escape.csv',
          bytes: Stream.value(utf8.encode('x')),
          mediaType: 'text/csv',
        ),
        throwsA(isA<TomExportException>()),
      );
    });
  });

  group('TomMemoryExportStore', () {
    test('holds what it was given and hands it back', () async {
      final store = TomMemoryExportStore();
      final stored = await store.store(
        key: 'a.csv',
        bytes: Stream.value(utf8.encode('x,y')),
        mediaType: 'text/csv',
      );
      expect(stored.byteCount, 3);
      expect(store.textOf('a.csv'), 'x,y');
      expect(store.keys, ['a.csv']);
      expect(store.descriptorFor('a.csv')?.mediaType, 'text/csv');
    });

    test('delete removes both content and descriptor', () async {
      final store = TomMemoryExportStore();
      await store.store(
        key: 'a.csv',
        bytes: Stream.value(utf8.encode('x')),
        mediaType: 'text/csv',
      );
      expect(await store.delete('a.csv'), isTrue);
      expect(store.descriptorFor('a.csv'), isNull);
      expect(() => store.textOf('a.csv'), throwsA(isA<TomExportException>()));
    });

    test('validates keys exactly as the filesystem backend does', () {
      expect(
        TomMemoryExportStore().store(
          key: '../x.csv',
          bytes: const Stream.empty(),
          mediaType: 'text/csv',
        ),
        throwsA(isA<TomExportException>()),
      );
    });
  });

  // ===========================================================================
  // DELIVERY
  // ===========================================================================

  group('TomExportService (apiResponse channel)', () {
    test('serves the renderer media type and an attachment name', () async {
      final response =
          TomExportService().respondWith(_sampleResult(), 'xlsx',
              baseName: 'sales-2026-07');
      expect(
        response.headers['content-type'],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(
        response.headers['content-disposition'],
        'attachment; filename="sales-2026-07.xlsx"',
      );
    });

    test('the body is the rendered document', () async {
      final response = TomExportService()
          .respondWith(_sampleResult(), 'csv', baseName: 'sales');
      final text = await response.readAsString();
      expect(text, contains('ID,Name,Amount'));
      expect(text, contains('Widget'));
    });

    test('no content-length is set, because the length is not yet known', () {
      final response = TomExportService()
          .respondWith(_sampleResult(), 'csv', baseName: 'sales');
      expect(response.headers.containsKey('content-length'), isFalse);
    });

    test('a PDF can be shown in the browser rather than downloaded', () {
      final response = TomExportService()
          .respondWith(_sampleResult(), 'pdf', baseName: 'r', inline: true);
      expect(
        response.headers['content-disposition'],
        'inline; filename="r.pdf"',
      );
    });

    test('an unknown format fails before a response is built', () {
      expect(
        () => TomExportService()
            .respondWith(_sampleResult(), 'doc', baseName: 'x'),
        throwsA(isA<TomExportException>()),
      );
    });

    test('a shelf handler can return the response unchanged', () async {
      Future<Response> handler(Request request) async => TomExportService()
          .respondWith(_sampleResult(), 'csv', baseName: 'sales');
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/reports/sales.csv')),
      );
      expect(response.statusCode, 200);
      expect(await response.readAsString(), contains('Widget'));
    });
  });

  group('TomExportService (fileExport channel)', () {
    test('renders and stores in one call, returning the reference', () async {
      final store = TomMemoryExportStore();
      final service = TomExportService(store: store);
      final stored =
          await service.storeAs(_sampleResult(), 'csv', key: 'sales.csv');
      expect(stored.key, 'sales.csv');
      expect(stored.mediaType, startsWith('text/csv'));
      expect(store.textOf('sales.csv'), contains('Widget'));
    });

    test('a server with nowhere to store says so', () {
      expect(
        () => TomExportService().storeAs(_sampleResult(), 'csv', key: 'a.csv'),
        throwsA(isA<TomExportException>()),
      );
    });

    test('keyFor applies the format extension', () {
      expect(TomExportService().keyFor('sales', 'xlsx'), 'sales.xlsx');
    });

    test('keyFor partitions by day when asked', () {
      expect(
        TomExportService()
            .keyFor('sales', 'pdf', partitionOn: DateTime(2026, 7, 8)),
        '2026/07/08/sales.pdf',
      );
    });

    test('keyFor rejects a base name that would escape the store', () {
      expect(
        () => TomExportService().keyFor('../etc/passwd', 'csv'),
        throwsA(isA<TomExportException>()),
      );
    });

    test('render is the primitive both channels share', () async {
      final bytes =
          await _collect(TomExportService().render(_sampleResult(), 'csv'));
      expect(utf8.decode(bytes), contains('Widget'));
    });
  });

  group('TomExportService.sanitiseFileName', () {
    test('a plain name passes through', () {
      expect(TomExportService.sanitiseFileName('sales.csv'), 'sales.csv');
    });

    test('a quote or newline cannot end the header parameter', () {
      expect(
        TomExportService.sanitiseFileName('a".csv\r\nX-Evil: 1'),
        'a_.csv__X-Evil: 1',
      );
    });

    test('a path separator is neutralised', () {
      expect(TomExportService.sanitiseFileName('a/b.csv'), 'a_b.csv');
    });

    test('non-ASCII is replaced, because filename= is a Latin-1 field', () {
      expect(TomExportService.sanitiseFileName('Bericht_Ümsatz.csv'),
          'Bericht__msatz.csv');
    });

    test('a name that sanitises to nothing still yields a file name', () {
      expect(TomExportService.sanitiseFileName('   '), 'export');
    });
  });
}

/// A byte stream that produces something and then fails.
///
/// The shape of a real export whose query dies partway: the store has already
/// written bytes when it learns the result is not coming.
Stream<List<int>> _failingHalfway() async* {
  yield utf8.encode('partial');
  throw StateError('query died');
}

/// An application-supplied format, proving the registry is genuinely open.
class _JsonLinesRenderer extends TomTabularRenderer {
  const _JsonLinesRenderer();

  @override
  String get formatId => 'jsonl';

  @override
  String get mediaType => 'application/x-ndjson';

  @override
  String get fileExtension => 'jsonl';

  @override
  Stream<List<int>> render(TomTabularResult result) async* {
    for (final section in result.sections) {
      await for (final row in section.rows) {
        yield utf8.encode(
          '${jsonEncode({
                for (var i = 0; i < section.columns.length; i++)
                  section.columns[i].name: tomFormatCellAsText(row.cell(i)),
              })}\n',
        );
      }
    }
  }
}
