/// The one place this package decides where a SQL quoted run ends, and where
/// one statement ends and the next begins.
///
/// Every consumer that walks migration or DDL text — the applier that sends a
/// script statement by statement, the reader that parses a schema out of it,
/// the comment stripper, the comma splitter — needs the same answer to the same
/// question: *is this character inside a quoted run?* Getting it wrong does not
/// fail loudly. It cuts a statement in half inside a string literal and sends a
/// syntactically broken fragment to the server, or it swallows a closing quote
/// and glues two statements into one.
///
/// Answered separately by each of them, it comes out five different ways — five
/// hand-rolled scanners, no two agreeing with each other **or** with the
/// server. So the scan lives here once, in [endOfQuotedRun], and everything
/// else is written on top of it.
library;

/// Lexing primitives shared by every consumer of raw SQL text in this module.
///
/// ## Escaping, as MariaDB actually does it
///
/// The rules are not uniform across the three quote characters, which is where
/// a hand-rolled copy goes wrong — each one in a different place:
///
/// | Quote | `''` doubling | `\'` backslash |
/// | ----- | ------------- | -------------- |
/// | `'` string literal | yes | yes |
/// | `"` string literal | yes | yes |
/// | `` ` `` identifier | yes | **no** |
///
/// A backslash is an ordinary character inside a backtick-quoted identifier:
/// ``CREATE TABLE `bs\` (id INT)`` creates a table genuinely named ``bs\`` and
/// terminates at that second backtick. A scanner that treats the backslash as
/// an escape there swallows the closing backtick and runs on into the next
/// statement.
///
/// Both backslash columns assume the server's default `sql_mode` — that is,
/// `NO_BACKSLASH_ESCAPES` off. That is the mode migrations run under; a schema
/// that enables it would need this table revisited.
class TomSqlLexer {
  /// The three characters that open a quoted run.
  static const String quoteCharacters = '\'"`';

  /// The index of the closing quote of the run opened at [openIndex], or
  /// `sql.length - 1` when the run is never closed.
  ///
  /// [openIndex] must be the index of an opening quote character. The result is
  /// the index of the character that closes it, so a caller copying the run
  /// verbatim copies `openIndex .. result` inclusive and resumes at
  /// `result + 1`.
  ///
  /// A doubled quote (`''`) does not close the run — it is one escaped quote
  /// and the scan continues. A backslash escapes the character after it and so
  /// cannot close the run either, but **only** in a string literal; inside a
  /// backtick identifier a backslash is an ordinary character. See the class
  /// docs for why that asymmetry is real rather than an oversight.
  ///
  /// The doubling rule is load-bearing for *this* function's contract but not,
  /// as it happens, for any current caller's output: a doubled quote
  /// contributes two quote characters, so a scanner that stopped at the first
  /// would immediately reopen at the second and mark exactly the same span as
  /// quoted. It is kept — and pinned by a direct unit test rather than through a
  /// splitter — because the documented result is "the index that closes the
  /// run", and a caller that used the index for anything but resuming the scan
  /// would be handed the index of an *escaped* quote.
  ///
  /// An unterminated run reports the end of the input rather than throwing.
  /// This is a lexer, not a validator: a caller splitting statements should
  /// hand the malformed tail to the server and let it produce the syntax error,
  /// which says far more than anything this function could.
  ///
  /// [backslashEscapes] is the database's literal rule: MariaDB's default mode
  /// escapes with a backslash, PostgreSQL does not — `'C:\'` is a complete
  /// literal there.
  static int endOfQuotedRun(
    String sql,
    int openIndex, {
    bool backslashEscapes = true,
  }) {
    final quote = sql[openIndex];
    // Backslash escapes apply to string literals only, never to identifiers.
    final escapes = backslashEscapes && quote != '`';
    for (var i = openIndex + 1; i < sql.length; i++) {
      final c = sql[i];
      if (escapes && c == r'\' && i + 1 < sql.length) {
        i++; // whatever follows is escaped, including a quote
        continue;
      }
      if (c == quote) {
        // A doubled quote is an escaped quote: stay inside and skip both.
        if (i + 1 < sql.length && sql[i + 1] == quote) {
          i++;
          continue;
        }
        return i;
      }
    }
    return sql.length - 1;
  }

  /// The index of the last character of the comment starting at [startIndex],
  /// or `sql.length - 1` when it runs to the end of the input.
  ///
  /// [startIndex] must be the index of a character that opens a comment, as
  /// reported by [commentOpensAt]. A line comment (`-- …`, `# …`) ends at the
  /// character before its newline, so the newline itself survives for the
  /// caller to treat as ordinary text; a block comment (`/* … */`) ends at its
  /// closing slash.
  static int endOfComment(String sql, int startIndex) {
    if (sql[startIndex] == '/') {
      final close = sql.indexOf('*/', startIndex + 2);
      return close < 0 ? sql.length - 1 : close + 1;
    }
    final newline = sql.indexOf('\n', startIndex);
    return newline < 0 ? sql.length - 1 : newline - 1;
  }

  /// Whether a comment opens at [index] — `--`, `#` or `/*`.
  ///
  /// Only meaningful outside a quoted run; `'-- not a comment'` is a string.
  static bool commentOpensAt(String sql, int index) {
    final c = sql[index];
    if (c == '#') return true;
    final next = index + 1 < sql.length ? sql[index + 1] : '';
    return (c == '-' && next == '-') || (c == '/' && next == '*');
  }

  /// Splits [sql] into its individual statements on unquoted, uncommented
  /// semicolons, preserving each statement's text as written.
  ///
  /// Statements come back trimmed, and whitespace-only fragments are dropped —
  /// so a script ending in `;` yields no empty tail entry, and a script that is
  /// nothing but whitespace yields an empty list.
  ///
  /// **Comments are kept.** They are not noise that can be discarded on the way
  /// to the server: `/*!40101 SET NAMES utf8 */` is a MariaDB *executable*
  /// comment — real, version-gated SQL — and stripping it would silently drop a
  /// statement a migration author wrote. A consumer that genuinely wants
  /// comments gone (a parser, say) strips them explicitly first; see
  /// `TomSchemaDdlReader.splitStatements`.
  ///
  /// Splitting matters beyond tidiness: the underlying `mysql_client` only
  /// half-reads a multi-statement command, consuming the first result set and
  /// leaving the rest, which desyncs the shared connection so every later read
  /// returns stale data.
  ///
  /// [backslashEscapes] is the database's literal rule — see
  /// [endOfQuotedRun]; a caller holding a dialect passes its
  /// `TomStandardSqlDialect.backslashEscapes`.
  static List<String> splitStatements(
    String sql, {
    bool backslashEscapes = true,
  }) {
    final statements = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < sql.length; i++) {
      final ch = sql[i];

      if (commentOpensAt(sql, i)) {
        final end = endOfComment(sql, i);
        buffer.write(sql.substring(i, end + 1));
        i = end;
        continue;
      }
      if (quoteCharacters.contains(ch)) {
        final end = endOfQuotedRun(sql, i, backslashEscapes: backslashEscapes);
        buffer.write(sql.substring(i, end + 1));
        i = end;
        continue;
      }
      if (ch == ';') {
        final statement = buffer.toString().trim();
        if (statement.isNotEmpty) statements.add(statement);
        buffer.clear();
        continue;
      }
      buffer.write(ch);
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) statements.add(tail);
    return statements;
  }
}
