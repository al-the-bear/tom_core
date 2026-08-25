/// XLSX rendering: one worksheet per section, written straight to the wire.
///
/// An `.xlsx` file is a ZIP archive of XML parts. That happens to be the one
/// office format that can be produced front-to-back without ever holding the
/// document, which is why it — and not PDF — is the rich format that keeps
/// [TomTabularRenderer.streamsRows] `true`.
///
/// ## Why no XLSX package
///
/// `package:excel` (MIT, 4.0.6) was evaluated and not adopted, for two
/// independent reasons:
///
/// 1. **It buffers everything.** Its model is `Excel.createExcel()`,
///    `sheet.appendRow(...)` per row, then `excel.encode()` returning the whole
///    file as bytes. Both the workbook object graph and the encoded archive are
///    resident at once — the failure this module exists to prevent.
/// 2. **It pins `xml <7.0.0`.** `package:pdf` moves to `xml ^7` at 3.13.0, so
///    depending on both would freeze the PDF renderer at 3.12.x indefinitely.
///
/// The alternative was not "write a spreadsheet format". The **hard** parts of
/// XLSX — a formula engine, styles, charts, shared strings, the reading side —
/// are exactly the parts an export does not use. What is left is a fixed set of
/// small XML parts — six, plus one per sheet, plus one more when the result
/// carries metadata — and a ZIP container, and the ZIP compression itself is
/// `dart:io`'s `ZLibEncoder`. So this renderer takes no dependency at all.
///
/// ## Where the title and the metadata go
///
/// Both land in the package's document properties rather than in a cell:
/// [TomTabularResult.title] as `dc:title` in `docProps/core.xml`, and
/// [TomTabularResult.metadata] as user-defined properties in
/// `docProps/custom.xml`. That is the same choice the PDF renderer makes when
/// it passes the title to the document's info dictionary — with the difference
/// that the PDF *also* prints both, because a page has somewhere to print them
/// and a sheet does not.
///
/// A header block above the table was the alternative and is the wrong answer
/// here: it would push the header row down by however many metadata entries
/// there happened to be, so a consumer reading the sheet as a table would find
/// its columns at a row number that varies with the metadata. A spreadsheet's
/// value is that it is machine-readable; the properties carry the context
/// without spending that.
///
/// ## How it streams
///
/// Two techniques, both standard, together remove every reason to buffer:
///
/// - **Inline strings** (`t="inlineStr"`) rather than a shared-strings table. A
///   shared-strings table must be written *before* the sheets that index into
///   it, which means knowing every string in the document before emitting the
///   first row. Inline strings cost some size and save the entire result.
/// - **ZIP data descriptors** (general-purpose bit 3). A local file header
///   normally carries the entry's CRC and sizes, which are unknown until the
///   entry is finished. Bit 3 says "the three values follow the data instead",
///   so each part is written as it is compressed. Every mainstream reader,
///   Excel included, supports this.
///
/// The result: peak memory is one row of XML plus the deflate window,
/// regardless of how many rows there are.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'tabular_renderer.dart';
import 'tabular_result.dart';

/// Renders a tabular result as an Office Open XML workbook, streaming.
class TomXlsxRenderer extends TomTabularRenderer {
  /// Creates an XLSX renderer.
  const TomXlsxRenderer({this.compressionLevel = 6});

  /// The deflate level, 0 (store) to 9 (smallest).
  ///
  /// 6 is zlib's default and the right trade for tabular XML, which compresses
  /// roughly ten to one. 0 is worth choosing only when the consumer is a
  /// program on the same machine and the CPU matters more than the bytes.
  final int compressionLevel;

  @override
  String get formatId => 'xlsx';

  @override
  String get mediaType =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  @override
  String get fileExtension => 'xlsx';

  @override
  Stream<List<int>> render(TomTabularResult result) async* {
    final zip = _ZipStreamWriter(compressionLevel);
    final sheetNames = _sheetNames(result);
    final properties = _customPropertyEntries(result.metadata);

    yield* zip.addText(
      '[Content_Types].xml',
      _contentTypes(
        sheetNames.length,
        withCustomProperties: properties.isNotEmpty,
      ),
    );
    yield* zip.addText(
      '_rels/.rels',
      _rootRels(withCustomProperties: properties.isNotEmpty),
    );
    yield* zip.addText('docProps/core.xml', _coreProperties(result.title));
    if (properties.isNotEmpty) {
      yield* zip.addText('docProps/custom.xml', _customProperties(properties));
    }
    yield* zip.addText('xl/workbook.xml', _workbook(sheetNames));
    yield* zip.addText(
      'xl/_rels/workbook.xml.rels',
      _workbookRels(sheetNames.length),
    );
    yield* zip.addText('xl/styles.xml', _styles);

    for (var i = 0; i < result.sections.length; i++) {
      yield* zip.addStream(
        'xl/worksheets/sheet${i + 1}.xml',
        _sheetXml(result.sections[i]),
      );
    }
    yield* zip.finish();
  }

