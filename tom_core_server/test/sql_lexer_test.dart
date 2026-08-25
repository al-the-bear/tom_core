import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for [TomSqlLexer], the one place this package decides where a quoted
/// run ends and where one statement ends and the next begins.
///
/// The scan used to be hand-rolled five times over — once in the migration
/// applier, four times in the DDL reader — and no two copies agreed. Each was
/// wrong exactly where the other was right: the applier handled a backslash
/// inside a backtick identifier correctly and mishandled one inside a string
/// literal, and the reader did the reverse. The matrix below is therefore not
/// decoration; it is the whole point of the consolidation, and it is asserted
/// against the semantics a real MariaDB server was observed to have:
///
/// | Quote | `''` doubling | `\'` backslash |
/// | ----- | ------------- | -------------- |
/// | `'` string literal | yes | yes |
/// | `"` string literal | yes | yes |
/// | `` ` `` identifier | yes | **no** |
///
/// The asymmetry is real: ``CREATE TABLE `bs\` (id INT)`` executes and creates
/// a table literally named ``bs\``, so a scanner that treats the backslash as an
/// escape there swallows the closing backtick and welds the statement to the
/// next one.
void main() {
  // A multi-statement migration script must be split into individual statements
  // before it is sent. The underlying mysql_client only half-reads a
  // multi-statement command — it consumes the first result set and leaves the
  // rest, desyncing the single shared connection so every later read returns
  // stale data (a first-boot seed sees an empty users table even though the
  // migration committed its rows). These tests pin that splitter.
  group('TomSqlLexer.splitStatements', () {
    test('splits a multi-statement script into its statements', () {
      const sql =
          'CREATE TABLE a (id INT);\n'
          'CREATE TABLE b (id INT);\n'
          'INSERT INTO a VALUES (1);';
      expect(TomSqlLexer.splitStatements(sql), [
        'CREATE TABLE a (id INT)',
        'CREATE TABLE b (id INT)',
        'INSERT INTO a VALUES (1)',
      ]);
    });

    test('returns the single statement for a single-statement script', () {
      expect(TomSqlLexer.splitStatements('SELECT 1;'), ['SELECT 1']);
    });

    test('drops the empty tail after a trailing semicolon', () {
      expect(TomSqlLexer.splitStatements('SELECT 1;\n\n'), ['SELECT 1']);
    });

    test('returns an empty list for a whitespace-only script', () {
      expect(TomSqlLexer.splitStatements('  \n\t '), isEmpty);
    });

    test('keeps the tail of a script with no trailing semicolon', () {
      expect(TomSqlLexer.splitStatements('SELECT 1;\nSELECT 2'), [
        'SELECT 1',
        'SELECT 2',
      ]);
    });
  });

  // The escape matrix, as one table rather than a list of hand-written cases.
  //
  // A table because the matrix has to be asserted against *every* splitter this
  // package builds on the lexer, and a splitter with its own copy of the cases
  // is a splitter whose copy can fall behind. That is not hypothetical: it is
  // the shape of the original defect. Five hand-rolled scanners each had their
  // own idea of the rules and their own tests, so each stayed green while
  // disagreeing with the others (tcinc476).
  //
  // Every case is a semicolon that must NOT split, because that is the
  // observable consequence of getting a cell wrong: a scanner that loses track
  // of the quoted run treats the literal's semicolon as a statement boundary
  // and cuts the statement in half.
  for (final splitter in _splitters) {
    group('${splitter.name} escape matrix', () {
      for (final escapeCase in _escapeMatrix) {
        test(escapeCase.description, () {
          expect(
            splitter.split(escapeCase.sql),
            splitter.expectationOf(escapeCase),
            reason:
                'the ${splitter.name} splitter disagrees with the lexer about '
                '${escapeCase.description}. Every splitter in this package is '
                'built on TomSqlLexer.endOfQuotedRun precisely so it cannot; a '
                'failure here means one of them has grown its own scan again.',
          );
        });
      }
    });
  }

  // The third consumer of endOfQuotedRun, and the reason this file rather than
  // the reader's own test file is where the matrix lives.
  //
  // splitTopLevel is not a statement splitter — it cuts a CREATE TABLE body on
  // its top-level commas, so `DECIMAL(10, 2)` stays one entry — but it asks the
  // lexer the same question and can get the same answer wrong. Its own tests
  // cover a backslash inside an identifier, which happens to pin the
  // over-escaping direction; nothing pinned the under-escaping one, and a
  // splitTopLevel rewritten to scan naively passed the entire package.
  //
  // The cases are separate from _escapeMatrix because the input shape is
  // different — a column list, not a script — and forcing one table to serve
  // both would mean a column of nulls. What is shared is the vocabulary and the
  // rule being asserted.
  group('TomSchemaDdlReader.splitTopLevel escape matrix', () {
    for (final commaCase in _topLevelMatrix) {
      test(commaCase.description, () {
        expect(
          TomSchemaDdlReader.splitTopLevel(commaCase.text),
          commaCase.parts,
          reason:
              'splitTopLevel disagrees with the lexer about '
              '${commaCase.description}. A comma inside a quoted run is part of '
              'the run, and treating it as a separator silently splits one '
              'column definition into two.',
        );
      });
    }
  });

  // The table earns its keep only if it is complete, and "complete" is a
  // property of the matrix in the class docs — three quote characters times the
  // two escape forms MariaDB recognises. A cell quietly dropped while
  // refactoring would take its coverage with it and nothing else would notice,
  // so the shape of the table is asserted rather than assumed.
  group('the escape matrix covers every cell', () {
    test('every quote character appears with both escape forms', () {
      for (final quote in const ['\'', '"', '`']) {
        for (final form in _EscapeForm.values) {
          expect(
            _escapeMatrix.any((c) => c.quote == quote && c.form == form),
            isTrue,
            reason:
                'no case covers $form inside $quote, so a splitter could get '
                'that cell wrong and stay green',
          );
        }
      }
    });

    test('the comma splitter is held to the same six cells', () {
      for (final quote in const ['\'', '"', '`']) {
        for (final form in _EscapeForm.values) {
          expect(
            _topLevelMatrix.any((c) => c.quote == quote && c.form == form),
            isTrue,
            reason:
                'no splitTopLevel case covers $form inside $quote. It is the '
                'third consumer of endOfQuotedRun and gets nothing from the '
                'statement table above, so a cell missing here is a cell '
                'genuinely untested.',
          );
        }
      }
    });

    test('both splitters are asserted, not just the lexer', () {
      expect(
        _splitters.map((s) => s.name),
        containsAll(<String>['TomSqlLexer', 'TomSchemaDdlReader']),
        reason:
            'the reader composes the lexer with stripComments, which walks the '
            'text a second time. A table asserted against the lexer alone '
            'leaves that second walk uncovered — it was, and a stripComments '
            'that re-hand-rolled the scan passed the whole suite.',
      );
    });

    // Running the table against the reader is not the same as testing the
    // reader. Its extra walk only becomes observable when a misparse moves a
    // comment marker across a quoted-run boundary, so a case with no marker
    // exercises the reader without being able to fail it. This is the guard on
    // that distinction, and it is here because the first version of this table
    // did not have it and was vacuous for the reader in all nine cases.
    test('a backslash case per quote character can fail the reader', () {
      for (final quote in const ['\'', '"', '`']) {
        expect(
          _escapeMatrix.any(
            (c) =>
                c.quote == quote &&
                c.form == _EscapeForm.backslash &&
                _commentMarker.hasMatch(c.sql),
          ),
          isTrue,
          reason:
              'no case combines a backslash inside $quote with a comment '
              'marker, so stripComments could lose that run and this table '
              'would still pass — it copies quoted text through verbatim, and '
              'a marker is the only way to see where it thinks the run ended',
        );
      }
    });
  });

  group('TomSqlLexer comment handling', () {
    test('a semicolon inside a line comment does not split', () {
      const sql = 'SELECT 1; -- a comment with ; inside\nSELECT 2;';
      expect(TomSqlLexer.splitStatements(sql), [
        'SELECT 1',
        '-- a comment with ; inside\nSELECT 2',
      ]);
    });

    test('a semicolon inside a hash comment does not split', () {
      const sql = 'SELECT 1; # a comment with ; inside\nSELECT 2;';
      expect(TomSqlLexer.splitStatements(sql), [
        'SELECT 1',
        '# a comment with ; inside\nSELECT 2',
      ]);
    });

    test('a semicolon inside a block comment does not split', () {
      const sql = 'SELECT 1 /* ; not a split */ ;\nSELECT 2;';
      expect(TomSqlLexer.splitStatements(sql), [
        'SELECT 1 /* ; not a split */',
        'SELECT 2',
      ]);
    });

    // A MariaDB executable comment is version-gated SQL, not a remark. Dropping
    // it silently removes a statement the migration author wrote, so the
    // splitter — whose output is *sent to the server* — must preserve it
    // verbatim. Stripping is a separate, opt-in step
    // (`TomSchemaDdlReader.stripComments`) for consumers that parse instead.
    test('an executable comment survives the split verbatim', () {
      const sql = '/*!40101 SET NAMES utf8 */;\nSELECT 1;';
      expect(TomSqlLexer.splitStatements(sql), [
        '/*!40101 SET NAMES utf8 */',
        'SELECT 1',
      ]);
    });

    test('a comment marker inside a literal is not a comment', () {
      const sql = "SELECT '-- not a comment; really';\nSELECT 2;";
      expect(TomSqlLexer.splitStatements(sql), [
        "SELECT '-- not a comment; really'",
        'SELECT 2',
      ]);
    });
  });

  group('TomSqlLexer.endOfQuotedRun', () {
    test('reports the index of the closing quote', () {
      const sql = "a 'bc' d";
      expect(TomSqlLexer.endOfQuotedRun(sql, 2), 5);
    });

    // This is the *only* discriminating assertion for the doubling rule.
    // Removing the rule from `endOfQuotedRun` leaves every splitStatements case
    // green, because a doubled quote is two quote characters: a scanner that
    // stopped at the first would reopen at the second and mark the same span.
    // The rule still has to hold, since the documented result is the index that
    // closes the run — so it is pinned here, directly, rather than through a
    // splitter that cannot see the difference.
    test('skips past a doubled quote to the real close', () {
      const sql = "'a''b'";
      expect(TomSqlLexer.endOfQuotedRun(sql, 0), 5);
    });

    test('skips past a backslashed quote in a literal', () {
      const sql = "'a\\'b'";
      expect(TomSqlLexer.endOfQuotedRun(sql, 0), 5);
    });

    test('does not skip past a backslash in an identifier', () {
      const sql = '`a\\` b';
      expect(TomSqlLexer.endOfQuotedRun(sql, 0), 3);
    });

    // Deliberately not an exception: this is a lexer, not a validator. A caller
    // splitting statements hands the malformed tail to the server, whose syntax
    // error says far more than anything raised here could.
    test('reports the end of input for an unterminated run', () {
      const sql = "SELECT 'unterminated";
      expect(TomSqlLexer.endOfQuotedRun(sql, 7), sql.length - 1);
    });
  });
}

