/// Executable example for the datasources module of `tom_core_server`.
///
/// Demonstrates the connection-independent surface: boxing and parsing
/// SQL-typed values ([TomDbInt], [TomDbBool], [TomDbString], …) and rendering
/// SQL fragments with [TomStandardSqlDialect] (literals, bound-parameter
/// placeholders, list and object literals).
///
/// The data-source drivers ([MariaDbDatasource], the registry
/// [TomDataSourceInfo], and the generated query objects) require a live
/// database connection and annotated entity types, so they are described in
/// `doc/datasources.md` rather than executed here.
///
/// Run with `dart run example/datasources/datasources_example.dart`.
/// `test/datasources_test.dart` runs this file under exactly that command and
/// requires it to exit 0 with every numbered step reported, so what is printed
/// below is what the module currently does rather than what it did when this
/// was written.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// Throws unless [ok] holds, naming the expectation that failed.
///
/// Deliberately not `assert`: `dart run` leaves assertions **disabled** — that
/// is what its `--enable-asserts` flag is for — so an `assert` here compiles
/// out under the very command this file's header gives. An example whose
/// checks vanish under its own documented invocation is worse than one with no
/// checks at all, because it still prints a plausible transcript and still
/// exits 0 while every expectation in it is violated. A plain `if`/`throw`
/// holds however the file is run.
void check(bool ok, String expectation) {
  if (!ok) throw StateError('datasources example failed: $expectation');
}

void run() {
  // 1. SQL-typed values box a nullable Dart value; `of(String?)` parses one
  //    from its string form, and a null string yields a null box.
  print('1. typed values');
  print('   TomDbInt.of("42")    -> ${TomDbInt.of('42').get()}'); // 42
  print('   TomDbBool.of("true") -> ${TomDbBool.of('true').get()}'); // true
  print('   TomDbDouble.of(null) -> ${TomDbDouble.of(null).get()}'); // null
  check(TomDbInt.of('42').get() == 42, 'TomDbInt.of parses an int');
  check(TomDbBool.of('true').get() == true, 'TomDbBool.of parses a bool');
  check(TomDbDouble.of(null).get() == null, 'a null string boxes as null');

  // 2. The dialect renders literals.
  final dialect = TomStandardSqlDialect();
  print('2. literals');
  print('   text("abc") -> ${dialect.text('abc')}'); // 'abc'
  print('   intOp(7)    -> ${dialect.intOp(7)}'); // 7
  print('   nullOp()    -> ${dialect.nullOp()}'); // NULL
  check(dialect.text('abc') == "'abc'", 'text quotes a string literal');
  check(dialect.intOp(7) == '7', 'intOp renders an int unquoted');
  check(dialect.nullOp() == 'NULL', 'nullOp renders the SQL null keyword');

  // 3. `objectOp` dispatches on the runtime type, and an iterable becomes a
  //    comma-separated list of literals.
  print('3. objectOp');
  print('   objectOp("x")          -> ${dialect.objectOp('x')}'); // 'x'
  print('   objectOp(["a", 1, true]) -> ${dialect.objectOp(['a', 1, true])}');
  check(dialect.objectOp('x') == "'x'", 'objectOp quotes a String operand');
  check(
    dialect.objectOp([1, 2, 3]) == '1,2,3',
    'objectOp renders an iterable as a comma-separated list',
  );

  // 4. A bound-parameter placeholder keeps untrusted input out of the SQL.
  print('4. parameters');
  print('   p("userId") -> ${dialect.p('userId')}'); // :userId
  check(dialect.p('userId') == ':userId', 'p renders a named placeholder');

  print('\nDatasources example completed.');
}

void main() {
  run();
}
