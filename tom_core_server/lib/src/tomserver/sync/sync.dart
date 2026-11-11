/// The server side of the offline sync protocol: the entities a device may
/// keep a copy of, the change log a pull reads, and pushes applied through the
/// entities' repositories.
///
/// An application exposes an entity under a collection name
/// ([TomSync.expose]); the entity needs a `@TomVersion` field and a single
/// `String` or `int` key. From then on:
///
/// * **every write** of the entity — through the sync endpoint or anywhere else
///   in the server — is numbered in its collection's change sequence. A
///   [TomEntityLifecycle] change listener writes the change-log row inside the
///   write's transaction, so a change is in the log exactly when it committed.
/// * **a push** applies each change through the repository, in a transaction
///   of its own: a save or a deletion only while the stored version is still
///   the change's base, a creation only while there is no entity under the id.
///   The answer is `applied` with the new version, `conflict` with what the
///   server holds, or `rejected` with a reason — the application's `validate`
///   refused the data, the row scope or a column grade refused the write, the
///   data could not be read as the entity, or the id is taken by an entity the
///   caller cannot see. Any other failure fails the push, and the device keeps
///   its changes for the next sync.
/// * **a pull** reads the log after the device's cursor and each entity through
///   the repository, as the caller: an entity the caller's row scope does not
///   reach is left out, column grades mask what they mask, encrypted columns
///   arrive decrypted. A deletion carries the id alone and reaches every
///   device pulling the collection.
///
/// The semantics are `TomMemorySyncServer`'s; `tom_core_kernel`'s sync
/// contract runs against both.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../datasources/table_qualification.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/column_authorization.dart';
import '../object_persistence/crud_repository.dart';
import '../object_persistence/data_scope.dart';
import '../object_persistence/entity_lifecycle.dart';
import '../object_persistence/persistence_annotations.dart';
import '../tenancy/tenancy.dart';
import '../transactions/transaction_manager.dart';
import 'sync_sql.dart';

/// A failure of the sync module.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `sync.collection.unknown` | no entity is exposed under the collection |
/// | `sync.pull.invalid` | a pull's `since` is negative or its `limit` not positive |
/// | `sync.expose.*` | the entity cannot be synced (see [TomSync.expose]) |
/// | `sync.rejected` | thrown by the application to refuse a pushed change |
class TomSyncException extends TomServerException {
  /// Creates the exception with [key] and [defaultUserMessage].
  TomSyncException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.clientThrow,
  });
}

/// Thrown by an application — from a [TomEntityListener]'s `beforeSave`, say —
/// to refuse a pushed change: the device is told `rejected` with [reason], and
/// gets the server's value back.
class TomSyncRejection extends TomSyncException {
  /// Refuses the change with [reason].
  TomSyncRejection(this.reason, [String? message])
    : super('sync.rejected', message ?? 'The change was refused: $reason.');

  /// The reason the device is told.
  final String reason;
}

/// One exposed entity: its collection, repository and the conversions between
/// the entity and the protocol's JSON data.
class _SyncedEntity<T extends Object, K> {
  _SyncedEntity(this.collection, this.repository, this.validate)
    : version = TomAnnotationAnalyzer.findVersionColumn(T)!,
      key = repository.primaryKeyColumns.single;

  final String collection;
  final TomSqlDatasourceRepository<T, K> repository;
  final String? Function(Map<String, Object?> data)? validate;
  final TomColumnInformation version;
  final TomColumnInformation key;

  Type get type => T;

  K keyOf(String id) => (K == int ? int.parse(id) : id) as K;

  int versionOf(T entity) => version.getVariableValue(entity) as int;

  /// [entity] as the protocol's data: its fields, without the version, which
  /// travels beside the data.
  Map<String, Object?> dataOf(T entity) =>
      tomReflectionInfo.getValues(entity)..remove(version.declaredName);

  /// [data] as an entity of id [id]: written over [current] when there is
  /// one, so a field the device does not hold keeps its stored value.
  T entityOf(String id, Map<String, Object?> data, T? current) {
    final values = Map<String, Object?>.of(data)
      ..remove(version.declaredName)
      ..remove(key.declaredName);
    final entity = current == null
        ? tomReflectionInfo.createInstanceFromJson<T>(
            tomReflector.reflectType(T) as ClassMirror,
            values,
          )
        : tomReflectionInfo.setValues<T>(current, values);
    key.setVariableValue(entity, keyOf(id));
    return entity;
  }