/// The three comment openers MariaDB recognises.
///
/// Used to tell a case that can fail the reader from one that merely runs
/// against it — see `a backslash case per quote character can fail the reader`.
final RegExp _commentMarker = RegExp(r'--|#|/\*');

/// The two ways MariaDB lets a quote character appear inside its own quoted run.
enum _EscapeForm {
  /// The quote written twice — `''`. Recognised in all three quote characters.
  doubled,

  /// A leading backslash — `\'`. Recognised in string literals only; inside a
  /// backtick identifier a backslash is an ordinary character.
  backslash;

  @override
  String toString() => switch (this) {
    _EscapeForm.doubled => 'a doubled quote',
    _EscapeForm.backslash => 'a backslash escape',
  };
}

/// One cell of the escape matrix: a script whose semicolon sits inside a quoted
/// run, and the statements each splitter must produce from it.
class _EscapeCase {
  const _EscapeCase({
    required this.description,
    required this.quote,
    required this.form,
    required this.sql,
    required this.statements,
    List<String>? readerStatements,
  }) : _readerStatements = readerStatements;

  /// What the case establishes, used as the test name.
  final String description;

  /// The quote character whose run holds the semicolon.
  final String quote;

  /// The escape form exercised inside that run.
  final _EscapeForm form;

  /// The script to split.
  final String sql;

