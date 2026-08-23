/// DB-backed verification of what an **optional column** must be declared as on
/// a persistent entity (`qrc1`).
///
/// `tom_core_kernel` ships two ways to spell "this value may be absent" on a
/// member: a plain nullable Dart field (`String?`) and a nullable observable
/// (`TomNString`). Both *read* — the row mapper normalises a `String?` onto
/// `String` before dispatching, which is what CSEXF1 fixed. That symmetry on the
/// read side is exactly why the choice looks free and is not.
///
/// The **write** side is a different mechanism.
/// [TomSqlDatasourceRepository.save] binds each column from
/// `TomColumnInformation.getVariableValue`, which is `invokeGetter(declaredName)`
/// — the field itself. On a plain field that is the value; on an observable
/// member it is the `TomNString` *object*, which is not something the driver can
/// bind. So only one of the two shapes round-trips, and this file pins which.
///
/// That is the ground under the CodeSpecs `@CsColumn` emission rule
/// (`codespecs_derivation_contract.md` §3.3.2): an optional CE-DB attribute
/// emits `T?`, never `TomN*`. The rule is a documentation act, but it is only
/// worth writing down if the alternative is genuinely unavailable — so both arms
/// are exercised here rather than one being asserted about.
///
/// Two groups, and both matter:
///
///  - **the plain-field arm round-trips**, for all five persistable value types,
///    with values *and* with SQL `NULL` — because a write that stores and a read
///    that returns the initial value are indistinguishable unless the null case
///    is checked separately;
///  - **the observable arm does not**, which is the evidence rather than a
///    claim. If someone later teaches the repository to unwrap observables, this
///    test goes red and the documented rule gets revisited deliberately instead
///    of quietly becoming wrong.
///
/// The group is `@Tags(['db'])` and skips itself when no MariaDB is reachable,
/// so the default `testkit :test` run stays green everywhere. Bring a server up
/// with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureNullableRecord,
        FixtureNullableRepository,
        FixtureOptionalColumnRecord,
        FixtureOptionalColumnRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The reference instant.
///
/// **UTC**, because that is what a `DateTime` column round-trips as: the
/// datasource writes every instant as UTC text and reads it back UTC-flagged
/// (`datasources/sql_instant.dart`), and `DateTime.==` compares the flag as well
/// as the moment. A local value here would fail on the flag alone and say
/// nothing about optionality.
///
/// Seconds-resolution and no sub-second part, because the column is a plain
/// `DATETIME`: a microsecond component would be rounded by the database and the
/// assertion would fail for a reason that has nothing to do with optionality
/// either.
final DateTime _occurred = DateTime.utc(2026, 3, 4, 5, 6, 7);

/// A record with every optional column populated.
FixtureOptionalColumnRecord _populated() => FixtureOptionalColumnRecord()
  ..name = 'widget'
  ..ratio = 2.5
  ..quantity = 7
  ..active = true
  ..occurredAt = _occurred;

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('optional column emission', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureNullableTable(dsi);
    });

    setUp(() => TestDatabase.truncateFixtureNullable(dsi));

    tearDownAll(TestDatabase.reset);

    group('plain nullable field (the emitted arm)', () {
      test('persists and re-reads every one of the five value types', () async {
        final repo = FixtureOptionalColumnRepository();

        final saved = await repo.save(_populated());
        expect(saved.id, isNotNull);

        // Re-read rather than trusting what `save` returned, so the assertion
        // covers the storage round trip and not just the in-memory object.
        final loaded = await repo.findById(saved.id!);
        expect(loaded, isNotNull);
        // isA<T> on each, not just the value: a String that happens to print as
        // "2.5" would satisfy a loose equality matcher.
        expect(loaded!.name, isA<String>());
        expect(loaded.name, 'widget');
        expect(loaded.ratio, isA<double>());
        expect(loaded.ratio, closeTo(2.5, 1e-9));
        expect(loaded.quantity, isA<int>());
        expect(loaded.quantity, 7);
        expect(loaded.active, isA<bool>());
        expect(loaded.active, isTrue);
        expect(loaded.occurredAt, isA<DateTime>());
        expect(loaded.occurredAt, _occurred);
      });

      test(
        'stores an absent value as SQL NULL and reads it back as null',
        () async {
          final repo = FixtureOptionalColumnRepository();

          // Every optional column left unset — the state the whole rule exists to
          // make representable.
          final saved = await repo.save(FixtureOptionalColumnRecord());
          final loaded = await repo.findById(saved.id!);

          expect(loaded, isNotNull);
          expect(loaded!.name, isNull);
          expect(loaded.ratio, isNull);
          expect(loaded.quantity, isNull);
          expect(loaded.active, isNull);
          expect(loaded.occurredAt, isNull);

          // …and it is a real SQL NULL, not an empty string or a zero that reads
          // back as absent. Asked of the database directly, because that is the
          // only place the distinction survives.
          final counts = await dsi.datasource.executeQuery<TomCountResult>(
            'SELECT COUNT(*) AS count FROM fixture_nullable '
            'WHERE name IS NULL AND ratio IS NULL AND quantity IS NULL '
            'AND active IS NULL AND occurred_at IS NULL',
            null,
            TomCountResult,
          );
          expect(counts.single.count, 1);
        },
      );

      test('an absent value survives being written over a present one', () async {
        final repo = FixtureOptionalColumnRepository();

        final saved = await repo.save(_populated());
        saved.name = null;
        saved.occurredAt = null;
        await repo.save(saved);

        // The UPDATE path is a separate statement builder from the INSERT path,
        // so clearing a column is its own case: a save that silently kept the
        // previous value would pass the insert test and still be wrong.
        final loaded = await repo.findById(saved.id!);
        expect(loaded!.name, isNull);
        expect(loaded.occurredAt, isNull);
        // Untouched columns are unchanged — otherwise "cleared" could just mean
        // the update wrote nulls everywhere.
        expect(loaded.quantity, 7);
        expect(loaded.active, isTrue);
      });
    });

    group('nullable observable member (the rejected arm)', () {
      test('cannot be written through the shipped repository', () async {
        final repo = FixtureNullableRepository();

        final record = FixtureNullableRecord()..name.set('widget');

        // The failure is the point, and so is its shape. `save` reads each
        // column with `invokeGetter`, which returns the `TomNInt` object rather
        // than the `int?` it holds — the very first thing `save` does with it is
        // cast it to the key type, and that is where it comes apart. Matching
        // the message rather than just `throwsA(anything)` keeps the test
        // pinned to *this* mechanism: an unrelated failure (a missing table, a
        // closed connection) would otherwise let it pass while proving nothing.
        await expectLater(
          repo.save(record),
          throwsA(
            isA<TypeError>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('TomNInt'), contains('int?')),
            ),
          ),
        );
      });

      test(
        'read-back still works, which is why the asymmetry is easy to miss',
        () async {
          // Inserted directly: the observable arm has no write path, which is the
          // previous test's subject.
          await dsi.datasource.executeCommand(
            "INSERT INTO fixture_nullable (name) VALUES ('widget')",
          );

          final rows = await dsi.datasource.executeQuery<FixtureNullableRecord>(
            'SELECT id, name, ratio, quantity, active, occurred_at '
            'FROM fixture_nullable',
          );

          // Mapping in is fine — so a spec author choosing observables for an
          // entity would see it work, right up to the first save.
          expect(rows.single.name.get(), 'widget');
        },
      );
    });
  }, skip: skipReason);
}