  Future<T?> find(String id) => repository.findById(keyOf(id));

  /// The entities of [ids] the caller may read, by id.
  Future<Map<String, T>> findAll(Iterable<String> ids) async {
    final found = <String, T>{};
    for (final id in ids) {
      final entity = await find(id);
      if (entity != null) found[id] = entity;
    }
    return found;
  }

  Future<bool> existsUnscoped(String id) =>
      TomDataScope.runUnscoped(() => repository.existsById([keyOf(id)]));

  TomPushResult _held(
    TomPendingChange change,
    TomPushOutcome outcome,
    T? current, {
    String? reason,
  }) => TomPushResult(
    changeId: change.changeId,
    outcome: outcome,
    version: current == null ? null : versionOf(current),
    serverData: current == null ? null : dataOf(current),
    reason: reason,
  );

  Future<TomPushResult> apply(TomPendingChange change) async {
    try {
      return await TomTransactionManager.runInTransaction(
        (_) => _applyIn(change),
      );
    } on TomOptimisticLockException {
      // Changed or deleted between the read and the write.
      return _held(change, TomPushOutcome.conflict, await find(change.id));
    } on TomSyncRejection catch (refusal) {
      return _rejected(change, refusal.reason);
    } on TomDataScopeException catch (refusal) {
      return _rejected(change, refusal.key);
    } on TomColumnAuthorizationException catch (refusal) {
      return _rejected(change, refusal.key);
    } on TomReflectorException {
      return _rejected(change, 'sync.data.unreadable');
    } on Object {
      if (change.baseVersion != null ||
          change.operation != TomChangeOperation.save) {
        rethrow;
      }
      // A creation that failed: another writer created the id first, or an
      // entity the caller cannot see holds it.
      final current = await find(change.id);
      if (current != null) {
        return _held(change, TomPushOutcome.conflict, current);
      }
      if (await existsUnscoped(change.id)) {
        return _rejected(change, 'sync.id.taken');
      }
      rethrow;
    }
  }

  Future<TomPushResult> _rejected(
    TomPendingChange change,
    String reason,
  ) async => _held(
    change,
    TomPushOutcome.rejected,
    await find(change.id),
    reason: reason,
  );

  Future<TomPushResult> _applyIn(TomPendingChange change) async {
    final current = await find(change.id);
    final held = current == null ? null : versionOf(current);
    if (held != change.baseVersion ||
        (current == null && change.operation == TomChangeOperation.delete)) {
      return _held(change, TomPushOutcome.conflict, current);
    }
    switch (change.operation) {
      case TomChangeOperation.save:
        final data = change.data ?? const <String, Object?>{};
        final refusal = validate?.call(data);
        if (refusal != null) throw TomSyncRejection(refusal);
        final entity = entityOf(change.id, data, current);
        final stored = current == null
            ? await repository.insert(entity)
            : await repository.save(entity);
        return TomPushResult(
          changeId: change.changeId,
          outcome: TomPushOutcome.applied,
          version: versionOf(stored),
        );
      case TomChangeOperation.delete:
        await repository.delete(current!);
        return TomPushResult(
          changeId: change.changeId,
          outcome: TomPushOutcome.applied,
          version: held! + 1,
        );
    }
  }

  /// Writes the change-log row for [change], inside its transaction.
  Future<void> record(TomEntityChange change, TomSqlSyncLog log) async {
    final deleted =
        change.kind == TomEntityChangeKind.deleted || change.after == null;
    final T? after = change.after as T?;
    final T? before = change.before as T?;
    final int changedVersion = after != null
        ? versionOf(after)
        : versionOf(before!) + 1;
    // A system entity written on a tenant's connection keeps its log beside
    // it: the log's table is qualified the way the entity's is.
    await TomSqlTableQualification.run(
      repository.tableQualifier,
      () => log.append(
        repository.datasourceInfo.datasource,
        collection: collection,
        entityId: '${change.key}',
        version: changedVersion,
        deleted: deleted,
        at: change.at,
      ),
    );
  }
}

