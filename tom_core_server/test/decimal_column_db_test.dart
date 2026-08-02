/// DB-backed tests for reading `DECIMAL` columns on the entity-mapping paths
/// (CSEXE1).
///
/// `mysql_client` converts a driver column to a Dart `double` only from a fixed
/// whitelist of protocol types — TINY, SHORT, LONG, LONGLONG, INT24, FLOAT,
/// DOUBLE. `NEWDECIMAL` (246), which is what MariaDB reports for every
/// `DECIMAL` column, is in neither that list nor the corresponding `int` one,
/// so `ResultSetRow.typedColByName<double>` *throws* rather than widening. The
/// grouped-row mapper worked around this for aggregates (CSEXD1); the four
/// entity-mapping variants and the `TomDbType` boxing path did not, which made
/// every entity with a money column unreadable.
///
/// These tests pin the behaviour on all of those paths at once, because the fix
/// is a single shared reader and a per-path regression would otherwise be
/// invisible:
///
/// - the annotated-entity path, through a repository round-trip and a direct
///   `executeQuery` (the variant almost every real entity takes);
/// - the table-less reflected holder, mapped by field name from an aggregate;
/// - the two `TomClass` variants, mapped by observable member;
/// - `SUM`/`AVG` over a `DECIMAL` column, which is `NEWDECIMAL` twice over.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring
/// a server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureAmountObservable,
        FixtureAmountRecord,
        FixtureAmountRepository,
        FixtureAmountSummary;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

void main() async {
  // Probe once, before declaring the group, so the group can skip when nothing
  // is listening — keeping the default run green with no database.
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('DECIMAL columns on the entity-mapping paths', () {
    late TomDataSourceInfo dsi;
    late MariaDbDatasource ds;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      ds = dsi.datasource as MariaDbDatasource;
      await TestDatabase.ensureFixtureAmountTable(dsi);
    });

    setUp(() => TestDatabase.truncateFixtureAmount(dsi));

    tearDownAll(TestDatabase.reset);

    /// Inserts one row directly, so the read under test is not also asserting
    /// the write path.
    Future<void> insertRow(
      String label,
      String amount,
      String quantity,
    ) => ds.executeCommand(
      'INSERT INTO fixture_amount (label, amount, quantity) '
      "VALUES ('$label', $amount, $quantity)",
    );

    test(
      'annotated entity with a DECIMAL column reads through executeQuery',
      () async {
        await insertRow('rent', '1234.56', '3');

        final rows = await ds.executeQuery<FixtureAmountRecord>(
          'SELECT id, label, amount, quantity FROM fixture_amount ORDER BY id',
        );

        expect(rows, hasLength(1));
        expect(rows.single.label, 'rent');
        // The value, and that it really is a Dart double — a String that
        // happens to print as "1234.56" would satisfy a loose matcher.
        expect(rows.single.amount, isA<double>());
        expect(rows.single.amount, closeTo(1234.56, 1e-9));
      },
    );

    test('DECIMAL(10,0) reads onto an int-declared field', () async {
      await insertRow('crates', '10.00', '42');

      final rows = await ds.executeQuery<FixtureAmountRecord>(
        'SELECT id, label, amount, quantity FROM fixture_amount',
      );

      expect(rows.single.quantity, isA<int>());
      expect(rows.single.quantity, 42);
    });

    test('a DECIMAL entity round-trips through the repository', () async {
      final repo = FixtureAmountRepository();
      final saved = await repo.save(
        FixtureAmountRecord()
          ..label = 'invoice'
          ..amount = 99.99
          ..quantity = 7,
      );

      expect(saved.id, isNotNull);
      expect(saved.amount, closeTo(99.99, 1e-9));
      expect(saved.quantity, 7);

      final read = await repo.findById(saved.id!);
      expect(read, isNotNull);
      expect(read!.amount, isA<double>());
      expect(read.amount, closeTo(99.99, 1e-9));
      expect(read.quantity, 7);
    });

    test('a negative DECIMAL keeps its sign and scale', () async {
      await insertRow('refund', '-42.05', '-1');

      final rows = await ds.executeQuery<FixtureAmountRecord>(
        'SELECT id, label, amount, quantity FROM fixture_amount',
      );

      expect(rows.single.amount, closeTo(-42.05, 1e-9));
      expect(rows.single.quantity, -1);
    });

    test('a NULL DECIMAL reads as null, not as zero', () async {
      await ds.executeCommand(
        "INSERT INTO fixture_amount (label, amount, quantity) "
        "VALUES ('empty', NULL, NULL)",
      );

      final rows = await ds.executeQuery<FixtureAmountRecord>(
        'SELECT id, label, amount, quantity FROM fixture_amount',
      );

      expect(rows.single.amount, isNull);
      expect(rows.single.quantity, isNull);
    });

    test(
      'a table-less reflected holder maps a DECIMAL aggregate by field name',
      () async {
        await insertRow('a', '10.50', '1');
        await insertRow('b', '4.50', '2');

        // SUM over a DECIMAL column is itself NEWDECIMAL, so this reaches the
        // gap through the by-field-name mapping variant.
        final rows = await ds.executeQuery<FixtureAmountSummary>(
          'SELECT SUM(amount) AS total, COUNT(*) AS entries '
          'FROM fixture_amount',
        );

        expect(rows.single.total, isA<double>());
        expect(rows.single.total, closeTo(15.0, 1e-9));
        expect(rows.single.entries, 2);
      },
    );

    test('a TomClass result holder maps a DECIMAL by member', () async {
      await insertRow('boxed', '77.25', '5');

      final rows = await ds.executeQuery<FixtureAmountObservable>(
        'SELECT amount, quantity FROM fixture_amount',
      );

      expect(rows.single.amount.get(), isA<double>());
      expect(rows.single.amount.get(), closeTo(77.25, 1e-9));
      expect(rows.single.quantity.get(), 5);
    });

    // The `int` side of the decision (CSEXE1 step 4). The driver's `int`
    // whitelist omits NEWDECIMAL exactly as its `double` one does, so an
    // int-declared field over a DECIMAL column had to be given a defined
    // behaviour rather than inheriting the driver's refusal. The rule is:
    // read it when the value is exactly integral, refuse it by name when it is
    // not. Silent truncation is the one outcome that is never acceptable —
    // dropping the cents off a money column produces wrong numbers that no
    // assertion downstream would catch.
    test('an exactly integral DECIMAL reads onto an int field', () async {
      await insertRow('whole', '10.00', '1');

      final rows = await ds.executeQuery<FixtureAmountSummary>(
        'SELECT amount AS entries, 0 AS total FROM fixture_amount',
      );

      expect(rows.single.entries, 10);
    });

    test('a fractional DECIMAL on an int field is refused, not truncated', () {
      expect(
        () async {
          await insertRow('fractional', '1234.56', '1');
          await ds.executeQuery<FixtureAmountSummary>(
            'SELECT amount AS entries, 0 AS total FROM fixture_amount',
          );
        },
        throwsA(
          isA<MariadbDatasourceException>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('1234.56'), contains('entries')),
          ),
        ),
      );
    });

    test('AVG over a DECIMAL column reads as a double', () async {
      await insertRow('a', '10.00', '1');
      await insertRow('b', '20.00', '1');

      final rows = await ds.executeQuery<FixtureAmountSummary>(
        'SELECT AVG(amount) AS total, COUNT(*) AS entries FROM fixture_amount',
      );

      expect(rows.single.total, closeTo(15.0, 1e-9));
    });
  }, skip: skipReason);
}