  /// The statements [TomSqlLexer.splitStatements] must yield.
  final List<String> statements;

  final List<String>? _readerStatements;

  /// The statements `TomSchemaDdlReader.splitStatements` must yield.
  ///
  /// Usually identical, and defaulted accordingly: the point of the shared
  /// table is that a quoted run is a quoted run whoever is looking at it.
  ///
  /// It differs for exactly one reason, and the difference is a feature rather
  /// than a tolerance. The reader strips comments before splitting because it
  /// parses structure; the lexer keeps them because its output is *sent*, and a
  /// MariaDB executable comment (`/*!40101 … */`) is version-gated SQL that
  /// would be silently dropped. So a case carrying a comment **outside** any
  /// quoted run must state both expectations. A case whose comment marker sits
  /// **inside** a run states one, and that is the whole assertion: neither
  /// splitter may see a comment there at all.
  List<String> get expectedFor => _readerStatements ?? statements;
}

/// A splitter this package builds on [TomSqlLexer], under test as a unit.
class _Splitter {
  const _Splitter(this.name, this.split, this.expectationOf);

  /// The type that owns the splitter, used as the group name.
  final String name;

  /// The splitter itself.
  final List<String> Function(String sql) split;

  /// The expectation from [escapeCase] that applies to this splitter.
  final List<String> Function(_EscapeCase escapeCase) expectationOf;
}