/// The change log in the data source of each synced entity: rows of
/// [syncChangeTable] numbered through [syncSequenceTable].
///
/// ## Why a change is numbered when it is pulled, not when it is written
///
/// A cursor counts on one thing: a number it has passed is never given to a
/// change that commits later. Numbering inside the write's transaction would
/// make every write of a collection take the same counter row, and on MariaDB
/// (snapshot isolation) a write that has already read anything is refused
/// (error 1020) when another committed the counter first. So a write records
/// its change unnumbered — an insert nothing else touches — and [number],
/// which runs before every pull, gives the committed unnumbered changes the
/// next numbers in the order they were recorded, under the counter's lock. A
/// change still in an open transaction is not visible to it and is numbered by
/// a later pull, after everything numbered before.
class TomSqlSyncLog {
  /// A log in the tables [changeTable] and [sequenceTable].
  ///
  /// With [createSchema] (the default) the tables are created in a data source
  /// the first time [prepare] meets it — at [TomSync.expose] and before each
  /// push and pull, never inside a write's transaction, where DDL would commit
  /// it on MariaDB. A deployment whose user may not run DDL, or whose tenants
  /// each have a database of their own, applies the shipped migration and
  /// passes `false`.
  TomSqlSyncLog({
    this.changeTable = defaultSyncChangeTable,
    this.sequenceTable = defaultSyncSequenceTable,
    this.createSchema = true,
  });

  /// The change-log table's name.
  final String changeTable;

  /// The sequence-counter table's name.
  final String sequenceTable;

  /// Whether the tables are created on first use.
  final bool createSchema;

  late final TomFrameworkTable _changes = syncChangeTable(changeTable);
  late final TomFrameworkTable _sequences = syncSequenceTable(sequenceTable);
  final Expando<TomSchemaProvisioning> _schemas = Expando();
  final Expando<Set<String>> _counters = Expando();

  static String get _tenant => TomTenantContext.currentId ?? '';

  /// Creates the tables in [datasource] when [createSchema] is set, and the
  /// counter row of [collection] for the current tenant.
  Future<void> prepare(TomDataSource datasource, String collection) async {
    if (createSchema) {
      await (_schemas[datasource] ??= TomSchemaProvisioning()).ensure(() async {
        await _changes.create(datasource);
        await _sequences.create(datasource);
      });
    }
    final known = _counters[datasource] ??= {};
    final counter = '$_tenant/$collection';
    if (known.contains(counter)) return;
    await datasource.executeCommand(
      _sequences.insertRow(datasource.sqlDialect, const {
        'tenant': ':tenant',
        'collection': ':collection',
        'last_sequence': '0',
      }, ignoreConflict: true),
      {'tenant': _tenant, 'collection': collection},
    );
    known.add(counter);
  }

  /// Records a change of [collection], unnumbered, in the caller's
  /// transaction.
  Future<void> append(
    TomDataSource datasource, {
    required String collection,
    required String entityId,
    required int version,
    required bool deleted,
    required DateTime at,
  }) => datasource.executeCommand(
    _changes.insertRow(datasource.sqlDialect, const {
      'tenant': ':tenant',
      'collection': ':collection',
      'entity_id': ':entity',
      'version': ':version',
      'deleted': ':deleted',
      'changed_at': ':at',
    }),
    {
      'tenant': _tenant,
      'collection': collection,
      'entity': entityId,
      'version': version,
      'deleted': deleted ? 1 : 0,
      'at': sqlInstant(at),
    },
  );

  /// Numbers the committed unnumbered changes of [collection], in the order
  /// they were recorded, and answers the last number given out.
  ///
  /// One transaction of locking statements only: the counter row is locked
  /// first, so two numberings run one after the other, and with no plain read
  /// in it the transaction never holds a snapshot a later write contradicts.
  Future<int> number(TomDataSource datasource, String collection) =>
      TomTransactionManager.runInTransaction((_) async {
        final key = {'tenant': _tenant, 'collection': collection};
        final counters = await datasource.executeQuery<TomSyncSequenceRow>(
          'SELECT last_sequence FROM $sequenceTable '
          'WHERE tenant = :tenant AND collection = :collection FOR UPDATE',
          key,
        );
        var last = counters.single.lastSequence;
        final unnumbered = await datasource.executeQuery<TomSyncChangeIdRow>(
          'SELECT id FROM $changeTable WHERE tenant = :tenant '
          'AND collection = :collection AND seq IS NULL ORDER BY id FOR UPDATE',
          key,
        );
        if (unnumbered.isEmpty) return last;
        for (final row in unnumbered) {
          await datasource.executeCommand(
            'UPDATE $changeTable SET seq = :seq WHERE id = :id',
            {'seq': ++last, 'id': row.id},
          );
        }
        await datasource.executeCommand(
          'UPDATE $sequenceTable SET last_sequence = :last '
          'WHERE tenant = :tenant AND collection = :collection',
          {...key, 'last': last},
        );
        return last;
      });

