/// DB-backed tests for mapping a result row onto **nullable observable
/// members** of a `TomClass`.
///
/// `TomObject<T>.getType()` returns `T` exactly as declared, so a `TomNString`
/// answers `String?` and a `TomNDouble` answers `double?`. Both `TomClass`
/// mapping variants in `MariaDbDatasource.mapResultSet` switched on that
/// answer against bare `case String:` / `case double:` patterns, which a
/// nullable type never matches — so every such member fell through to the
/// `default:` branch and was refused by name with
/// `error.result_processing_tcp.unknown_type` /
/// `error.result_processing_tc.unknown_type`.
///
/// That made a whole ordinary shape unmappable: the nullable observables are
/// the natural choice for a column that can be `NULL`, which is most columns.
/// A holder with a single `TomNString` over a plain `VARCHAR` was enough to
/// trigger it — no `DECIMAL`, no aggregate, no driver quirk involved. The
/// fixtures here use deliberately plain column types for exactly that reason:
/// anything exotic would blur this defect with the driver's separate `NEWDECIMAL`
/// gap.
///
/// Three things are pinned, and all three matter:
///
///  - **both** `TomClass` variants — the table-less one (bound by member name)
///    and the `@TomDbTable` one (bound by persistent column) — because they are
///    near-duplicate switches that carried the same defect, so a fix verified
///    on one of them is half a fix;
///  - **every** supported element type, because the defect was in the dispatch
///    rather than in any one conversion; handling `String?` alone would leave
///    the other four still refused;
///  - a real SQL `NULL` arriving as Dart `null`, because a nullable member that
///    maps but silently keeps its initial value is still wrong — and the
///    `DateTime` branch did precisely that, having only assigned when the raw
///    column was non-null.
///
/// The group is `@Tags(['db'])` and skips itself when no MariaDB is reachable,
/// so the default `testkit :test` run stays green everywhere. Bring a server up
/// with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureNullableObservable, FixtureNullableRecord;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The instant the populated row's `occurred_at` column holds.
///
/// **UTC**, matching the raw characters the row is inserted with. A `DATETIME`
/// column carries no zone, and the framework's convention is that the zone it
/// omits is UTC — the datasource writes instants as UTC text and reads them
/// back UTC-flagged (`datasources/sql_instant.dart`). `DateTime.==` compares
/// the flag as well as the moment, so asserting the local reading of the same
/// characters would be asserting that a row means something different on every
/// node that loads it.
final DateTime _occurredAt = DateTime.utc(2026, 3, 4, 5, 6, 7);

void main() async {
  // Probe once, before declaring the group, so the group can skip when nothing
  // is listening — keeping the default run green with no database.
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('nullable observable members on the TomClass mapping paths', () {
    late TomDataSourceInfo dsi;
    late TomSqlDatasource ds;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      ds = dsi.datasource as TomSqlDatasource;
      await TestDatabase.ensureFixtureNullableTable(dsi);
    });

    setUp(() => TestDatabase.truncateFixtureNullable(dsi));

    tearDownAll(TestDatabase.reset);

    /// Inserts one fully-populated row directly, so the read under test is not
    /// also asserting the write path.
    Future<void> insertPopulatedRow() => ds.executeCommand(
      'INSERT INTO fixture_nullable '
      '(name, ratio, quantity, active, occurred_at) '
      "VALUES ('widget', 2.5, 7, 1, '2026-03-04 05:06:07')",
    );

    /// Inserts one row whose every value column is SQL `NULL`.
    Future<void> insertNullRow() => ds.executeCommand(
      'INSERT INTO fixture_nullable '
      '(name, ratio, quantity, active, occurred_at) '
      'VALUES (NULL, NULL, NULL, NULL, NULL)',
    );

    /// The table-less variant binds by member name, so `occurred_at` is
    /// projected under the member's own spelling.
    const String tableLessSelect =
        'SELECT name, ratio, quantity, active, occurred_at AS occurredAt '
        'FROM fixture_nullable';

    /// The annotated variant binds by `@TomDbColumn`, so the columns are
    /// projected under their own names.
    const String annotatedSelect =
        'SELECT id, name, ratio, quantity, active, occurred_at '
        'FROM fixture_nullable';

    group('table-less TomClass (bound by member name)', () {
      test('maps every nullable element type', () async {
        await insertPopulatedRow();

        final rows = await ds.executeQuery<FixtureNullableObservable>(
          tableLessSelect,
        );

        expect(rows, hasLength(1));
        final row = rows.single;
        // isA<T> on each, not just the value: a String that happens to print
        // as "2.5" would satisfy a loose equality matcher.
        expect(row.name.get(), isA<String>());
        expect(row.name.get(), 'widget');
        expect(row.ratio.get(), isA<double>());
        expect(row.ratio.get(), closeTo(2.5, 1e-9));
        expect(row.quantity.get(), isA<int>());
        expect(row.quantity.get(), 7);
        expect(row.active.get(), isA<bool>());
        expect(row.active.get(), isTrue);
        expect(row.occurredAt.get(), isA<DateTime>());
        expect(row.occurredAt.get(), _occurredAt);
      });

      test('carries a SQL NULL through as null', () async {
        await insertNullRow();

        final rows = await ds.executeQuery<FixtureNullableObservable>(
          tableLessSelect,
        );

        final row = rows.single;
        expect(row.name.get(), isNull);
        expect(row.ratio.get(), isNull);
        expect(row.quantity.get(), isNull);
        expect(row.active.get(), isNull);
        // The one that did not merely fail to map but silently kept its
        // initial value: the DateTime branch only assigned when the raw column
        // was non-null, so a NULL left the member untouched.
        expect(row.occurredAt.get(), isNull);
      });
    });

    group('@TomDbTable TomClass (bound by persistent column)', () {
      test('maps every nullable element type', () async {
        await insertPopulatedRow();

        final rows = await ds.executeQuery<FixtureNullableRecord>(
          annotatedSelect,
        );

        expect(rows, hasLength(1));
        final row = rows.single;
        expect(row.id.get(), isA<int>());
        expect(row.name.get(), isA<String>());
        expect(row.name.get(), 'widget');
        expect(row.ratio.get(), isA<double>());
        expect(row.ratio.get(), closeTo(2.5, 1e-9));
        expect(row.quantity.get(), isA<int>());
        expect(row.quantity.get(), 7);
        expect(row.active.get(), isA<bool>());
        expect(row.active.get(), isTrue);
        expect(row.occurredAt.get(), isA<DateTime>());
        expect(row.occurredAt.get(), _occurredAt);
      });

      test('carries a SQL NULL through as null', () async {
        await insertNullRow();

        final rows = await ds.executeQuery<FixtureNullableRecord>(
          annotatedSelect,
        );

        final row = rows.single;
        expect(row.name.get(), isNull);
        expect(row.ratio.get(), isNull);
        expect(row.quantity.get(), isNull);
        expect(row.active.get(), isNull);
        expect(row.occurredAt.get(), isNull);
      });

      test('a member whose column name differs from it still binds', () async {
        await insertPopulatedRow();

        final rows = await ds.executeQuery<FixtureNullableRecord>(
          annotatedSelect,
        );

        // `occurredAt` is declared over the column `occurred_at`; the table-less
        // variant could not express that, so this assertion only means anything
        // on the annotated one.
        expect(rows.single.occurredAt.get(), isNotNull);
      });
    });
  }, skip: skipReason);
}
