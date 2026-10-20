/// Field-level encryption with `@TomEncrypted`, step by step, without a
/// database.
///
/// Run with
/// `dart run example/object_persistence/field_encryption_example.dart`.
///
/// An encrypted field is stored as AES-256-GCM ciphertext under a data key,
/// and the data keys are kept wrapped under a key-encryption key that never
/// touches the database. Everything that decides what is stored is visible
/// without one: the keyring over the in-memory data-key store, the cipher the
/// repository calls on a save and the data source on a read, the blind index a
/// lookup by value compares, the three rotations, the audit redaction and the
/// query the compiler refuses. The round trip through a repository, and the
/// background re-encryption, run against a live database in
/// `test/field_encryption_db_test.dart`. Every step checks its own result, and
/// the run fails when one does not hold.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';
import '../example_reflection.reflection.dart';
import 'object_persistence_entities.dart';

/// A key-encryption key of 32 bytes of [seed]. A deployment reads its bytes
/// from a secret store; these are fixed so the run is reproducible.
TomAesKeyEncryptionKey _kek(String id, int seed) =>
    TomAesKeyEncryptionKey(id, List.filled(32, seed));

/// The column [field] of the example's patient record.
TomColumnInformation _column(String field) =>
    TomAnnotationAnalyzer.getPersistentColumns(
      ExamplePatientRecord,
    )!.firstWhere((c) => c.declaredName == field);

