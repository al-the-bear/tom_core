/// Connection-free tests for the MariaDB row mapper's shape decision.
///
/// `MariaDbDatasource.mapResultSet` picks between five row shapes — a grouped
/// row, a table-less `TomClass`, an annotated `TomClass`, a plain reflected
/// holder and an annotated entity — and refuses a result type the reflector
/// does not hold. It is the largest decision in the module, and until this file
/// existed every branch of it was reachable only with a MariaDB listening: the
/// `db`-tagged suites cover the shapes well, and skip themselves on every
/// machine that has no server, which is the ordinary case. A decision that is
/// only checked when a database happens to be up has no regression protection
/// in the run people actually make.
///
/// **Why a fake result set is honest here.** `grouped_query_db_test.dart` warns
/// against exactly this shape of test: "a connection-free fake that hands back
/// an `int` where the driver hands back a decimal string would confirm the
/// claim while hiding the bug". That warning is about a fake that *invents* a
/// conversion. This one does not. The MySQL text protocol delivers every column
/// as text, so a driver row is fully described by `(column type, length, text)`
/// — and [_FakeRow] stores exactly that and hands typed reads to the driver's
/// own `MySQLColumnType.convertStringValueToProvidedType`, the same function
/// the real `ResultSetRow` calls. So `typedColByName<double>` over a
/// `NEWDECIMAL` column throws here for the same reason and from the same code
/// as against a live server, which is the fact the numeric readers exist to
/// work around.
///
/// What the fake cannot stand in for is what the *server* sends: which protocol
/// type a given SQL expression yields, and what text it puts in the column.
/// That stays the `db`-tagged suites' job — `decimal_column_db_test.dart` pins
/// the `NEWDECIMAL` spellings, `grouped_query_db_test.dart` the aggregate
/// widening. The two halves are complementary: those files establish what
/// arrives, this one establishes what the mapper does with it.
library;

import 'package:mysql_client/mysql_protocol.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureAmountSummary,
        FixtureExportRecord,
        FixtureNullableObservable,
        FixtureNullableRecord,
        FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// One column of a fake result row: what the server said it is, and the text it
/// sent.
///
/// [length] matters for exactly one conversion — `TINYINT(1)` is the only shape
/// the driver reads as a Dart `bool` — so it is carried rather than defaulted.
typedef _Cell = ({MySQLColumnType type, int length, String? text});

/// A `VARCHAR`-shaped text column.
_Cell _text(String? value) =>
    (type: MySQLColumnType.varStringType, length: 255, text: value);

/// An `INT` column.
_Cell _int(String? value) =>
    (type: MySQLColumnType.longType, length: 11, text: value);

/// A `DOUBLE` column.
_Cell _double(String? value) =>
    (type: MySQLColumnType.doubleType, length: 22, text: value);

/// A `DECIMAL` column — the protocol type whose absence from the driver's
/// int/double whitelists the numeric readers exist to absorb.
_Cell _decimal(String? value) =>
    (type: MySQLColumnType.newDecimalType, length: 12, text: value);

/// A `TINYINT(1)` column, the only shape the driver converts to `bool`.
_Cell _bool(bool? value) => (
  type: MySQLColumnType.tinyType,
  length: 1,
  text: value == null
      ? null
      : value
      ? '1'
      : '0',
);

/// A `DATETIME` column, carrying the text `sqlInstant` renders.
_Cell _instant(String? value) =>
    (type: MySQLColumnType.dateTimeType, length: 26, text: value);

/// A driver row whose typed reads are the driver's own.
///
/// Only the packet decoding is stood in for; every conversion is delegated to
/// [MySQLColumnType.convertStringValueToProvidedType], which is the entire body
/// of the real `ResultSetRow.typedColByName`.
class _FakeRow implements ResultSetRow {
  _FakeRow(this.cells);

  final Map<String, _Cell> cells;

  _Cell _cell(String name) {
    final cell = cells[name];
    if (cell == null) {
      // The real row raises this too, rather than answering null — a column
      // that was never selected is a query mistake, not a null value.
      throw MySQLClientException('There is no column with name: $name');
    }
    return cell;
  }

  @override
  int get numOfColumns => cells.length;

  @override
  String? colAt(int index) => cells.values.elementAt(index).text;

  @override
  String? colByName(String columnName) => _cell(columnName).text;

  @override
  T? typedColAt<T>(int index) {
    final cell = cells.values.elementAt(index);
    return cell.type.convertStringValueToProvidedType<T>(
      cell.text,
      cell.length,
    );
  }

