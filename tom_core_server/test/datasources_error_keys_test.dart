/// Pins the error keys the `datasources` module raises that need no database
/// and no altered reflection data: the registry's own refusals, the port
/// parser, the prepared-statement retry, and the row mapper's plain-holder and
/// `@TomReference` failures.
///
/// A key is the contract a caller, a log search or a translation table is
/// written against. One that no test names is a failure mode nobody checks:
/// its raise site can be deleted, reworded into a different key, or swallowed
/// by a broader catch, and every suite stays green. Each test here reaches its
/// raise site through the smallest real input that gets there and asserts the
/// exact key — the exception type alone would pass just as well if the wrong
/// branch had thrown it.
///
/// No server is needed for any of them. The row mapper takes the driver's
/// result set rather than a connection, so a result set built from column text
/// drives it; the `@TomReference` loader reaches the database only through
/// [MariaDbDatasource.executeQuery], which a subclass answers instead. The
/// prepared-statement retry is driven through a connection that reports itself
/// dropped, which is the one state a live server will not hold still for: its
/// retry re-opens the link, so against a real server the key is raised and
/// then recovered from, never seen by the caller.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureTag,
        FixtureTaggedRecord,
        FixtureUnreadableFieldHolder,
        FixtureUntaggedRecord;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/text_result_set.dart';

/// Completes with a [TomServerException] whose key is exactly [key].
Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

/// A data source whose reference reads answer from [answer] rather than from a
/// server: a `List` is returned as the rows, anything else is thrown.
///
/// The loader reaches the database through [executeQuery] and nothing else, so
/// this is the whole of what a `@TomReference` needs from a connection.
class _ReferenceAnswers extends MariaDbDatasource {
  _ReferenceAnswers(this.answer);

  final Object Function() answer;

  @override
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]) async {
    final reply = answer();
    if (reply is List) return reply.cast<T>();
    throw reply;
  }
}

/// A server-side statement on a link that has gone: every execution fails on
/// the way to the server, which is the failure a dropped connection produces.
class _DeadStatement implements PreparedStmt {
  @override
  Future<IResultSet> execute(List<dynamic> params) async =>
      throw const SocketException('Connection reset by peer');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The dead statement was asked for ${invocation.memberName}.',
  );
}

/// A connection that reports itself dropped and re-prepares onto a link that
/// is still dropped.
class _DeadConnection implements MySQLConnection {
  @override
  bool get connected => false;

  @override
  Future<PreparedStmt> prepare(String query, [bool iterable = false]) async =>
      _DeadStatement();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The dead connection was asked for ${invocation.memberName}.',
  );
}

/// A data source whose every connection is dead on arrival, so a statement's
/// single retry fails the same way the first attempt did.
class _UnrecoverableLink extends MariaDbDatasource {
  @override
  Future<MySQLConnection> openConnection() async => _DeadConnection();
}

void main() {
  setUpAll(initializeReflection);

  group('TomDataSourceInfo.initialize', () {
    setUp(TomDataSourceInfo.datasources.clear);
    tearDown(TomDataSourceInfo.datasources.clear);

    test('a delegate that is not registered is refused', () {
      final info = TomDataSourceInfo('alias', {'delegateTo': 'missing'});
      expect(
        info.initialize(),
        _throwsKey('tom_datasource_info.initialize.delegate_not_found'),
      );
    });

    for (final settings in <Map<String, dynamic>>[
      {},
      {'type': ''},
    ]) {
      test('a block without a usable type is refused: $settings', () {
        expect(
          TomDataSourceInfo('untyped', settings).initialize(),
          _throwsKey('tom_datasource_info.initialize.no_type_specified'),
        );
      });
    }
  });

  group('TomDataSourceInfo before initialize', () {
    // The data source is null until initialize has run, so asking for it is
    // refused with a key — and asking whether it is operational answers false
    // rather than throwing.
    test('reading the data source is refused', () {
      final info = TomDataSourceInfo('unopened', {'type': 'mariadb'});
      expect(info.isOperational, isFalse);
      expect(
        () => info.datasource,
        throwsA(
          isA<TomDatasourceInitException>().having(
            (e) => e.key,
            'key',
            'tom_datasource_info.get_datasource.datasource_is_null',
          ),
        ),
      );
    });
  });

  group('MariaDbDatasource.parsePort', () {
    for (final raw in <Object?>['not-a-port', '33.06', null, 3306.0]) {
      test('refuses ${raw.runtimeType} $raw', () {
        expect(
          () => MariaDbDatasource.parsePort(raw),
          _throwsKey('error.initialize.invalid_port'),
        );
      });
    }

    test('refuses a string port through normalizeIntegerSettings', () {
      expect(
        () => MariaDbDatasource.normalizeIntegerSettings({'port': 'db'}),
        _throwsKey('error.initialize.invalid_port'),
      );
    });
  });

  group('MariadbPreparedStatement.execute', () {
    test(
      'a link still dropped after the retry surfaces as connection_closed',
      () async {
        final datasource = _UnrecoverableLink();
        await datasource.connect();
        final statement = MariadbPreparedStatement<Object>(
          const [],
          datasource,
          null,
          'SELECT 1',
        );
        await expectLater(
          statement.execute(),
          _throwsKey('error.failed-to-execute.connection_closed'),
        );
      },
    );
  });

  group('mapResultSet on a plain reflected holder', () {
    test('a field of a type the mapper cannot read is refused', () async {
      // The holder is reflected, carries no @TomDbTable and is not a TomClass,
      // so it is mapped by declared field name — and its `window` field is a
      // Duration, which no column can become.
      final datasource = MariaDbDatasource();
      await expectLater(
        datasource.mapResultSet<Object>(
          OneTextRow({'window': 'anything'}),
          FixtureUnreadableFieldHolder,
        ),
        _throwsKey('error.result_processing_field.unknown_type'),
      );
    });
  });

  group('mapResultSet resolving a @TomReference', () {
    final taggedRow = {'id': '7', 'label': 'owner'};

    test('a reference query the data source cannot run', () async {
      // Never opened, so the reference read is refused by the data source and
      // reaches the loader as an exception to wrap.
      await expectLater(
        MariaDbDatasource().mapResultSet<FixtureTaggedRecord>(
          OneTextRow(taggedRow),
        ),
        _throwsKey('error.result_processing.ref_query_execution_failed'),
      );
    });

    test('rows that do not fit the reference list', () async {
      final datasource = _ReferenceAnswers(() => <Object>[Object()]);
      await expectLater(
        datasource.mapResultSet<FixtureTaggedRecord>(OneTextRow(taggedRow)),
        _throwsKey('error.result_processing.ref_failed_adding_result_to_value'),
      );
    });

    test('a reference field holding null', () async {
      final datasource = _ReferenceAnswers(() => <FixtureTag>[]);
      await expectLater(
        datasource.mapResultSet<FixtureUntaggedRecord>(OneTextRow(taggedRow)),
        _throwsKey(
          'error.result_processing.ref_reference_field_must_have_non-null_value',
        ),
      );
    });

    test('a failure that is not an exception the loader wraps', () async {
      // An Error passes `runChecked` untouched, so it reaches the loader's
      // outer catch rather than the execution step's own key.
      final datasource = _ReferenceAnswers(
        () => StateError('the reference read broke'),
      );
      await expectLater(
        datasource.mapResultSet<FixtureTaggedRecord>(OneTextRow(taggedRow)),
        _throwsKey('error.result_processing.ref_failed_unexpected'),
      );
    });
  });
}