Future<void> main() async {
  initializeReflection();
  final store = TomMemoryDataKeyStore();
  final keyring = TomFieldKeyring(store: store, keys: [_kek('kek-1', 7)]);
  await TomFieldEncryption.install(keyring);

  // 1. The first load creates an encryption key and the first index key, and
  //    stores both wrapped under the key-encryption key.
  final records = await keyring.records();
  print(
    '1. data keys                : '
    '${records.map((r) => '${r.purpose.name}/${r.kekId}').join(', ')}',
  );
  check(
    records.length == 2 &&
        records.every((r) => r.state == TomDataKeyState.active) &&
        records.any((r) => r.id == TomFieldKeyring.indexKeyId),
    'one active encryption key and the index key exist, both wrapped',
  );

  // 2. A value is stored as ciphertext naming its data key, and reads back.
  final name = _column('name');
  final stored = (await TomFieldEncryption.encrypt(name, 'Ada Lovelace'))!;
  print('2. stored                   : ${stored.substring(0, 50)}…');
  check(
    stored.startsWith(TomFieldEncryption.prefix) && !stored.contains('Ada'),
    'the table holds ciphertext, never the plaintext',
  );
  check(
    TomFieldEncryption.keyIdOf(stored) == await keyring.activeKeyId(),
    'the stored value names the active data key',
  );
  check(
    TomFieldEncryption.decrypt(name, stored) == 'Ada Lovelace',
    'the value reads back as plaintext',
  );
  check(
    await TomFieldEncryption.encrypt(name, 'Ada Lovelace') != stored,
    'the encryption is randomised: equal values store differently',
  );
  check(
    stored.length <= TomFieldEncryption.storedLength('Ada Lovelace'.length),
    'storedLength covers what is stored',
  );

  // 3. The table and column are authenticated with the value: copied into
  //    another column, it does not decrypt.
  final email = _column('email');
  String? moved;
  try {
    TomFieldEncryption.decrypt(email, stored);
  } on TomFieldEncryptionException catch (refused) {
    moved = refused.key;
  }
  print('3. moved to another column  : $moved');
  check(
    moved == 'field_encryption.decrypt_failed',
    'a value moved to another column fails its authentication',
  );

  // 4. A lookup by value compares the blind index; the condition lists the
  //    index value under every index key, and normalisation makes equal
  //    addresses index equally.
  final lookup = await TomFieldEncryption.blindIndexCondition(
    ExamplePatientRecord,
    'email',
    ' Ada@Example.com',
  );
  print('4. lookup                   : find by ${lookup.condition}');
  check(
    lookup.condition == 'emailIndex is in ( :emailIndex0 )',
    'one index key, one value to compare',
  );
  check(
    lookup.params['emailIndex0'] ==
        await TomFieldEncryption.blindIndexOf(
          ExamplePatientRecord,
          'email',
          'ada@example.com',
        ),
    'trimmed and lower-cased, both spellings index equally',
  );
  TomQuerySentenceCompiler([
    ExamplePatientRecord,
  ]).compileQuerySentence('find by ${lookup.condition}');

  // 5. A data-key rotation: new values use the new key at once, and a value
  //    written under the old one still reads.
  final before = await keyring.activeKeyId();
  final rotated = await keyring.rotateDataKey();
  final fresh = (await TomFieldEncryption.encrypt(name, 'Grace Hopper'))!;
  print('5. data key rotated         : ${rotated != before}');
  check(
    TomFieldEncryption.keyIdOf(fresh) == rotated,
    'a value written after the rotation uses the new key',
  );
  check(
    TomFieldEncryption.decrypt(name, stored) == 'Ada Lovelace',
    'a value under the previous key still decrypts',
  );

  // 6. An index-key rotation: the lookup matches both index keys until the
  //    re-encryption pass has recomputed every row.
  final nextIndex = await keyring.rotateIndexKey();
  final during = await TomFieldEncryption.blindIndexCondition(
    ExamplePatientRecord,
    'email',
    'ada@example.com',
  );
  print('6. lookup during rotation   : find by ${during.condition}');
  check(nextIndex == 'index-2', 'index keys are numbered');
  check(
    during.params.length == 2 &&
        during.params['emailIndex1'] == lookup.params['emailIndex0'],
    'the lookup still finds a row indexed under the previous key',
  );

  // 7. A key-encryption-key rotation re-wraps the data keys; no value changes,
  //    and the new key alone then reads everything.
  final rewrapping = TomFieldKeyring(
    store: store,
    keys: [_kek('kek-2', 9), _kek('kek-1', 7)],
  );
  final rewrapped = await rewrapping.rewrap();
  await TomFieldEncryption.install(
    TomFieldKeyring(store: store, keys: [_kek('kek-2', 9)]),
  );
  print('7. data keys re-wrapped     : $rewrapped');
  check(rewrapped == 4, 'every data key is wrapped again under the new key');
  check(
    TomFieldEncryption.decrypt(name, stored) == 'Ada Lovelace',
    'the old key-encryption key is no longer needed',
  );

  // 8. An audit record's images carry no encrypted value.
  final image = TomFieldEncryption.redact(ExamplePatientRecord, {
    'name': 'Ada Lovelace',
    'emailIndex': lookup.params['emailIndex0'],
    'ward': 'B',
  });
  print('8. audit image              : $image');
  check(
    image['name'] == TomFieldEncryption.redacted &&
        image['emailIndex'] == TomFieldEncryption.redacted &&
        image['ward'] == 'B',
    'encrypted fields and blind indexes are redacted, other fields are not',
  );

  // 9. A condition on an encrypted column is refused: ciphertext compares
  //    equal to nothing.
  String? refusedQuery;
  try {
    TomQuerySentenceCompiler([
      ExamplePatientRecord,
    ]).compileQuerySentence('find by email = :email');
  } on TomQuerySyntaxException catch (refused) {
    refusedQuery = refused.key;
  }
  print('9. find by email            : $refusedQuery');
  check(
    refusedQuery == 'query_sentence_compiler.encrypted_column',
    'the compiler refuses to compare an encrypted column',
  );

  // 10. Plaintext left in an encrypted column reads as it is until it is no
  //     longer accepted.
  final legacy = TomFieldEncryption.decrypt(name, 'Old Timer');
  TomFieldEncryption.acceptPlaintext = false;
  String? plaintext;
  try {
    TomFieldEncryption.decrypt(name, 'Old Timer');
  } on TomFieldEncryptionException catch (refused) {
    plaintext = refused.key;
  }
  print('10. plaintext refused       : $plaintext');
  check(legacy == 'Old Timer', 'plaintext reads while it is accepted');
  check(
    plaintext == 'field_encryption.plaintext_refused',
    'once every column is encrypted, plaintext is refused',
  );
  TomFieldEncryption.reset();
}
