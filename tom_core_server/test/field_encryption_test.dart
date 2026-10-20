/// Field-level encryption without a database: the cipher and its stored form,
/// the keyring's envelope, data-key and key-encryption-key rotation, blind
/// indexes, audit redaction, and the refusals of the analyzer, the query
/// compiler and the configuration.
///
/// `field_encryption_db_test.dart` runs the repository and the background
/// re-encryption against a live database.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

/// A key-encryption key of 32 bytes of [seed].
TomAesKeyEncryptionKey _kek(String id, int seed) =>
    TomAesKeyEncryptionKey(id, List.filled(32, seed));

TomColumnInformation _column(String field) =>
    TomAnnotationAnalyzer.getPersistentColumns(
      FixturePatient,
    )!.firstWhere((c) => c.declaredName == field);

Matcher _refused(String key) => throwsA(
  isA<TomFieldEncryptionException>().having((e) => e.key, 'key', key),
);

/// Two memory stores behind one, chosen by the tenant in context: what a SQL
/// store routed per tenant looks like to a keyring.
class _TenantRoutedStore implements TomDataKeyStore {
  final Map<String, TomMemoryDataKeyStore> _stores = {};

  TomMemoryDataKeyStore get _current =>
      _stores[TomTenantContext.currentId ?? ''] ??= TomMemoryDataKeyStore();

  @override
  Object get scope => _current;

  @override
  Future<void> prepare() => _current.prepare();

  @override
  Future<List<TomDataKeyRecord>> all() => _current.all();

  @override
  Future<bool> insert(TomDataKeyRecord record) => _current.insert(record);

  @override
  Future<void> update(TomDataKeyRecord record) => _current.update(record);
}

