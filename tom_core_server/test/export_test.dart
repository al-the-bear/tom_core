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
      section: TomTabularSection.ofRows(_columns(), [
        TomTabularRow([1, 'Widget', 9.5, true, DateTime.utc(2026, 7, 28)]),
        TomTabularRow([
          2,
          'Gadget, large',
          12.0,
          false,
          DateTime.utc(2026, 7, 28, 14, 30),
        ]),
      ], title: section),
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
      bytes[at] |
      bytes[at + 1] << 8 |
      bytes[at + 2] << 16 |
      bytes[at + 3] << 24;

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
      final dataAt =
          localOffset + 30 + _u16(localOffset + 26) + _u16(localOffset + 28);
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
      final columns = [TomTabularColumn('b'), TomTabularColumn('a')];
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
      // The table this asserts is load-bearing rather than descriptive:
      // `_TomEntityProjection.columnTypeOf` derives a candidate type from the
      // SQL type family and then keeps it only if `dartType` says the declared
      // Dart type can inhabit it. A wrong entry here would not fail loudly —
      // it would silently demote that family's columns to `text`, and an
      // export would format its dates as strings with nothing reported.
      expect(TomColumnType.integer.dartType, int);
      expect(TomColumnType.decimal.dartType, double);
      expect(TomColumnType.text.dartType, String);
      expect(TomColumnType.boolean.dartType, bool);
      expect(TomColumnType.timestamp.dartType, DateTime);
      // The set is exactly `TomGroupedRow`'s, so an aggregate result adapts
      // without a lossy conversion and a renderer never meets a value it has
      // no rule for. A type added here is a renderer change, not a data one.
      expect(TomColumnType.values.map((type) => type.dartType), [
        int,
        double,
        String,
        bool,
        DateTime,
      ]);
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

  group('TomTabularColumn.effectiveWidth (one meaning for a width)', () {
    test('a hint is passed through, whatever its size', () {
      expect(TomTabularColumn('a', width: 30).effectiveWidth, 30);
      // Past the cap that governs a *derived* width: an explicit number is the
      // caller's decision and is not second-guessed.
      expect(TomTabularColumn('a', width: 200).effectiveWidth, 200);
    });

    test('without a hint the type decides', () {
      // The widths a cell of each type actually renders at, so that a column
      // left alone is wide enough to read rather than wide enough for Excel.
      expect(
        TomTabularColumn('a', type: TomColumnType.timestamp).effectiveWidth,
        23,
      );
      expect(
        TomTabularColumn('a', type: TomColumnType.boolean).effectiveWidth,
        5,
      );
      expect(TomTabularColumn('a').effectiveWidth, 16);
    });

    test('a label wider than its type raises the column', () {
      // `false` is five characters, but a header no reader can make out is not
      // a saving. The header is part of what has to fit.
      expect(
        TomTabularColumn(
          'x',
          label: 'Discontinued?',
          type: TomColumnType.boolean,
        ).effectiveWidth,
        13,
      );
    });

    test('a derived width is capped, so a heading cannot starve a table', () {
      expect(
        TomTabularColumn('x', label: 'y' * 200).effectiveWidth,
        TomTabularColumn.maxDerivedWidth,
      );
    });

    test('a width below one character is rejected at construction', () {
      // Zero is not a narrow column, it is a hidden one in a spreadsheet and a
      // collapsed one on a page — never what a width was asked to say.
      for (final bad in [0, -1]) {
        expect(
          () => TomTabularColumn('a', width: bad),
          throwsA(
            isA<TomExportException>().having(
              (e) => e.key,
              'key',
              'export.column.invalid_width',
            ),
          ),
          reason: 'width $bad',
        );
      }
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
      final bytes = await _collect(
        const TomCsvRenderer(byteOrderMark: false).render(_sampleResult()),
      );
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

    test(
      'an embedded newline is quoted rather than breaking the row',
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
      },
    );

    test(
      'a leading = is neutralised, so an export cannot inject a formula',
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
      },
    );

    test('a negative number is not mistaken for a formula', () async {
      final text = await _renderCsv(
        TomTabularResult.single(
          title: 't',
          section: TomTabularSection.ofRows(
            [
              TomTabularColumn('balance', type: TomColumnType.decimal),
              TomTabularColumn('count', type: TomColumnType.integer),
            ],
            [
              TomTabularRow([-1234.5, -7]),
            ],
          ),
        ),
      );
      // Bare, so the spreadsheet reads two numbers. A tab-prefixed quoted
      // field is text: totals stop summing and sorting turns lexical.
      expect(text, contains('-1234.5,-7\r\n'));
      expect(text, isNot(contains('\t')));
    });

    test(
      'a number is judged by its value, not by the column it sits in',
      () async {
        final text = await _renderCsv(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              // Declared text, holding a num. The guard exists for text someone
              // else supplied; a Dart num cannot be an expression whatever
              // column it was declared under.
              [TomTabularColumn('note')],
              [
                TomTabularRow([-42]),
              ],
            ),
          ),
        );
        expect(text, contains('-42\r\n'));
        expect(text, isNot(contains('\t')));
      },
    );

    test(
      'text in a numeric column is still guarded, mismatch or not',
      () async {
        final text = await _renderCsv(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              // A String reaching an integer column is a mismatch the renderers
              // tolerate by formatting it as text — so it is exactly the cell
              // that would smuggle a formula past a column-type-based guard.
              [TomTabularColumn('count', type: TomColumnType.integer)],
              [
                const TomTabularRow(['=1+1']),
              ],
            ),
          ),
        );
        expect(text, contains('"\t=1+1"'));
      },
    );

    test('a column label that looks like a formula is still guarded', () async {
      final text = await _renderCsv(
        TomTabularResult.single(
          title: 't',
          section: TomTabularSection.ofRows(
            [TomTabularColumn('a', label: '=cmd')],
            [
              TomTabularRow([1]),
            ],
          ),
        ),
      );
      expect(text, contains('"\t=cmd"'));
    });

    test(
      'a whole double loses its .0 so it does not read as approximate',
      () async {
        final text = await _renderCsv(_sampleResult());
        expect(text, contains(',12,'));
        expect(text, contains(',9.5,'));
      },
    );

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

    test(
      'a European separator is honoured, including in the quoting rule',
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
      },
    );

    test(
      'multiple sections are separated by a blank line and a title',
      () async {
        final text = await _renderCsv(
          TomTabularResult(
            title: 'two',
            sections: [
              TomTabularSection.ofRows(
                [TomTabularColumn('a')],
                [
                  const TomTabularRow(['1']),
                ],
                title: 'First',
              ),
              TomTabularSection.ofRows(
                [TomTabularColumn('b')],
                [
                  const TomTabularRow(['2']),
                ],
                title: 'Second',
              ),
            ],
          ),
        );
        expect(text, 'First\r\na\r\n1\r\n\r\nSecond\r\nb\r\n2\r\n');
      },
    );

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
          'docProps/core.xml',
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
      expect(parts['xl/_rels/workbook.xml.rels'], contains('Id="rId1" Type="'));
    });

    test('the header row is bold via the style index, not inline markup', () {
      expect(
        parts['xl/worksheets/sheet1.xml'],
        contains('s="1" t="inlineStr"'),
      );
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
      expect(parts['xl/worksheets/sheet1.xml'], contains('s="2"><v>46231</v>'));
    });

    test('a time of day becomes the fractional part of the serial', () {
      expect(
        parts['xl/worksheets/sheet1.xml'],
        contains('s="2"><v>46231.6041666667</v>'),
      );
    });
  });

  /// The title and metadata land in the package's document properties.
  ///
  /// Asserted on the parts rather than on a cell because that *is* the choice:
  /// a header block above the table would move the header row by however many
  /// metadata entries there were, and a consumer reading the sheet as a table
  /// would find its columns at a varying row. So these tests are what stops the
  /// context from being quietly dropped again, and equally what stops it from
  /// reappearing in the data region.
  group('TomXlsxRenderer (document properties)', () {
    late Map<String, String> parts;

    setUpAll(() async {
      parts = _ZipReader(await _render(_sampleResult(), 'xlsx')).read();
    });

    test('the result title is the workbook title', () {
      expect(
        parts['docProps/core.xml'],
        contains('<dc:title>Sales</dc:title>'),
      );
    });

    test('the core properties part is declared and related', () {
      expect(
        parts['[Content_Types].xml'],
        contains('PartName="/docProps/core.xml"'),
      );
      expect(parts['_rels/.rels'], contains('Target="docProps/core.xml"'));
    });

    test('each metadata entry becomes a custom property', () {
      expect(
        parts['docProps/custom.xml'],
        contains('name="Filter"><vt:lpwstr>region = EU</vt:lpwstr>'),
      );
    });

    test('the custom properties part is declared and related', () {
      expect(
        parts['[Content_Types].xml'],
        contains('PartName="/docProps/custom.xml"'),
      );
      expect(parts['_rels/.rels'], contains('Target="docProps/custom.xml"'));
    });

    test('property ids number from 2, which is the first id not reserved', () {
      expect(parts['docProps/custom.xml'], contains('pid="2"'));
      expect(parts['docProps/custom.xml'], isNot(contains('pid="0"')));
      expect(parts['docProps/custom.xml'], isNot(contains('pid="1"')));
    });

    test(
      'the title is escaped, so a report named after a range still opens',
      () async {
        final escaped = _ZipReader(
          await _render(_sampleResult(title: 'Q1 & Q2 <all>'), 'xlsx'),
        ).read();
        expect(
          escaped['docProps/core.xml'],
          contains('<dc:title>Q1 &amp; Q2 &lt;all&gt;</dc:title>'),
        );
      },
    );

    test(
      'a result without metadata carries no custom properties part',
      () async {
        final bare = _ZipReader(
          await _render(
            TomTabularResult.single(
              title: 'Bare',
              section: TomTabularSection.ofRows(
                [TomTabularColumn('a')],
                [
                  const TomTabularRow(['x']),
                ],
              ),
            ),
            'xlsx',
          ),
        ).read();
        expect(bare.keys, isNot(contains('docProps/custom.xml')));
        expect(
          bare['[Content_Types].xml'],
          isNot(contains('PartName="/docProps/custom.xml"')),
        );
        expect(bare['_rels/.rels'], isNot(contains('docProps/custom.xml')));
        // The title has no such condition — every workbook carries one.
        expect(
          bare['docProps/core.xml'],
          contains('<dc:title>Bare</dc:title>'),
        );
      },
    );

    test('a metadata name XML cannot carry is dropped, not written', () async {
      final odd = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('a')],
              [
                const TomTabularRow(['x']),
              ],
            ),
            metadata: const {
              '': 'dropped-because-nameless',
              // A name of only control characters: XML 1.0 cannot carry
              // them even as numeric references, so escaping leaves
              // nothing to name the property with.
              '\u0001': 'dropped-because-unnameable',
              'Kept': 'survives',
            },
          ),
          'xlsx',
        ),
      ).read();
      final custom = odd['docProps/custom.xml'];
      expect(custom, contains('name="Kept"><vt:lpwstr>survives</vt:lpwstr>'));
      expect(custom, isNot(contains('dropped-because-nameless')));
      expect(custom, isNot(contains('dropped-because-unnameable')));
      expect(custom, isNot(contains('name=""')));
      // The survivor is renumbered, not left at the id its position implied.
      expect(custom, contains('pid="2"'));
    });

    test('metadata of only unusable names produces no part at all', () async {
      final none = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('a')],
              [
                const TomTabularRow(['x']),
              ],
            ),
            metadata: const {'': 'x'},
          ),
          'xlsx',
        ),
      ).read();
      expect(none.keys, isNot(contains('docProps/custom.xml')));
      expect(
        none['[Content_Types].xml'],
        isNot(contains('PartName="/docProps/custom.xml"')),
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

    test(
      'a value of the wrong type renders as text rather than failing',
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
      },
    );

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

    test(
      'a control character XML cannot carry is dropped, not escaped',
      () async {
        final parts = _ZipReader(
          await _render(
            TomTabularResult.single(
              title: 't',
              section: TomTabularSection.ofRows(
                [TomTabularColumn('a')],
                [
                  const TomTabularRow(['a\u0000b\u0007c']),
                ],
              ),
            ),
            'xlsx',
          ),
        ).read();
        expect(parts['xl/worksheets/sheet1.xml'], contains('>abc<'));
      },
    );

    test('a column width hint becomes a column definition', () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [TomTabularColumn('a', width: 30)],
              [
                const TomTabularRow(['x']),
              ],
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

    test('every column is given a width, not only the hinted ones', () async {
      // The unhinted case has to mean the same thing in both renderers, and
      // leaving it to the consumer means it does not: Excel's own default is
      // 8.43 characters, which shows an ISO timestamp as `#####`. So a column
      // with no hint is written at the width its type and label imply.
      final parts = _ZipReader(
        await _render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [
                TomTabularColumn('a', width: 24),
                TomTabularColumn('b', type: TomColumnType.timestamp),
                TomTabularColumn(
                  'c',
                  label: 'Active',
                  type: TomColumnType.boolean,
                ),
              ],
              [
                TomTabularRow(['x', DateTime.utc(2026, 7, 1), true]),
              ],
            ),
          ),
          'xlsx',
        ),
      ).read();
      final sheet = parts['xl/worksheets/sheet1.xml'];
      expect(
        sheet,
        contains('<col min="1" max="1" width="24" customWidth="1"/>'),
      );
      expect(
        sheet,
        contains('<col min="2" max="2" width="23" customWidth="1"/>'),
      );
      expect(
        sheet,
        contains('<col min="3" max="3" width="6" customWidth="1"/>'),
      );
    });

    test(
      'references pass Z into AA, so wide results stay addressable',
      () async {
        final columns = [for (var i = 0; i < 28; i++) TomTabularColumn('c$i')];
        final parts = _ZipReader(
          await _render(
            TomTabularResult.single(
              title: 't',
              section: TomTabularSection.ofRows(columns, [
                TomTabularRow(List<String>.filled(28, 'x')),
              ]),
            ),
            'xlsx',
          ),
        ).read();
        final sheet = parts['xl/worksheets/sheet1.xml']!;
        expect(sheet, contains('r="Z1"'));
        expect(sheet, contains('r="AA1"'));
        expect(sheet, contains('r="AB1"'));
      },
    );

    test('each section becomes its own sheet', () async {
      final parts = _ZipReader(
        await _render(
          TomTabularResult(
            title: 'two',
            sections: [
              TomTabularSection.ofRows(
                [TomTabularColumn('a')],
                [
                  const TomTabularRow(['1']),
                ],
                title: 'First',
              ),
              TomTabularSection.ofRows(
                [TomTabularColumn('b')],
                [
                  const TomTabularRow(['2']),
                ],
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
              [
                const TomTabularRow(['1']),
              ],
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
              [
                const TomTabularRow(['1']),
              ],
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
                  [
                    const TomTabularRow(['1']),
                  ],
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

    test(
      'uncompressed output is readable too, for the CPU-bound case',
      () async {
        final parts = _ZipReader(
          await _collect(
            const TomXlsxRenderer(compressionLevel: 0).render(_sampleResult()),
          ),
        ).read();
        expect(parts['xl/worksheets/sheet1.xml'], contains('Widget'));
      },
    );

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
        const TomPdfRenderer(
          compress: false,
        ).render(_sampleResult(section: 'Regions')),
      );
      expect(latin1.decode(bytes, allowInvalid: true), contains('(Regions)'));
    });

    test(
      'a result beyond the row limit fails instead of being truncated',
      () async {
        final result = TomTabularResult.single(
          title: 'big',
          section: TomTabularSection.ofRows(
            [TomTabularColumn('a')],
            [
              for (var i = 0; i < 5; i++) TomTabularRow(['$i']),
            ],
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
      },
    );

    test('the row limit counts across sections, not per section', () async {
      final result = TomTabularResult(
        title: 'big',
        sections: [
          for (var s = 0; s < 2; s++)
            TomTabularSection.ofRows(
              [TomTabularColumn('a')],
              [
                for (var i = 0; i < 2; i++) TomTabularRow(['$i']),
              ],
            ),
        ],
      );
      expect(
        _collect(const TomPdfRenderer(rowLimit: 3).render(result)),
        throwsA(isA<TomExportException>()),
      );
    });

    test(
      'a result long enough to paginate does not hit the page ceiling',
      () async {
        final result = TomTabularResult.single(
          title: 'long',
          section: TomTabularSection.ofRows(
            [TomTabularColumn('a'), TomTabularColumn('b')],
            [
              for (var i = 0; i < 400; i++)
                TomTabularRow(['row $i', 'value $i']),
            ],
          ),
        );
        final bytes = await _collect(const TomPdfRenderer().render(result));
        expect(bytes.length, greaterThan(1000));
      },
    );

    test('landscape output is produced without error', () async {
      final bytes = await _collect(
        const TomPdfRenderer(
          orientation: PageOrientation.landscape,
        ).render(_sampleResult()),
      );
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('a width hint does not starve the columns beside it', () async {
      // The module's own example is this shape: one column hinted, the rest
      // left to the renderer. When the hint was read as a flex factor, 24
      // against 1 gave that column 89 per cent of the table and what was left
      // could not hold a word — `Amount` came out as four fragments, `A`, `m`,
      // `ou`, `nt`, and twenty rows needed four pages. A character count that
      // both renderers read the same way is what makes this table legible.
      final bytes = await _collect(
        const TomPdfRenderer(compress: false).render(
          TomTabularResult.single(
            title: 't',
            section: TomTabularSection.ofRows(
              [
                TomTabularColumn('product', label: 'Product', width: 24),
                TomTabularColumn(
                  'amount',
                  label: 'Amount',
                  type: TomColumnType.decimal,
                ),
                TomTabularColumn(
                  'sold',
                  label: 'Sold',
                  type: TomColumnType.timestamp,
                ),
                TomTabularColumn(
                  'active',
                  label: 'Active',
                  type: TomColumnType.boolean,
                ),
              ],
              [
                for (var i = 0; i < 20; i++)
                  TomTabularRow([
                    'Widget $i',
                    19.5,
                    DateTime(2026, 7, 1),
                    true,
                  ]),
              ],
            ),
          ),
        ),
      );
      final text = latin1.decode(bytes, allowInvalid: true);
      expect(text, contains('(Amount)'), reason: 'the header is one piece');
      expect(text, contains('(Sold)'));
      expect(
        text,
        contains('(2026-07-01T00:00:00.000)'),
        reason: 'a timestamp fits the column its type asked for',
      );
      expect(
        RegExp(r'/Type\s*/Page[^s]').allMatches(text).length,
        1,
        reason: 'twenty rows are one page once nothing is squeezed',
      );
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
      expect(
        utf8.decode(await _collect(store.open('a.csv'))),
        'x,y\r\n1,2\r\n',
      );
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

    test('reading a key that holds nothing is an error, not an empty file', () {
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

    test('a failure in the rename is a write failure, not a raw '
        'FileSystemException', () async {
      // The rename is the last step of the write and can fail on its own — a
      // full disk, a cross-device destination. Here the destination path is
      // occupied by a directory, which no rename can replace. It used to run
      // outside the try, so the caller met a FileSystemException and the
      // .part file stayed behind.
      final store = TomDirectoryExportStore(root);
      Directory('${root.path}/blocked.csv').createSync();
      await expectLater(
        store.store(
          key: 'blocked.csv',
          bytes: Stream.value(utf8.encode('x')),
          mediaType: 'text/csv',
        ),
        throwsA(
          isA<TomExportException>()
              .having((e) => e.key, 'key', 'export.store.write_failed')
              .having((e) => e.rootException, 'rootException', isNotNull),
        ),
      );
      // "A failed write leaves nothing readable" has to include the partial.
      expect(File('${root.path}/blocked.csv.part').existsSync(), isFalse);
    });

    test(
      'a read that fails after the file was found is a read failure',
      () {
        // Distinct from not_found: the key does hold an export, and reading it
        // is what failed. `openRead` reports that on the stream, which a `yield*`
        // would have forwarded straight past the translation.
        final store = TomDirectoryExportStore(root);
        final file = File('${root.path}/locked.csv')
          ..writeAsStringSync('secret');
        file.setLastModifiedSync(DateTime.now());
        Process.runSync('chmod', ['000', file.path]);
        addTearDown(() => Process.runSync('chmod', ['600', file.path]));
        expect(
          _collect(store.open('locked.csv')),
          throwsA(
            isA<TomExportException>().having(
              (e) => e.key,
              'key',
              'export.store.read_failed',
            ),
          ),
        );
      },
      skip: _chmodIsIneffective ? 'needs a non-root POSIX filesystem' : null,
    );

    test('a delete that fails is a delete failure, not a raw '
        'FileSystemException', () async {
      final store = TomDirectoryExportStore(root);
      final dir = Directory('${root.path}/ro')..createSync();
      File('${dir.path}/a.csv').writeAsStringSync('x');
      Process.runSync('chmod', ['500', dir.path]);
      addTearDown(() => Process.runSync('chmod', ['700', dir.path]));
      await expectLater(
        store.delete('ro/a.csv'),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.key,
            'key',
            'export.store.delete_failed',
          ),
        ),
      );
    }, skip: _chmodIsIneffective ? 'needs a non-root POSIX filesystem' : null);

    test('an invalid key still surfaces as invalid_key, not as the '
        'operation that was refused', () async {
      // The translation must not swallow the module's own errors: a caller
      // catching export.store.invalid_key keeps catching it from every method.
      final store = TomDirectoryExportStore(root);
      for (final operation in <Future<Object?> Function()>[
        () => store.exists('../escape'),
        () => store.delete('../escape'),
        () => _collect(store.open('../escape')),
        () => store.store(
          key: '../escape',
          bytes: const Stream.empty(),
          mediaType: 'text/csv',
        ),
      ]) {
        await expectLater(
          operation(),
          throwsA(
            isA<TomExportException>().having(
              (e) => e.key,
              'key',
              'export.store.invalid_key',
            ),
          ),
        );
      }
    });

    // Every test above hands the store a directory that already exists, which
    // is how the constructor's dartdoc came to claim it created the root while
    // the constructor only assigned the field: nothing ever ran against a root
    // that was missing. The creation is real but lazy, done by the first write.
    // These tests state *when* it happens, so the dartdoc that now says so has
    // something holding it to it.
    group('a root that does not exist yet', () {
      late Directory absent;

      setUp(() => absent = Directory('${root.path}/nested/exports'));

      test('constructing a store does not create it', () {
        TomDirectoryExportStore(absent);
        expect(absent.existsSync(), isFalse);
      });

      test('the first write creates it, and the key\'s directories with it',
          () async {
        final store = TomDirectoryExportStore(absent);
        await store.store(
          key: '2026/07/28/sales.csv',
          bytes: Stream.value(utf8.encode('a,b\n')),
          mediaType: 'text/csv',
        );
        expect(absent.existsSync(), isTrue);
        expect(
          File('${absent.path}/2026/07/28/sales.csv').existsSync(),
          isTrue,
        );
      });

      test('the three read paths report absence rather than creating it',
          () async {
        // Deliberate, and the half of the behaviour a caller is most likely to
        // be surprised by: asking a store whether it holds something is a
        // question, and a question should not have a filesystem side effect.
        final store = TomDirectoryExportStore(absent);

        expect(await store.exists('sales.csv'), isFalse);
        expect(absent.existsSync(), isFalse);

        expect(await store.delete('sales.csv'), isFalse);
        expect(absent.existsSync(), isFalse);

        await expectLater(
          _collect(store.open('sales.csv')),
          throwsA(
            isA<TomExportException>().having(
              (e) => e.key,
              'key',
              'export.store.not_found',
            ),
          ),
        );
        expect(absent.existsSync(), isFalse);
      });

      test('a root that disappears after construction comes back', () async {
        // What lazy creation buys over doing it once in the constructor: a
        // volume remounted, a tmpfs reaped, a container's writable layer reset.
        // An eagerly-created root would be just as gone, and every later write
        // would fail on a store that reported itself configured.
        final store = TomDirectoryExportStore(absent);
        await store.store(
          key: 'a.csv',
          bytes: Stream.value(utf8.encode('first')),
          mediaType: 'text/csv',
        );
        absent.deleteSync(recursive: true);

        await store.store(
          key: 'a.csv',
          bytes: Stream.value(utf8.encode('second')),
          mediaType: 'text/csv',
        );
        expect(utf8.decode(await _collect(store.open('a.csv'))), 'second');
      });
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

    test('every method that takes a key refuses an invalid one', () async {
      // The previous version of this test was named for the filesystem backend
      // and exercised `store` alone, so the three inherited methods and the two
      // inspection accessors could each accept `../escape` with it still green.
      // This backend is the one tests and development servers run on, which is
      // exactly where a key too lax for production must not pass.
      final store = TomMemoryExportStore();
      for (final operation in <Future<Object?> Function()>[
        () => store.store(
          key: '../escape',
          bytes: const Stream.empty(),
          mediaType: 'text/csv',
        ),
        () => _collect(store.open('../escape')),
        () => store.exists('../escape'),
        () => store.delete('../escape'),
        () async => store.textOf('../escape'),
        () async => store.descriptorFor('../escape'),
      ]) {
        await expectLater(
          operation(),
          throwsA(
            isA<TomExportException>().having(
              (e) => e.key,
              'key',
              'export.store.invalid_key',
            ),
          ),
        );
      }
    });

    test('an absent key and an invalid one are different diagnoses', () {
      // `descriptorFor` answering `null` and `textOf` answering `not_found` for
      // a key that is not a key at all sends the reader looking for a missing
      // write. The two faults are told apart here so a fix that makes every
      // unhappy path throw the same thing cannot pass.
      final store = TomMemoryExportStore();
      expect(store.descriptorFor('absent.csv'), isNull);
      expect(
        () => store.textOf('absent.csv'),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.key,
            'key',
            'export.store.not_found',
          ),
        ),
      );
    });

    test('a failing source stream is a write failure, as it is on disk', () {
      // The memory backend used to let the source stream's own error through
      // untranslated, so which exception a caller met depended on which
      // backend happened to be configured.
      expect(
        TomMemoryExportStore().store(
          key: 'a.csv',
          bytes: _failingHalfway(),
          mediaType: 'text/csv',
        ),
        throwsA(
          isA<TomExportException>()
              .having((e) => e.key, 'key', 'export.store.write_failed')
              .having(
                (e) => e.rootException,
                'rootException',
                isA<StateError>(),
              ),
        ),
      );
    });

    test(
      'a failed write leaves nothing readable, as it does on disk',
      () async {
        final store = TomMemoryExportStore();
        await expectLater(
          store.store(
            key: 'a.csv',
            bytes: _failingHalfway(),
            mediaType: 'text/csv',
          ),
          throwsA(isA<TomExportException>()),
        );
        expect(await store.exists('a.csv'), isFalse);
        expect(store.keys, isEmpty);
      },
    );

    test('a chunk handed to a reader belongs to the reader', () async {
      // Both halves matter, and they pull in opposite directions. The chunk
      // must be *writable*, because every other backend reads one off a file or
      // a socket and hands the consumer something it owns — a decoder working
      // in place runs on production and must not throw on the backend the tests
      // use. And the write must go nowhere: this backend used to yield the list
      // held in its own map, so a consumer decoding in place edited the stored
      // export.
      final store = TomMemoryExportStore();
      await store.store(
        key: 'a.csv',
        bytes: Stream.value(utf8.encode('x,y')),
        mediaType: 'text/csv',
      );

      final chunk = (await store.open('a.csv').toList()).single;
      chunk[0] = 0x7a; // 'z'

      expect(chunk[0], 0x7a, reason: 'the chunk is the reader\'s to write to');
      expect(
        store.textOf('a.csv'),
        'x,y',
        reason: 'and the store is untouched',
      );
    });

    test('a writer that reuses one buffer stores what it streamed', () async {
      // The mirror of the read case, and the one a streaming producer hits
      // without doing anything unusual: a fixed-size scratch buffer refilled
      // per chunk is the normal shape of an encoder. A backend that retained
      // the chunks instead of copying them would store the buffer's *last*
      // state once per chunk — 'ccc' rather than 'abc'.
      final store = TomMemoryExportStore();
      final scratch = Uint8List(1);
      Stream<List<int>> reusing() async* {
        for (final byte in 'abc'.codeUnits) {
          scratch[0] = byte;
          yield scratch;
        }
      }

      await store.store(key: 'a.csv', bytes: reusing(), mediaType: 'text/csv');
      expect(store.textOf('a.csv'), 'abc');

      scratch[0] = 0x7a;
      expect(store.textOf('a.csv'), 'abc', reason: 'and later writes miss it');
    });
  });

  group('TomExportStore (one error contract across backends)', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('tom_export_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('the same failure yields the same key whichever backend is '
        'configured', () async {
      // The point of the abstract store: swapping the backend in configuration
      // must not change what a caller has to catch.
      final keys = <String>[];
      for (final store in <TomExportStore>[
        TomDirectoryExportStore(root),
        TomMemoryExportStore(),
        TomBlobExportStore(TomMemoryBlobStore()),
      ]) {
        try {
          await store.store(
            key: 'a.csv',
            bytes: _failingHalfway(),
            mediaType: 'text/csv',
          );
          fail('$store accepted a failing stream');
        } on TomExportException catch (e) {
          keys.add(e.key);
        }
      }
      expect(keys, everyElement('export.store.write_failed'));
    });
  });

  // ===========================================================================
  // DELIVERY
  // ===========================================================================

  group('TomExportService (apiResponse channel)', () {
    test('serves the renderer media type and an attachment name', () async {
      final response = TomExportService().respondWith(
        _sampleResult(),
        'xlsx',
        baseName: 'sales-2026-07',
      );
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
      final response = TomExportService().respondWith(
        _sampleResult(),
        'csv',
        baseName: 'sales',
      );
      final text = await response.readAsString();
      expect(text, contains('ID,Name,Amount'));
      expect(text, contains('Widget'));
    });

    test('no content-length is set, because the length is not yet known', () {
      final response = TomExportService().respondWith(
        _sampleResult(),
        'csv',
        baseName: 'sales',
      );
      expect(response.headers.containsKey('content-length'), isFalse);
    });

    test('a PDF can be shown in the browser rather than downloaded', () {
      final response = TomExportService().respondWith(
        _sampleResult(),
        'pdf',
        baseName: 'r',
        inline: true,
      );
      expect(
        response.headers['content-disposition'],
        'inline; filename="r.pdf"',
      );
    });

    test('an unknown format fails before a response is built', () {
      expect(
        () => TomExportService().respondWith(
          _sampleResult(),
          'doc',
          baseName: 'x',
        ),
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
      final stored = await service.storeAs(
        _sampleResult(),
        'csv',
        key: 'sales.csv',
      );
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
        TomExportService().keyFor(
          'sales',
          'pdf',
          partitionOn: DateTime(2026, 7, 8),
        ),
        '2026/07/08/sales.pdf',
      );
    });

    test(
      'render answers directly, for the caller neither channel fits',
      () async {
        final bytes = await _collect(
          TomExportService().render(_sampleResult(), 'csv'),
        );
        expect(utf8.decode(bytes), contains('Widget'));
      },
    );
  });

  // `render` is documented as the primitive both channels are built on, which
  // is a claim about the *call graph* and not about output. Nothing asserted it
  // — and it was false: `respondWith` and `storeAs` each reached past it to
  // `formats.rendererFor(format).render(result)`, so an override adding a
  // metric, a trace or a limit saw only the callers who used `render`
  // explicitly, which the same documentation calls the rarest case.
  //
  // Being on the path is not the same as being *called*, so these tests assert
  // both: the format the override was asked for, and the byte count it could
  // only have if the channel carried the stream it returned.
  group('TomExportService.render (the primitive both channels share)', () {
    test('respondWith streams the bytes render returned', () async {
      final service = _MeteredExportService();
      final response = service.respondWith(
        _sampleResult(),
        'csv',
        baseName: 'sales',
      );
      // The body is read as bytes rather than as a string: `readAsString`
      // strips the CSV renderer's UTF-8 BOM, so a re-encoded string is three
      // bytes short of what actually crossed the wire.
      final body = await _collect(response.read());

      expect(service.renders, ['csv']);
      expect(utf8.decode(body), contains('Widget'));
      expect(
        service.byteCount,
        body.length,
        reason: "the response body is the override's stream, not a second one",
      );
    });

    test('storeAs stores the bytes render returned', () async {
      final store = TomMemoryExportStore();
      final service = _MeteredExportService(store: store);
      final stored = await service.storeAs(
        _sampleResult(),
        'xlsx',
        key: 'sales.xlsx',
      );

      expect(service.renders, ['xlsx']);
      expect(stored.byteCount, service.byteCount);
      expect(await store.exists('sales.xlsx'), isTrue);
    });

    test('a limit check placed in render guards both channels', () async {
      final store = TomMemoryExportStore();
      final service = _MeteredExportService(store: store, refuses: 'pdf');

      // The apiResponse channel: the refusal surfaces on the body rather than
      // from the call, because the body is a stream and the response object is
      // built before a byte is produced.
      final response = service.respondWith(
        _sampleResult(),
        'pdf',
        baseName: 'r',
      );
      await expectLater(response.read(), emitsError(isA<TomExportException>()));

      // The fileExport channel: nothing is written.
      await expectLater(
        service.storeAs(_sampleResult(), 'pdf', key: 'r.pdf'),
        throwsA(isA<TomExportException>()),
      );
      expect(await store.exists('r.pdf'), isFalse);
      expect(service.renders, ['pdf', 'pdf']);
    });

    test('the headers still describe the format, not the override', () async {
      final service = _MeteredExportService();
      final response = service.respondWith(
        _sampleResult(),
        'pdf',
        baseName: 'r',
      );
      // The registry is asked what a format *is*; `render` is asked what it
      // *produces*. Overriding the latter does not silently relabel the former.
      expect(response.headers['content-type'], 'application/pdf');
      expect(
        response.headers['content-disposition'],
        'attachment; filename="r.pdf"',
      );
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
      expect(
        TomExportService.sanitiseFileName('Bericht_Ümsatz.csv'),
        'Bericht__msatz.csv',
      );
    });

    test('a name that sanitises to nothing still yields a file name', () {
      expect(TomExportService.sanitiseFileName('   '), 'export');
    });
  });

  // `respondWith` sanitised its base name and `keyFor` only validated one, so a
  // single report name — anything with a space in it, which is most report
  // names — was a download on the apiResponse channel and an
  // `export.store.invalid_key` on the fileExport channel. The module's own
  // example stepped over it by passing `sales` to one and `Q3 sales` to the
  // other, so nothing put the same name through both. These tests do.
  //
  // The two channels still *spell* a name differently, and must: a
  // `Content-Disposition` filename is a Latin-1 quoted string and a storage key
  // is a relative path made of unreserved characters. What is now symmetric is
  // which names are **accepted**, which is the property a caller can act on.
  group('TomExportService naming (one report name, both channels)', () {
    test('a name with a space is accepted by both channels', () async {
      const reportName = 'Q3 sales';
      final store = TomMemoryExportStore();
      final service = TomExportService(store: store);

      final response = service.respondWith(
        _sampleResult(),
        'csv',
        baseName: reportName,
      );
      final key = service.keyFor(reportName, 'csv');
      final stored = await service.storeAs(_sampleResult(), 'csv', key: key);

      expect(
        response.headers['content-disposition'],
        'attachment; filename="Q3 sales.csv"',
      );
      expect(stored.key, 'Q3_sales.csv');
      expect(await store.exists(key), isTrue);
    });

    test('an empty name falls back to the same word on both channels', () {
      expect(TomExportService.sanitiseFileName('   '), 'export');
      expect(TomExportService().keyFor('   ', 'csv'), 'export.csv');
    });

    test('a report name cannot bring path structure of its own', () {
      // The only structure `keyFor` adds is the partition, which it owns. A
      // slash in a report name is a slash in a report name — "Sales / Returns"
      // is a title, not two directories.
      expect(
        TomExportService().keyFor(
          'Q3/2026 sales',
          'pdf',
          partitionOn: DateTime(2026, 7, 8),
        ),
        '2026/07/08/Q3_2026_sales.pdf',
      );
    });

    test('a traversal in a report name is neutralised, not refused', () {
      // This previously threw. Refusing was safe but asymmetric — the same name
      // downloads happily on the other channel — and replacing the characters
      // keeps the traversal impossible *and* keeps the channels agreeing.
      expect(
        TomExportService().keyFor('../etc/passwd', 'csv'),
        '.._etc_passwd.csv',
      );
    });

    test('a name too long to be a key is still refused, loudly', () {
      // The one refusal left, and deliberately not sanitised away: truncating
      // would make two different reports share a key, and the second export
      // would overwrite the first with nothing reported anywhere.
      expect(
        () => TomExportService().keyFor('n' * 600, 'csv'),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.key,
            'key',
            'export.store.invalid_key',
          ),
        ),
      );
    });
  });

  // The sanitiser lives next to `isValidKey` because the two are one grammar
  // spelled twice, and a sanitiser that drifts from its own validator produces
  // the worst output available: something refused by the check it exists to
  // satisfy. These tests hold the two together mechanically.
  group('TomBlobStore.sanitiseKeySegment', () {
    test('every code unit it can meet sanitises into a valid key', () {
      // The property, not a sample of it. A character added to one side of the
      // grammar and not the other fails here rather than in a deployment.
      for (var unit = 0; unit < 0x250; unit++) {
        final segment = TomBlobStore.sanitiseKeySegment(
          String.fromCharCode(unit),
        );
        expect(
          TomBlobStore.isValidKey(segment),
          isTrue,
          reason:
              'U+${unit.toRadixString(16).padLeft(4, '0')} '
              'sanitised to "$segment", which is not a valid key',
        );
      }
    });

    test('a plain name passes through untouched', () {
      expect(
        TomBlobStore.sanitiseKeySegment('sales-2026_Q3.csv'),
        'sales-2026_Q3.csv',
      );
    });

    test('a separator cannot survive, so one segment stays one segment', () {
      expect(TomBlobStore.sanitiseKeySegment('a/b'), 'a_b');
      expect(TomBlobStore.sanitiseKeySegment(r'a\b'), 'a_b');
      expect(
        TomBlobStore.sanitiseKeySegment('../../etc/passwd'),
        '.._.._etc_passwd',
      );
    });

    test('the two segments the grammar reserves become the fallback', () {
      expect(TomBlobStore.sanitiseKeySegment('.'), 'file');
      expect(TomBlobStore.sanitiseKeySegment('..'), 'file');
      expect(TomBlobStore.sanitiseKeySegment(''), 'file');
      expect(TomBlobStore.sanitiseKeySegment('   '), 'file');
      expect(
        TomBlobStore.sanitiseKeySegment('  ', fallback: 'export'),
        'export',
      );
    });

    test('length is the one fault it does not repair', () {
      // Deliberate: truncating would give two different names one key, and the
      // second write would replace the first in silence. It hands the caller a
      // name `validateKey` refuses instead of a collision nothing reports.
      final long = TomBlobStore.sanitiseKeySegment('n' * 600);
      expect(long.length, 600);
      expect(TomBlobStore.isValidKey(long), isFalse);
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

/// Whether `chmod` cannot be relied on to deny this process access.
///
/// The store's I/O failure paths are only reachable by making the filesystem
/// refuse — which Windows has no `chmod` for, and which root ignores. Probing
/// once, rather than assuming, keeps the tests honest: they run where they can
/// prove something and say why they did not where they cannot.
final bool _chmodIsIneffective = () {
  if (Platform.isWindows) return true;
  final probe = File(
    '${Directory.systemTemp.createTempSync('tom_chmod_').path}/p',
  )..writeAsStringSync('x');
  Process.runSync('chmod', ['000', probe.path]);
  try {
    probe.readAsBytesSync();
    return true; // Read anyway — running as root.
  } on FileSystemException {
    return false;
  } finally {
    Process.runSync('chmod', ['600', probe.path]);
    probe.parent.deleteSync(recursive: true);
  }
}();

/// A service that meters `render`, the way a real subclass would.
///
/// The three reasons to override `render` named in the module's own
/// documentation are a metric, a trace and a limit check, and this fixture is
/// all three: it records what it was asked for ([renders]), it counts what came
/// back ([byteCount]) — which it can only do by being on the path the bytes
/// take — and it [refuses] a format outright.
class _MeteredExportService extends TomExportService {
  _MeteredExportService({super.store, this.refuses});

  /// The format this service declines to render at all, if any.
  final String? refuses;

  /// One entry per `render`, in call order.
  final List<String> renders = [];

  /// The bytes that actually passed through this override.
  int byteCount = 0;

  @override
  Stream<List<int>> render(TomTabularResult result, String format) async* {
    renders.add(format);
    if (format == refuses) {
      throw TomExportException('test.refused', 'Not on this service.');
    }
    await for (final chunk in super.render(result, format)) {
      byteCount += chunk.length;
      yield chunk;
    }
  }
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
          '${jsonEncode({for (var i = 0; i < section.columns.length; i++) section.columns[i].name: tomFormatCellAsText(row.cell(i))})}\n',
        );
      }
    }
  }
}
