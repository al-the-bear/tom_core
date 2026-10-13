/// Tests that **a repository's delete methods return the row count the database
/// reported**, not a constant.
///
/// `TomRepository` declared `deleteById`, `deleteByQuerySentence` and
/// `deleteByQuery` as `Future<void>` while [TomSqlDatasourceRepository]
/// implemented them as `Future<int>` — a signature the contract never promised,
/// so no caller could rely on it. What the three returned was worse than
/// unusable: `deleteById` always answered `1` and the two query deletes always
/// answered `0`, whatever the statement had actually done. A caller that read
/// those numbers was reading a literal.
///
/// Two things had to change for the number to become real. The count is
/// something the driver reports per execution, and `TomPreparedStatement`
/// carried no member for it — only `MariaDbDatasource.executeCommand` (a
/// different, non-prepared path) ever looked at `IResultSet.affectedRows`. So
/// the contract gained [TomPreparedStatement.run], whose
/// [TomStatementOutcome.affectedRows] is the count of that execution.
///
/// **Connection-free**, driven against `fixtures/scripted_datasource.dart`.
/// The number under test is one the database hands over; scripting it is what
/// makes "the repository returns what it was told" observable, and a live
/// server cannot be made to report 7 deleted rows more cheaply than by
/// inserting seven. The scripted source reports its count on `DELETE`
/// statements only, so a repository that read the count off the data-scope
/// check or off the file-reference read would return `0` and fail here — the
/// attribution is under test, not just the number. The DB-backed half — that a
/// real multi-row delete really does report its rows — is
/// `object_persistence_db_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTaskRecord, FixtureTaskRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/scripted_datasource.dart';

void main() {
  setUpAll(initializeReflection);

  late ScriptedDataSource scripted;

  setUp(() => scripted = registerScriptedDatasource());
  tearDown(unregisterScriptedDatasource);

  /// Compiles [sentence] against the fixture entity, for the `deleteByQuery`
  /// path — which takes a built query rather than a written one.
  TomDelete built(String sentence) =>
      TomQuerySentenceCompiler([
            FixtureTaskRecord,
          ]).compileQuerySentence(sentence)
          as TomDelete;

  group('a delete returns the count the database reported', () {
    // The three entry points share nothing but the contract: `deleteById` runs
    // a cached statement it holds itself, while the two query deletes prepare
    // one per call through a shared helper and must read the count before the
    // `finally` deallocates it. Running all three against the same scripted
    // number is what catches the count being lost on one path only.
    final deletes = <String, Future<int> Function(FixtureTaskRepository)>{
      'deleteById': (r) => r.deleteById(1),
      'deleteAllById': (r) => r.deleteAllById([1, 2, 3]),
      'deleteByQuerySentence': (r) =>
          r.deleteByQuerySentence('delete by title = :t', {'t': 'x'}),
      'deleteByQuery': (r) =>
          r.deleteByQuery(built('delete by title = :t'), {'t': 'x'}),
    };

    for (final entry in deletes.entries) {
      test('${entry.key} reports a multi-row delete', () async {
        scripted.affectedRows = 7;
        expect(await entry.value(FixtureTaskRepository()), 7);
      });

      test('${entry.key} reports a delete that matched nothing', () async {
        // The distinction the old constants destroyed: `deleteById` answered
        // `1` for a row that was not there, and the query deletes answered `0`
        // for a hundred that were.
        scripted.affectedRows = 0;
        expect(await entry.value(FixtureTaskRepository()), 0);
      });

      test('${entry.key} reports a single-row delete', () async {
        scripted.affectedRows = 1;
        expect(await entry.value(FixtureTaskRepository()), 1);
      });
    }
  });

  group('the contract and the implementation agree on one signature', () {
    // The defect was not only the constant. `TomRepository` promised
    // `Future<void>` and `TomSqlDatasourceRepository` returned `Future<int>`,
    // so the count existed but was unreachable through the interface every
    // caller actually holds. Typing the variable as the *interface* is what
    // makes that a compile-time claim rather than a comment.
    test('the count is reachable through TomRepository', () async {
      scripted.affectedRows = 4;
      final TomRepository<FixtureTaskRecord, int> repo =
          FixtureTaskRepository();
      expect(await repo.deleteById(1), 4);
      expect(await repo.deleteAllById([1, 2]), 4);
      expect(
        await repo.deleteByQuerySentence('delete by title = :t', {'t': 'x'}),
        4,
      );
      expect(
        await repo.deleteByQuery(built('delete by title = :t'), {'t': 'x'}),
        4,
      );
    });

    test('delete(entity) stays void', () {
      // Deliberately the one exception: it addresses a row the caller already
      // holds, so its count can only be `1` or `0` and `0` is not a
      // distinction any caller asked to act on. Asserting it here stops the
      // widening from being applied to all four by reflex later.
      final TomRepository<FixtureTaskRecord, int> repo =
          FixtureTaskRepository();
      expect(repo.delete, isA<Future<void> Function(FixtureTaskRecord)>());
      expect(
        repo.delete,
        isNot(isA<Future<int> Function(FixtureTaskRecord)>()),
      );
    });
  });
}
