/// DB-backed round trip for the two halves a timestamp splits into: a
/// `TomZonedDate` through a `DATE` column and a `TomZonedTime` through a `TIME`
/// one.
///
/// The framework has mapped both Dart types to their SQL families for as long
/// as either existed, and both directions were covered: the renderers were
/// asserted against each other, and the readers against strings a test wrote by
/// hand. What no test did was complete the circle — write a value through the
/// framework and read that same row back — and the circle is exactly where the
/// two disagreed. `sqlDate` and `sqlTimeOfDay` wrote `'2026-07-15'` and
/// `'14:30:05'`; `TomDbDate.of` and `TomDbTime.of` read Tom's `@D@…` / `@T@…`
/// serialization and nothing else, so every value the framework stored in one
/// of these columns threw when it came back.
///
/// A live server is the only place that fact is observable, because it is the
/// database that turns the written literal into the text the reader is handed.
/// A hand-built string proves nothing about what MariaDB stores a `TIME` as.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default run stays green everywhere. Bring a server up with
/// `tool/run_db_tests.sh`.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTemporalRecord, FixtureTemporalRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('a DATE and a TIME column round-trip their Dart types', () {
    late TomDataSourceInfo dsi;
    late FixtureTemporalRepository repo;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureTemporalTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureTemporal(dsi);
      repo = FixtureTemporalRepository();
    });

    tearDownAll(TestDatabase.reset);

    /// Saves [record] and reads it back by its assigned key, which is the whole
    /// point: reading the returned instance would assert the value the caller
    /// already held rather than the one the database now holds.
    Future<FixtureTemporalRecord> roundTrip(
      FixtureTemporalRecord record,
    ) async {
      final saved = await repo.save(record);
      final read = await repo.findById(saved.id!);
      expect(read, isNotNull, reason: 'the row that was just written');
      return read!;
    }

    test('a date is stored and read back naming the same day', () async {
      final read = await roundTrip(
        FixtureTemporalRecord()
          ..label = 'plain'
          ..dueOn = TomZonedDate(year: 2026, month: 7, day: 15),
      );
      expect(read.dueOn, isNotNull);
      expect(read.dueOn!.year, 2026);
      expect(read.dueOn!.month, 7);
      expect(read.dueOn!.day, 15);
    });

    test('a time is stored and read back naming the same reading', () async {
      final read = await roundTrip(
        FixtureTemporalRecord()
          ..label = 'plain'
          ..remindAt = TomZonedTime(hour: 14, minute: 30, second: 5),
      );
      expect(read.remindAt, isNotNull);
      expect(read.remindAt!.hour, 14);
      expect(read.remindAt!.minute, 30);
      expect(read.remindAt!.second, 5);
    });

    test(
      'a zone-anchored date keeps the day it names, not the day it stores',
      () async {
        // Fourteen hours east, so the day the value names locally and the day it
        // holds internally are different ones. On a UTC-anchored value every rule
        // agrees by accident, which is what hides a zone defect — and this one
        // was hidden: the renderer read the inherited UTC components, so the 5th
        // in Kiritimati was written as the 4th.
        final read = await roundTrip(
          FixtureTemporalRecord()
            ..label = 'east'
            ..dueOn = TomZonedDate(
              year: 2026,
              month: 7,
              day: 5,
              timezone: TomTimezone.fromName('Pacific/Kiritimati'),
            ),
        );
        expect(read.dueOn!.day, 5);
        expect(read.dueOn!.month, 7);
      },
    );

    test('a zone-anchored time keeps the reading it names', () async {
      final read = await roundTrip(
        FixtureTemporalRecord()
          ..label = 'tokyo'
          ..remindAt = TomZonedTime(
            hour: 14,
            minute: 30,
            timezone: TomTimezone.fromName('Asia/Tokyo'),
          ),
      );
      expect(read.remindAt!.hour, 14);
      expect(read.remindAt!.minute, 30);
    });

    test(
      'the zone itself does not come back, because the column has none',
      () async {
        // The cost of a native `TIME`, asserted rather than described: the column
        // holds `'14:30:00'` and has nowhere to put `Asia/Tokyo`, so the value
        // returns anchored in UTC. A deployment that needs the zone stores the
        // serialized form in a text column.
        final read = await roundTrip(
          FixtureTemporalRecord()
            ..label = 'tokyo'
            ..remindAt = TomZonedTime(
              hour: 14,
              minute: 30,
              timezone: TomTimezone.fromName('Asia/Tokyo'),
            ),
        );
        expect(read.remindAt!.timezone, TomTimezone.utc);
      },
    );

    test('a NULL column reads back as null, not as a parse failure', () async {
      final read = await roundTrip(FixtureTemporalRecord()..label = 'empty');
      expect(read.dueOn, isNull);
      expect(read.remindAt, isNull);
    });

    test('both halves survive one row together', () async {
      // Written as one row because that is the shape an entity actually has,
      // and because a mapper that handled each column type in isolation could
      // still bind them to the wrong fields.
      final read = await roundTrip(
        FixtureTemporalRecord()
          ..label = 'both'
          ..dueOn = TomZonedDate(year: 2026, month: 12, day: 31)
          ..remindAt = TomZonedTime(hour: 23, minute: 59, second: 59),
      );
      expect(read.dueOn!.day, 31);
      expect(read.dueOn!.month, 12);
      expect(read.remindAt!.hour, 23);
      expect(read.remindAt!.second, 59);
    });
  }, skip: skipReason);

  group(
    'a DATETIME(6) column round-trips the instant, fraction included',
    () {
      late TomDataSourceInfo dsi;
      late FixtureTemporalRepository repo;

      setUpAll(() async {
        initializeReflection();
        dsi = await TestDatabase.register();
        await TestDatabase.ensureFixtureTemporalTable(dsi);
      });

      setUp(() async {
        await TestDatabase.truncateFixtureTemporal(dsi);
        repo = FixtureTemporalRepository();
      });

      tearDownAll(TestDatabase.reset);

      // A repository reads through a prepared statement, so the row comes back
      // over MySQL's binary protocol, where the driver renders the microsecond
      // field as a bare integer: 91 371 µs arrived as `.91371`, which any parser
      // reads as 0.91371 s. Every instant whose fraction is under a tenth of a
      // second was read back up to 0.9 s late — one value in ten, silently. The
      // leading-zero cases are the ones that tell; the rest are controls.
      for (final micros in [91371, 5, 99999, 1, 100000, 913710, 0, 999999]) {
        test('a fraction of $micros µs survives', () async {
          final written = DateTime.utc(2026, 9, 30, 5, 42, 27, 0, micros);
          final saved = await repo.save(
            FixtureTemporalRecord()
              ..label = 'instant'
              ..occurredAt = written,
          );
          final read = await repo.findById(saved.id!);
          expect(read?.occurredAt, written);
          // The instant as the repository hands back from `save` goes through
          // the same reader, and `save`'s re-read is what the preferences
          // store's `updatedAt` came from when this was first seen.
          expect(saved.occurredAt, written);
        });
      }

      test(
        'the repair is for binary rows only: a text-protocol DATETIME(3) keeps '
        'its milliseconds',
        () async {
          // The same digits mean different things per protocol. Over the text
          // protocol the server formats the value with the column's precision, so
          // `.091` from a DATETIME(3) is 91 ms; a repair applied to every row
          // would pad it to 91 µs. `executeQuery` reads over the text protocol,
          // and the cast gives the column a precision below six.
          await repo.save(
            FixtureTemporalRecord()
              ..label = 'text'
              ..occurredAt = DateTime.utc(2026, 9, 30, 5, 42, 27, 91, 371),
          );
          final rows = await dsi.datasource.executeQuery<FixtureTemporalRecord>(
            'SELECT id, label, CAST(occurred_at AS DATETIME(3)) AS occurred_at '
            'FROM fixture_temporal',
          );
          expect(
            rows.single.occurredAt,
            DateTime.utc(2026, 9, 30, 5, 42, 27, 91),
          );
        },
        skip: TestDatabase.onlyOnMariaDb(
          'the binary-protocol fraction repair is the MariaDB client\'s',
        ),
      );
    },
    skip: skipReason,
  );
}