  /// The numbered changes of [collection] after [since], at most [limit], in
  /// sequence order.
  Future<List<TomSyncChangeRow>> after(
    TomDataSource datasource,
    String collection,
    int since,
    int limit,
  ) => datasource.executeQuery<TomSyncChangeRow>(
    'SELECT seq, entity_id, version, deleted FROM $changeTable '
    'WHERE tenant = :tenant AND collection = :collection '
    'AND seq > :since ORDER BY seq LIMIT $limit',
    {'tenant': _tenant, 'collection': collection, 'since': since},
  );
}

/// One row of the change log, as [TomSqlSyncLog] reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["sequence"],
)
class TomSyncChangeRow {
  /// The change's number in its collection's sequence.
  @TomDbColumn(columnName: "seq")
  int sequence = 0;

  /// The entity's id.
  @TomDbColumn(columnName: "entity_id")
  String entityId = "";

  /// The entity's version after the change.
  @TomDbColumn(columnName: "version")
  int version = 0;

  /// `1` when the change deleted the entity.
  @TomDbColumn(columnName: "deleted")
  int deleted = 0;
}

/// The id of an unnumbered change, as [TomSqlSyncLog.number] reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["id"],
)
class TomSyncChangeIdRow {
  /// The change row's id, in the order changes were recorded.
  @TomDbColumn(columnName: "id")
  int id = 0;
}

/// A sequence counter's value, as [TomSqlSyncLog] reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["lastSequence"],
)
class TomSyncSequenceRow {
  /// The last number given out.
  @TomDbColumn(columnName: "last_sequence")
  int lastSequence = 0;
}

/// The synced entities and the protocol's two operations over them.
abstract final class TomSync {
  static final Map<String, _SyncedEntity<Object, Object?>> _collections = {};
  static final List<void Function()> _listeners = [];

  /// The change log; replace it before the first [expose] to rename its
  /// tables or leave their creation to a migration.
  static TomSqlSyncLog log = TomSqlSyncLog();

  /// The most changes one pull answers, whatever the device asks for.
  static int maxPullLimit = 1000;

  /// The exposed collections.
  static List<String> get collections => List.unmodifiable(_collections.keys);

  /// Exposes [repository]'s entity as [collection]: a device may push changes
  /// of it and pull its changes, and every write of it from now on is
  /// recorded in the change log. [validate] may refuse a pushed save's data
  /// with a reason (`null` accepts it).
  ///
  /// Refused (`sync.expose.unversioned`) for an entity without a
  /// `@TomVersion` field, (`sync.expose.key`) for one whose key is composite
  /// or neither a `String` nor an `int`, and (`sync.expose.duplicate`) for a
  /// collection or an entity exposed already.
  static Future<void> expose<T extends Object, K>(
    String collection,
    TomSqlDatasourceRepository<T, K> repository, {
    String? Function(Map<String, Object?> data)? validate,
  }) async {
    if (TomAnnotationAnalyzer.findVersionColumn(T) == null) {
      throw TomSyncException(
        'sync.expose.unversioned',
        '$T has no @TomVersion field, which a synced entity needs: pushes are '
            'applied by version.',
        parameters: {'entity': '$T'},
        clientThrow: false,
      );
    }
    if (repository.hasCompositeKey || (K != String && K != int)) {
      throw TomSyncException(
        'sync.expose.key',
        '$T is keyed by $K; a synced entity has a single String or int key.',
        parameters: {'entity': '$T'},
        clientThrow: false,
      );
    }
    if (_collections.containsKey(collection) ||
        _collections.values.any((entity) => entity.type == T)) {
      throw TomSyncException(
        'sync.expose.duplicate',
        "The collection '$collection' or the entity $T is exposed already.",
        parameters: {'collection': collection, 'entity': '$T'},
        clientThrow: false,
      );
    }
    final entity = _SyncedEntity<T, K>(collection, repository, validate);
    // A tenant table's change log lives beside the tenant's rows: with a
    // tenancy installed and no tenant in context it is prepared in every
    // tenant served now; a tenant added later is prepared by its first push or
    // pull, or by its migrations.
    final tenancy = TomTenancy.current;
    if (repository.isTenantTable &&
        tenancy != null &&
        TomTenantContext.currentId == null) {
      await tenancy.forEachTenant(
        (_) => log.prepare(repository.datasourceInfo.datasource, collection),
      );
    } else {
      await log.prepare(repository.datasourceInfo.datasource, collection);
    }
    _collections[collection] = entity as _SyncedEntity<Object, Object?>;
    _listeners.add(
      TomEntityLifecycle.onChange(
        (change) => entity.record(change, log),
        entity: T,
      ),
    );
  }

