/// Tests for **how a repository fails** — that every rejection it raises is a
/// keyed [TomServerException] rather than a bare `Exception`.
///
/// `crud_repository.dart` used to `throw Exception(...)` at seven sites: the
/// constructor's datasource lookup, the duplicate-primary-key guard in
/// [TomSqlDatasourceRepository.findById], the read-back guards in the insert and
/// update halves of [TomSqlDatasourceRepository.save], and the
/// "a count returned other than one row" guard, which appears three times over.
/// Every *other* rejection in the module raises a `TomServerException` subclass
/// carrying a stable key, and the module's API summary states as a fact that all
/// of its exceptions do.
///
/// A bare `Exception` is not merely untidy. It has no key, so no handler can
/// match it and no message catalogue can localise it; it is outside the family
/// the framework auto-logs; and the endpoint pipeline, which classifies by type,
/// sees an unclassified error. The seven were the only places in the module
/// where a failure arrived at a caller with nothing to match on.
///
/// Three further sites had the same shape without being `throw` statements at
/// all. [TomSqlDatasourceRepository.findByQuerySentence],
/// [TomSqlDatasourceRepository.deleteByQuerySentence] and
/// [TomSqlDatasourceRepository.countByQuerySentence] each cast the compiled
/// sentence to the query kind they need (`as TomSelect` / `as TomDelete` /
/// `as TomCount`). The sentence is caller-supplied, so a `find by …` handed to
/// `countByQuerySentence` is an ordinary caller mistake — and it surfaced as a
/// raw `_TypeError`, "type 'TomSelect' is not a subtype of type 'TomCount' in
/// type cast", which names two internal classes the caller never wrote and does
/// not say which of its own words was wrong.
///
/// **Connection-free.** The repository is driven against a scripted data source
/// rather than a database. Every failure under test is a decision the repository
/// makes *about an answer it was given*, so a real server would contribute
/// nothing but the ability to produce the answer — and two of these answers
/// (two rows for one primary key; a `COUNT(*)` returning no row at all) are
/// states a correct server will not produce on request.
library;

import 'dart:collection';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTaskRecord, FixtureTaskRepository;
import 'fixtures/reflection_fixture.reflection.dart';

/// The data source name [FixtureTaskRecord] declares on its `@TomDbTable`.
const _fixtureDatasource = 'tom_core_server_test';

/// A prepared statement that answers from [_ScriptedDataSource.answers].
class _ScriptedStatement<T extends Object> implements TomPreparedStatement<T> {
  _ScriptedStatement(this.source);

  final _ScriptedDataSource source;

  @override
  Future<List<T>> execute([Map<String, Object?>? params]) async =>
      source.nextAnswer<T>();

  @override
  Future<void> deallocate() async {}

  @override
  int? get lastGeneratedId => source.generatedId;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The scripted statement was asked for ${invocation.memberName}, which no '
    'test needs. Implement it here if that changes.',
  );
}

/// A [TomDataSource] that answers from a script instead of from a server.
///
/// Each execution takes the next entry from [answers] — a `List` of rows to
/// return, or any other object to throw — and an exhausted script answers with
/// no rows. That default is deliberate: "the query found nothing" is the input
/// four of these guards are about, so most tests need to script nothing at all.
///
/// Only the execution surface is implemented; [noSuchMethod] turns anything
/// else into a loud test bug rather than a silent `null`.
class _ScriptedDataSource implements TomDataSource {
  /// What each successive execution does, in order.
  final Queue<Object> answers = Queue();

  /// What [TomPreparedStatement.lastGeneratedId] reports after an insert.
  int? generatedId;

  /// The next scripted answer as a `List<T>`, or no rows once the script runs
  /// out.
  List<T> nextAnswer<T extends Object>() {
    if (answers.isEmpty) return <T>[];
    final answer = answers.removeFirst();
    // `cast` rather than an `is List<T>` test: a `[FixtureTaskRecord()]`
    // literal is a `List<FixtureTaskRecord>`, which is not a `List<TomCountResult>`
    // even when that is what the call wants back.
    if (answer is List) return answer.cast<T>();
    throw answer;
  }

  @override
  TomStandardSqlDialect get sqlDialect => MariadbSqlDialect();

  @override
  Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(
    TomQuery query, [
    Type? resultType,
  ]) async => _ScriptedStatement<T>(this);

  @override
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]) async => nextAnswer<T>();

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async => BigInt.one;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The scripted data source was asked for ${invocation.memberName}, which no '
    'test needs. Implement it here if that changes.',
  );
}

/// A registry entry whose [datasource] is the scripted one.
///
/// [TomDataSourceInfo.initialize] is the only way to populate the real field and
/// it demands a registered driver, so the getter is overridden instead — the
/// repository reads the data source through exactly this getter.
class _ScriptedDataSourceInfo extends TomDataSourceInfo {
  _ScriptedDataSourceInfo(this.scripted) : super(_fixtureDatasource, const {});

  final _ScriptedDataSource scripted;

