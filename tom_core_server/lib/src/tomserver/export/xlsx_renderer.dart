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
/// XLSX — a formula engine, styles, shared strings, the reading side — are
/// exactly the parts an export does not use. What is left is a fixed set of
/// small XML parts — six, plus one per sheet, one more when the result carries
/// metadata, and for a sheet with charts its drawing and one part per chart —
/// and a ZIP container, and the ZIP compression itself is
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
  const TomXlsxRenderer({
    this.compressionLevel = 6,
    this.maxRowsPerSheet = 1048576,
    this.maxColumnsPerSheet = 16384,
    this.maxPartBytes = 0xFFFFFFFF,
  });

  /// The deflate level, 0 (store) to 9 (smallest).
  ///
  /// 6 is zlib's default and the right trade for tabular XML, which compresses
  /// roughly ten to one. 0 is worth choosing only when the consumer is a
  /// program on the same machine and the CPU matters more than the bytes.
  final int compressionLevel;

  /// The most rows one worksheet may hold, header included.
  ///
  /// Defaults to Excel's own limit since the 2007 format, and it is Excel's
  /// rather than this writer's: a sheet past it renders perfectly here and is
  /// refused *by the reader*. Checked while the rows stream, so a result that
  /// will not fit fails on the row that crosses the line rather than at the
  /// reader an hour later.
  ///
  /// Lower it for a consumer with a tighter limit of its own. Raising it
  /// produces a file Excel will not open, which is the caller's to decide in
  /// the same way [TomPdfRenderer.rowLimit] is.
  final int maxRowsPerSheet;

  /// The most columns one worksheet may hold — Excel's limit, as above.
  ///
  /// Checked before any row is written, because a section's columns are known
  /// up front and a refusal that waited for the stream would have spent the
  /// query first.
  final int maxColumnsPerSheet;

  /// The largest value the archive's 32-bit size and offset fields can hold.
  ///
  /// Every size and offset this writer emits is 32-bit and ZIP64 — the
  /// extension that widens them — is not written. A part or an archive past
  /// this would wrap **silently**: the fields would hold the value modulo 4
  /// GiB, the reader would believe them, and the result is a corrupt workbook
  /// produced by a run that reported success. The module's stated purpose is
  /// the export too large to hold in memory, so this is a ceiling a real report
  /// reaches rather than a theoretical one.
  ///
  /// So it is checked as the bytes go past and the render **fails at the
  /// ceiling**, which is what [TomPdfRenderer] does with its own. Emitting
  /// ZIP64 instead is the other honest answer and a larger one: it changes the
  /// local header, the data descriptor, the central directory and the
  /// end-of-central-directory record, and every reader that has to accept them.
  ///
  /// A parameter so that the refusal can be reached in a test without producing
  /// four gigabytes; a deployment has no reason to change it.
  final int maxPartBytes;

  @override
  String get formatId => 'xlsx';

  @override
  String get mediaType =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  @override
  String get fileExtension => 'xlsx';

  @override
  Stream<List<int>> render(TomTabularResult result) async* {
    final zip = _ZipStreamWriter(compressionLevel, maxPartBytes);
    final sheetNames = _sheetNames(result);
    final properties = _customPropertyEntries(result.metadata);

    // Which sheets carry charts, and each chart's global number: the content
    // types are written first, so every chart part is named before any row
    // has been read.
    final chartedSheets = [
      for (var i = 0; i < result.sections.length; i++)
        if (result.sections[i].charts.isNotEmpty) i + 1,
    ];
    final chartCount = result.sections.fold<int>(
      0,
      (sum, section) => sum + section.charts.length,
    );
    yield* zip.addText(
      '[Content_Types].xml',
      _contentTypes(
        sheetNames.length,
        withCustomProperties: properties.isNotEmpty,
        drawings: chartedSheets,
        chartCount: chartCount,
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

    var nextChart = 1;
    for (var i = 0; i < result.sections.length; i++) {
      final section = result.sections[i];
      final rows = _RowCount();
      yield* zip.addStream(
        'xl/worksheets/sheet${i + 1}.xml',
        _sheetXml(section, rows),
      );
      if (section.charts.isEmpty) continue;
      final first = nextChart;
      nextChart += section.charts.length;
      yield* zip.addText(
        'xl/worksheets/_rels/sheet${i + 1}.xml.rels',
        '$_xmlDeclaration<Relationships xmlns="$_nsPackageRelationships">'
            '<Relationship Id="rId1" Type="$_nsRel/drawing" '
            'Target="../drawings/drawing${i + 1}.xml"/></Relationships>',
      );
      yield* zip.addText('xl/drawings/drawing${i + 1}.xml', _drawing(section));
      yield* zip.addText(
        'xl/drawings/_rels/drawing${i + 1}.xml.rels',
        '$_xmlDeclaration<Relationships xmlns="$_nsPackageRelationships">'
            '${[for (var k = 0; k < section.charts.length; k++) '<Relationship Id="rId${k + 1}" Type="$_nsRel/chart" Target="../charts/chart${first + k}.xml"/>'].join()}'
            '</Relationships>',
      );
      for (var k = 0; k < section.charts.length; k++) {
        yield* zip.addText(
          'xl/charts/chart${first + k}.xml',
          _chartXml(section, section.charts[k], sheetNames[i], rows.last),
        );
      }
    }
    yield* zip.finish();
  }

  static const String _nsPackageRelationships =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const String _nsChart =
      'http://schemas.openxmlformats.org/drawingml/2006/chart';
  static const String _nsDrawingMain =
      'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const String _nsSpreadsheetDrawing =
      'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing';

  /// How many columns a chart spans, and how many rows.
  static const int _chartColumns = 8;
  static const int _chartRows = 18;

  /// The drawing part placing [section]'s charts: one anchor each, beside the
  /// table and stacked downwards, so no chart covers a cell of the data.
  static String _drawing(TomTabularSection section) {
    final left = section.columns.length + 1;
    final anchors = [
      for (var k = 0; k < section.charts.length; k++)
        '<xdr:twoCellAnchor>'
            '<xdr:from><xdr:col>$left</xdr:col><xdr:colOff>0</xdr:colOff>'
            '<xdr:row>${1 + k * (_chartRows + 2)}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>'
            '<xdr:to><xdr:col>${left + _chartColumns}</xdr:col><xdr:colOff>0</xdr:colOff>'
            '<xdr:row>${1 + k * (_chartRows + 2) + _chartRows}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>'
            '<xdr:graphicFrame macro="">'
            '<xdr:nvGraphicFramePr><xdr:cNvPr id="${k + 2}" name="Chart ${k + 1}"/>'
            '<xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>'
            '<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm>'
            '<a:graphic><a:graphicData uri="$_nsChart">'
            '<c:chart xmlns:c="$_nsChart" r:id="rId${k + 1}"/>'
            '</a:graphicData></a:graphic></xdr:graphicFrame>'
            '<xdr:clientData/></xdr:twoCellAnchor>',
    ].join();
    return '$_xmlDeclaration'
        '<xdr:wsDr xmlns:xdr="$_nsSpreadsheetDrawing" xmlns:a="$_nsDrawingMain" '
        'xmlns:r="$_nsRel">$anchors</xdr:wsDr>';
  }

  /// The chart part for [chart], its series bound to the cells of [sheetName]
  /// from row 2 to [lastRow] — the exported data itself, so the chart follows
  /// any edit a recipient makes to it.
  static String _chartXml(
    TomTabularSection section,
    TomTabularChart chart,
    String sheetName,
    int lastRow,
  ) {
    final sheet = "'${sheetName.replaceAll("'", "''")}'";
    final last = lastRow < 2 ? 2 : lastRow;
    int columnOf(String name) =>
        section.columns.indexWhere((column) => column.name == name);
    String absolute(String ref) => ref.replaceFirstMapped(
      RegExp(r'([A-Z]+)(\d+)'),
      (m) => '\$${m[1]}\$${m[2]}',
    );
    String range(int column) =>
        '$sheet!${absolute(_ref(column, 2))}:${absolute(_ref(column, last))}';
    final categories = range(columnOf(chart.categoryColumn));
    final series = [
      for (var k = 0; k < chart.valueColumns.length; k++)
        '<c:ser><c:idx val="$k"/><c:order val="$k"/>'
            '<c:tx><c:strRef><c:f>${_escapeXml('$sheet!${absolute(_ref(columnOf(chart.valueColumns[k]), 1))}')}</c:f></c:strRef></c:tx>'
            '<c:cat><c:strRef><c:f>${_escapeXml(categories)}</c:f></c:strRef></c:cat>'
            '<c:val><c:numRef><c:f>${_escapeXml(range(columnOf(chart.valueColumns[k])))}</c:f></c:numRef></c:val>'
            '${chart.type == TomChartType.line ? '<c:smooth val="0"/>' : ''}'
            '</c:ser>',
    ].join();
    const axes = '<c:axId val="1"/><c:axId val="2"/>';
    const axisElements =
        '<c:catAx><c:axId val="1"/><c:scaling><c:orientation val="minMax"/></c:scaling>'
        '<c:delete val="0"/><c:axPos val="b"/><c:crossAx val="2"/></c:catAx>'
        '<c:valAx><c:axId val="2"/><c:scaling><c:orientation val="minMax"/></c:scaling>'
        '<c:delete val="0"/><c:axPos val="l"/><c:majorGridlines/><c:crossAx val="1"/></c:valAx>';
    final plot = switch (chart.type) {
      TomChartType.bar =>
        '<c:barChart><c:barDir val="col"/><c:grouping val="clustered"/>'
            '<c:varyColors val="0"/>$series$axes</c:barChart>$axisElements',
      TomChartType.line =>
        '<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>'
            '$series<c:marker val="1"/>$axes</c:lineChart>$axisElements',
      TomChartType.pie =>
        '<c:pieChart><c:varyColors val="1"/>$series'
            '<c:firstSliceAng val="0"/></c:pieChart>',
    };
    final title = chart.title == null
        ? '<c:autoTitleDeleted val="1"/>'
        : '<c:title><c:tx><c:rich><a:bodyPr/><a:p><a:r><a:t>'
              '${_escapeXml(chart.title!)}</a:t></a:r></a:p></c:rich></c:tx>'
              '<c:overlay val="0"/></c:title><c:autoTitleDeleted val="0"/>';
    return '$_xmlDeclaration'
        '<c:chartSpace xmlns:c="$_nsChart" xmlns:a="$_nsDrawingMain" '
        'xmlns:r="$_nsRel"><c:chart>$title'
        '<c:plotArea><c:layout/>$plot</c:plotArea>'
        '<c:legend><c:legendPos val="r"/><c:overlay val="0"/></c:legend>'
        '<c:plotVisOnly val="1"/></c:chart></c:chartSpace>';
  }

  /// Emits one worksheet part as a stream of XML fragments, one per row.
  ///
  /// [rows] is told the number of the last row written, which a chart of the
  /// section binds its ranges to.
  Stream<String> _sheetXml(TomTabularSection section, _RowCount rows) async* {
    if (section.columns.length > maxColumnsPerSheet) {
      throw TomExportException(
        'export.xlsx.too_many_columns',
        'That result has more columns than a worksheet can hold.',
        parameters: {
          'section': section.title ?? '',
          'columns': section.columns.length,
          'limit': maxColumnsPerSheet,
          'alternative': 'csv',
        },
      );
    }
    yield '$_xmlDeclaration'
        '<worksheet xmlns="$_nsMain" xmlns:r="$_nsRel">';
    // Every column, not only the hinted ones. OOXML's width unit is already a
    // character count, so a hint is written out as it stands; a column without
    // one would otherwise be left at Excel's default of 8.43, which shows an
    // ISO timestamp as `#####`. Sizing both from `effectiveWidth` is what makes
    // an unhinted column mean the same here as it does on a page.
    final widths = [
      for (var i = 0; i < section.columns.length; i++)
        '<col min="${i + 1}" max="${i + 1}" '
            'width="${section.columns[i].effectiveWidth}" customWidth="1"/>',
    ];
    yield '<cols>${widths.join()}</cols>';
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
      if (rowNumber > maxRowsPerSheet) {
        throw TomExportException(
          'export.xlsx.too_many_rows',
          'That result has more rows than a worksheet can hold. Export it as '
              'csv instead.',
          parameters: {
            'section': section.title ?? '',
            'limit': maxRowsPerSheet,
            'alternative': 'csv',
          },
        );
      }
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
    rows.last = rowNumber;
    // A drawing is referenced after the cells, where SpreadsheetML orders it.
    yield '</sheetData>'
        '${section.charts.isEmpty ? '' : '<drawing r:id="rId1"/>'}'
        '</worksheet>';
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
    List<int> drawings = const [],
    int chartCount = 0,
  }) {
    final charts = [
      for (final i in drawings)
        '<Override PartName="/xl/drawings/drawing$i.xml" ContentType='
            '"application/vnd.openxmlformats-officedocument.drawing+xml"/>',
      for (var n = 1; n <= chartCount; n++)
        '<Override PartName="/xl/charts/chart$n.xml" ContentType='
            '"application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>',
    ].join();
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
        '$sheets$charts</Types>';
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

/// The number of the last row a worksheet part wrote, read once the part has
/// been streamed.
class _RowCount {
  int last = 1;
}

/// Writes a ZIP archive incrementally, one entry at a time.
///
/// Uses general-purpose bit 3 (data descriptors) so that an entry's CRC and
/// sizes are written *after* its data — which is what makes it possible to
/// compress and emit an entry that has not been produced yet.
class _ZipStreamWriter {
  _ZipStreamWriter(this._level, this._maxBytes);

  /// The most entries the 16-bit central-directory counts can hold.
  ///
  /// A workbook has one part per sheet plus six fixed ones, so this is far out
  /// of reach — checked anyway because the cost is one comparison and the
  /// failure it prevents is the same silent wrap as the sizes.
  static const int maxZipEntries = 0xFFFF;

  final int _level;

  /// The ceiling every 32-bit size and offset is held to — see
  /// [TomXlsxRenderer.maxPartBytes].
  final int _maxBytes;
  final List<_ZipEntry> _entries = [];
  int _offset = 0;

  /// Refuses [value] — [what] of [name] — before it can wrap a 32-bit field.
  static void _requireFits(int value, int limit, String what, String name) {
    if (value <= limit) return;
    throw TomExportException(
      'export.xlsx.archive_too_large',
      'That export is too large for the xlsx container. Export it as csv '
          'instead.',
      parameters: {
        'part': name,
        'measure': what,
        'value': value,
        'limit': limit,
        'alternative': 'csv',
      },
    );
  }

  /// Appends an entry whose content is [text], emitting its bytes.
  Stream<List<int>> addText(String name, String text) =>
      addStream(name, Stream<String>.value(text));

  /// Appends an entry whose content is [chunks], emitting bytes as it goes.
  Stream<List<int>> addStream(String name, Stream<String> chunks) async* {
    final nameBytes = utf8.encode(name);
    // The offset goes into this entry's central-directory record, so an archive
    // that has already passed 4 GiB cannot address the part about to be
    // written — checked before the part is produced rather than after.
    _requireFits(_offset, _maxBytes, 'archive offset', name);
    _requireFits(_entries.length + 1, maxZipEntries, 'entry count', name);
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
      // Per chunk, not at the end: the point is to fail *before* the fields
      // wrap and before the rest of a multi-gigabyte query is pulled, not to
      // discover it once the part is complete.
      _requireFits(
        entry.uncompressedSize,
        _maxBytes,
        'uncompressed size',
        name,
      );
      crc.add(bytes);
      if (deflate == null) {
        _offset += bytes.length;
        entry.compressedSize += bytes.length;
        _requireFits(entry.compressedSize, _maxBytes, 'compressed size', name);
        _requireFits(_offset, _maxBytes, 'archive offset', name);
        yield bytes;
      } else {
        deflate.add(bytes);
        final out = collector.take();
        if (out.isNotEmpty) {
          _offset += out.length;
          entry.compressedSize += out.length;
          _requireFits(
            entry.compressedSize,
            _maxBytes,
            'compressed size',
            name,
          );
          _requireFits(_offset, _maxBytes, 'archive offset', name);
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
    // The two fields of the end record that are not an entry's: where the
    // central directory begins and how long it is. Both are 32-bit, and an
    // archive whose *parts* each fit can still push the directory past the
    // ceiling.
    _requireFits(start, _maxBytes, 'central directory offset', 'archive');
    _requireFits(
      _offset - start,
      _maxBytes,
      'central directory size',
      'archive',
    );
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
