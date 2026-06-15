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
/// The same behaviour is covered by `test/datasources_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

void run() {
  // 1. SQL-typed values box a nullable Dart value; `of(String?)` parses one
  //    from its string form, and a null string yields a null box.
  print('1. typed values');
  print('   TomDbInt.of("42")    -> ${TomDbInt.of('42').get()}'); // 42
  print('   TomDbBool.of("true") -> ${TomDbBool.of('true').get()}'); // true
  print('   TomDbDouble.of(null) -> ${TomDbDouble.of(null).get()}'); // null
  assert(TomDbInt.of('42').get() == 42);
  assert(TomDbBool.of('true').get() == true);
  assert(TomDbDouble.of(null).get() == null);

  // 2. The dialect renders literals.
  final dialect = TomStandardSqlDialect();
  print('2. literals');
  print('   text("abc") -> ${dialect.text('abc')}'); // 'abc'
  print('   intOp(7)    -> ${dialect.intOp(7)}'); // 7
  print('   nullOp()    -> ${dialect.nullOp()}'); // NULL
  assert(dialect.text('abc') == "'abc'");
  assert(dialect.intOp(7) == '7');
  assert(dialect.nullOp() == 'NULL');

  // 3. `objectOp` dispatches on the runtime type, and an iterable becomes a
  //    comma-separated list of literals.
  print('3. objectOp');
  print('   objectOp("x")          -> ${dialect.objectOp('x')}'); // 'x'
  print('   objectOp(["a", 1, true]) -> ${dialect.objectOp(['a', 1, true])}');
  assert(dialect.objectOp('x') == "'x'");
  assert(dialect.objectOp([1, 2, 3]) == '1,2,3');

  // 4. A bound-parameter placeholder keeps untrusted input out of the SQL.
  print('4. parameters');
  print('   p("userId") -> ${dialect.p('userId')}'); // :userId
  assert(dialect.p('userId') == ':userId');

  print('\nDatasources example completed.');
}

void main() {
  run();
}
