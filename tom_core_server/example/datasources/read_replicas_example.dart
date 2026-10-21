/// Read replicas, step by step, without a database.
///
/// A SQL data source configured with `replicas` keeps a pool per replica beside
/// its own and sends a statement to a replica only when four rules hold: the
/// work is read-only, the statement is a repository read of an entity not
/// marked `@TomPrimaryReads`, it is a read ([TomReplicaRouting.isReadStatement])
/// and the principal has not written within `replicaStickinessMs`. Everything
/// those rules decide on is visible without a server, and this example shows
/// it:
///
///  1. which SQL counts as a read;
///  2. a [TomReplicaRouting.readOnly] block is read-only work;
///  3. a read-only transaction is read-only work, a write transaction is not;
///  4. [TomReplicaRouting.primary] forces the primary;
///  5. the framework entities pinned to the primary with `@TomPrimaryReads`;
///  6. a repository read marks its zone, unless its entity is pinned;
///  7. the replica settings and their defaults;
///  8. a `replicas` setting of the wrong shape is refused.
///
/// The routing itself — a read served by the replica, a write transaction and
/// a principal's recent write kept on the primary, a replica that cannot be
/// reached left out — runs against a live server in
/// `test/read_replicas_db_test.dart`; `doc/datasources.md` describes it under
/// "Read Replicas".
///
/// Run with `dart run example/datasources/read_replicas_example.dart`. Every
/// step checks its own result and the run fails when one does not hold, so a
/// green run is a verification and not just a transcript.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';
import '../example_reflection.reflection.dart';
import '../object_persistence/object_persistence_entities.dart';

