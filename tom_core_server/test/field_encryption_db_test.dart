/// Field-level encryption against a live database: a repository stores
/// ciphertext and reads plaintext, a blind index finds a row by value, a
/// data-key rotation is re-encrypted by a background job, and a column that
/// held plaintext before it was encrypted is migrated by the same pass.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixturePatient, FixturePatientRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const _patientDdl = '''
CREATE TABLE fixture_patient (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  name       TEXT         NULL,
  email      TEXT         NULL,
  email_bidx VARCHAR(64)  NULL,
  ward       VARCHAR(32)  NULL,
  PRIMARY KEY (id)
)''';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  late TomDataSourceInfo info;
  late FixturePatientRepository patients;
  late TomFieldKeyring keyring;

  final kek = TomAesKeyEncryptionKey('kek-1', List.filled(32, 7));

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    info = await TestDatabase.register();
  });

  tearDownAll(() async {
    if (!reachable) return;
    await TestDatabase.reset();
  });

  setUp(() async {
    if (!reachable) return;
    await info.datasource.executeCommand(
      'DROP TABLE IF EXISTS fixture_patient',
    );
    await TestDatabase.execute(info.datasource, _patientDdl);
    final keys = TomSqlDataKeyStore(TestDatabase.datasourceName);
    await keys.deleteAll();
    keyring = TomFieldKeyring(store: keys, keys: [kek]);
    await TomFieldEncryption.install(keyring);
    patients = FixturePatientRepository();
  });

  tearDown(TomFieldEncryption.reset);

  Future<FixturePatient> admit(String name, String email) => patients.save(
    FixturePatient()
      ..name = name
      ..email = email
      ..ward = 'B',
  );

  /// The row as stored, encrypted columns undecrypted.
  Future<FixturePatient> stored(int id) async =>
      (await TomFieldEncryption.raw<Future<FixturePatient?>>(
        () => patients.findById(id),
      ))!;

  test('stored values are ciphertext, and reads decrypt them', () async {
    final saved = await admit('Ada Lovelace', 'ada@example.com');
    expect(saved.name, 'Ada Lovelace');
    expect(saved.email, 'ada@example.com');

    final raw = await stored(saved.id!);
    expect(raw.name, startsWith(TomFieldEncryption.prefix));
    expect(raw.email, startsWith(TomFieldEncryption.prefix));
    expect(raw.name, isNot(contains('Ada')));
    expect(raw.ward, 'B', reason: 'a plain column is stored as it is');
    expect(raw.emailIndex, isNotNull);

    final read = await patients.findById(saved.id!);
    expect(read!.name, 'Ada Lovelace');
    expect(read.email, 'ada@example.com');
  }, skip: skip);

  test('a save re-encrypts the changed value; the plaintext never reaches '
      'the table', () async {
    final saved = await admit('Ada', 'ada@example.com');
    final first = (await stored(saved.id!)).name;
    final updated = await patients.save(saved..name = 'Ada King');
    expect(updated.name, 'Ada King');
    final second = (await stored(saved.id!)).name;
    expect(second, isNot(first));
    expect(second, isNot(contains('King')));
  }, skip: skip);

  test('a blind index finds a row by value', () async {
    await admit('Ada', 'ada@example.com');
    await admit('Bob', 'bob@example.com');
    final found = await patients
        .findByQuerySentence('find by emailIndex = :index', {
          'index': await TomFieldEncryption.blindIndexOf(
            FixturePatient,
            'email',
            ' ADA@example.com',
          ),
        });
    expect(found.map((p) => p.name), ['Ada']);
    await expectLater(
      () => patients.findByQuerySentence('find by email = :e', {'e': 'x'}),
      throwsA(
        isA<TomQuerySyntaxException>().having(
          (e) => e.key,
          'key',
          'query_sentence_compiler.encrypted_column',
        ),
      ),
    );
  }, skip: skip);

  test('a rotation is re-encrypted in the background, reads working '
      'throughout', () async {
    final ids = [
      for (final n in ['Ada', 'Bob', 'Cy']) (await admit(n, '$n@x.org')).id!,
    ];
    final old = TomFieldEncryption.keyIdOf((await stored(ids.first)).name);
    final next = await keyring.rotateDataKey();
    expect(next, isNot(old));
    // A save after the rotation already uses the new key.
    final late = (await admit('Dee', 'dee@x.org')).id!;
    expect(TomFieldEncryption.keyIdOf((await stored(late)).name), next);
    // Values under the old key still read, before the pass has run.
    expect((await patients.findById(ids.first))!.name, 'Ada');

    // The pass runs as a scheduler job, on the scheduler's own pass.
    final jobs = TomMemoryJobStore();
    final scheduler = TomScheduler(
      store: jobs,
      dispatcher: const TomInlineJobDispatcher(),
    );
    addTearDown(scheduler.close);
    final pass = TomFieldReencryption(entities: [FixturePatient], batchSize: 2);
    scheduler.register(
      pass.job(schedule: const TomEventSchedule(Stream<Object?>.empty())),
    );
    final now = DateTime.now();
    await jobs.enqueue(
      TomJobRun(
        id: 'reencrypt-1',
        jobName: tomReencryptionJobName,
        scheduledFor: now,
        runAt: now,
      ),
    );
    await scheduler.tick();
    await scheduler.drain();
    final run = (await jobs.all()).single;
    expect(run.state, TomJobRunState.succeeded);

    for (final id in [...ids, late]) {
      final raw = await stored(id);
      expect(TomFieldEncryption.keyIdOf(raw.name), next);
      expect(TomFieldEncryption.keyIdOf(raw.email), next);
    }
    expect(
      [for (final id in ids) (await patients.findById(id))!.name],
      ['Ada', 'Bob', 'Cy'],
    );
    final again = await pass.run();
    expect(again.rewritten, 0, reason: 'nothing is left under the old key');
    expect(again.examined, 4);
  }, skip: skip);

  test(
    'an index-key rotation finds every row before and after the pass',
    () async {
      final ada = (await admit('Ada', 'ada@example.com')).id!;
      Future<List<String?>> lookup(String email) async {
        final c = await TomFieldEncryption.blindIndexCondition(
          FixturePatient,
          'email',
          email,
        );
        return [
          for (final p in await patients.findByQuerySentence(
            'find by ${c.condition}',
            c.params,
          ))
            p.name,
        ];
      }

      final before = (await stored(ada)).emailIndex;
      await keyring.rotateIndexKey();
      await admit('Bob', 'bob@example.com');
      // Ada's row still holds the old index value, Bob's the new: both found.
      expect(await lookup('ada@example.com'), ['Ada']);
      expect(await lookup('bob@example.com'), ['Bob']);

      final report = await TomFieldReencryption(
        entities: [FixturePatient],
      ).run();
      expect(report.rewritten, 1, reason: "only Ada's index was stale");
      expect((await stored(ada)).emailIndex, isNot(before));
      expect(await lookup('ada@example.com'), ['Ada']);
    },
    skip: skip,
  );

  test('a column that held plaintext is encrypted by the pass, and its '
      'index filled', () async {
    await info.datasource.executeCommand(
      "INSERT INTO fixture_patient (name, email, ward) "
      "VALUES ('Old Timer', 'old@example.com', 'A')",
    );
    final legacy = (await patients.findAll()).single;
    expect(legacy.name, 'Old Timer', reason: 'plaintext reads as it is');
    expect((await stored(legacy.id!)).emailIndex, isNull);

    final report = await TomFieldReencryption(entities: [FixturePatient]).run();
    expect(report.rewritten, 1);
    expect(report.failures, isEmpty);

    final raw = await stored(legacy.id!);
    expect(raw.name, startsWith(TomFieldEncryption.prefix));
    expect(raw.emailIndex, isNotNull);
    final found = await patients
        .findByQuerySentence('find by emailIndex = :index', {
          'index': await TomFieldEncryption.blindIndexOf(
            FixturePatient,
            'email',
            'old@example.com',
          ),
        });
    expect(found.map((p) => p.name), ['Old Timer']);
    // Once every column is encrypted, plaintext can be refused.
    TomFieldEncryption.acceptPlaintext = false;
    expect((await patients.findById(legacy.id!))!.name, 'Old Timer');
  }, skip: skip);

  test(
    'the configuration installs a keyring over the data-key table',
    () async {
      TomFieldEncryption.reset();
      // The key comes from a secrets provider, named by reference.
      TomSecrets.register(
        TomMapSecretsProvider('field_encryption_test', {
          'kek': base64.encode(List.filled(32, 7)),
        }),
      );
      await TomFieldEncryption.configure({
        'datasource': TestDatabase.datasourceName,
        'keys': [
          {'id': 'kek-1', 'key': 'secret:field_encryption_test:kek'},
        ],
        'acceptPlaintext': false,
      });
      expect(TomFieldEncryption.acceptPlaintext, isFalse);
      final saved = await admit('Eve', 'eve@example.com');
      expect((await patients.findById(saved.id!))!.email, 'eve@example.com');
      final records = await TomFieldEncryption.keyring!.records();
      expect(records.map((r) => r.kekId).toSet(), {'kek-1'});
    },
    skip: skip,
  );
}
