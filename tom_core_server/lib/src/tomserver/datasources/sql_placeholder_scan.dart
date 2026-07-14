/// Quote-aware scan of `:name` parameter placeholders in generated SQL.
///
/// The object-persistence query builder renders bound parameters as `:name`
/// (see `TomStandardSqlDialect.p`) and inlines string literals with the
/// dialect's escaping (`TomStandardSqlDialect.text` doubles single quotes and
/// backslashes). Two consumers translate that `:name` text: the MariaDB
/// datasource rewrites each placeholder to a positional `?`
/// (`MariaDbDatasource.toPositionalStatement`) and the CRUD repository extracts
/// the placeholder names to bind a raw statement
/// (`_extractPlaceholderNames`).
///
/// Both used to scan with `RegExp(r':([A-Za-z_][A-Za-z0-9_]*)')`, which has no
/// notion of string-literal context — a `:identifier`-looking substring *inside*
/// an inlined literal (e.g. `WHERE a = 'x:y' AND b = :p`) was mis-tokenised into
/// a spurious slot, desynchronising every following positional bind (RCC6).
///
/// This is the single implementation both consumers share. It walks the SQL
/// character by character, copying the contents of single- or double-quoted
/// string literals verbatim, and only recognises a `:name` placeholder in
/// ordinary (outside-literal) text. Inside a literal both escape conventions the
/// dialect can emit are honoured: a backslash escapes the next character
/// (MariaDB's default mode) and a doubled delimiter (`''` / `""`) is an escaped
/// delimiter that keeps the scan inside the literal.
class SqlPlaceholderScan {
  SqlPlaceholderScan._();

  static const int _colon = 0x3A; // :
  static const int _singleQuote = 0x27; // '
  static const int _doubleQuote = 0x22; // "
  static const int _backslash = 0x5C; // \
  static const int _underscore = 0x5F; // _
  static const int _zero = 0x30; // 0
  static const int _nine = 0x39; // 9
  static const int _upperA = 0x41; // A
  static const int _upperZ = 0x5A; // Z
  static const int _lowerA = 0x61; // a
  static const int _lowerZ = 0x7A; // z

  /// Rewrites every outside-of-literal `:name` placeholder in [namedSql] to a
  /// positional `?`, returning the rewritten SQL and the placeholder names in
  /// the exact left-to-right order the `?` slots appear (repeats included).
  ///
  /// Content inside string literals is copied verbatim, so a `:name`-looking
  /// substring there never becomes a slot.
  static (String, List<String>) toPositional(String namedSql) {
    final names = <String>[];
    final out = StringBuffer();
    final length = namedSql.length;
    var i = 0;
    while (i < length) {
      final c = namedSql.codeUnitAt(i);
      if (c == _singleQuote || c == _doubleQuote) {
        i = _copyLiteral(namedSql, i, c, out);
        continue;
      }
      if (c == _colon &&
          i + 1 < length &&
          _isIdentifierStart(namedSql.codeUnitAt(i + 1))) {
        var j = i + 1;
        while (j < length && _isIdentifierPart(namedSql.codeUnitAt(j))) {
          j++;
        }
        names.add(namedSql.substring(i + 1, j));
        out.write('?');
        i = j;
        continue;
      }
      out.writeCharCode(c);
      i++;
    }
    return (out.toString(), names);
  }

  /// The placeholder names in [namedSql] in textual order (repeats included),
  /// skipping any `:name`-looking substring inside a string literal.
  ///
  /// Equivalent to `toPositional(namedSql).$2`; the positional rewrite is
  /// discarded. Used by the CRUD repository, which binds names to a raw
  /// statement rather than rewriting the SQL.
  static List<String> extractNames(String namedSql) => toPositional(namedSql).$2;

  /// Copies the string literal that opens at [start] (its delimiter is [quote])
  /// into [out] verbatim, returning the index just past the closing delimiter.
  ///
  /// A backslash escapes the following character; a doubled delimiter is an
  /// escaped delimiter that stays inside the literal. An unterminated literal
  /// (which balanced generated SQL never produces) is copied to the end.
  static int _copyLiteral(String sql, int start, int quote, StringBuffer out) {
    final length = sql.length;
    out.writeCharCode(quote); // opening delimiter
    var i = start + 1;
    while (i < length) {
      final c = sql.codeUnitAt(i);
      if (c == _backslash && i + 1 < length) {
        out.writeCharCode(c);
        out.writeCharCode(sql.codeUnitAt(i + 1));
        i += 2;
        continue;
      }
      if (c == quote) {
        if (i + 1 < length && sql.codeUnitAt(i + 1) == quote) {
          // Doubled delimiter: an escaped quote that stays inside the literal.
          out.writeCharCode(quote);
          out.writeCharCode(quote);
          i += 2;
          continue;
        }
        out.writeCharCode(quote); // closing delimiter
        return i + 1;
      }
      out.writeCharCode(c);
      i++;
    }
    return i;
  }

  static bool _isIdentifierStart(int c) =>
      c == _underscore ||
      (c >= _upperA && c <= _upperZ) ||
      (c >= _lowerA && c <= _lowerZ);

  static bool _isIdentifierPart(int c) =>
      _isIdentifierStart(c) || (c >= _zero && c <= _nine);
}
