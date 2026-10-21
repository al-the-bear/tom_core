/// What happens around a repository write: soft delete, history tables,
/// lifecycle hooks and change events.
///
/// All four are declared or registered per entity and carried out by
/// `TomSqlDatasourceRepository` — no other code path writes them, so a store
/// that talks to its data source directly has none of them.
///
/// - [TomSoftDelete] turns a repository delete into setting a timestamp, and
///   hides the rows that carry one from every repository read
///   ([TomSoftDelete.includingDeleted] shows them).
/// - [TomHistory] copies the row as it was before every update and delete
///   into a history table.
/// - A [TomEntityListener] is called before and after every save and delete
///   of its entity; a [TomEntityChangeListener] is told of every change, of
///   any entity, as a [TomEntityChange].
///
/// Whenever an entity has any of the last three, its write runs inside a
/// transaction — the caller's, or one of its own — so the history row, a
/// listener's own writes and the change itself commit or roll back together.
/// A change listener that writes an outbox row therefore publishes exactly the
/// changes that committed.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'annotation_analyzer.dart';
import 'persistence_annotations.dart';

/// Marks an entity whose repository deletes are soft: a delete sets [field],
/// a nullable `DateTime` column, to the time of the delete, and every
/// repository read leaves out the rows whose [field] is set.
///
/// The filter is the repository's, so it applies wherever the data scope
/// does — `findAll`, `findById`, the counts, the query methods, the existence
/// checks — and nowhere a statement is written by hand.
/// [includingDeleted] reads the deleted rows as well, `restoreById` undeletes
/// a row and `purgeById` removes it for good.
class TomSoftDelete {
  /// Soft-deletes through [field].
  const TomSoftDelete({this.field = 'deletedAt'});

  /// The entity field holding the deletion time — `null` while the row lives.
  final String field;

  static final Object _includingDeletedKey = Object();

  /// Runs [body] with soft-deleted rows visible to repository reads.
  static Future<R> includingDeleted<R>(Future<R> Function() body) =>
      runZoned(body, zoneValues: {_includingDeletedKey: true});

  /// Whether the current zone reads soft-deleted rows.
  static bool get isIncludingDeleted =>
      Zone.current[_includingDeletedKey] == true;

  /// The [TomSoftDelete] of [entity], or `null` when its deletes are hard.
  static TomSoftDelete? of(Type entity) => _annotation<TomSoftDelete>(entity);
}

/// Marks an entity whose rows keep their past: before every update and every
/// delete — soft, hard or by query — the row as it was is copied into
/// [table].
///
/// The history table carries every column of the entity's table under the
/// same name, the entity's key not unique, plus four of its own:
///
/// ```sql
/// CREATE TABLE note_history (
///   history_id     BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
///   history_action VARCHAR(16)  NOT NULL,  -- update, delete, restore
///   history_at     DATETIME(6)  NOT NULL,
///   history_by     VARCHAR(255) NULL,      -- the principal, if any
///   id             BIGINT       NOT NULL,  -- the entity's columns from here
///   text           VARCHAR(200) NULL
/// );
/// ```
///
/// An encrypted column is copied as its ciphertext. `historyOf` reads a row's
/// versions back, oldest first.
class TomHistory {
  /// Keeps the entity's past in [table].
  const TomHistory({required this.table});

  /// The history table.
  final String table;

  /// The [TomHistory] of [entity], or `null` when it keeps none.
  static TomHistory? of(Type entity) => _annotation<TomHistory>(entity);
}

/// One past version of a row, as `historyOf` answers it.
class TomHistoryEntry<T extends Object> {
  /// The row as it was before the [action].
  const TomHistoryEntry({
    required this.entity,
    required this.action,
    required this.at,
    this.by,
  });

  /// The row as it was.
  final T entity;

  /// What replaced it: `update`, `delete` or `restore`.
  final String action;

  /// When (UTC).
  final DateTime at;

  /// The principal that did it, if any.
  final String? by;
}

/// The history table's own columns, read beside the entity's.
///
/// Mapped by reflection; the `@TomDbTable` values are placeholders, as the
/// table is named by each entity's [TomHistory].
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["historyId"],
)
class TomHistoryMeta {
  /// The history row's own key, in insertion order.
  @TomDbColumn(columnName: "history_id")
  int historyId = 0;

  /// `update`, `delete` or `restore`.
  @TomDbColumn(columnName: "history_action")
  String historyAction = "";

  /// When the version was replaced.
  @TomDbColumn(columnName: "history_at")
  DateTime historyAt = DateTime.utc(1970);

  /// The principal that replaced it, if any.
  @TomDbColumn(columnName: "history_by")
  String? historyBy;
}

T? _annotation<T>(Type entity) {
  for (final meta
      in TomAnnotationAnalyzer.findMirror(entity)?.metadata ?? const []) {
    if (meta is T) return meta;
  }
  return null;
}

/// What a [TomEntityChange] reports.
enum TomEntityChangeKind {
  /// A row was inserted.
  inserted,

  /// A row was updated.
  updated,

  /// A row was deleted — or, for a [TomSoftDelete] entity, marked deleted
  /// ([TomEntityChange.soft]).
  deleted,

  /// A soft-deleted row was restored.
  restored,
}

