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
/// Four further sites had the same shape without being `throw` statements at
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
/// The fourth is [TomSqlDatasourceRepository.delete], which read the entity's
/// primary key with a bare `as K`. `save` reads the same value through
/// [TomSqlDatasourceRepository.readPrimaryKey], which is null-tolerant precisely
/// because an entity that was never persisted carries a null or negative key —
/// so deleting an unsaved entity, an ordinary caller mistake, failed the cast
/// and surfaced `type 'Null' is not a subtype of type 'int'`. That names two
/// types the caller never wrote and does not say that the entity was never
/// saved.
///
/// **Connection-free.** The repository is driven against the scripted data
/// source in `fixtures/scripted_datasource.dart` rather than against a
/// database. Every failure under test is a decision the repository
/// makes *about an answer it was given*, so a real server would contribute
/// nothing but the ability to produce the answer — and two of these answers
/// (two rows for one primary key; a `COUNT(*)` returning no row at all) are
/// states a correct server will not produce on request.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureKeylessRepository, FixtureTaskRecord, FixtureTaskRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/scripted_datasource.dart';

void main() {
  setUpAll(initializeReflection);

  late ScriptedDataSource scripted;

  /// Registers the scripted data source under the name the fixture entity
  /// declares, so `FixtureTaskRepository()` can be constructed.
  void registerDatasource() {
    scripted = registerScriptedDatasource();
  }

  // The registry is process-wide static state, so it is cleared after every
  // test rather than left for the next file to trip over.
  tearDown(unregisterScriptedDatasource);

  /// Matches a [TomRepositoryException] carrying exactly [key].
  Matcher repositoryError(String key) => isA<TomRepositoryException>()
      .having((e) => e.key, 'key', key)
      // Every one of these is an internal fault — a broken deployment, a
      // broken table, or a driver that reported success and then lost the row.
      // None of them is the client's to act on, and each message names server
      // internals.
      .having((e) => e.clientThrow, 'clientThrow', isFalse);

  /// Matches a [TomRepositoryException] carrying exactly [key] whose message is
  /// meant for the caller.
  ///
  /// The counterpart of [repositoryError]: the same type, the opposite
  /// disposition. This one is raised for something the caller did and can undo,
  /// and its message names nothing but that — so it travels, where the type's
  /// `false` default would leave a client facing a masked internal error for a
  /// mistake it could have corrected.
  Matcher callerError(String key) => isA<TomRepositoryException>()
      .having((e) => e.key, 'key', key)
      .having((e) => e.clientThrow, 'clientThrow', isTrue);

  /// Matches a [TomQuerySyntaxException] carrying exactly [key].
  Matcher sentenceError(String key) =>
      isA<TomQuerySyntaxException>().having((e) => e.key, 'key', key);

  group('a repository that cannot be built says so with a key', () {
    test('an entity that lists no key field is refused', () {
      // Every by-key method addresses a row by its key fields, so an entity
      // with none could address nothing; it is refused at construction, before
      // the first method call could fail less clearly.
      expect(
        FixtureKeylessRepository.new,
        throwsA(repositoryError('crud_repository.constructor.no_primary_key')),
      );
    });

    test('an unregistered datasource is a keyed repository error', () {
      // No `registerDatasource()`: the fixture entity names a data source that
      // only `test_database.dart` registers, so the lookup in the constructor
      // finds nothing. This is the one site of the seven that needs no scripted
      // answer — it fails before the repository can ask anything.
      unregisterScriptedDatasource();
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
      unregisterScriptedDatasource();
      expect(
        FixtureTaskRepository.new,
        throwsA(
          isA<TomRepositoryException>()
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains(fixtureDatasourceName),
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

    test('a driver that reports no generated key is refused by name', () async {
      // The scripted source leaves `generatedId` null, which is what a driver
      // that never implemented `generatedId` answers for every insert.
      // `save` asked the database to assign the key, so there is no key to
      // return and nothing later in the method can be about the right row.
      expect(scripted.generatedId, isNull);
      await expectLater(
        FixtureTaskRepository().save(FixtureTaskRecord()..title = 'x'),
        throwsA(repositoryError('crud_repository.save.no_generated_key')),
      );
    });

    test('the refusal names the table and the driver', () async {
      // Both halves are the diagnosis: the table is where an author looks for a
      // missing AUTO_INCREMENT, the driver is where they look for an
      // unimplemented `generatedId`, and the message cannot say which of
      // the two it is.
      await expectLater(
        FixtureTaskRepository().save(FixtureTaskRecord()..title = 'x'),
        throwsA(
          isA<TomRepositoryException>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('fixture_task'),
              contains('ScriptedDataSource'),
              contains('generatedId'),
            ),
          ),
        ),
      );
    });

    test('a missing key and an unreadable row are different faults', () {
      // An insert that reported no key never produced one to read back, so it
      // cannot also be the row that vanished — and the two are fixed in
      // different places, the driver or the table against the row.
      expect(
        'crud_repository.save.no_generated_key',
        isNot('crud_repository.save.insert_not_readable'),
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

  group('deleting an entity that was never saved is a keyed caller error', () {
    setUp(registerDatasource);

    // `isUnsavedKey` accepts two conventions, and `delete` has to refuse both.
    // The null arrives from a nullable surrogate key before its first persist;
    // the negative sentinel from the `id >= 0` convention. They failed
    // *differently* before this change — null threw a `TypeError` from the
    // cast, while `-1` passed the cast and ran a `DELETE` that matched no row,
    // reporting success for a deletion that never happened. The second is the
    // worse of the two, and the one no stack trace would have revealed.
    final unsaved = <String, FixtureTaskRecord>{
      'a null surrogate key': FixtureTaskRecord()..title = 'never saved',
      'a negative sentinel key': FixtureTaskRecord()
        ..id = -1
        ..title = 'never saved',
    };

    for (final entry in unsaved.entries) {
      test('[${entry.key}]', () async {
        await expectLater(
          FixtureTaskRepository().delete(entry.value),
          throwsA(callerError('crud_repository.delete.unsaved_entity')),
        );
      });
    }

    test('it is not a TypeError', () async {
      // The point of the change. A `TypeError` is not in the server exception
      // family, so it is not auto-logged, carries no key to match on, and
      // reaches the endpoints pipeline unclassified.
      await expectLater(
        FixtureTaskRepository().delete(FixtureTaskRecord()),
        throwsA(isA<TomServerException>()),
      );
    });

    test('the message names the entity, not the cast', () async {
      await expectLater(
        FixtureTaskRepository().delete(FixtureTaskRecord()),
        throwsA(
          isA<TomRepositoryException>()
              .having(
                (e) => e.parameters,
                'parameters',
                containsPair('entity', 'FixtureTaskRecord'),
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                isNot(anyOf(contains('Null'), contains('subtype'))),
              ),
        ),
      );
    });

    test('a saved entity is still deleted', () async {
      // The guard's other side: it must refuse only the unsaved key. A record
      // carrying a real id goes through untouched, which is what stops the
      // check from being written one branch too high.
      await FixtureTaskRepository().delete(FixtureTaskRecord()..id = 5);
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
