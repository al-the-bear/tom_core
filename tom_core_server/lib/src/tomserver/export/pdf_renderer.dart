/// PDF rendering: the format a person reads, and the one that cannot stream.
///
/// ## Why a package here and not for the other two
///
/// `package:pdf` (Apache-2.0, 3.13.0 — see `doc/export.md` for the recorded
/// evaluation) is adopted. CSV and XLSX were hand-written because what those
/// formats need from an export is small and fully specified; PDF is the
/// opposite. Paginating a table means knowing how wide a string is in a given
/// font at a given size, which means font metrics, line breaking, and a layout
/// pass that can split a row across a page boundary. That is the *whole* hard
/// part of a PDF writer, none of it is specific to this package, and writing it
/// again would be exactly the format-encoder work this package declines to own.
///
/// The dependency is pure Dart with no native or Flutter part, so it is usable
/// from a plain server isolate.
///
/// ## Why this renderer does not stream
///
/// A PDF ends with a cross-reference table of byte offsets into everything
/// before it, so no conforming writer can emit the first page before the last
/// object is placed. On top of that, how many pages there are — a number the
/// footer prints on the first of them — is only known once every row has been
/// laid out. Both facts point the same way, and neither is a property of the
/// library: PDF is a *random-access* document format, and rendering one costs
/// memory proportional to the result.
///
/// [TomTabularRenderer.streamsRows] is therefore `false` here, and this
/// renderer states its limits rather than discovering them:
///
/// - [rowLimit] caps how many rows it will accept, and it **fails** rather
///   than truncating. A silently shortened report is a wrong report that looks
///   right; an error names the limit and points at CSV or XLSX, which have no
///   such ceiling.
/// - [maxPages] raises `package:pdf`'s own 20-page default, which exists for
///   invoices and would reject any real report.
///
/// ## Text outside Latin-1
///
/// The default is the PDF base-14 Helvetica, which no file has to embed but
/// which can only encode WinAnsi. A result containing Greek, Cyrillic or CJK
/// text needs a real font: build a [pw.ThemeData] over an embedded TTF and pass
/// it as [theme]. This is left to the application because a Unicode font is a
/// megabyte-scale asset and which one is right is a deployment's decision, not
/// the framework's.
///
/// ### The default announces itself, and that is not a leak
///
/// `package:pdf` prints `Helvetica has no Unicode support …` as it builds each
/// document, and the same for `Helvetica-Bold`, because a bold header draws on
/// a second base-14 face. Three things are worth knowing before treating that
/// as log noise to be fixed.
///
/// It is **not a logger call**, so it cannot be silenced the way a logger can:
/// it is a bare `print` inside an `assert` in `PdfType1Font.create`. There is no
/// level to raise and no scope to narrow, and the only interception point is the
/// enclosing [Zone]'s print handler — which would mean string-matching the
/// library's own message, and would swallow every other print the render makes,
/// including the application's. This renderer does not try.
///
/// It is also easy to get wrong in a way that looks right. The font is created
/// while the page is laid out, inside `addPage`, not while the document is
/// serialised — so a zone wrapped around `document.save()`, which is where one
/// would naturally put it, suppresses nothing at all. A suppression has to
/// enclose the whole build, which widens exactly the blast radius that made it
/// a bad idea.
///
/// Sitting inside an `assert` is also why it **cannot reach a deployment**.
/// Assertions are compiled out of a `dart compile exe` binary and of `dart run`
/// without `--enable-asserts`, so the line appears in test runs and in
/// explicitly assert-enabled runs, and nowhere else. It is a developer
/// diagnostic delivered by the only channel a package has before an application
/// has configured a logger.
///
/// And it stops for the reason it exists: pass a [theme] carrying an embedded
/// font and no base-14 face is ever created, so nothing warns. Suppressing it
/// any other way would be suppressing the answer to a question this module has
/// already decided on purpose.
///
/// `test/export_test.dart` pins both halves — that the diagnostic is emitted
/// once per face under assertions, and that a production-shaped run of the
/// example is silent — because this paragraph is a claim about someone else's
/// library and would otherwise rot without anyone noticing.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'tabular_renderer.dart';
import 'tabular_result.dart';