/// One change of one row, as a [TomEntityChangeListener] is told of it.
///
/// [before] and [after] are the row as stored before and after the change,
/// read without the current principal's column masks; either is `null` where
/// the change has no such side (an insert has no before, a hard delete no
/// after). [toJson] is the form an outbox row or a message carries: the
/// values of an encrypted column are redacted there.
class TomEntityChange {
  /// A change of [entityType]'s row [key].
  TomEntityChange({
    required this.entityType,
    required this.kind,
    required this.key,
    this.before,
    this.after,
    this.beforeValues = const {},
    this.afterValues = const {},
    this.soft = false,
    DateTime? at,
    String? principalId,
    String? tenant,
  }) : at = at ?? DateTime.now().toUtc(),
       principalId = principalId ?? getFromCurrentZone<TomPrincipal>()?.id,
       tenant = tenant ?? TomTenantContext.currentId;

  /// The entity type.
  final Type entityType;

  /// What happened.
  final TomEntityChangeKind kind;

  /// The row's key.
  final Object? key;

  /// The row before the change.
  final Object? before;

  /// The row after the change.
  final Object? after;

  /// [before]'s field values, encrypted fields redacted.
  final Map<String, Object?> beforeValues;

  /// [after]'s field values, encrypted fields redacted.
  final Map<String, Object?> afterValues;

  /// Whether a delete marked the row deleted rather than removing it.
  final bool soft;

  /// When the change was made (UTC).
  final DateTime at;

  /// The principal that made it, if any.
  final String? principalId;

  /// The tenant it was made in, if any.
  final String? tenant;

  /// The change as JSON-ready values — an outbox row's payload.
  Map<String, Object?> toJson() => {
    'entity': '$entityType',
    'kind': kind.name,
    'key': key?.toString(),
    'soft': soft,
    'at': at.toIso8601String(),
    'principal': principalId,
    'tenant': tenant,
    'before': _jsonValues(beforeValues),
    'after': _jsonValues(afterValues),
  };

  static Map<String, Object?>? _jsonValues(Map<String, Object?> values) =>
      values.isEmpty
      ? null
      : {
          for (final e in values.entries)
            e.key: switch (e.value) {
              final DateTime d => d.toUtc().toIso8601String(),
              final num n => n,
              final bool b => b,
              null => null,
              final other => '$other',
            },
        };

  @override
  String toString() => 'TomEntityChange($entityType ${kind.name} $key)';
}

/// Told of every [TomEntityChange] of the entity types it registered for,
/// inside the change's transaction.
typedef TomEntityChangeListener = FutureOr<void> Function(TomEntityChange);

/// The hooks of one entity type's repository writes.
///
/// Each runs inside the write's transaction. A `before` hook may change the
/// entity it is handed (stamp a field, normalise a value) and may throw to
/// refuse the write, which then does not happen. An `after` hook sees the row
/// as stored and may write elsewhere — its writes commit with the change, and
/// its throw rolls the change back.
///
/// For a delete the hooks are handed the key and the row as stored, which is
/// `null` only when the row was not found.
abstract class TomEntityListener<T extends Object> {
  /// A listener; override what it hooks.
  const TomEntityListener();

  /// Before [entity] is inserted ([insert]) or updated.
  FutureOr<void> beforeSave(T entity, {required bool insert}) {}

  /// After [entity] was inserted ([insert]) or updated; [entity] is the row
  /// as stored.
  FutureOr<void> afterSave(T entity, {required bool insert}) {}

  /// Before the row [key] ([entity]) is deleted.
  FutureOr<void> beforeDelete(Object key, T? entity) {}

  /// After the row [key] was deleted; [entity] is the row before it was.
  FutureOr<void> afterDelete(Object key, T? entity) {}
}

/// Thrown when a lifecycle declaration cannot be carried out — a
/// [TomSoftDelete] field that is not a nullable `DateTime` column.
class TomEntityLifecycleException extends TomServerException {
  /// Creates the exception with [key] and [defaultUserMessage].
  TomEntityLifecycleException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
  });
}

/// The registry of [TomEntityListener]s and [TomEntityChangeListener]s.
abstract final class TomEntityLifecycle {
  static final Map<Type, List<TomEntityListener<Object>>> _listeners = {};
  static final List<(Type?, TomEntityChangeListener)> _changeListeners = [];

  /// Registers [listener] for the writes of [T]; the function returned
  /// removes it.
  static void Function() register<T extends Object>(
    TomEntityListener<T> listener,
  ) {
    final list = _listeners.putIfAbsent(T, () => []);
    final erased = listener as TomEntityListener<Object>;
    list.add(erased);
    return () => list.remove(erased);
  }

  /// Registers [listener] for the changes of [entity], or of every entity
  /// when [entity] is `null`; the function returned removes it.
  static void Function() onChange(
    TomEntityChangeListener listener, {
    Type? entity,
  }) {
    final entry = (entity, listener);
    _changeListeners.add(entry);
    return () => _changeListeners.remove(entry);
  }

  /// The listeners registered for [entity].
  static List<TomEntityListener<Object>> listenersOf(Type entity) =>
      List.of(_listeners[entity] ?? const []);

  /// Whether a change of [entity] has a listener to tell.
  static bool hasChangeListeners(Type entity) =>
      _changeListeners.any((e) => e.$1 == null || e.$1 == entity);

  /// Whether a write of [entity] has anything to do besides the write itself
  /// — and so runs inside a transaction.
  static bool isObserved(Type entity) =>
      (_listeners[entity]?.isNotEmpty ?? false) ||
      hasChangeListeners(entity) ||
      TomHistory.of(entity) != null;

  /// Tells every listener registered for [change]'s entity of it, in
  /// registration order.
  static Future<void> notify(TomEntityChange change) async {
    for (final (type, listener) in List.of(_changeListeners)) {
      if (type == null || type == change.entityType) await listener(change);
    }
  }

  /// Removes every listener. For tests.
  static void reset() {
    _listeners.clear();
    _changeListeners.clear();
  }
}