  /// Emits one worksheet part as a stream of XML fragments, one per row.
  Stream<String> _sheetXml(TomTabularSection section) async* {
    yield '$_xmlDeclaration'
        '<worksheet xmlns="$_nsMain">';
    final widths = <String>[];
    for (var i = 0; i < section.columns.length; i++) {
      final width = section.columns[i].width;
      if (width != null) {
        widths.add(
          '<col min="${i + 1}" max="${i + 1}" width="$width" customWidth="1"/>',
        );
      }
    }
    if (widths.isNotEmpty) yield '<cols>${widths.join()}</cols>';
    yield '<sheetData>';

    final buffer = StringBuffer()..write('<row r="1">');
    for (var i = 0; i < section.columns.length; i++) {
      buffer.write(
        '<c r="${_ref(i, 1)}" s="1" t="inlineStr"><is><t>'
        '${_escapeXml(section.columns[i].label)}</t></is></c>',
      );
    }
    buffer.write('</row>');
    yield buffer.toString();

    var rowNumber = 1;
    await for (final row in section.rows) {
      rowNumber++;
      final line = StringBuffer()..write('<row r="$rowNumber">');
      for (var i = 0; i < section.columns.length; i++) {
        final cell = _cellXml(
          _ref(i, rowNumber),
          section.columns[i].type,
          row.cell(i),
        );
        if (cell != null) line.write(cell);
      }
      line.write('</row>');
      yield line.toString();
    }
    yield '</sheetData></worksheet>';
  }

  /// The `<c>` element for one cell, or `null` when the cell is empty.
  ///
  /// An omitted cell is how SpreadsheetML spells "blank" — writing an empty
  /// `<c>` would create a cell that exists, which changes what a `COUNTA` over
  /// the column returns.
  String? _cellXml(String ref, TomColumnType type, Object? value) {
    if (value == null) return null;
    return switch (type) {
      TomColumnType.integer || TomColumnType.decimal when value is num =>
        '<c r="$ref"><v>${_number(value)}</v></c>',
      TomColumnType.boolean when value is bool =>
        '<c r="$ref" t="b"><v>${value ? 1 : 0}</v></c>',
      TomColumnType.timestamp when value is DateTime =>
        '<c r="$ref" s="2"><v>${_excelSerial(value)}</v></c>',
      // Either a text column, or a value whose runtime type does not match the
      // column it landed in. Rendering the mismatch as text is deliberate: an
      // export that shows a surprising value is recoverable, one that fails
      // outright on the last row of a long report is not.
      _ =>
        '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
            '${_escapeXml(tomFormatCellAsText(value))}</t></is></c>',
    };
  }

  /// Renders [value] as an XML number literal without a trailing `.0`.
  static String _number(num value) =>
      value is int || value == value.roundToDouble() && value.abs() < 1e15
      ? value.toInt().toString()
      : value.toString();

  /// Converts [value] to an Excel date serial: days since 1899-12-30.
  ///
  /// Computed from the calendar fields rather than by subtracting epochs, so it
  /// is independent of the process time zone and of historical UTC offsets —
  /// a spreadsheet cell has no time zone, and the value a user typed is the
  /// value they should see back.
  static String _excelSerial(DateTime value) {
    final days = DateTime.utc(
      value.year,
      value.month,
      value.day,
    ).difference(DateTime.utc(1899, 12, 30)).inDays;
    final fraction =
        (value.hour * 3600 + value.minute * 60 + value.second) / 86400.0 +
        value.millisecond / 86400000.0;
    if (fraction == 0) return '$days';
    return (days + fraction).toStringAsFixed(10);
  }