  /// Forgets the exposed collections and their listeners, and restores the
  /// defaults. For tests.
  static void reset() {
    for (final remove in _listeners) {
      remove();
    }
    _listeners.clear();
    _collections.clear();
    log = TomSqlSyncLog();
    maxPullLimit = 1000;
  }

  static _SyncedEntity<Object, Object?>? _entity(String collection) =>
      _collections[collection];

  /// Applies [changes] in order and answers one result per change.
  static Future<List<TomPushResult>> push(
    List<TomPendingChange> changes,
  ) async {
    final results = <TomPushResult>[];
    for (final change in changes) {
      final entity = _entity(change.collection);
      if (entity == null) {
        results.add(
          TomPushResult(
            changeId: change.changeId,
            outcome: TomPushOutcome.rejected,
            reason: tomSyncUnknownCollectionErrorKey,
          ),
        );
        continue;
      }
      await log.prepare(
        entity.repository.datasourceInfo.datasource,
        change.collection,
      );
      results.add(await entity.apply(change));
    }
    return results;
  }

  /// The changes of [collection] after [since] that the caller may read, at
  /// most [limit] (and at most [maxPullLimit]).
  ///
  /// The cursor moves past every change read, the ones left out included, so a
  /// page full of entities the caller may not read still advances the device.
  static Future<TomPullBatch> pull(
    String collection,
    int since, {
    int limit = 500,
  }) async {
    final entity = _entity(collection);
    if (entity == null) {
      throw TomSyncException(
        tomSyncUnknownCollectionErrorKey,
        "No entity is synced as '$collection'.",
        parameters: {'collection': collection},
      );
    }
    if (since < 0 || limit < 1) {
      throw TomSyncException(
        'sync.pull.invalid',
        'A pull needs a cursor of 0 or more and a limit of 1 or more.',
        parameters: {'since': since, 'limit': limit},
      );
    }
    final page = limit > maxPullLimit ? maxPullLimit : limit;
    final datasource = entity.repository.datasourceInfo.datasource;
    await log.prepare(datasource, collection);
    await log.number(datasource, collection);
    final rows = await log.after(datasource, collection, since, page + 1);
    final batch = rows.take(page).toList();
    final current = await entity.findAll({
      for (final row in batch)
        if (row.deleted == 0) row.entityId,
    });
    final changes = <TomPulledChange>[];
    for (final row in batch) {
      if (row.deleted != 0) {
        changes.add(
          TomPulledChange(
            id: row.entityId,
            data: null,
            version: row.version,
            sequence: row.sequence,
          ),
        );
        continue;
      }
      final held = current[row.entityId];
      // Not readable by the caller, or deleted since: a later change says so.
      if (held == null) continue;
      changes.add(
        TomPulledChange(
          id: row.entityId,
          data: entity.dataOf(held),
          version: entity.versionOf(held),
          sequence: row.sequence,
        ),
      );
    }
    return TomPullBatch(
      changes: changes,
      cursor: batch.isEmpty ? since : batch.last.sequence,
      hasMore: rows.length > page,
    );
  }
}