/// Renders a tabular result as a paginated PDF document.
class TomPdfRenderer extends TomTabularRenderer {
  /// Creates a PDF renderer.
  const TomPdfRenderer({
    this.pageFormat = PdfPageFormat.a4,
    this.orientation = pw.PageOrientation.portrait,
    this.rowLimit = 20000,
    this.maxPages = 2000,
    this.baseFontSize = 8,
    this.theme,
    this.compress = true,
    this.chartHeight = 180,
  });

  /// The paper size. A4 by default; use [PdfPageFormat.letter] for US output.
  final PdfPageFormat pageFormat;

  /// Portrait or landscape.
  ///
  /// Worth setting to landscape from about eight columns on: the column count
  /// a table can carry legibly is what decides this, and only the caller knows
  /// how wide its columns really are.
  final pw.PageOrientation orientation;

  /// The largest number of rows, across all sections, this renderer accepts.
  ///
  /// Exceeding it throws a [TomExportException] on the output stream. The
  /// default is chosen to be well inside a server's heap while being far more
  /// than anyone reads on paper.
  final int rowLimit;

  /// The page ceiling handed to `package:pdf`, whose own default is 20.
  final int maxPages;

  /// The body text size in points. Header text is one point larger and bold.
  final double baseFontSize;

  /// An optional theme, typically supplying an embedded Unicode font.
  ///
  /// Supplying one is also the only way to stop `package:pdf`'s base-14
  /// diagnostic, because it stops the base-14 font from being created at all —
  /// see *The default announces itself* in this library's documentation for why
  /// that is the only way, and why the line never reaches a deployment.
  final pw.ThemeData? theme;

  /// Whether to deflate the document's object streams.
  ///
  /// Set `false` to produce a PDF whose text is readable in a hex dump —
  /// useful when debugging output, and what the tests use to assert content.
  final bool compress;

  /// How high a chart is drawn, in points.
  final double chartHeight;

  @override
  String get formatId => 'pdf';

  @override
  String get mediaType => 'application/pdf';

  @override
  String get fileExtension => 'pdf';

  @override
  bool get streamsRows => false;

