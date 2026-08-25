/// The guard on the comparison three schema suites make through one function.
///
/// `normaliseSql` decides what "the same statement" means for file storage,
/// scheduling and audit alike: comments do not count, layout does not count, a
/// trailing semicolon does not count. That is a judgement, and a judgement in
/// one place is worth testing in one place — a version that discarded its input
/// would turn every file-versus-DDL assertion in all three suites into `''` on
/// both sides, and each of those suites would report green while comparing
/// nothing.
///
/// The negative test is therefore the point of the file. The positive ones say
/// what the normalisation is allowed to ignore; the negative one says it must
/// still be able to tell two statements apart.
library;

import 'package:test/test.dart';

import 'fixtures/sql_text.dart';

void main() {
  group('normaliseSql', () {
    test('two statements that differ are still different afterwards', () {
      // The property everything else rests on: without it the comparison is
      // vacuous and every suite that uses it is decoration.
      expect(
        normaliseSql('CREATE TABLE a (x INT)'),
        isNot(normaliseSql('CREATE TABLE b (x INT)')),
      );
      expect(normaliseSql('CREATE TABLE a (x INT)'), isNotEmpty);
    });

    test('comment lines are dropped', () {
      expect(
        normaliseSql('-- why this table exists\nCREATE TABLE a (x INT)'),
        'CREATE TABLE a (x INT)',
      );
    });

    test('layout does not count', () {
      expect(
        normaliseSql('CREATE TABLE a (\n  x   INT\n)'),
        normaliseSql('CREATE TABLE a ( x INT )'),
      );
    });

    test('a trailing semicolon does not count', () {
      // A migration file ends its statement; the generated DDL does not. The
      // difference is a file format's, not a schema's.
      expect(
        normaliseSql('CREATE TABLE a (x INT);'),
        normaliseSql('CREATE TABLE a (x INT)'),
      );
    });

    test('a comment inside the body is dropped, not the line it precedes', () {
      expect(
        normaliseSql('CREATE TABLE a (\n  -- the key\n  x INT\n)'),
        'CREATE TABLE a ( x INT )',
      );
    });
  });
}