void main() {
  setUpAll(initializeReflection);
  tearDown(TomFieldEncryption.reset);

  late TomMemoryDataKeyStore store;

  Future<TomFieldKeyring> install({
    List<TomKeyEncryptionKey>? keys,
    TomDataKeyStore? on,
  }) async {
    final keyring = TomFieldKeyring(
      store: on ?? store,
      keys: keys ?? [_kek('kek-1', 7)],
    );
    await TomFieldEncryption.install(keyring);
    return keyring;
  }

  setUp(() => store = TomMemoryDataKeyStore());

  group('the cipher', () {
    test('a value round-trips, and is stored as ciphertext', () async {
      await install();
      final name = _column('name');
      final stored = await TomFieldEncryption.encrypt(name, 'Ada Lovelace');
      expect(stored, startsWith(TomFieldEncryption.prefix));
      expect(stored, isNot(contains('Ada')));
      expect(TomFieldEncryption.decrypt(name, stored), 'Ada Lovelace');
      expect(await TomFieldEncryption.encrypt(name, null), isNull);
      expect(TomFieldEncryption.decrypt(name, null), isNull);
    });

    test('two encryptions of one value differ', () async {
      await install();
      final name = _column('name');
      final a = await TomFieldEncryption.encrypt(name, 'same');
      final b = await TomFieldEncryption.encrypt(name, 'same');
      expect(a, isNot(b));
    });

    test('a value moved to another column does not decrypt', () async {
      await install();
      final stored = await TomFieldEncryption.encrypt(_column('name'), 'x');
      expect(
        () => TomFieldEncryption.decrypt(_column('email'), stored),
        _refused('field_encryption.decrypt_failed'),
      );
    });

    test('an altered value does not decrypt', () async {
      await install();
      final name = _column('name');
      final stored = (await TomFieldEncryption.encrypt(name, 'secret'))!;
      final last = stored[stored.length - 2] == 'A' ? 'B' : 'A';
      final altered =
          '${stored.substring(0, stored.length - 2)}$last'
          '${stored.substring(stored.length - 1)}';
      expect(
        () => TomFieldEncryption.decrypt(name, altered),
        _refused('field_encryption.decrypt_failed'),
      );
    });

    test('plaintext reads as it is until it is no longer accepted', () async {
      await install();
      final name = _column('name');
      expect(TomFieldEncryption.decrypt(name, 'legacy'), 'legacy');
      TomFieldEncryption.acceptPlaintext = false;
      expect(
        () => TomFieldEncryption.decrypt(name, 'legacy'),
        _refused('field_encryption.plaintext_refused'),
      );
    });

    test('nothing encrypts without a keyring', () async {
      await expectLater(
        TomFieldEncryption.encrypt(_column('name'), 'x'),
        _refused('field_encryption.not_configured'),
      );
    });

    test('the stored length covers what is stored', () async {
      await install();
      const plaintext = 'someone@example.com';
      final stored = await TomFieldEncryption.encrypt(
        _column('email'),
        plaintext,
      );
      expect(
        stored!.length,
        lessThanOrEqualTo(
          TomFieldEncryption.storedLength(utf8.encode(plaintext).length),
        ),
      );
    });

    test('keyIdOf names the data key, and nothing for plaintext', () async {
      final keyring = await install();
      final stored = await TomFieldEncryption.encrypt(_column('name'), 'x');
      expect(TomFieldEncryption.keyIdOf(stored), await keyring.activeKeyId());
      expect(TomFieldEncryption.keyIdOf('plain'), isNull);
      expect(TomFieldEncryption.isCiphertext('plain'), isFalse);
    });
  });

  group('the envelope', () {
    test('the first load creates an encryption key and the index key, '
        'stored wrapped', () async {
      final keyring = await install();
      final records = await keyring.records();
      expect(
        records.map((r) => r.purpose),
        unorderedEquals(TomDataKeyPurpose.values),
      );
      for (final r in records) {
        expect(r.kekId, 'kek-1');
        expect(r.state, TomDataKeyState.active);
        // The stored form is wrapped: nonce, sealed key and tag, not the key.
        expect(base64.decode(r.wrapped), hasLength(12 + 32 + 16));
      }
      expect(
        records
            .where((r) => r.purpose == TomDataKeyPurpose.blindIndex)
            .single
            .id,
        TomFieldKeyring.indexKeyId,
      );
    });

    test('a keyring without the key-encryption key unwraps nothing', () async {
      await install();
      await expectLater(
        TomFieldKeyring(store: store, keys: [_kek('kek-2', 9)]).load(),
        _refused('field_encryption.unknown_kek'),
      );
      // The same id with other key bytes is refused too.
      await expectLater(
        TomFieldKeyring(store: store, keys: [_kek('kek-1', 9)]).load(),
        _refused('field_encryption.unknown_kek'),
      );
    });

    test('a key-encryption key needs an id and 32 bytes', () {
      expect(() => _kek('', 1), _refused('field_encryption.invalid_kek'));
      expect(
        () => TomAesKeyEncryptionKey('k', List.filled(16, 1)),
        _refused('field_encryption.invalid_kek'),
      );
      expect(
        () => TomAesKeyEncryptionKey.base64('k', '***'),
        _refused('field_encryption.invalid_kek'),
      );
      expect(
        TomAesKeyEncryptionKey.base64(
          'k',
          base64.encode(List.filled(32, 3)),
        ).id,
        'k',
      );
      expect(
        () => TomFieldKeyring(store: store, keys: const []),
        _refused('field_encryption.invalid_kek'),
      );
    });
  });

  group('rotation', () {
    test('a rotated data key encrypts new values, and old values still '
        'decrypt', () async {
      final keyring = await install();
      final name = _column('name');
      final before = await keyring.activeKeyId();
      final old = await TomFieldEncryption.encrypt(name, 'before');
      final next = await keyring.rotateDataKey();
      expect(next, isNot(before));
      final fresh = await TomFieldEncryption.encrypt(name, 'after');
      expect(TomFieldEncryption.keyIdOf(fresh), next);
      expect(TomFieldEncryption.decrypt(name, old), 'before');
      expect(TomFieldEncryption.decrypt(name, fresh), 'after');
      final states = {for (final r in await keyring.records()) r.id: r.state};
      expect(states[before], TomDataKeyState.previous);
      expect(states[next], TomDataKeyState.active);
    });

    test(
      'another node reads a value under a key it has not seen yet',
      () async {
        // Two keyrings over one store: two nodes.
        final first = TomFieldKeyring(store: store, keys: [_kek('kek-1', 7)]);
        final second = TomFieldKeyring(store: store, keys: [_kek('kek-1', 7)]);
        await first.load();
        await second.load();
        final rotated = await first.rotateDataKey();
        await TomFieldEncryption.install(first);
        final stored = await TomFieldEncryption.encrypt(_column('name'), 'x');
        expect(TomFieldEncryption.keyIdOf(stored), rotated);
        // The second node read the keys before the rotation: it reads the
        // table again when a value names a key it does not hold.
        expect(second.materialOf(rotated), isNull);
        expect(await second.ensure([rotated]), isEmpty);
        expect(second.materialOf(rotated), isNotNull);
        expect(await second.ensure(['no-such-key']), {'no-such-key'});
      },
    );

    test('a value naming a key nobody has is refused', () async {
      await install();
      const stored = '${TomFieldEncryption.prefix}no-such-key:AAAA';
      await TomFieldEncryption.prepareRead([stored]);
      expect(
        () => TomFieldEncryption.decrypt(_column('name'), stored),
        _refused('field_encryption.unknown_key'),
      );
    });

    test('a key-encryption key is rotated by re-wrapping, and no value '
        'changes', () async {
      final keyring = await install();
      final stored = await TomFieldEncryption.encrypt(_column('name'), 'kept');
      final rotated = TomFieldKeyring(
        store: store,
        keys: [_kek('kek-2', 9), _kek('kek-1', 7)],
      );
      expect(await rotated.rewrap(), 2);
      expect(await rotated.rewrap(), 0, reason: 'nothing left to re-wrap');
      expect((await keyring.records()).map((r) => r.kekId).toSet(), {'kek-2'});
      // The old key-encryption key can go: the new one alone reads it all.
      await install(keys: [_kek('kek-2', 9)]);
      expect(TomFieldEncryption.decrypt(_column('name'), stored), 'kept');
    });
  });

  group('blind indexes', () {
    test(
      'equal values index equally after normalisation, others do not',
      () async {
        await install();
        final a = await TomFieldEncryption.blindIndexOf(
          FixturePatient,
          'email',
          'Ada@Example.com ',
        );
        final b = await TomFieldEncryption.blindIndexOf(
          FixturePatient,
          'email',
          'ada@example.com',
        );
        final c = await TomFieldEncryption.blindIndexOf(
          FixturePatient,
          'email',
          'bob@example.com',
        );
        expect(a, b);
        expect(a, isNot(c));
        expect(a, isNot(contains('ada')));
        expect(
          await TomFieldEncryption.blindIndexOf(FixturePatient, 'email', null),
          isNull,
        );
      },
    );

    test('a data-key rotation leaves the index as it was', () async {
      final keyring = await install();
      final before = await TomFieldEncryption.blindIndexOf(
        FixturePatient,
        'email',
        'x@y.z',
      );
      await keyring.rotateDataKey();
      expect(
        await TomFieldEncryption.blindIndexOf(FixturePatient, 'email', 'x@y.z'),
        before,
      );
    });

    test('an index-key rotation keeps every key a lookup must match', () async {
      final keyring = await install();
      final before = await TomFieldEncryption.blindIndexOf(
        FixturePatient,
        'email',
        'x@y.z',
      );
      expect(await keyring.rotateIndexKey(), 'index-2');
      expect(await keyring.indexKeyIds(), ['index-2', 'index-1']);
      final after = await TomFieldEncryption.blindIndexOf(
        FixturePatient,
        'email',
        'x@y.z',
      );
      expect(after, isNot(before));
      expect(
        await TomFieldEncryption.blindIndexCandidates(
          FixturePatient,
          'email',
          'x@y.z',
        ),
        [after, before],
      );
      final c = await TomFieldEncryption.blindIndexCondition(
        FixturePatient,
        'email',
        'x@y.z',
      );
      expect(c.condition, 'emailIndex is in ( :emailIndex0 , :emailIndex1 )');
      expect(c.params, {'emailIndex0': after, 'emailIndex1': before});
      // The condition compiles.
      TomQuerySentenceCompiler([
        FixturePatient,
      ]).compileQuerySentence('find by ${c.condition}');
      // A node rotating again does not create a second key of one number.
      expect(await keyring.rotateIndexKey(), 'index-3');
      expect(
        (await keyring.records())
            .where((r) => r.purpose == TomDataKeyPurpose.blindIndex)
            .where((r) => r.state == TomDataKeyState.active)
            .map((r) => r.id),
        ['index-3'],
      );
    });

    test('each data source indexes under its own index key', () async {
      await install(on: _TenantRoutedStore());
      Future<String?> indexIn(String tenant) => TomTenantContext.run(
        tenant,
        () => TomFieldEncryption.blindIndexOf(FixturePatient, 'email', 'x@y.z'),
      );
      final a = await indexIn('acme');
      final b = await indexIn('globex');
      expect(a, isNot(b), reason: "two scopes' index-1 keys are two keys");
      expect(await indexIn('acme'), a, reason: 'and each stays its own');
    });

    test('a field without an index is a programmer error', () async {
      await install();
      await expectLater(
        TomFieldEncryption.blindIndexOf(FixturePatient, 'name', 'x'),
        throwsArgumentError,
      );
    });
  });

  group('everything around it', () {
    test('an audit image never carries an encrypted value', () {
      final image = TomFieldEncryption.redact(FixturePatient, {
        'id': 1,
        'name': 'Ada',
        'email': 'ada@example.com',
        'emailIndex': 'abc',
        'ward': 'B',
        'note': null,
      });
      expect(image, {
        'id': 1,
        'name': TomFieldEncryption.redacted,
        'email': TomFieldEncryption.redacted,
        'emailIndex': TomFieldEncryption.redacted,
        'ward': 'B',
        'note': null,
      });
      expect(TomFieldEncryption.redact(FixturePatient, const {'email': null}), {
        'email': null,
      });
    });

    test('a query on an encrypted column is refused', () {
      expect(
        () => TomQuerySentenceCompiler([
          FixturePatient,
        ]).compileQuerySentence('find by email = :e'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.encrypted_column',
          ),
        ),
      );
      // The index column compares.
      TomQuerySentenceCompiler([
        FixturePatient,
      ]).compileQuerySentence('find by emailIndex = :i');
    });

    test('a sort on an encrypted column is refused', () {
      final info = [
        TomAnnotationAnalyzer.analysePersistentType(FixturePatient),
      ];
      expect(
        () => TomGeneratedQuery.resolveSortColumns(const [
          TomSortField.asc('name'),
        ], info),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.encrypted_column',
          ),
        ),
      );
      expect(
        TomGeneratedQuery.resolveSortColumns(const [
          TomSortField.asc('ward'),
        ], info),
        hasLength(1),
      );
    });

    test('a keyring whose keys do not unwrap is not installed', () async {
      await install();
      TomFieldEncryption.reset();
      await expectLater(
        TomFieldEncryption.install(
          TomFieldKeyring(store: store, keys: [_kek('kek-2', 9)]),
        ),
        _refused('field_encryption.unknown_kek'),
      );
      expect(TomFieldEncryption.keyring, isNull);
    });

    test('the analyzer refuses what the repository could not maintain', () {
      void refused(Type type, String key) => expect(
        () => TomAnnotationAnalyzer.getPersistentColumns(type),
        throwsA(
          isA<TomAnnotationAnalyzerSyntaxException>().having(
            (e) => e.key,
            'key',
            key,
          ),
        ),
      );
      refused(
        FixtureEncryptedNumberRecord,
        'annotation_analyzer.encryption.not_string',
      );
      refused(
        FixtureEncryptedKeyRecord,
        'annotation_analyzer.encryption.structural_column',
      );
      refused(
        FixtureStrayIndexRecord,
        'annotation_analyzer.encryption.index_without_field',
      );
      refused(
        FixtureBothAnnotationsRecord,
        'annotation_analyzer.encryption.both',
      );
      expect(
        TomAnnotationAnalyzer.encryptedColumns(
          FixturePatient,
        ).map((c) => c.declaredName),
        ['name', 'email'],
      );
      expect(
        TomAnnotationAnalyzer.blindIndexColumns(
          FixturePatient,
        ).map((c) => c.declaredName),
        ['emailIndex'],
      );
    });

    test('the configuration is checked before anything is installed', () async {
      Future<void> invalid(Object? settings) => expectLater(
        TomFieldEncryption.configure(settings),
        _refused('field_encryption.config.invalid'),
      );
      final key = base64.encode(List.filled(32, 1));
      await invalid('nope');
      await invalid({'keys': []});
      await invalid({'datasource': 'main'});
      await invalid({
        'datasource': 'main',
        'keys': [
          {'id': 'k'},
        ],
      });
      await invalid({
        'datasource': 'main',
        'refreshSeconds': 0,
        'keys': [
          {'id': 'k', 'key': key},
        ],
      });
      await invalid({
        'datasource': 'main',
        'acceptPlaintext': 'yes',
        'keys': [
          {'id': 'k', 'key': key},
        ],
      });
      expect(TomFieldEncryption.keyring, isNull);
    });

    test(
      'a SQL key store naming an unregistered data source says so',
      () async {
        await expectLater(
          TomSqlDataKeyStore('no_such_source').prepare(),
          _refused('field_encryption.no_datasource'),
        );
      },
    );

    test('a raw read is marked for the data source', () {
      expect(TomFieldEncryption.isRaw, isFalse);
      expect(TomFieldEncryption.raw(() => TomFieldEncryption.isRaw), isTrue);
    });
  });
}