  @override
  TomDataSource get datasource => scripted;
}

void main() {
  setUpAll(initializeReflection);

  late _ScriptedDataSource scripted;

  /// Registers the scripted data source under the name the fixture entity
  /// declares, so `FixtureTaskRepository()` can be constructed.
  void registerDatasource() {
    scripted = _ScriptedDataSource();
    TomDataSourceInfo.datasources[_fixtureDatasource] = _ScriptedDataSourceInfo(
      scripted,
    );
  }

  // The registry is process-wide static state, so it is cleared after every
  // test rather than left for the next file to trip over.
  tearDown(() => TomDataSourceInfo.datasources.remove(_fixtureDatasource));

  /// Matches a [TomRepositoryException] carrying exactly [key].
  Matcher repositoryError(String key) => isA<TomRepositoryException>()
      .having((e) => e.key, 'key', key)
      // Every one of these is an internal fault — a broken deployment, a
      // broken table, or a driver that reported success and then lost the row.
      // None of them is the client's to act on, and each message names server
      // internals.
      .having((e) => e.clientThrow, 'clientThrow', isFalse);

  /// Matches a [TomQuerySyntaxException] carrying exactly [key].
  Matcher sentenceError(String key) =>
      isA<TomQuerySyntaxException>().having((e) => e.key, 'key', key);

  group('a repository that cannot be built says so with a key', () {
    test('an unregistered datasource is a keyed repository error', () {
      // No `registerDatasource()`: the fixture entity names a data source that
      // only `test_database.dart` registers, so the lookup in the constructor
      // finds nothing. This is the one site of the seven that needs no scripted
      // answer — it fails before the repository can ask anything.
      TomDataSourceInfo.datasources.remove(_fixtureDatasource);
      expect(
        FixtureTaskRepository.new,
        throwsA(
          repositoryError(
            'crud_repository.constructor.datasource_not_registered',
          ),
        ),
      );
    });

    test('the message names the datasource and the entity', () {
      // Both halves are needed to act on it: the name to look for in the
      // configuration, and the class that asked for it.
      TomDataSourceInfo.datasources.remove(_fixtureDatasource);
      expect(
        FixtureTaskRepository.new,
        throwsA(
          isA<TomRepositoryException>()
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains(_fixtureDatasource),
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('FixtureTaskRecord'),
              ),
        ),
      );
    });
  });

  group('a broken row set is a keyed repository error', () {
    setUp(registerDatasource);

    test('two rows for one primary key', () async {
      // A primary key that matches twice means the table has lost its key
      // constraint. The repository cannot choose between the rows, and picking
      // the first would hide the corruption.
      scripted.answers.add([
        FixtureTaskRecord()..id = 1,
        FixtureTaskRecord()..id = 1,
      ]);
      await expectLater(
        FixtureTaskRepository().findById(1),
        throwsA(
          repositoryError('crud_repository.find_by_id.duplicate_primary_key'),
        ),
      );
    });

    test('one row for one primary key is not an error', () async {
      // The guard's other side: a single match still returns, so the new throw
      // cannot have been placed one branch too high.
      scripted.answers.add([FixtureTaskRecord()..id = 1]);
      expect(await FixtureTaskRepository().findById(1), isNotNull);
    });

    test('no row for one primary key is not an error either', () async {
      expect(await FixtureTaskRepository().findById(1), isNull);
    });
  });

  group('a count that did not return one row is a keyed repository error', () {
    setUp(registerDatasource);

    // The same guard stands in three methods, and before this change it stood
    // as three copies of the same four lines. Each keeps its own key, because a
    // handler that sees one wants to know which count failed; running all three
    // here is what stops the shared implementation from being wired to the
    // wrong key in one of them.
    final counts = <String, Future<TomDbInt> Function(FixtureTaskRepository)>{
      'crud_repository.count.illegal_count_result': (r) => r.count(),
      'crud_repository.count_by_query_sentence.illegal_count_result': (r) =>
          r.countByQuerySentence('count by title = :t', {'t': 'x'}),
      'crud_repository.count_by_query.illegal_count_result': (r) =>
          r.countByQuery(
            TomQuerySentenceCompiler([
                  FixtureTaskRecord,
                ]).compileQuerySentence('count by title = :t')
                as TomCount,
            {'t': 'x'},
          ),
    };

    for (final entry in counts.entries) {
      test('[${entry.key}]', () async {
        // The scripted source answers with no rows, which is what a `COUNT(*)`
        // must never do.
        await expectLater(
          entry.value(FixtureTaskRepository()),
          throwsA(repositoryError(entry.key)),
        );
      });
    }

    test('exactly one count row still returns the count', () async {
      // The shared guard has to pass the ordinary case through unchanged, and
      // the count it returns must be the row's, not the row *count*.
      scripted.answers.add([TomCountResult()..count = 42]);
      expect((await FixtureTaskRepository().count()).get(), 42);
    });
  });

  group('a write whose row cannot be read back is a keyed repository error', () {
    setUp(registerDatasource);

    test('an insert that stored nothing', () async {
      // The insert reports success and the read-back finds nothing: the row is
      // gone between two statements on the same connection. `save` is declared
      // to return the stored entity, so there is nothing truthful to return.
      scripted.generatedId = 7;
      await expectLater(
        FixtureTaskRepository().save(FixtureTaskRecord()..title = 'x'),
        throwsA(repositoryError('crud_repository.save.insert_not_readable')),
      );
    });

    test('an update whose row cannot be re-read', () async {
      await expectLater(
        FixtureTaskRepository().save(
          FixtureTaskRecord()
            ..id = 5
            ..title = 'y',
        ),
        throwsA(repositoryError('crud_repository.save.update_not_readable')),
      );
    });

    test('the two write paths do not share one key', () {
      // An insert that vanished and an update that vanished are different
      // faults — the first suspects the insert, the second suspects the row's
      // continued existence — so a handler must be able to tell them apart.
      expect(
        'crud_repository.save.insert_not_readable',
        isNot('crud_repository.save.update_not_readable'),
      );
    });
  });

  group('a sentence of the wrong kind is a query-syntax error', () {
    setUp(registerDatasource);

    // Each method compiles the caller's sentence and casts it to the one query
    // kind it can run. The cast is the boundary check, and an unguarded `as`
    // reports it in the vocabulary of the compiler's own class names.
    final mismatches = <String, Future<void> Function(FixtureTaskRepository)>{
      'crud_repository.find_by_query_sentence.sentence_verb_mismatch': (r) =>
          r.findByQuerySentence('count by title = :t', {'t': 'x'}),
      'crud_repository.delete_by_query_sentence.sentence_verb_mismatch': (r) =>
          r.deleteByQuerySentence('find by title = :t', {'t': 'x'}),
      'crud_repository.count_by_query_sentence.sentence_verb_mismatch': (r) =>
          r.countByQuerySentence('find by title = :t', {'t': 'x'}),
    };

    for (final entry in mismatches.entries) {
      test('[${entry.key}]', () async {
        await expectLater(
          entry.value(FixtureTaskRepository()),
          throwsA(sentenceError(entry.key)),
        );
      });
    }

    test('the message names the verb that was written', () async {
      // A caller who wrote `find by` needs to be told that *`find`* is the
      // wrong word here — not that `TomSelect` is not a `TomCount`.
      await expectLater(
        FixtureTaskRepository().countByQuerySentence('find by title = :t', {
          't': 'x',
        }),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.defaultUserMessage,
            'message',
            allOf(contains('count by'), contains('find by title = :t')),
          ),
        ),
      );
    });

    test('a matching verb is not refused', () async {
      // The guard must reject only the mismatch. `count by` through
      // `countByQuerySentence` reaches the count guard instead, which is a
      // different key — proof that the cast was passed rather than skipped.
      await expectLater(
        FixtureTaskRepository().countByQuerySentence('count by title = :t', {
          't': 'x',
        }),
        throwsA(
          repositoryError(
            'crud_repository.count_by_query_sentence.illegal_count_result',
          ),
        ),
      );
    });
  });

  group('the module raises no unkeyed errors', () {
    // A guard on the source rather than on behaviour. The seven sites were not
    // written in one sitting and would not be reintroduced in one either: what
    // keeps them out is that `throw Exception(` is checked, not remembered.
    final source = File(
      'lib/src/tomserver/object_persistence/crud_repository.dart',
    ).readAsStringSync();

    test('no bare `throw Exception(` remains', () {
      expect(
        source,
        isNot(contains('throw Exception(')),
        reason:
            'every rejection in this module must carry a key a handler can '
            'match; raise a TomRepositoryException instead',
      );
    });

    test('every key it raises is scoped to this file', () {
      // `crud_repository.<method>.<condition>`: the prefix says where to look,
      // the middle says which entry point, the last says what went wrong. A key
      // that skips the middle segment cannot be told apart from its siblings —
      // which is exactly what the three count guards would otherwise share.
      final keys = RegExp(
        r"'(crud_repository\.[a-z0-9_.]+)'",
      ).allMatches(source).map((m) => m.group(1)!).toSet();
      expect(keys, isNotEmpty);
      for (final key in keys) {
        expect(
          key.split('.').length,
          3,
          reason: '[$key] should read crud_repository.<method>.<condition>',
        );
      }
    });

    test('every raise site in the file is keyed', () {
      // Counts the `throw` statements and requires each to name an exception
      // type from the server family. A new `throw StateError(...)` would fail
      // here even though it is not the string the first test looks for.
      final throws = RegExp(
        r'throw ([A-Za-z_][A-Za-z0-9_]*)\(',
      ).allMatches(source).map((m) => m.group(1)!).toSet();
      expect(
        throws,
        everyElement(matches(RegExp(r'^Tom[A-Za-z]*Exception$'))),
        reason: 'raise sites must use the module exception family',
      );
    });
  });
}
