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
  const TomCsvRenderer({
    this.fieldSeparator = ',',
    this.byteOrderMark = true,
  });

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
          buffer.write(_escape(tomFormatCellAsText(row.cell(i))));
        }
        buffer.write('\r\n');
        yield utf8.encode(buffer.toString());
      }
    }
  }

  /// Quotes [field] when RFC 4180 requires it, doubling any embedded quote.
  ///
  /// A leading `=`, `+`, `-` or `@` is also quoted *and prefixed with a tab*:
  /// spreadsheets treat such a field as a formula, which is how an exported
  /// value someone else supplied becomes code executing on the machine that
  /// opens the file. Quoting alone does not stop it; the tab does, and is
  /// stripped on display.
  String _escape(String field) {
    final injectable = field.isNotEmpty && '=+-@'.contains(field[0]);
    final escaped = field.replaceAll('"', '""');
    final needsQuotes = injectable ||
        escaped != field ||
        field.contains(fieldSeparator) ||
        field.contains('\n') ||
        field.contains('\r');
    if (!needsQuotes) return field;
    return injectable ? '"\t$escaped"' : '"$escaped"';
  }
}