  @override
  Stream<List<int>> render(TomTabularResult result) async* {
    final sections = await _collect(result);

    final document = pw.Document(
      compress: compress,
      title: result.title,
      theme: theme,
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        orientation: orientation,
        maxPages: maxPages,
        theme: theme,
        header: (context) => _header(context, result),
        footer: _footer,
        build: (context) => _body(result, sections),
      ),
    );
    yield await document.save();
  }

  /// Pulls every section's rows into memory as formatted text.
  ///
  /// Formatting happens here rather than during layout because
  /// `package:pdf` walks its cell data more than once while measuring, and
  /// [tomFormatCellAsText] on a `DateTime` is not free.
  Future<List<_RenderedSection>> _collect(TomTabularResult result) async {
    final sections = <_RenderedSection>[];
    var total = 0;
    for (final section in result.sections) {
      final rows = <List<String>>[];
      final points = <TomTabularRow>[];
      await for (final row in section.rows) {
        total++;
        if (total > rowLimit) {
          throw TomExportException(
            'export.pdf.row_limit_exceeded',
            'The report is too large to render as a PDF.',
            parameters: {'limit': '$rowLimit', 'formats': 'csv, xlsx'},
          );
        }
        rows.add([
          for (var i = 0; i < section.columns.length; i++)
            tomFormatCellAsText(row.cell(i)),
        ]);
        // A chart plots the raw values, not their text: kept only for a
        // section that has one.
        if (section.charts.isNotEmpty) points.add(row);
      }
      sections.add(_RenderedSection(section, rows, points));
    }
    return sections;
  }

  /// The repeated page header: the document title, on continuation pages only.
  ///
  /// The first page carries the title in the body, at full size, above the
  /// metadata block — repeating it in the header there would print it twice.
  pw.Widget _header(pw.Context context, TomTabularResult result) {
    if (context.pageNumber == 1) return pw.SizedBox();
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        result.title,
        style: pw.TextStyle(fontSize: baseFontSize, color: PdfColors.grey700),
      ),
    );
  }

  /// The repeated page footer: `n / total`, right-aligned.
  pw.Widget _footer(pw.Context context) => pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 8),
    child: pw.Text(
      '${context.pageNumber} / ${context.pagesCount}',
      style: pw.TextStyle(fontSize: baseFontSize - 1, color: PdfColors.grey700),
    ),
  );

  /// The document body: title, metadata block, then one table per section.
  List<pw.Widget> _body(
    TomTabularResult result,
    List<_RenderedSection> sections,
  ) {
    final widgets = <pw.Widget>[
      pw.Text(
        result.title,
        style: pw.TextStyle(
          fontSize: baseFontSize + 6,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 6),
    ];
    if (result.metadata.isNotEmpty) {
      widgets
        ..add(_metadataBlock(result.metadata))
        ..add(pw.SizedBox(height: 10));
    }
    for (var i = 0; i < sections.length; i++) {
      if (i > 0) widgets.add(pw.SizedBox(height: 14));
      final title = sections[i].section.title;
      if (title != null) {
        widgets
          ..add(
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: baseFontSize + 2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          )
          ..add(pw.SizedBox(height: 4));
      }
      widgets.add(_table(sections[i]));
      for (final chart in sections[i].section.charts) {
        widgets
          ..add(pw.SizedBox(height: 10))
          ..addAll(_chart(chart, sections[i]));
      }
    }
    return widgets;
  }

  /// About five evenly spaced value-axis ticks from zero (or the lowest
  /// negative value) to the highest value, on a 1-2-5 step.
  static List<double> _ticks(List<double> values) {
    final low = values.fold<double>(0, (a, b) => b < a ? b : a);
    final high = values.fold<double>(0, (a, b) => b > a ? b : a);
    final span = high - low;
    if (span <= 0) return [low, low + 1];
    final rough = span / 5;
    final magnitude = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final step = [
      1,
      2,
      5,
      10,
    ].map((m) => m * magnitude).firstWhere((candidate) => candidate >= rough);
    final first = (low / step).floor() * step;
    return [for (var v = first; v < high + step; v += step) v];
  }

  /// The series colours, in order; a series past the last reuses them.
  static const List<PdfColor> _palette = [
    PdfColors.blue600,
    PdfColors.orange600,
    PdfColors.green600,
    PdfColors.red600,
    PdfColors.purple600,
    PdfColors.teal600,
    PdfColors.amber600,
    PdfColors.brown600,
  ];

  /// [chart] drawn from [rendered]'s rows as vector graphics: its caption, then
  /// the chart in a box [chartHeight] points high.
  List<pw.Widget> _chart(TomTabularChart chart, _RenderedSection rendered) {
    final columns = rendered.section.columns;
    int indexOf(String name) => columns.indexWhere((c) => c.name == name);
    final categoryIndex = indexOf(chart.categoryColumn);
    final labels = [
      for (final row in rendered.points)
        tomFormatCellAsText(row.cell(categoryIndex)),
    ];
    final series = [
      for (final name in chart.valueColumns)
        (
          label: columns[indexOf(name)].label,
          values: [
            for (final row in rendered.points)
              (row.cell(indexOf(name)) as num?)?.toDouble(),
          ],
        ),
    ];
    final textStyle = pw.TextStyle(fontSize: baseFontSize - 1);
    final caption = <pw.Widget>[
      if (chart.title != null) ...[
        pw.Text(
          chart.title!,
          style: pw.TextStyle(
            fontSize: baseFontSize + 1,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
      ],
    ];
    if (labels.isEmpty) return caption;

    final pw.Widget drawn;
    if (chart.type == TomChartType.pie) {
      drawn = pw.Chart(
        grid: pw.PieGrid(),
        datasets: [
          for (var i = 0; i < labels.length; i++)
            if ((series.single.values[i] ?? 0) > 0)
              pw.PieDataSet(
                value: series.single.values[i]!,
                legend: labels[i],
                color: _palette[i % _palette.length],
                legendStyle: textStyle,
              ),
        ],
      );
    } else {
      final values = [for (final s in series) ...s.values.whereType<double>()];
      final barWidth = 24.0 / series.length;
      drawn = pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis.fromStrings(
            labels,
            marginStart: 20,
            marginEnd: 20,
            ticks: true,
            textStyle: textStyle,
          ),
          yAxis: pw.FixedAxis(
            _ticks(values),
            divisions: true,
            textStyle: textStyle,
          ),
        ),
        overlay: series.length > 1
            ? pw.ChartLegend(textStyle: textStyle)
            : null,
        datasets: [
          for (var k = 0; k < series.length; k++)
            if (chart.type == TomChartType.bar)
              pw.BarDataSet(
                legend: series[k].label,
                color: _palette[k % _palette.length],
                width: barWidth,
                offset: (k - (series.length - 1) / 2) * barWidth,
                data: [
                  for (var i = 0; i < labels.length; i++)
                    if (series[k].values[i] case final value?)
                      pw.PointChartValue(i.toDouble(), value),
                ],
              )
            else
              pw.LineDataSet(
                legend: series[k].label,
                color: _palette[k % _palette.length],
                pointSize: 2,
                data: [
                  for (var i = 0; i < labels.length; i++)
                    if (series[k].values[i] case final value?)
                      pw.PointChartValue(i.toDouble(), value),
                ],
              ),
        ],
      );
    }
    return [...caption, pw.SizedBox(height: chartHeight, child: drawn)];
  }

  /// The `name: value` block describing how the result was produced.
  pw.Widget _metadataBlock(Map<String, String> metadata) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final entry in metadata.entries)
        pw.Text(
          '${entry.key}: ${entry.value}',
          style: pw.TextStyle(fontSize: baseFontSize, color: PdfColors.grey800),
        ),
    ],
  );

  /// One section as a bordered table with a repeating header row.
  ///
  /// Columns are laid out by flex, not intrinsically. An intrinsic width is the
  /// width of the longest cell, so one row holding a long free-text value would
  /// push the table past the page edge and clip every other column; flex makes
  /// the text wrap instead.
  ///
  /// The flex factors are the columns' [TomTabularColumn.effectiveWidth]s —
  /// character counts, the same numbers a spreadsheet is written at. A page's
  /// total width is fixed, so the counts cannot be honoured literally; what
  /// survives the fit is their *ratio*, and the ratio is what a reader sees.
  /// A column asking for 24 characters beside one asking for 12 gets twice the
  /// room whatever the paper size, which is the most of an absolute request a
  /// page can keep.
  ///
  /// The characters are deliberately **not** converted to points first. The
  /// conversion is a single factor applied to every column, and flex is scale
  /// invariant, so it would cancel exactly — arithmetic that changes no output
  /// and implies a precision this has no way to deliver.
  ///
  /// What matters far more than the unit is that an unhinted column gets a
  /// factor of its own. It used to get 1, against hints in the twenties, and
  /// the module's own example is what that looked like: `product` at 24 took
  /// seven eighths of the table and `Amount` came down the remaining strip as
  /// `A`, `m`, `ou`, `nt`.
  pw.Widget _table(_RenderedSection rendered) {
    final columns = rendered.section.columns;
    return pw.TableHelper.fromTextArray(
      headers: [for (final column in columns) column.label],
      data: rendered.rows,
      headerStyle: pw.TextStyle(
        fontSize: baseFontSize,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: pw.TextStyle(fontSize: baseFontSize),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      cellAlignments: {
        for (var i = 0; i < columns.length; i++)
          if (_isNumeric(columns[i].type)) i: pw.Alignment.centerRight,
      },
      headerAlignments: {
        for (var i = 0; i < columns.length; i++)
          if (_isNumeric(columns[i].type)) i: pw.Alignment.centerRight,
      },
      columnWidths: {
        for (var i = 0; i < columns.length; i++)
          i: pw.FlexColumnWidth(columns[i].effectiveWidth.toDouble()),
      },
    );
  }

  /// Whether [type] is a number, and so belongs on the right of its cell.
  static bool _isNumeric(TomColumnType type) =>
      type == TomColumnType.integer || type == TomColumnType.decimal;
}

/// One section with its rows already pulled and formatted.
class _RenderedSection {
  _RenderedSection(this.section, this.rows, this.points);

  final TomTabularSection section;
  final List<List<String>> rows;

  /// The raw rows, kept for the section's charts; empty when it has none.
  final List<TomTabularRow> points;
}