/// Every splitter that has to agree with the lexer about where a quoted run
/// ends.
///
/// The reader's is not a redundant entry. It is
/// `TomSqlLexer.splitStatements(stripComments(sql))`, and `stripComments` walks
/// the text a second time with its own loop — so it can lose a quoted run
/// before the splitter ever sees one. Only comment-free cases can be shared
/// between the two, which is why the matrix holds none: the reader strips an
/// executable `/*!40101 … */` that the lexer is required to keep, and that
/// difference is deliberate and tested separately.
final List<_Splitter> _splitters = [
  _Splitter(
    'TomSqlLexer',
    TomSqlLexer.splitStatements,
    (escapeCase) => escapeCase.statements,
  ),
  _Splitter(
    'TomSchemaDdlReader',
    TomSchemaDdlReader.splitStatements,
    (escapeCase) => escapeCase.expectedFor,
  ),
];

/// The escape matrix: three quote characters, each with a plain semicolon, a
/// doubled-quote escape and a backslash.
///
/// The backtick row is where the two historical scanners disagreed, and it is
/// the one cell whose expected behaviour is *not* "the backslash escapes":
/// ``CREATE TABLE `bs\` (id INT)`` creates a table genuinely named ``bs\``, so
/// the very next backtick closes the run. A scanner that escapes there swallows
/// the closing backtick and welds the following statement onto this one.
const List<_EscapeCase> _escapeMatrix = [
  _EscapeCase(
    description: "a semicolon inside a ' literal does not split",
    quote: "'",
    form: _EscapeForm.doubled,
    sql: "INSERT INTO t (s) VALUES ('a;b');\nSELECT 1;",
    statements: ["INSERT INTO t (s) VALUES ('a;b')", 'SELECT 1'],
  ),
  _EscapeCase(
    description: "a doubled quote inside a ' literal is an escaped quote",
    quote: "'",
    form: _EscapeForm.doubled,
    sql: "INSERT INTO t (s) VALUES ('it''s; ok');\nSELECT 2;",
    statements: ["INSERT INTO t (s) VALUES ('it''s; ok')", 'SELECT 2'],
  ),
  _EscapeCase(
    description: "a backslashed quote inside a ' literal is an escaped quote",
    quote: "'",
    form: _EscapeForm.backslash,
    sql: "INSERT INTO t (s) VALUES ('it\\'s; ok');\nSELECT 2;",
    statements: ["INSERT INTO t (s) VALUES ('it\\'s; ok')", 'SELECT 2'],
  ),
  _EscapeCase(
    description: 'a semicolon inside a " literal does not split',
    quote: '"',
    form: _EscapeForm.doubled,
    sql: 'INSERT INTO t (s) VALUES ("a;b");\nSELECT 1;',
    statements: ['INSERT INTO t (s) VALUES ("a;b")', 'SELECT 1'],
  ),
  _EscapeCase(
    description: 'a doubled quote inside a " literal is an escaped quote',
    quote: '"',
    form: _EscapeForm.doubled,
    sql: 'INSERT INTO t (s) VALUES ("a"";b");\nSELECT 2;',
    statements: ['INSERT INTO t (s) VALUES ("a"";b")', 'SELECT 2'],
  ),
  _EscapeCase(
    description: 'a backslashed quote inside a " literal is an escaped quote',
    quote: '"',
    form: _EscapeForm.backslash,
    sql: 'INSERT INTO t (s) VALUES ("a\\";b");\nSELECT 2;',
    statements: ['INSERT INTO t (s) VALUES ("a\\";b")', 'SELECT 2'],
  ),
  _EscapeCase(
    description: 'a semicolon inside a backtick identifier does not split',
    quote: '`',
    form: _EscapeForm.doubled,
    sql: 'CREATE TABLE `weird;name` (id INT);\nSELECT 3;',
    statements: ['CREATE TABLE `weird;name` (id INT)', 'SELECT 3'],
  ),
  _EscapeCase(
    description:
        'a doubled backtick inside an identifier is an escaped '
        'backtick',
    quote: '`',
    form: _EscapeForm.doubled,
    sql: 'CREATE TABLE `we``ird;name` (id INT);\nSELECT 3;',
    statements: ['CREATE TABLE `we``ird;name` (id INT)', 'SELECT 3'],
  ),
  _EscapeCase(
    description:
        'a backslash inside a backtick identifier is an ordinary '
        'character',
    quote: '`',
    form: _EscapeForm.backslash,
    sql: 'CREATE TABLE `bs\\` (id INT);\nSELECT 1;',
    statements: ['CREATE TABLE `bs\\` (id INT)', 'SELECT 1'],
  ),
  _EscapeCase(
    description: 'a comment marker inside a literal is not a comment',
    quote: "'",
    form: _EscapeForm.doubled,
    sql: "SELECT '-- not a comment; really';\nSELECT 2;",
    statements: ["SELECT '-- not a comment; really'", 'SELECT 2'],
  ),

  // The three cases below are the only ones in this table that the *reader*
  // can fail, and without them its half of the matrix is decoration.
  //
  // The reason is worth stating, because it is not obvious and it cost this
  // table a rewrite. `stripComments` copies quoted text through verbatim, so
  // whether it tracks a run correctly or not, the characters it emits are
  // identical — unless the misparse lands a comment marker outside a run that
  // should have contained it, or inside one that should not. A case without a
  // comment marker therefore cannot observe the reader's scan at all: the first
  // draft of this table had nine such cases, and a `stripComments` rewritten to
  // scan naively passed all 2836 tests in the package.
  //
  // The two failure directions need different cases, because they are different
  // bugs — and they are precisely the two that were found in the wild
  // (tcinc476). Under-escaping (a scan that ignores backslashes) ends a literal
  // early and exposes the marker inside it. Over-escaping (a scan that honours
  // backslashes inside identifiers too) runs past the closing backtick and
  // swallows a marker that was genuinely outside.
  _EscapeCase(
    description: "a backslashed quote hides a comment marker in a ' literal",
    quote: "'",
    form: _EscapeForm.backslash,
    sql: "INSERT INTO t (s) VALUES ('it\\'s -- x; y');\nSELECT 2;",
    statements: ["INSERT INTO t (s) VALUES ('it\\'s -- x; y')", 'SELECT 2'],
  ),
  _EscapeCase(
    description: 'a backslashed quote hides a comment marker in a " literal',
    quote: '"',
    form: _EscapeForm.backslash,
    sql: 'INSERT INTO t (s) VALUES ("a\\" -- x; y");\nSELECT 2;',
    statements: ['INSERT INTO t (s) VALUES ("a\\" -- x; y")', 'SELECT 2'],
  ),
  // The comment here is genuinely outside the identifier, so the two splitters
  // are *supposed* to disagree — the lexer keeps it, the reader strips it. That
  // is why this case carries both expectations. A scan that treats the
  // backslash as an escape swallows the closing backtick, and the comment then
  // falls inside the run for both of them.
  _EscapeCase(
    description:
        'a backslash in an identifier does not swallow a following '
        'comment',
    quote: '`',
    form: _EscapeForm.backslash,
    sql: 'CREATE TABLE `bs\\` (id INT);\n-- x\nSELECT 1;',
    statements: ['CREATE TABLE `bs\\` (id INT)', '-- x\nSELECT 1'],
    readerStatements: ['CREATE TABLE `bs\\` (id INT)', 'SELECT 1'],
  ),
];