  /// The A1-style reference for a zero-based [column] and one-based [row].
  static String _ref(int column, int row) {
    final letters = StringBuffer();
    var n = column;
    do {
      letters.write(String.fromCharCode(65 + n % 26));
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return '${String.fromCharCodes(letters.toString().codeUnits.reversed)}$row';
  }

  /// Sheet names for [result]'s sections: sanitised, truncated and made unique.
  ///
  /// Excel rejects a workbook whose sheet names collide, exceed 31 characters
  /// or contain `: \ / ? * [ ]` — a report titled `Q1/Q2 comparison` would
  /// otherwise produce a file that will not open.
  static List<String> _sheetNames(TomTabularResult result) {
    final names = <String>[];
    final taken = <String>{};
    for (var i = 0; i < result.sections.length; i++) {
      var name = (result.sections[i].title ?? 'Sheet${i + 1}')
          .replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ')
          .trim();
      if (name.isEmpty) name = 'Sheet${i + 1}';
      if (name.length > 31) name = name.substring(0, 31);
      var candidate = name;
      var suffix = 2;
      while (!taken.add(candidate.toLowerCase())) {
        final tag = ' ($suffix)';
        candidate = name.length + tag.length > 31
            ? '${name.substring(0, 31 - tag.length)}$tag'
            : '$name$tag';
        suffix++;
      }
      names.add(candidate);
    }
    return names;
  }

  static const String _xmlDeclaration =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  static const String _nsMain =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const String _nsRel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const String _nsPackageRel =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const String _nsCoreProperties =
      'http://schemas.openxmlformats.org/package/2006/metadata/core-properties';
  static const String _nsDc = 'http://purl.org/dc/elements/1.1/';
  static const String _nsCustomProperties =
      'http://schemas.openxmlformats.org/officeDocument/2006/custom-properties';
  static const String _nsDocPropsTypes =
      'http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes';

  static String _contentTypes(
    int sheetCount, {
    required bool withCustomProperties,
  }) {
    final sheets = [
      for (var i = 1; i <= sheetCount; i++)
        '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType='
            '"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    ].join();
    final custom = withCustomProperties
        ? '<Override PartName="/docProps/custom.xml" ContentType='
              '"application/vnd.openxmlformats-officedocument.custom-properties+xml"/>'
        : '';
    return '$_xmlDeclaration'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType='
        '"application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/docProps/core.xml" ContentType='
        '"application/vnd.openxmlformats-package.core-properties+xml"/>'
        '$custom'
        '<Override PartName="/xl/workbook.xml" ContentType='
        '"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType='
        '"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '$sheets</Types>';
  }

  static String _rootRels({required bool withCustomProperties}) {
    final custom = withCustomProperties
        ? '<Relationship Id="rId3" Type="$_nsRel/custom-properties" '
              'Target="docProps/custom.xml"/>'
        : '';
    return '$_xmlDeclaration'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="$_nsRel/officeDocument" Target="xl/workbook.xml"/>'
        '<Relationship Id="rId2" Type="$_nsPackageRel/metadata/core-properties" '
        'Target="docProps/core.xml"/>'
        '$custom'
        '</Relationships>';
  }

  /// The core properties part, carrying the result title as `dc:title`.
  ///
  /// It deliberately carries no `dcterms:created` or `dcterms:modified`. Those
  /// are the two fields a real authoring tool always writes, and writing either
  /// would make the same result render to different bytes on two runs — the
  /// property the zeroed MS-DOS timestamps in [_ZipStreamWriter._localHeader]
  /// exist to preserve. An export has no author and no edit history; it has a
  /// title, and that is what it says.
  static String _coreProperties(String title) =>
      '$_xmlDeclaration'
      '<cp:coreProperties xmlns:cp="$_nsCoreProperties" xmlns:dc="$_nsDc">'
      '<dc:title>${_escapeXml(title)}</dc:title>'
      '</cp:coreProperties>';

  /// The metadata entries that can become custom properties, escaped.
  ///
  /// An entry whose name escapes to nothing — empty, or made only of control
  /// characters XML cannot carry — is dropped rather than written. A custom
  /// property with an empty `name` is what makes Excel declare the file
  /// corrupt, and the same trade is made here as in [_escapeXml]: losing one
  /// entry of context beats a workbook that will not open.
  static List<MapEntry<String, String>> _customPropertyEntries(
    Map<String, String> metadata,
  ) {
    final entries = <MapEntry<String, String>>[];
    for (final entry in metadata.entries) {
      final name = _escapeXml(entry.key);
      if (name.isEmpty) continue;
      entries.add(MapEntry(name, _escapeXml(entry.value)));
    }
    return entries;
  }

  /// The custom properties part: one user-defined property per metadata entry.
  ///
  /// `fmtid` is the format id OOXML reserves for user-defined properties, and
  /// `pid` numbers them from 2 — 0 and 1 are reserved by the underlying
  /// property-set format, and a property claiming either is rejected.
  static String _customProperties(List<MapEntry<String, String>> entries) {
    final properties = [
      for (var i = 0; i < entries.length; i++)
        '<property fmtid="{D5CDD505-2E9C-101B-9397-08002B2CF9AE}" '
            'pid="${i + 2}" name="${entries[i].key}">'
            '<vt:lpwstr>${entries[i].value}</vt:lpwstr></property>',
    ].join();
    return '$_xmlDeclaration'
        '<Properties xmlns="$_nsCustomProperties" xmlns:vt="$_nsDocPropsTypes">'
        '$properties</Properties>';
  }

  static String _workbook(List<String> sheetNames) {
    final sheets = [
      for (var i = 0; i < sheetNames.length; i++)
        '<sheet name="${_escapeXml(sheetNames[i])}" sheetId="${i + 1}" '
            'r:id="rId${i + 1}"/>',
    ].join();
    return '$_xmlDeclaration'
        '<workbook xmlns="$_nsMain" xmlns:r="$_nsRel">'
        '<sheets>$sheets</sheets></workbook>';
  }

  static String _workbookRels(int sheetCount) {
    final rels = [
      for (var i = 1; i <= sheetCount; i++)
        '<Relationship Id="rId$i" Type="$_nsRel/worksheet" '
            'Target="worksheets/sheet$i.xml"/>',
      '<Relationship Id="rId${sheetCount + 1}" Type="$_nsRel/styles" '
          'Target="styles.xml"/>',
    ].join();
    return '$_xmlDeclaration'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rels</Relationships>';
  }

  /// The minimal stylesheet: index 0 default, 1 bold header, 2 date-time.
  static const String _styles =
      '$_xmlDeclaration'
      '<styleSheet xmlns="$_nsMain">'
      '<numFmts count="1">'
      '<numFmt numFmtId="164" formatCode="yyyy\\-mm\\-dd\\ hh:mm:ss"/>'
      '</numFmts>'
      '<fonts count="2">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="2">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '</fills>'
      '<borders count="1">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '</borders>'
      '<cellStyleXfs count="1">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
      '</cellStyleXfs>'
      '<cellXfs count="3">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" '
      'applyNumberFormat="1"/>'
      '</cellXfs>'
      '<cellStyles count="1">'
      '<cellStyle name="Normal" xfId="0" builtinId="0"/>'
      '</cellStyles>'
      '</styleSheet>';
}

/// Escapes [text] for XML character data, dropping characters XML cannot carry.
///
/// Control characters below 0x20 (other than tab, newline and carriage return)
/// are not representable in XML 1.0 *at all* — not even as a numeric reference
/// — so they are removed rather than escaped. They reach an export from binary
/// data mis-stored in a text column, and a workbook that will not open is a
/// worse answer than a cell missing a byte no one can see.
String _escapeXml(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    switch (rune) {
      case 0x26:
        buffer.write('&amp;');
      case 0x3C:
        buffer.write('&lt;');
      case 0x3E:
        buffer.write('&gt;');
      case 0x22:
        buffer.write('&quot;');
      case 0x09 || 0x0A || 0x0D:
        buffer.writeCharCode(rune);
      default:
        if (rune >= 0x20) buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Writes a ZIP archive incrementally, one entry at a time.
///
/// Uses general-purpose bit 3 (data descriptors) so that an entry's CRC and
/// sizes are written *after* its data — which is what makes it possible to
/// compress and emit an entry that has not been produced yet.
class _ZipStreamWriter {
  _ZipStreamWriter(this._level);

  final int _level;
  final List<_ZipEntry> _entries = [];
  int _offset = 0;

  /// Appends an entry whose content is [text], emitting its bytes.
  Stream<List<int>> addText(String name, String text) =>
      addStream(name, Stream<String>.value(text));

  /// Appends an entry whose content is [chunks], emitting bytes as it goes.
  Stream<List<int>> addStream(String name, Stream<String> chunks) async* {
    final nameBytes = utf8.encode(name);
    final entry = _ZipEntry(name: nameBytes, offset: _offset);
    _entries.add(entry);

    final header = _localHeader(nameBytes);
    _offset += header.length;
    yield header;

    final collector = _ByteCollector();
    final deflate = _level == 0
        ? null
        : ZLibEncoder(
            raw: true,
            level: _level,
          ).startChunkedConversion(collector);
    final crc = _Crc32();

    await for (final chunk in chunks) {
      final bytes = utf8.encode(chunk);
      entry.uncompressedSize += bytes.length;
      crc.add(bytes);
      if (deflate == null) {
        _offset += bytes.length;
        entry.compressedSize += bytes.length;
        yield bytes;
      } else {
        deflate.add(bytes);
        final out = collector.take();
        if (out.isNotEmpty) {
          _offset += out.length;
          entry.compressedSize += out.length;
          yield out;
        }
      }
    }
    if (deflate != null) {
      deflate.close();
      final out = collector.take();
      if (out.isNotEmpty) {
        _offset += out.length;
        entry.compressedSize += out.length;
        yield out;
      }
    }
    entry.crc = crc.value;

    final descriptor = _bytes([
      ..._u32(0x08074b50),
      ..._u32(entry.crc),
      ..._u32(entry.compressedSize),
      ..._u32(entry.uncompressedSize),
    ]);
    _offset += descriptor.length;
    yield descriptor;
  }

  /// Emits the central directory and end-of-central-directory record.
  Stream<List<int>> finish() async* {
    final start = _offset;
    for (final entry in _entries) {
      final record = _bytes([
        ..._u32(0x02014b50),
        ..._u16(0x0014), // version made by
        ..._u16(0x0014), // version needed
        ..._u16(0x0808), // bit 3 (data descriptor) + bit 11 (UTF-8 names)
        ..._u16(_level == 0 ? 0 : 8), // store or deflate
        ..._u16(0), ..._u16(0), // MS-DOS time and date: fixed, see below
        ..._u32(entry.crc),
        ..._u32(entry.compressedSize),
        ..._u32(entry.uncompressedSize),
        ..._u16(entry.name.length),
        ..._u16(0), ..._u16(0), // extra, comment
        ..._u16(0), ..._u16(0), // disk, internal attrs
        ..._u32(0), // external attrs
        ..._u32(entry.offset),
        ...entry.name,
      ]);
      _offset += record.length;
      yield record;
    }
    yield _bytes([
      ..._u32(0x06054b50),
      ..._u16(0),
      ..._u16(0),
      ..._u16(_entries.length),
      ..._u16(_entries.length),
      ..._u32(_offset - start),
      ..._u32(start),
      ..._u16(0),
    ]);
  }

  /// The local file header for [nameBytes], with sizes deferred to bit 3.
  ///
  /// The MS-DOS timestamp fields are written as zero on purpose. A real
  /// modification time would make the same result render to two different byte
  /// sequences on two runs, which breaks the cheapest possible test — compare
  /// the bytes — and any caching keyed on a content hash. Readers show the
  /// entries as dated 1980-01-01; nothing depends on it.
  Uint8List _localHeader(List<int> nameBytes) => _bytes([
    ..._u32(0x04034b50),
    ..._u16(0x0014),
    ..._u16(0x0808),
    ..._u16(_level == 0 ? 0 : 8),
    ..._u16(0), ..._u16(0),
    ..._u32(0), ..._u32(0), ..._u32(0), // crc + sizes: in the descriptor
    ..._u16(nameBytes.length),
    ..._u16(0),
    ...nameBytes,
  ]);

  static Uint8List _bytes(List<int> values) => Uint8List.fromList(values);
  static List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
  static List<int> _u32(int v) => [
    v & 0xFF,
    (v >> 8) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 24) & 0xFF,
  ];
}

/// One archive entry's bookkeeping while it is being written.
class _ZipEntry {
  _ZipEntry({required this.name, required this.offset});

  final List<int> name;
  final int offset;
  int crc = 0;
  int compressedSize = 0;
  int uncompressedSize = 0;
}

/// Accumulates the deflater's output until the writer drains it.
class _ByteCollector implements Sink<List<int>> {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  @override
  void add(List<int> data) => _builder.add(data);

  @override
  void close() {}

  /// Removes and returns everything accumulated so far.
  Uint8List take() => _builder.takeBytes();
}

/// The CRC-32 the ZIP format requires, computed as bytes arrive.
class _Crc32 {
  static final Uint32List _table = _buildTable();

  int _value = 0xFFFFFFFF;

  /// The finished checksum.
  int get value => _value ^ 0xFFFFFFFF;

  /// Folds [bytes] into the running checksum.
  void add(List<int> bytes) {
    var crc = _value;
    for (final byte in bytes) {
      crc = _table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    _value = crc;
  }

  static Uint32List _buildTable() {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
      }
      table[i] = c;
    }
    return table;
  }
}
