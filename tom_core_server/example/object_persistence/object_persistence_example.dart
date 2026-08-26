/// Executable example for the object-persistence module of `tom_core_server`.
///
/// The module's job is to turn an annotated Dart class into SQL and to enforce
/// the security rules on the way past. Almost all of that is decidable without a
/// database — a query sentence compiles to a statement whose text can be
/// printed, a page request rejects an unrenderable window where it is built, and
/// the column-grade decision is a pure function — so this example runs the real
/// surface rather than describing it.
///
/// The sixteen steps below cover: mapping an entity ([TomAnnotationAnalyzer]),
/// compiling the four sentence kinds ([TomQuerySentenceCompiler]), grouping and
/// aggregation ([TomGroupedSelect]), paging ([TomPageRequest]), column
/// authorization ([TomColumnAuthorization]) and the [TomQueryBuilder] DSL every
/// sentence compiles down to — each with its refusals. The refusals are most of
/// what the module has to say: a query it accepts is one you would have written
/// anyway, so what is worth showing is where it stops you, and when.
///
/// Two neighbouring features are demonstrated by their own examples rather than
/// repeated here, because each needs a principal and a registry this one has no
/// use for:
///
///  * **row scopes** (C-3) — `example/authorization/resource_data_scope_example.dart`;
///  * **file-reference keys** — `example/file_storage/file_storage_example.dart`.
///
/// What genuinely needs a live data source is the repository round trip itself
/// ([TomRepository], [MariadbRepository] — save, find, delete). That is covered
/// against MariaDB by `test/object_persistence_db_test.dart` and described in
/// [`doc/object_persistence.md`](../../doc/object_persistence.md), which is the
/// module's full reference.
///
/// Run with
/// `dart run --enable-asserts example/object_persistence/object_persistence_example.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../example_reflection.reflection.dart';
import 'object_persistence_entities.dart';

/// A trivial host for the [TomQueryBuilder] DSL (a repository is one too).
class _Builder with TomQueryBuilder {}

/// The grades the example's principal holds, standing in for the process-wide
/// [TomAuthorization] singleton the repository would consult.
///
/// A resolver is passed explicitly throughout because the singleton answers
/// `full` for everything in development mode — which is the right default for an
/// unconfigured server and would make every authorization step below print the
/// same uninteresting answer.
TomAuthState _grade(String authKey) => switch (authKey) {
  'example.claim.reimbursement_account' => TomAuthState.read,
  'example.claim.fraud_score' => TomAuthState.none,
  _ => TomAuthState.full,
};

