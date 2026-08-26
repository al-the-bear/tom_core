/// A [TomDataSource] that answers from a script instead of from a server, for
/// repository tests that need no database.
///
/// A repository decision made *about an answer it was given* — a duplicate
/// primary key, a `COUNT(*)` that returned no row, the row count a `DELETE`
/// reported — is fully determined by that answer. A real server would
/// contribute nothing but the ability to produce it, and several of these
/// answers are states a correct server will not produce on request at all.
///
/// Shared by `crud_repository_exceptions_test.dart` (which scripts *failures*)
/// and `crud_repository_delete_counts_test.dart` (which scripts *counts*).
library;

import 'dart:collection';

import 'package:tom_core_server/tom_core_server.dart';

/// The data source name the reflection fixture's entities declare on their
/// `@TomDbTable`, and therefore the name a scripted source must be registered
/// under for `FixtureTaskRepository()` to find it.
const String fixtureDatasourceName = 'tom_core_server_test';

/// A prepared statement that answers from [ScriptedDataSource.answers].
class ScriptedStatement<T extends Object> implements TomPreparedStatement<T> {
  ScriptedStatement(this.source, {required this.affectedRows});

  final ScriptedDataSource source;

  /// What this statement reports as its affected-row count.
  final int affectedRows;

  @override
  Future<List<T>> execute([Map<String, Object?>? params]) async =>
      source.nextAnswer<T>();

  @override
  Future<void> deallocate() async {}

  @override
  int? get lastGeneratedId => source.generatedId;

  @override
  int get lastAffectedRows => affectedRows;

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
/// most of these guards are about, so most tests need to script nothing at all.
///
/// Only the execution surface is implemented; [noSuchMethod] turns anything
/// else into a loud test bug rather than a silent `null`.
class ScriptedDataSource implements TomDataSource {
  /// What each successive execution does, in order.
  final Queue<Object> answers = Queue();

  /// What [TomPreparedStatement.lastGeneratedId] reports after an insert.
  int? generatedId;

  /// What a `DELETE` statement reports as its affected-row count.
  ///
  /// Only deletes report it. A repository that read the count off the wrong
  /// statement — the data-scope check, or the read that collects file
  /// references before the rows go — would see `0` here, so the attribution is
  /// under test and not merely the number.
  int affectedRows = 0;

  /// The next scripted answer as a `List<T>`, or no rows once the script runs
  /// out.
  List<T> nextAnswer<T extends Object>() {
    if (answers.isEmpty) return <T>[];
    final answer = answers.removeFirst();
    // `cast` rather than an `is List<T>` test: a `[FixtureTaskRecord()]`
    // literal is a `List<FixtureTaskRecord>`, which is not a
    // `List<TomCountResult>` even when that is what the call wants back.
    if (answer is List) return answer.cast<T>();
    throw answer;
  }

  @override
  TomStandardSqlDialect get sqlDialect => MariadbSqlDialect();

  @override
  Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(
    TomQuery query, [
    Type? resultType,
  ]) async => ScriptedStatement<T>(
    this,
    affectedRows: query is TomDelete ? affectedRows : 0,
  );

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
class ScriptedDataSourceInfo extends TomDataSourceInfo {
  ScriptedDataSourceInfo(this.scripted)
    : super(fixtureDatasourceName, const {});

  final ScriptedDataSource scripted;

  @override
  TomDataSource get datasource => scripted;
}

/// Registers a fresh [ScriptedDataSource] under [fixtureDatasourceName] and
/// returns it, so `FixtureTaskRepository()` can be constructed.
///
/// The registry is process-wide static state; pair this with
/// [unregisterScriptedDatasource] in a `tearDown` so the next file does not
/// trip over it.
ScriptedDataSource registerScriptedDatasource() {
  final scripted = ScriptedDataSource();
  TomDataSourceInfo.datasources[fixtureDatasourceName] = ScriptedDataSourceInfo(
    scripted,
  );
  return scripted;
}

/// Removes the scripted entry from the process-wide data-source registry.
void unregisterScriptedDatasource() =>
    TomDataSourceInfo.datasources.remove(fixtureDatasourceName);
