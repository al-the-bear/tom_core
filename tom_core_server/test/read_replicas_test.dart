/// Read-replica routing rules that need no database: which statements count
/// as reads, which entities are pinned to the primary, and which zones are
/// read-only work.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixturePinnedNote, FixtureReplicaNote;
import 'fixtures/reflection_fixture.reflection.dart';

void main() {
  setUpAll(initializeReflection);

  group('isReadStatement', () {
    for (final sql in [
      'SELECT * FROM t',
      '  select a from t where b = 1',
      '(SELECT a FROM t) UNION (SELECT a FROM u)',
      'WITH x AS (SELECT 1) SELECT * FROM x',
      '/* note */ SELECT a FROM t -- trailing',
    ]) {
      test('reads: $sql', () {
        expect(TomReplicaRouting.isReadStatement(sql), isTrue);
      });
    }
    for (final sql in [
      'INSERT INTO t VALUES (1)',
      'UPDATE t SET a = 1',
      'DELETE FROM t',
      'SELECT * FROM t FOR UPDATE',
      'SELECT * FROM t FOR SHARE',
      'SELECT * FROM t FOR NO KEY UPDATE',
      'SELECT a INTO @v FROM t',
      'SELECT GET_LOCK("x", 1)',
      "SELECT nextval('s')",
      'SELECT LAST_INSERT_ID()',
      'SELECT pg_advisory_lock(1)',
      'WITH d AS (DELETE FROM t RETURNING *) SELECT * FROM d',
      'CALL p()',
      'SHOW TABLES',
    ]) {
      test('does not read: $sql', () {
        expect(TomReplicaRouting.isReadStatement(sql), isFalse);
      });
    }
  });

  test('@TomPrimaryReads pins an entity to the primary', () {
    expect(TomReplicaRouting.readsFromPrimary(FixturePinnedNote), isTrue);
    expect(TomReplicaRouting.readsFromPrimary(FixtureReplicaNote), isFalse);
  });

  test('framework entities a decision is taken on read the primary', () {
    for (final type in [
      TomResourceGrant,
      TomPrincipalResourceGrant,
      TomPrincipalDelegation,
    ]) {
      expect(TomReplicaRouting.readsFromPrimary(type), isTrue, reason: '$type');
    }
  });

  test('readOnly marks read-only work; primary forces the primary', () async {
    expect(TomReplicaRouting.isReadOnlyContext, isFalse);
    await TomReplicaRouting.readOnly(() async {
      expect(TomReplicaRouting.isReadOnlyContext, isTrue);
      expect(TomReplicaRouting.isPrimaryForced, isFalse);
      await TomReplicaRouting.primary(() async {
        expect(TomReplicaRouting.isPrimaryForced, isTrue);
      });
    });
  });

  test('repositoryRead marks a replica-servable read, unless pinned', () async {
    expect(TomReplicaRouting.isRepositoryRead, isFalse);
    await TomReplicaRouting.repositoryRead(FixtureReplicaNote, () async {
      expect(TomReplicaRouting.isRepositoryRead, isTrue);
    });
    await TomReplicaRouting.repositoryRead(FixturePinnedNote, () async {
      expect(TomReplicaRouting.isRepositoryRead, isFalse);
    });
  });

  test('replicas must be a list of settings maps', () async {
    final ds = TomDataSource.createDatasourceOf('mariadb');
    await expectLater(
      ds.initialize({
        'username': 'u',
        'password': 'p',
        'host': '127.0.0.1',
        'port': 1,
        'databaseName': 'd',
        'replicas': 'x',
      }),
      throwsA(
        predicate((e) => '$e'.contains('error.initialize.invalid_replicas')),
      ),
    );
  });
}