void run() {
  initializeReflection();
  final b = _Builder();
  final dialect = MariadbSqlDialect();
  final compiler = TomQuerySentenceCompiler([ExampleClaimRecord]);

  // ---------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------

  // 1. The annotations are the mapping. Everything afterwards is resolved from
  //    this one call: the table a statement names, the SQL type each predicate
  //    is built at, and which columns carry a grade.
  final entity = TomAnnotationAnalyzer.analysePersistentType(
    ExampleClaimRecord,
  );
  final columns = entity.columnInfo;
  print('1. table=${entity.table.table} columns=${columns.length}');
  assert(entity.table.table == 'example_claim');
  assert(columns.length == 7);

  // 2. A column knows its declared Dart name, its stored column name and — when
  //    it has one — the resource key its grade is looked up under. The two
  //    graded columns are the entity's whole authorization surface.
  final graded = columns.where((c) => c.column?.authKey != null).toList();
  print(
    '2. graded columns: '
    '${graded.map((c) => '${c.declaredName}->${c.column!.authKey}').join(', ')}',
  );
  assert(graded.length == 2);

  // ---------------------------------------------------------------------
  // Query sentences
  // ---------------------------------------------------------------------

  // 3. A `find` sentence compiles to a TomSelect whose SQL can be printed. The
  //    parameter stays a bind placeholder — a value is never concatenated into
  //    the text (C-7).
  final select =
      compiler.compileQuerySentence(
            'find by amount >= :floor order by submitted desc',
          )
          as TomSelect;
  print('3. ${select.generateQuery(dialect)}');
  assert(select.generateQuery(dialect).contains('example_claim.amount >= '));
  assert(select.generateQuery(dialect).contains('ORDER BY'));

  // 4. The verb picks the statement kind: find/count/delete/group are four
  //    different compiled types, not one type with a mode flag.
  final counted = compiler.compileQuerySentence('count by approved = TRUE');
  final deleted = compiler.compileQuerySentence('delete by id = :id');
  print(
    '4. find->${select.runtimeType} count->${counted.runtimeType} '
    'delete->${deleted.runtimeType}',
  );
  assert(counted is TomCount);
  assert(deleted is TomDelete);

  // 5. A literal has to fit the column it is compared against. `approved` is a
  //    boolean, so a number is refused at compile time — where the sentence is
  //    still in front of you — rather than becoming a driver-level bind error.
  try {
    compiler.compileQuerySentence('find by approved = 1');
    print('5. ERROR: no exception thrown');
  } on TomServerException catch (e) {
    print('5. `approved = 1` refused: ${e.key}');
    assert(e.key.endsWith('int_literal_invalid_type_expected'));
  }

  // 6. So does the sentence's shape. `AND` with nothing on its left is not a
  //    predicate, and the compiler says which mistake it was.
  try {
    compiler.compileQuerySentence('find by and amount > 0');
    print('6. ERROR: no exception thrown');
  } on TomServerException catch (e) {
    print('6. leading AND refused: ${e.key}');
    assert(e.key.endsWith('and_without_current_operation'));
  }

  // ---------------------------------------------------------------------
  // Grouping and aggregation
  // ---------------------------------------------------------------------

  // 7. A grouped query collapses rows into groups. Its result is a different
  //    shape from the entity — a tuple the query decides — which is why it is
  //    its own kind rather than an option on the select.
  final grouped =
      compiler.compileQuerySentence(
            'group count ( * ) as n , sum ( amount ) as revenue '
            'over employee by approved = TRUE having n > 2 order by revenue desc',
          )
          as TomGroupedSelect;
  print('7. ${grouped.generateQuery(dialect)}');
  assert(grouped.generateQuery(dialect).contains('GROUP BY'));
  assert(grouped.generateQuery(dialect).contains('HAVING'));
  assert(grouped.aggregates.length == 2);

  // 8. `WHERE` filters rows and `HAVING` filters groups, so HAVING addresses the
  //    projection: a group key or an aggregate alias. A HAVING on a bare column
  //    that is neither has many values per group and no rule for picking one —
  //    databases disagree about whether to refuse it or pick a row, so the query
  //    layer refuses it and makes the behaviour the same on every dialect.
  //
  //    Note *when* it is refused: comparing a column against a group is a
  //    question about the rendered statement, so the check belongs to
  //    `generateQuery` and the sentence itself compiles without complaint.
  final ungroupedHaving =
      compiler.compileQuerySentence(
            'group count ( * ) as n over employee '
            'by approved = TRUE having amount > 2.0',
          )
          as TomGroupedSelect;
  try {
    ungroupedHaving.generateQuery(dialect);
    print('8. ERROR: no exception thrown');
  } on TomQuerySyntaxException catch (e) {
    print('8. HAVING on an ungrouped column refused when rendered: ${e.key}');
    assert(e.key == 'grouped_query.select.having_on_ungrouped_field');
  }

  // ---------------------------------------------------------------------
  // Paging
  // ---------------------------------------------------------------------

  // 9. A page request is an offset, a limit and an ordering.
  final page = TomPageRequest.page(
    2,
    25,
    sort: const [TomSortField.desc('submitted'), TomSortField.asc('employee')],
  );
  print('9. $page needsStableSort=${page.needsStableSort}');
  assert(page.offset == 50 && page.limit == 25);
  // The window is cut from an ordering, so it needs one that settles the order;
  // the repository appends the primary key when the caller's sort does not.
  assert(page.needsStableSort);

  // 10. A window SQL cannot express is rejected where it is built. MariaDB's
  //     grammar is `LIMIT n [OFFSET m]` — there is no bare OFFSET — so a skip
  //     with no cap would be silently dropped rather than honoured.
  try {
    TomPageRequest(offset: 20);
    print('10. ERROR: no exception thrown');
  } on TomQuerySyntaxException catch (e) {
    print('10. offset without limit refused: ${e.key}');
    assert(e.key == 'paging.window.offset_without_limit');
  }

  // ---------------------------------------------------------------------
  // Column authorization (C-4)
  // ---------------------------------------------------------------------

  // 11. A read masks the columns whose grade does not show content. `fraudScore`
  //     is graded `none` and is withheld; `reimbursementAccount` is graded
  //     `read`, which *does* show content — it is visible, just not editable.
  final masked = TomColumnAuthorization.maskedColumns<TomColumnInformation>(
    columns: columns,
    keyOf: (c) => c.column?.authKey,
    resolver: _grade,
  );
  print('11. masked on read: ${masked.map((c) => c.declaredName).join(', ')}');
  assert(masked.length == 1);
  assert(masked.single.declaredName == 'fraudScore');

  // 12. A write partitions the same columns. The asymmetry between the two
  //     non-writable grades is the point, and it follows from masking above: a
  //     masked column reads back as null, so a client that loads a claim, edits
  //     one field and saves it returns null for `fraudScore` having never seen
  //     it. Rejecting that would make every ordinary round trip fail, so it is
  //     quietly overlaid from the stored row instead.
  final changed = {'employee', 'fraudScore'};
  final decision = TomColumnAuthorization.decideWrites<TomColumnInformation>(
    columns: columns,
    gradeOf: (c) => c.column?.authKey,
    changed: (c) => changed.contains(c.declaredName),
    onForbidden: (c, key, grade) => throw TomColumnAuthorizationException(
      'column_authorization.write.field_forbidden',
      'Column "${c.declaredName}" (resource "$key") is not writable at '
          'your access level (${grade.name}).',
    ),
    resolver: _grade,
  );
  print(
    '12. writable=${decision.writable.map((c) => c.declaredName).join(', ')}\n'
    '    preserved=${decision.preserved.map((c) => c.declaredName).join(', ')}',
  );
  // The changed masked column did not reject; it was preserved.
  assert(decision.preserved.any((c) => c.declaredName == 'fraudScore'));
  assert(decision.writable.any((c) => c.declaredName == 'employee'));

  // 13. Changing a *visible* column is different in kind: the caller can see it,
  //     so altering it is a real attempt to write something it may not write.
  //     That one is named rather than swallowed.
  try {
    TomColumnAuthorization.decideWrites<TomColumnInformation>(
      columns: columns,
      gradeOf: (c) => c.column?.authKey,
      changed: (c) => c.declaredName == 'reimbursementAccount',
      onForbidden: (c, key, grade) => throw TomColumnAuthorizationException(
        'column_authorization.write.field_forbidden',
        'Column "${c.declaredName}" (resource "$key") is not writable at '
            'your access level (${grade.name}).',
      ),
      resolver: _grade,
    );
    print('13. ERROR: no exception thrown');
  } on TomColumnAuthorizationException catch (e) {
    print('13. editing a read-graded column refused: ${e.key}');
    assert(e.key == 'column_authorization.write.field_forbidden');
  }

  // 14. And the read mask is applied to a live instance, in place: a caller
  //     holding the original reference must not still see the withheld value.
  final claim = ExampleClaimRecord()
    ..id = 7
    ..employee = 'r.mbeki'
    ..amount = 249.90
    ..reimbursementAccount = 'NL91ABNA0417164300'
    ..fraudScore = 0.82;
  TomColumnAuthorization.applyReadMask(claim, columns, resolver: _grade);
  print(
    '14. after masking: amount=${claim.amount} '
    'account=${claim.reimbursementAccount} fraudScore=${claim.fraudScore}',
  );
  assert(claim.fraudScore == null);
  assert(claim.reimbursementAccount == 'NL91ABNA0417164300');
  assert(claim.amount == 249.90);

  // ---------------------------------------------------------------------
  // The builder underneath
  // ---------------------------------------------------------------------

  // 15. Every sentence above compiles down to the same operator tree the
  //     TomQueryBuilder DSL builds by hand, which is what a caller uses when a
  //     predicate is assembled at runtime rather than written as a phrase.
  final amountCol = columns.firstWhere((c) => c.declaredName == 'amount');
  final employeeCol = columns.firstWhere((c) => c.declaredName == 'employee');
  final predicate = b.and([
    b.group(
      b.gte(
        b.doubleF(amountCol.getQueryFieldName(), amountCol),
        b.doubleOp(50),
      ),
    ),
    b.group(
      b.like(
        b.textF(employeeCol.getQueryFieldName(), employeeCol),
        b.text('r.%'),
      ),
    ),
  ]);
  print('15. ${predicate.generate(dialect)}');
  assert(
    predicate.generate(dialect) ==
        "( example_claim.amount >= 50.0 ) AND ( example_claim.employee LIKE 'r.%' )",
  );

  // 16. The DSL validates its own arity: BETWEEN takes exactly two bounds.
  try {
    b.between(b.doubleF(amountCol.getQueryFieldName(), amountCol), [
      b.doubleOp(1),
    ]);
    print('16. ERROR: no exception thrown');
  } on TomQuerySyntaxException catch (e) {
    print('16. between with one bound refused: ${e.key}');
    assert(e.key == 'between_expression.must_have_two_values');
  }

  print('\nObject-persistence example completed.');
}

void main() {
  run();
}
