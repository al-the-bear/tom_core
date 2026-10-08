/// Executable example for the datasources module of `tom_core_server`.
///
/// Demonstrates the connection-independent surface, which is most of the
/// module:
///
///  1. boxing and parsing SQL-typed values ([TomDbInt], [TomDbBool], …);
///  2. rendering literals with [TomStandardSqlDialect];
///  3. `objectOp` dispatching on the runtime type of an operand;
///  4. the `:name` bound-parameter placeholder;
///  5. the one encoding of an instant ([sqlInstant] / [parseSqlInstant]);
///  6. the static clause builders on [TomGeneratedQuery];
///  7. the quote-aware placeholder scan ([SqlPlaceholderScan]);
///  8. classifying a failed write ([classifySqlFailure]);
///  9. declaring a framework-owned table ([TomFrameworkTable]);
/// 10. walking an expression tree ([TomOperator.children]).
///
/// Two things genuinely need more than a Dart VM and are therefore described in
/// `doc/datasources.md` instead of run here. The drivers ([MariaDbDatasource],
/// [MariaDbXADatasource]) and the registry [TomDataSourceInfo] need a live
/// server to connect to; and rendering a whole [TomSelect], [TomCount] or
/// [TomDelete] needs annotated entity types, because the statement's column
/// list and its `ORDER BY` are resolved from reflected persistence metadata.
/// The *clause builders* those statements are assembled from are pure functions
/// over their arguments, so step 6 runs them directly.
///
/// Run with `dart run example/datasources/datasources_example.dart`.
/// `test/datasources_test.dart` runs this file under exactly that command and
/// requires it to exit 0 having printed every numbered step and no others, so
/// what is printed below is what the module currently does rather than what it
/// did when this was written.
library;