Future<void> main() async {
  // Steps 5, 6 and 8 read annotations and bind settings through the reflector.
  initializeReflection();

  // 1. A read is a SELECT (or WITH … SELECT) that locks nothing, writes nothing
  //    and calls no session function. Anything else — and anything in doubt —
  //    runs on the primary.
  print('1. reads');
  const reads = [
    'SELECT id, title FROM article WHERE id = ?',
    'WITH recent AS (SELECT * FROM article) SELECT * FROM recent',
  ];
  const notReads = [
    'UPDATE article SET title = ? WHERE id = ?',
    'SELECT * FROM article WHERE id = ? FOR UPDATE',
    "SELECT nextval('article_seq')",
    'SELECT GET_LOCK(\'job\', 1)',
  ];
  for (final sql in [...reads, ...notReads]) {
    print(
      '   ${TomReplicaRouting.isReadStatement(sql) ? 'read   ' : 'primary'}'
      ' $sql',
    );
  }
  check(
    reads.every(TomReplicaRouting.isReadStatement),
    'a plain SELECT and a WITH … SELECT are reads',
  );
  check(
    !notReads.any(TomReplicaRouting.isReadStatement),
    'a write, a locking read and a session function are not',
  );

  // 2. Outside any marked context nothing is read-only work; a readOnly block
  //    is, which is what a GET or HEAD request runs in.
  print('2. readOnly');
  final outside = TomReplicaRouting.isReadOnlyContext;
  final inside = await TomReplicaRouting.readOnly(
    () async => TomReplicaRouting.isReadOnlyContext,
  );
  print('   outside: $outside, inside: $inside');
  check(!outside, 'plain code is not read-only work');
  check(inside, 'a readOnly block is read-only work');

  // 3. A running transaction decides for itself: a read-only one is read-only
  //    work, a write transaction is not — even inside a readOnly block.
  print('3. transactions');
  final inReadOnly = await TomTransactionManager.runInTransaction(
    (_) => TomReplicaRouting.isReadOnlyContext,
    isReadOnly: true,
  );
  final inWrite = await TomReplicaRouting.readOnly(
    () => TomTransactionManager.runInTransaction(
      (_) => TomReplicaRouting.isReadOnlyContext,
    ),
  );
  print('   read-only transaction: $inReadOnly, write transaction: $inWrite');
  check(inReadOnly, 'a read-only transaction is read-only work');
  check(!inWrite, 'everything in a write transaction runs on the primary');

  // 4. primary() sends every read of its block to the primary, whatever the
  //    context.
  print('4. primary');
  final forced = await TomReplicaRouting.readOnly(
    () => TomReplicaRouting.primary(
      () async => TomReplicaRouting.isPrimaryForced,
    ),
  );
  print('   primary forced inside readOnly: $forced');
  check(!TomReplicaRouting.isPrimaryForced, 'nothing is forced by default');
  check(forced, 'primary() forces the primary inside read-only work');

  // 5. The framework's own entities a decision is taken on are pinned to the
  //    primary with @TomPrimaryReads; an application entity is not, unless it
  //    says so.
  print('5. @TomPrimaryReads');
  const pinned = <Type>[
    TomResourceGrant,
    TomPrincipalResourceGrant,
    TomPrincipalDelegation,
    TomUserTwoFactorEnrolment,
    TomExternalIdentityLink,
    TomExternalIdentityToken,
  ];
  for (final type in pinned) {
    print('   $type: ${TomReplicaRouting.readsFromPrimary(type)}');
  }
  print(
    '   ExampleArticle: '
    '${TomReplicaRouting.readsFromPrimary(ExampleArticle)}',
  );
  check(
    pinned.every(TomReplicaRouting.readsFromPrimary),
    'grants, delegations, enrolments and identity links read the primary',
  );
  check(
    !TomReplicaRouting.readsFromPrimary(ExampleArticle),
    'an unannotated entity may be read from a replica',
  );

  // 6. A repository runs every read method inside repositoryRead, which marks
  //    the zone as a read a replica may serve — unless the entity is pinned.
  //    Statements outside it (the framework's own stores) read the primary.
  print('6. repositoryRead');
  final articleRead = await TomReplicaRouting.repositoryRead(
    ExampleArticle,
    () async => TomReplicaRouting.isRepositoryRead,
  );
  final grantRead = await TomReplicaRouting.repositoryRead(
    TomPrincipalResourceGrant,
    () async => TomReplicaRouting.isRepositoryRead,
  );
  print(
    '   ExampleArticle: $articleRead, '
    'TomPrincipalResourceGrant: $grantRead',
  );
  check(articleRead, 'a read of an unpinned entity may go to a replica');
  check(!grantRead, 'a read of a pinned entity stays on the primary');
  check(
    !TomReplicaRouting.isRepositoryRead,
    'a statement outside a repository read is not one',
  );

  // 7. The settings. `replicas` lists one map per replica, each overriding the
  //    primary's own settings — usually only the host. The two timings are
  //    integer settings, so `${…}` substitutions bind.
  print('7. settings');
  final db = MariaDbDatasource();
  print(
    '   replicas: ${db.replicas}, replicaStickinessMs: '
    '${db.replicaStickinessMs}, replicaRetryMs: ${db.replicaRetryMs}',
  );
  print('   routeSafeRequests: ${TomReplicaRouting.routeSafeRequests}');
  check(db.replicas.isEmpty, 'no replicas unless configured');
  check(db.replicaStickinessMs == 5000, 'read-your-writes lasts 5 s');
  check(db.replicaRetryMs == 30000, 'a failed replica is left out for 30 s');
  check(
    TomSqlDatasource.integerSettings.containsAll([
      'replicaStickinessMs',
      'replicaRetryMs',
    ]),
    'both timings fold a string into an int',
  );
  check(
    TomReplicaRouting.routeSafeRequests,
    'GET and HEAD requests are read-only work by default',
  );
  check(db.replicaSources.isEmpty, 'a replica opens with its data source');

  // 8. `replicas` that is not a list of settings maps is refused before the
  //    data source dials out.
  print('8. a malformed replicas setting');
  TomServerException? refused;
  try {
    await db.initialize({
      'host': 'db-primary',
      'port': 3306,
      'username': 'app',
      'password': 'secret',
      'databaseName': 'app',
      'replicas': 'db-replica-1',
    });
  } on TomServerException catch (e) {
    refused = e;
  }
  print('   ${refused?.key}');
  check(
    refused?.key == 'error.initialize.invalid_replicas',
    'a replicas setting that is not a list of maps is refused by name',
  );

  print('\nRead replicas example completed.');
}