/// One column list, and the entries `splitTopLevel` should cut it into.
///
/// A separate shape from [_EscapeCase] because the input is a `CREATE TABLE`
/// body rather than a script: there are no statements, no comments and so no
/// reader/lexer divergence to record. Sharing one class would mean carrying
/// three fields that are always null on one side of the table.
class _TopLevelCase {
  const _TopLevelCase({
    required this.description,
    required this.quote,
    required this.form,
    required this.text,
    required this.parts,
  });

  /// The test name, read as "splitTopLevel … <description>".
  final String description;

  /// The quote character whose escaping this case pins.
  final String quote;

  /// The escape form inside that quote.
  final _EscapeForm form;

  /// The column list, as it appears between the parentheses of `CREATE TABLE`.
  final String text;

  /// The entries the list should split into.
  final List<String> parts;
}

/// The escape matrix again, in the shape `splitTopLevel` consumes.
///
/// Every case puts a comma *inside* a quoted run, because that is the only way
/// this splitter's scan becomes observable: a run it ends too early hands the
/// comma to the top level and cuts one column definition in two, and a run it
/// ends too late swallows the real separator and welds two definitions into
/// one. Both failures produce a column list the reader parses without
/// complaint, just not the one the author wrote.
const List<_TopLevelCase> _topLevelMatrix = [
  _TopLevelCase(
    description: "a backslashed quote keeps a comma inside a ' default",
    quote: "'",
    form: _EscapeForm.backslash,
    text: "a VARCHAR(8) DEFAULT 'x\\',y', b INT",
    parts: ["a VARCHAR(8) DEFAULT 'x\\',y'", 'b INT'],
  ),
  _TopLevelCase(
    description: 'a backslashed quote keeps a comma inside a " default',
    quote: '"',
    form: _EscapeForm.backslash,
    text: 'a VARCHAR(8) DEFAULT "x\\",y", b INT',
    parts: ['a VARCHAR(8) DEFAULT "x\\",y"', 'b INT'],
  ),
  // The backtick row, and the one case that fails in the other direction: a
  // scanner that treats the backslash as an escape runs past the closing
  // backtick, so the separating comma looks like part of the identifier and the
  // two columns arrive as one.
  _TopLevelCase(
    description: 'a backslash in an identifier does not swallow the separator',
    quote: '`',
    form: _EscapeForm.backslash,
    text: '`bs\\` INT, b INT',
    parts: ['`bs\\` INT', 'b INT'],
  ),
  _TopLevelCase(
    description: "a doubled quote keeps a comma inside a ' default",
    quote: "'",
    form: _EscapeForm.doubled,
    text: "a VARCHAR(8) DEFAULT 'x'',y', b INT",
    parts: ["a VARCHAR(8) DEFAULT 'x'',y'", 'b INT'],
  ),
  _TopLevelCase(
    description: 'a doubled quote keeps a comma inside a " default',
    quote: '"',
    form: _EscapeForm.doubled,
    text: 'a VARCHAR(8) DEFAULT "x"",y", b INT',
    parts: ['a VARCHAR(8) DEFAULT "x"",y"', 'b INT'],
  ),
  _TopLevelCase(
    description: 'a doubled backtick keeps a comma inside an identifier',
    quote: '`',
    form: _EscapeForm.doubled,
    text: '`we``ird,name` INT, b INT',
    parts: ['`we``ird,name` INT', 'b INT'],
  ),
];