  @override
  T? typedColByName<T>(String columnName) {
    final cell = _cell(columnName);
    return cell.type.convertStringValueToProvidedType<T>(
      cell.text,
      cell.length,
    );
  }

  @override
  Map<String, String?> assoc() => {
    for (final entry in cells.entries) entry.key: entry.value.text,
  };

  @override
  Map<String, dynamic> typedAssoc() => assoc();
}

/// A result set of [_FakeRow]s over one column list.
class _FakeResultSet extends IResultSet {
  _FakeResultSet(this._rows);

  final List<Map<String, _Cell>> _rows;

  @override
  int get numOfColumns => _rows.isEmpty ? 0 : _rows.first.length;

  @override
  int get numOfRows => _rows.length;

  @override
  BigInt get affectedRows => BigInt.zero;

  @override
  BigInt get lastInsertID => BigInt.zero;

  @override
  Iterable<ResultSetRow> get rows => _rows.map(_FakeRow.new);

  @override
  Iterable<ResultSetColumn> get cols =>
      (_rows.isEmpty ? const <MapEntry<String, _Cell>>[] : _rows.first.entries)
          .map(
            (entry) => ResultSetColumn(
              name: entry.key,
              type: entry.value.type,
              length: entry.value.length,
            ),
          );
}

/// A result set with one row of [cells].
IResultSet _oneRow(Map<String, _Cell> cells) => _FakeResultSet([cells]);

/// A result type the reflector does not hold, for the refusal.
///
/// Declared here rather than in the reflection fixture on purpose: the fixture
/// is the generator's root, so anything declared there *is* reflected, and a
/// type that cannot be reflected has to live outside it.
class UnreflectedResult {
  /// Never read — the mapper refuses the type before it looks at any member.
  int? value;
}

