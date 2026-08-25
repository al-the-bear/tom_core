/// CSV rendering: the baseline format, and the one that must always work.
///
/// CSV is the format with no optional parts. It has no dependency, no document
/// structure to close, and no failure mode more interesting than a quoting bug
/// — so it is the renderer everything else is compared against, and the one an
/// application can always fall back to when a richer format is unavailable.
///
/// ## Why no CSV package
///
/// `package:csv` (MIT) was evaluated and not adopted. Its `ListToCsvConverter`
/// takes a `List<List<dynamic>>` and returns a `String`: it materialises both
/// the input rows and the whole output document, which is precisely the shape
/// [TomTabularRenderer] exists to avoid. Writing RFC 4180 quoting directly is
/// about fifteen lines, and it keeps the always-must-work format free of any
/// dependency that could fail to resolve.
///
/// ## What it emits
///
/// RFC 4180 with two deliberate settlements:
///
/// - **CRLF line endings**, as RFC 4180 requires. Every consumer accepts them;
///   Excel on Windows is unhappy without them.
/// - **A UTF-8 byte-order mark, by default.** Excel reads a BOM-less UTF-8 CSV
///   in the system codepage and mangles every non-ASCII character in it. The
///   BOM is the difference between an export that opens correctly by
///   double-click and one that needs an import wizard. Set
///   [TomCsvRenderer.byteOrderMark] to `false` for pipelines that parse the
///   file rather than open it.
///
/// Multi-section results are concatenated with a blank line and the section
/// title between them. CSV has no notion of a sheet, so this is a convention
/// rather than a format feature — a result with more than one section is better
/// served by XLSX, and this behaviour exists so that asking for CSV anyway
/// produces something rather than an error.
library;

import 'dart:async';
import 'dart:convert';

import 'tabular_renderer.dart';
import 'tabular_result.dart';

/// Renders a tabular result as RFC 4180 CSV, one row at a time.
class TomCsvRenderer extends TomTabularRenderer {
  /// Creates a CSV renderer.
  const TomCsvRenderer({this.fieldSeparator = ',', this.byteOrderMark = true});

  /// The character between fields. `,` by default; `;` for locales that use
  /// the comma as a decimal separator and whose spreadsheet defaults follow.
  final String fieldSeparator;

  /// Whether to emit a UTF-8 BOM before the first row.
  final bool byteOrderMark;

  @override
  String get formatId => 'csv';

  @override
  String get mediaType => 'text/csv; charset=utf-8';

  @override
  String get fileExtension => 'csv';

  @override
  Stream<List<int>> render(TomTabularResult result) async* {
    if (byteOrderMark) {
      yield const [0xEF, 0xBB, 0xBF];
    }
    var first = true;
    for (final section in result.sections) {
      if (!first) {
        // A blank line, so a reader that splits on it sees two tables rather
        // than one table with a stray header in the middle.
        yield utf8.encode('\r\n');
      }
      first = false;
      final title = section.title;
      if (title != null && result.sections.length > 1) {
        yield utf8.encode('${_escape(title)}\r\n');
      }
      yield utf8.encode(
        '${section.columns.map((c) => _escape(c.label)).join(fieldSeparator)}'
        '\r\n',
      );
      await for (final row in section.rows) {
        final buffer = StringBuffer();
        for (var i = 0; i < section.columns.length; i++) {
          if (i > 0) buffer.write(fieldSeparator);
          final value = row.cell(i);
          buffer.write(
            _escape(
              tomFormatCellAsText(value),
              guardFormula: _mayCarryFormula(value),
            ),
          );
        }
        buffer.write('\r\n');
        yield utf8.encode(buffer.toString());
      }
    }
  }

  /// Whether [value] could reach the file as an expression someone else wrote.
  ///
  /// The formula guard costs something — a guarded field is quoted and
  /// tab-prefixed, and a spreadsheet reads that as *text*. Applying it to a
  /// number turns a financial column into strings: totals stop summing and
  /// sorting turns lexical, while the value still looks right on screen. So the
  /// guard has to be applied to the cells that can carry a formula and no
  /// others.
  ///
  /// [tomFormatCellAsText] decides that set. `null`, [DateTime], [num] and
  /// [bool] each have a formatting branch that can only produce a literal — a
  /// `-` in front of a [num] is a minus sign, never an operator. Every other
  /// value falls through to `toString()`, whose output is whatever the object
  /// chose to return, so it is guarded.
  ///
  /// This tests the *value*, not the column type. A [String] landing in a
  /// numeric column is a mismatch the renderers tolerate rather than reject
  /// (see [tomFormatCellAsText]), so a column-type test would emit `=1+1` from
  /// an integer column unguarded — the exact payload the guard exists to stop.
  static bool _mayCarryFormula(Object? value) =>
      value != null && value is! num && value is! bool && value is! DateTime;

  /// Quotes [field] when RFC 4180 requires it, doubling any embedded quote.
  ///
  /// When [guardFormula] is true, a leading `=`, `+`, `-` or `@` is also quoted
  /// *and prefixed with a tab*: spreadsheets treat such a field as a formula,
  /// which is how an exported value someone else supplied becomes code
  /// executing on the machine that opens the file. Quoting alone does not stop
  /// it; the tab does, and is stripped on display.
  ///
  /// Callers pass `guardFormula: false` for text they produced themselves —
  /// currently only the formatting of a cell whose value cannot be an
  /// expression, per [_mayCarryFormula]. Section titles and column labels are
  /// always guarded: they are strings the caller supplied, so they are as
  /// untrusted as any cell.
  String _escape(String field, {bool guardFormula = true}) {
    final injectable =
        guardFormula && field.isNotEmpty && '=+-@'.contains(field[0]);
    final escaped = field.replaceAll('"', '""');
    final needsQuotes =
        injectable ||
        escaped != field ||
        field.contains(fieldSeparator) ||
        field.contains('\n') ||
        field.contains('\r');
    if (!needsQuotes) return field;
    return injectable ? '"\t$escaped"' : '"$escaped"';
  }
}