// `MySQLServerException` and `MySQLClientException` arrive through this
// barrel: a caller classifying a failed write has to be able to name the
// driver types, so the module re-exports them rather than making every
// consumer depend on the driver package directly.
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

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

  // 5. An instant has exactly one encoding in a `DATETIME(6)` column: UTC,
  //    six fractional digits. Reading it back appends the zone marker, which
  //    is what makes the round trip exact — `DateTime.parse` on the column
  //    text alone yields a *local* value that compares unequal to the UTC one
  //    that was written, even though both denote the same moment.
  final written = DateTime.utc(2026, 8, 24, 17, 30, 0, 123, 456);
  print('5. instants');
  print('   sqlInstant(utc)      -> ${sqlInstant(written)}');
  print('   parseSqlInstant(…)   -> ${parseSqlInstant(sqlInstant(written))}');
  print('   parseOptional("")    -> ${parseOptionalSqlInstant('')}');
  check(
    sqlInstant(written) == '2026-08-24 17:30:00.123456',
    'sqlInstant renders UTC with six fractional digits',
  );
  check(
    parseSqlInstant(sqlInstant(written)) == written,
    'an instant round-trips through the column encoding',
  );
  final localNoon = DateTime(2026, 8, 24, 12);
  check(
    parseSqlInstant(sqlInstant(localNoon)).isUtc,
    'a local DateTime is read back as UTC',
  );
  check(
    parseSqlInstant(sqlInstant(localNoon)).isAtSameMomentAs(localNoon),
    'the same moment, differently labelled',
  );
  check(
    parseOptionalSqlInstant('') == null,
    'an empty column reads as an absent instant',
  );

  // 6. The clauses a generated statement is assembled from are static and
  //    pure, so they render without an entity model behind them. Assembling
  //    the whole statement is what needs one: the column list and the
  //    `ORDER BY` are resolved from reflected persistence metadata.
  final sort = [
    const TomSortField('priority', direction: TomSortDirection.descending),
    const TomSortField('name'),
  ];
  print('6. clause builders');
  print(
    '   distinctPrefix(true)  -> "${TomGeneratedQuery.distinctPrefix(true)}"',
  );
  print(
    '   orderByClause(…)      -> "${TomGeneratedQuery.orderByClause(sort)}"',
  );
  print(
    '   limitClause(10, 20)   -> "${TomGeneratedQuery.limitClause(10, 20)}"',
  );
  print(
    '   countProjection(…)    -> '
    '${TomGeneratedQuery.countProjection(true, ['t.a', 't.b'])}',
  );
  check(
    TomGeneratedQuery.distinctPrefix(true) == 'DISTINCT ',
    'distinctPrefix renders the projection prefix',
  );
  check(
    TomGeneratedQuery.orderByClause(sort) == ' ORDER BY priority DESC,name ASC',
    'every ordering term carries its own direction',
  );
  check(
    TomGeneratedQuery.limitClause(10, 20) == ' LIMIT 10 OFFSET 20',
    'a row window renders as LIMIT n OFFSET m',
  );
  check(
    TomGeneratedQuery.limitClause(0) == '',
    'an unbounded query has no window clause at all',
  );
  check(
    TomGeneratedQuery.countProjection(true, ['t.a', 't.b']) ==
        'COUNT(DISTINCT t.a, t.b)',
    'a distinct count names the columns to distinguish on',
  );
  check(
    TomGeneratedQuery.countProjection(false, ['t.a']) == 'COUNT(*)',
    'a plain count counts rows',
  );

  // 7. Finding `:name` placeholders is quote-aware. A `:x`-looking substring
  //    inside an inlined literal is *not* a bind, and treating it as one used
  //    to desynchronise every following positional slot.
  const sql = "SELECT * FROM t WHERE note = 'a:b' AND id = :id AND u = :owner";
  final (positional, names) = SqlPlaceholderScan.toPositional(sql);
  print('7. placeholders');
  print('   toPositional -> $positional');
  print('   names        -> $names');
  check(
    positional == "SELECT * FROM t WHERE note = 'a:b' AND id = ? AND u = ?",
    'the colon inside the literal is copied through, not tokenised',
  );
  check(
    names.join(',') == 'id,owner',
    'the names come back in the order their ? slots appear',
  );
  check(
    SqlPlaceholderScan.extractNames(sql).join(',') == 'id,owner',
    'extractNames is the same scan with the rewrite discarded',
  );

  // 8. A failed write says one of two things, and they are not the same
  //    thing. The server answering means the statement definitely did not
  //    take effect; anything else means the outcome is unknown, because the
  //    write may have been applied with only the acknowledgement lost.
  final serverSaid = MySQLServerException('Duplicate entry', 1062);
  final linkDied = MySQLClientException('connection closed');
  final wrapped = MariadbDatasourceException(
    'error.datasource.write_failed',
    'The write failed',
    rootException: serverSaid,
  );
  print('8. failed writes');
  print('   server error -> ${classifySqlFailure(serverSaid).name}');
  print('   lost link    -> ${classifySqlFailure(linkDied).name}');
  print('   wrapped      -> ${classifySqlFailure(wrapped).name}');
  check(
    classifySqlFailure(serverSaid) == TomSqlFailureMode.definite,
    'the server answered, so the statement did not take effect',
  );
  check(
    classifySqlFailure(linkDied) == TomSqlFailureMode.ambiguous,
    'a transport failure leaves the outcome unknown',
  );
  check(
    classifySqlFailure(wrapped) == TomSqlFailureMode.definite,
    'the verdict is read from the cause chain, not the outermost type',
  );
  check(
    sqlFailureCauses(wrapped).length == 2,
    'the chain is walked outermost first',
  );
  check(
    isLostConnectionFailure(linkDied, connected: false),
    'a dropped link with no server verdict is worth one retry',
  );
  check(
    !isLostConnectionFailure(serverSaid, connected: false),
    'a statement the server has already judged is not retried',
  );

  // 9. A table the framework itself owns is declared once, and its DDL, its
  //    column lists and its inserts are all derived from that declaration —
  //    so a column cannot be renamed on one side only.
  final leases = TomFrameworkTable(
    name: 'demo_lease',
    origin: 'datasources_example.run',
    columns: const [
      TomFrameworkColumn('name', 'VARCHAR(191)'),
      TomFrameworkColumn('owner', 'VARCHAR(191)', nullable: true),
      TomFrameworkColumn('expires_at', 'DATETIME(6)', nullable: true),
      TomFrameworkColumn('version', 'BIGINT', defaultValue: '0'),
    ],
    primaryKey: ['name'],
    keys: const [
      TomFrameworkKey('expiry', ['expires_at']),
    ],
  );
  print('9. framework-owned tables');
  print(leases.createTableDdl.split('\n').map((l) => '   $l').join('\n'));
  print('   columnsOf -> ${leases.columnsOf(['name', 'owner'])}');
  print(
    '   insert    -> '
    '${leases.insert('REPLACE', {'name': ':name', 'version': '1'})}',
  );
  check(
    leases.columnList == 'name, owner, expires_at, version',
    'the column list is the declaration order',
  );
  check(
    leases.createTableDdl.contains('KEY ix_demo_lease_expiry (expires_at)'),
    'an index is named from the table, so two stores cannot collide',
  );
  check(
    leases.insert('REPLACE', {'name': ':name', 'version': '1'}) ==
        'REPLACE INTO demo_lease (name, version) VALUES (:name, 1)',
    'an insert is keyed by column name, never by position',
  );
  // The half a column *list* cannot cover: a reference inside SET or WHERE.
  // Those stay written out and are audited instead.
  final stale = unknownFrameworkColumns(
    'UPDATE demo_lease SET owner = :owner WHERE lease_name = :name',
    [leases],
  );
  print('   unknown   -> $stale');
  check(
    stale.join(',') == 'lease_name',
    'a column reference no declaration knows about is reported',
  );

  // 10. An expression tree can be walked. `children` is the one traversal
  //     every structural walk goes through: a container yields its operands
  //     (flattening one that is itself a list, as AND and BETWEEN carry), a
  //     leaf yields none.
  //
  //     What this makes possible is asking the tree a question no member
  //     answers. `getFields` reports the *rendered* fragment — the string
  //     `demo_task.priority` — which is what SQL needs and not enough for a
  //     layer deciding whether a query touches a column the principal may not
  //     read: that decision needs the column's metadata, and only the DbCol
  //     node holds it. A walk reaches the node; the field set does not.
  const taskTable = TomDbTable(
    datasource: 'demo',
    table: 'demo_task',
    primaryKeyFields: ['id'],
  );
  TomColumnInformation columnInfo(String name, Type type) =>
      TomColumnInformation(
        tableType: Object,
        table: taskTable,
        declaredType: type,
        declaredName: name,
        field: name,
      );
  final priority = IntCol(Object, 'priority', columnInfo('priority', int));
  final title = StringCol(Object, 'title', columnInfo('title', String));
  final predicate = And([
    Between<TomDbInt>(priority, [IntegerLiteral(1), IntegerLiteral(9)]),
    Eq<TomDbString>(title, StringLiteral('release')),
  ]);

  /// Every column reference in [node]'s subtree, by declared name.
  List<String> columnsTouched(TomOperator node) => [
    if (node is DbCol) node.columnInformation.declaredName,
    for (final child in node.children) ...columnsTouched(child),
  ];

  print('10. walking the tree');
  print('   sql       -> ${predicate.generate(dialect)}');
  print('   children  -> ${predicate.children.length}');
  print('   columns   -> ${columnsTouched(predicate)}');
  print('   getFields -> ${predicate.getFields(dialect)}');
  check(
    predicate.children.length == 2,
    'AND yields its operand list flattened, not the list as one child',
  );
  check(
    columnsTouched(predicate).join(',') == 'priority,title',
    'the walk reaches each column node, left to right',
  );
  check(
    priority.children.isEmpty,
    'a column reference is a leaf: its operand is the column name, not a node',
  );
  check(
    predicate.getFields(dialect).join(',') ==
        'demo_task.priority,demo_task.title',
    'getFields answers with rendered SQL, which is why a walk is the way to '
    'the column metadata',
  );

  print('\nDatasources example completed.');
}

void main() {
  run();
}