void main() {
  // The mapper resolves the result type by mirror, so reflection has to be
  // initialised even though no database is involved.
  setUpAll(initializeReflection);

  final ds = MariaDbDatasource();

  group('mapResultSet chooses the row shape from the result type', () {
    test('a grouped projection maps into TomGroupedRow', () async {
      final rows = await ds.mapResultSet<TomGroupedRow>(
        _oneRow({
          'label': _text('alpha'),
          'entries': _int('3'),
          'total': _decimal('15.50'),
          'active': _bool(true),
          'occurredAt': _instant('2026-03-04 05:06:07.123456'),
        }),
        TomGroupedRow,
        {
          'label': String,
          'entries': int,
          'total': double,
          'active': bool,
          'occurredAt': DateTime,
        },
      );

      final row = rows.single;
      expect(row.stringValue('label'), 'alpha');
      expect(row.intValue('entries'), 3);
      expect(row.doubleValue('total'), closeTo(15.50, 1e-9));
      expect(row.value('active'), isTrue);
      expect(
        row.dateTimeValue('occurredAt'),
        DateTime.utc(2026, 3, 4, 5, 6, 7, 123, 456),
      );
    });

    test('a table-less TomClass binds by member name', () async {
      final rows = await ds.mapResultSet<FixtureNullableObservable>(
        _oneRow({
          'name': _text('table-less'),
          'ratio': _double('2.5'),
          'quantity': _int('7'),
          'active': _bool(true),
          'occurredAt': _instant('2026-03-04 05:06:07.000000'),
        }),
      );

      final row = rows.single;
      expect(row.name.get(), 'table-less');
      expect(row.ratio.get(), closeTo(2.5, 1e-9));
      expect(row.quantity.get(), 7);
      expect(row.active.get(), isTrue);
      expect(row.occurredAt.get(), DateTime.utc(2026, 3, 4, 5, 6, 7));
    });

    test('an annotated TomClass binds by @TomDbColumn name', () async {
      // `occurred_at` rather than `occurredAt`: the annotated variant exists
      // precisely so a member may be named differently from its column, and a
      // mapper that fell back to the member name would find no column here.
      final rows = await ds.mapResultSet<FixtureNullableRecord>(
        _oneRow({
          'id': _int('42'),
          'name': _text('annotated'),
          'ratio': _double('0.5'),
          'quantity': _int('9'),
          'active': _bool(false),
          'occurred_at': _instant('2026-03-04 05:06:07.000000'),
        }),
      );

      final row = rows.single;
      expect(row.id.get(), 42);
      expect(row.name.get(), 'annotated');
      expect(row.ratio.get(), closeTo(0.5, 1e-9));
      expect(row.quantity.get(), 9);
      expect(row.active.get(), isFalse);
      expect(row.occurredAt.get(), DateTime.utc(2026, 3, 4, 5, 6, 7));
    });

    test('a plain reflected holder binds by declared field name', () async {
      final rows = await ds.mapResultSet<FixtureAmountSummary>(
        _oneRow({'total': _decimal('15.00'), 'entries': _int('2')}),
      );

      expect(rows.single.total, closeTo(15.0, 1e-9));
      expect(rows.single.entries, 2);
    });

    test('an annotated entity binds by its persistent columns', () async {
      final rows = await ds.mapResultSet<FixtureTaskRecord>(
        _oneRow({
          'id': _int('1'),
          'title': _text('map me'),
          'priority': _int('7'),
          'done': _bool(true),
        }),
      );

      final row = rows.single;
      expect(row.id, 1);
      expect(row.title, 'map me');
      expect(row.priority, 7);
      expect(row.done, isTrue);
    });

    test('every row of a multi-row result is mapped', () async {
      final rows = await ds.mapResultSet<FixtureTaskRecord>(
        _FakeResultSet([
          {
            'id': _int('1'),
            'title': _text('first'),
            'priority': _int('1'),
            'done': _bool(false),
          },
          {
            'id': _int('2'),
            'title': _text('second'),
            'priority': _int('2'),
            'done': _bool(true),
          },
        ]),
      );

      expect(rows.map((r) => r.title), ['first', 'second']);
      expect(rows.map((r) => r.done), [false, true]);
    });

    test(
      'a column the result does not carry leaves its member alone',
      () async {
        // Every branch guards on the column being present, so a projection that
        // selects a subset is mapped rather than refused.
        final rows = await ds.mapResultSet<FixtureTaskRecord>(
          _oneRow({'title': _text('partial')}),
        );

        expect(rows.single.title, 'partial');
        expect(rows.single.id, isNull);
        expect(rows.single.priority, isNull);
      },
    );

    test('a NULL column reads as null on every shape', () async {
      final observable = await ds.mapResultSet<FixtureNullableObservable>(
        _oneRow({
          'name': _text(null),
          'ratio': _double(null),
          'quantity': _int(null),
          'active': _bool(null),
          'occurredAt': _instant(null),
        }),
      );
      expect(observable.single.name.get(), isNull);
      expect(observable.single.ratio.get(), isNull);
      expect(observable.single.quantity.get(), isNull);
      expect(observable.single.active.get(), isNull);
      expect(observable.single.occurredAt.get(), isNull);

      final holder = await ds.mapResultSet<FixtureAmountSummary>(
        _oneRow({'total': _decimal(null), 'entries': _int(null)}),
      );
      expect(holder.single.total, isNull);
      expect(holder.single.entries, isNull);
    });

    test('a result type the reflector does not hold is refused', () async {
      // The refusal lives at the mirror lookup rather than after the branch
      // chain, and this is the reason: the five shapes between them accept
      // every reflected type, so the only result a refusal can be about is one
      // the reflector does not hold — which is decided where the mirror is
      // taken, before any branch is chosen.
      await expectLater(
        ds.mapResultSet<UnreflectedResult>(_oneRow({'value': _int('1')})),
        throwsA(
          isA<MariadbDatasourceException>()
              .having(
                (e) => e.key,
                'key',
                'error.result_processing.unsuitable_class',
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(contains('UnreflectedResult'), contains('@tomReflector')),
              ),
        ),
      );
    });

    test('a grouped column type the mapper cannot read is named', () async {
      await expectLater(
        ds.mapResultSet<TomGroupedRow>(
          _oneRow({'link': _text('https://example.test')}),
          TomGroupedRow,
          {'link': Uri},
        ),
        throwsA(
          isA<MariadbDatasourceException>()
              .having(
                (e) => e.key,
                'key',
                'error.result_processing_grouped.unknown_type',
              )
              .having((e) => e.toString(), 'message', contains('link')),
        ),
      );
    });
  });

  group('the numeric readers parse the column text', () {
    /// Maps `total` (a `double` field) and `entries` (an `int` field) from the
    /// given column text, which is what the readers see.
    Future<FixtureAmountSummary> read(_Cell total, _Cell entries) async {
      final rows = await ds.mapResultSet<FixtureAmountSummary>(
        _oneRow({'total': total, 'entries': entries}),
      );
      return rows.single;
    }

    test('a DECIMAL spelling reads as a double the driver refuses', () async {
      // The premise of the whole reader: asking the driver directly throws,
      // because NEWDECIMAL is on neither of its conversion whitelists.
      expect(
        () => _FakeRow({
          'total': _decimal('1234.56'),
        }).typedColByName<double>('total'),
        throwsA(isA<MySQLProtocolException>()),
      );

      expect((await read(_decimal('1234.56'), _int('0'))).total, 1234.56);
      expect((await read(_decimal('43.0000'), _int('0'))).total, 43.0);
      expect((await read(_decimal('-42.05'), _int('0'))).total, -42.05);
      expect((await read(_decimal('0.00'), _int('0'))).total, 0.0);
    });

    test('an exactly integral DECIMAL reads onto an int field', () async {
      expect((await read(_double('0'), _decimal('10.00'))).entries, 10);
      expect((await read(_double('0'), _decimal('-7.0'))).entries, -7);
      expect((await read(_double('0'), _decimal('42'))).entries, 42);
    });

    test('a fractional value on an int field is refused, not truncated', () {
      expect(
        read(_double('0'), _decimal('1234.56')),
        throwsA(
          isA<MariadbDatasourceException>()
              .having(
                (e) => e.key,
                'key',
                'error.result_processing.fractional_int',
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(contains('1234.56'), contains('entries')),
              ),
        ),
      );
    });

    test('text that is no number at all is refused by column name', () {
      expect(
        read(_decimal('not a number'), _int('0')),
        throwsA(
          isA<MariadbDatasourceException>()
              .having(
                (e) => e.key,
                'key',
                'error.result_processing.not_a_double',
              )
              .having((e) => e.toString(), 'message', contains('total')),
        ),
      );
      expect(
        read(_double('0'), _decimal('not a number')),
        throwsA(
          isA<MariadbDatasourceException>()
              .having((e) => e.key, 'key', 'error.result_processing.not_an_int')
              .having((e) => e.toString(), 'message', contains('entries')),
        ),
      );
    });

    test('a null column yields null rather than zero', () async {
      final row = await read(_decimal(null), _int(null));
      expect(row.total, isNull);
      expect(row.entries, isNull);
    });
  });

  // A stored value the date/time readers cannot read is refused by column
  // name, exactly as the numeric readers refuse one. The readers underneath —
  // `parseSqlInstant`, `parseSqlDate`, `parseSqlTimeOfDay` — are public parse
  // functions and keep Dart's parse contract, a `FormatException`; what they
  // are handed here is a stored row, which is data from outside the process,
  // so the driver converts. Unconverted, the `FormatException` crossed the
  // endpoints pipeline unclassified: no key, no `clientThrow`, no column.
  group('a date or time the row cannot hold is refused by column name', () {
    Future<List<FixtureExportRecord>> read(Map<String, _Cell> cells) =>
        ds.mapResultSet<FixtureExportRecord>(_oneRow(cells));

    Matcher refusal(String key, String column, String value) => throwsA(
      isA<MariadbDatasourceException>()
          .having((e) => e.key, 'key', key)
          .having((e) => e.parameters?['attribute'], 'attribute', column)
          .having((e) => e.parameters?['value'], 'value', value)
          .having((e) => e.rootException, 'rootException', isFormatException),
    );

    test('a DATE column holding a timestamp is not a date', () {
      expect(
        read({'tag_day': _text('2026-07-15 12:30:00')}),
        refusal(
          'error.result_processing.not_a_date',
          'tag_day',
          '2026-07-15 12:30:00',
        ),
      );
    });

    test('a TIME column holding an interval is not a time of day', () {
      expect(
        read({'remind_at': _text('25:00:00')}),
        refusal('error.result_processing.not_a_time', 'remind_at', '25:00:00'),
      );
    });

    test('a DATETIME column holding no instant is not an instant', () {
      expect(
        read({'created_at': _text('not a timestamp')}),
        refusal(
          'error.result_processing.not_an_instant',
          'created_at',
          'not a timestamp',
        ),
      );
    });

    test('readable values still map', () async {
      final rows = await read({
        'tag_day': _text('2026-07-15'),
        'remind_at': _text('14:30:00'),
        'created_at': _instant('2026-07-15 12:30:00.000000'),
      });
      expect(rows.single.tagDay?.day, 15);
      expect(rows.single.remindAt?.hour, 14);
      expect(rows.single.createdAt, DateTime.utc(2026, 7, 15, 12, 30));
    });
  });
}
