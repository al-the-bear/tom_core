/// Soft delete, history tables, lifecycle hooks and change events, step by
/// step, without a database.
///
/// Run with
/// `dart run example/object_persistence/entity_lifecycle_example.dart`.
///
/// `@TomSoftDelete` turns a repository delete into setting a timestamp and
/// hides the rows that carry one; `@TomHistory` copies a row into a history
/// table before every update, delete and restore; a `TomEntityListener` is
/// called around every save and delete of its entity; a change listener is
/// told of every change as a `TomEntityChange`. The writes themselves run
/// against MariaDB and PostgreSQL in `test/entity_lifecycle_db_test.dart`;
/// what decides them — the declarations, the zone that shows deleted rows, the
/// registry that makes a write transactional, the change and its JSON form —
/// is visible without one, and this example shows it. Every step checks its
/// own result, and the run fails when one does not hold.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';
import '../example_reflection.reflection.dart';
import 'object_persistence_entities.dart';

/// Stamps nothing; registering it is what makes a write observed.
class _ArticleListener extends TomEntityListener<ExampleArticle> {}

Future<void> main() async {
  initializeReflection();

  // 1. Soft delete and history are declared per entity. An entity without
  //    the annotations deletes for good and keeps no past.
  const softDelete = TomSoftDelete();
  print('1. default soft-delete field: ${softDelete.field}');
  check(softDelete.field == 'deletedAt', 'the default field is deletedAt');
  check(
    TomSoftDelete.of(ExampleArticle) == null &&
        TomHistory.of(ExampleArticle) == null,
    'an entity without the annotations has neither',
  );

  // 2. A history table carries the entity's columns plus four of its own;
  //    `historyOf` reads them through the reflected `TomHistoryMeta`.
  final meta = [
    for (final c in TomAnnotationAnalyzer.getPersistentColumns(TomHistoryMeta)!)
      c.getQueryFieldName(),
  ];
  print('2. history columns          : ${meta.join(', ')}');
  check(
    meta.toSet().containsAll([
          'history_id',
          'history_action',
          'history_at',
          'history_by',
        ]) &&
        meta.length == 4,
    'the history table adds exactly its four own columns',
  );

  // 3. Deleted rows are visible to repository reads only inside
  //    `includingDeleted`, and only there.
  final inside = await TomSoftDelete.includingDeleted(
    () async => TomSoftDelete.isIncludingDeleted,
  );
  print(
    '3. includingDeleted inside  : $inside, outside: '
    '${TomSoftDelete.isIncludingDeleted}',
  );
  check(
    inside && !TomSoftDelete.isIncludingDeleted,
    'the zone shows deleted rows inside and nowhere else',
  );

  // 4. A write of an entity with a listener runs inside a transaction, so
  //    the listener's own writes commit or roll back with it.
  final before = TomEntityLifecycle.isObserved(ExampleArticle);
  final remove = TomEntityLifecycle.register(_ArticleListener());
  final during = TomEntityLifecycle.isObserved(ExampleArticle);
  remove();
  print(
    '4. article observed         : $before -> $during -> '
    '${TomEntityLifecycle.isObserved(ExampleArticle)}',
  );
  check(
    !before && during && !TomEntityLifecycle.isObserved(ExampleArticle),
    'registering a listener makes the write observed, removing it undoes it',
  );

  // 5. A change listener hears the entity it registered for. The values a
  //    change carries have an encrypted field redacted.
  final heard = <TomEntityChange>[];
  final stopPatients = TomEntityLifecycle.onChange(
    heard.add,
    entity: ExamplePatientRecord,
  );
  final stopArticles = TomEntityLifecycle.onChange(
    (_) => throw StateError('an article listener hears no patient'),
    entity: ExampleArticle,
  );
  final at = DateTime.utc(2026, 10, 21, 8);
  await TomEntityLifecycle.notify(
    TomEntityChange(
      entityType: ExamplePatientRecord,
      kind: TomEntityChangeKind.updated,
      key: 7,
      beforeValues: TomFieldEncryption.redact(ExamplePatientRecord, {
        'name': 'Ada',
        'ward': 'east',
      }),
      afterValues: TomFieldEncryption.redact(ExamplePatientRecord, {
        'name': 'Ada',
        'ward': 'west',
      }),
      at: at,
      principalId: 'nurse-1',
      tenant: 'clinic',
    ),
  );
  stopPatients();
  stopArticles();
  final change = heard.single;
  print(
    '5. heard                    : $change, name '
    '${change.afterValues['name']}',
  );
  check(
    change.afterValues['name'] == TomFieldEncryption.redacted &&
        change.afterValues['ward'] == 'west',
    'the encrypted field is redacted, the plain one is not',
  );

  // 6. `toJson` is the form an outbox row or a message carries.
  final json = change.toJson();
  print('6. toJson                   : $json');
  check(
    json['kind'] == 'updated' &&
        json['key'] == '7' &&
        json['at'] == '2026-10-21T08:00:00.000Z' &&
        json['principal'] == 'nurse-1' &&
        json['tenant'] == 'clinic' &&
        (json['before'] as Map)['ward'] == 'east',
    'the change renders as JSON-ready values',
  );
  TomEntityLifecycle.reset();
}
