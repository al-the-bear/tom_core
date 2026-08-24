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

  // The six cells of the escape matrix, each as a semicolon the splitter must
  // not split on — that is the observable consequence of getting the cell wrong.
  group('TomSqlLexer escape matrix', () {
    test("a semicolon inside a ' literal does not split", () {
      const sql = "INSERT INTO t (s) VALUES ('a;b');\nSELECT 1;";
      expect(TomSqlLexer.splitStatements(sql), [
        "INSERT INTO t (s) VALUES ('a;b')",
        'SELECT 1',
      ]);
    });

    test("a doubled quote inside a ' literal is an escaped quote", () {
      const sql = "INSERT INTO t (s) VALUES ('it''s; ok');\nSELECT 2;";
      expect(TomSqlLexer.splitStatements(sql), [
        "INSERT INTO t (s) VALUES ('it''s; ok')",
        'SELECT 2',
      ]);
    });

    test("a backslashed quote inside a ' literal is an escaped quote", () {
      const sql = "INSERT INTO t (s) VALUES ('it\\'s; ok');\nSELECT 2;";
      expect(TomSqlLexer.splitStatements(sql), [
        "INSERT INTO t (s) VALUES ('it\\'s; ok')",
        'SELECT 2',
      ]);
    });

    test('a semicolon inside a " literal does not split', () {
      const sql = 'INSERT INTO t (s) VALUES ("a;b");\nSELECT 1;';
      expect(TomSqlLexer.splitStatements(sql), [
        'INSERT INTO t (s) VALUES ("a;b")',
        'SELECT 1',
      ]);
    });

    test('a doubled quote inside a " literal is an escaped quote', () {
      const sql = 'INSERT INTO t (s) VALUES ("a"";b");\nSELECT 2;';
      expect(TomSqlLexer.splitStatements(sql), [
        'INSERT INTO t (s) VALUES ("a"";b")',
        'SELECT 2',
      ]);
    });

    test('a backslashed quote inside a " literal is an escaped quote', () {
      const sql = 'INSERT INTO t (s) VALUES ("a\\";b");\nSELECT 2;';
      expect(TomSqlLexer.splitStatements(sql), [
        'INSERT INTO t (s) VALUES ("a\\";b")',
        'SELECT 2',
      ]);
    });

    test('a semicolon inside a backtick identifier does not split', () {
      const sql = 'CREATE TABLE `weird;name` (id INT);\nSELECT 3;';
      expect(TomSqlLexer.splitStatements(sql), [
        'CREATE TABLE `weird;name` (id INT)',
        'SELECT 3',
      ]);
    });

    test('a doubled backtick inside an identifier is an escaped backtick', () {
      const sql = 'CREATE TABLE `we``ird;name` (id INT);\nSELECT 3;';
      expect(TomSqlLexer.splitStatements(sql), [
        'CREATE TABLE `we``ird;name` (id INT)',
        'SELECT 3',
      ]);
    });

    // The cell the applier got right and the reader got wrong. A trailing
    // backslash is an ordinary character in an identifier, so the very next
    // backtick closes the run; treating it as an escape swallows that backtick
    // and glues both statements into one.
    test(
      'a backslash inside a backtick identifier is an ordinary character',
      () {
        const sql = 'CREATE TABLE `bs\\` (id INT);\nSELECT 1;';
        expect(TomSqlLexer.splitStatements(sql), [
          'CREATE TABLE `bs\\` (id INT)',
          'SELECT 1',
        ]);
      },
    );
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
