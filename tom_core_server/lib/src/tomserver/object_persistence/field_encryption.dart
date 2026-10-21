/// Field-level encryption: personal data encrypted at rest, column by column,
/// with keys that rotate without downtime.
///
/// A `String` field marked [TomEncrypted] is stored as ciphertext and read as
/// plaintext. The repository encrypts it on every save and the data source
/// decrypts it on every read, so an entity — and everything above the
/// repository — only ever holds plaintext, and the database, its backups and
/// its replicas only ever hold ciphertext.
///
/// ## The cipher
///
/// AES-256-GCM, randomised: every write draws a fresh 96-bit nonce, so two
/// equal values store differently and the column reveals nothing about which
/// rows share a value. The table and column are the cipher's additional
/// authenticated data, so a value copied into another column — or another
/// table — fails its authentication instead of decrypting. A stored value reads
/// `tomenc:v1:<data key id>:<base64url of nonce, ciphertext and tag>`.
///
/// Randomised encryption cannot be compared, so an encrypted column cannot be
/// filtered on; the query compiler refuses it. A field that must be found by
/// value carries a [TomBlindIndex]: an HMAC-SHA-256 of the normalised plaintext
/// under an index key of its own, written by the repository beside the
/// ciphertext, and found with [TomFieldEncryption.blindIndexCondition].
///
/// ## Envelope encryption
///
/// Values are encrypted under **data keys**: random 256-bit keys kept in the
/// data-key table (`tom_encryption_key`), each one *wrapped* — itself encrypted
/// — under a **key-encryption key** ([TomKeyEncryptionKey]) that never touches
/// the database. The deployment supplies the key-encryption key, typically as a
/// `secret:` reference resolved from Vault, AWS Secrets Manager or Azure Key
/// Vault. A dump of the database decrypts nothing without it.
///
/// A [TomFieldKeyring] reads the data keys, unwraps them with the
/// key-encryption key and keeps them in memory; reads decrypt from that cache,
/// and a value naming a key the cache does not hold — one another node created
/// — makes the keyring read the table again.
///
/// ## Rotation without downtime
///
/// * **A data key** is rotated by [TomFieldKeyring.rotateDataKey]: a new key
///   becomes active and the old one is kept for reading. New writes use the new
///   key at once; values written under the old one still decrypt. A
///   [TomFieldReencryption] pass then rewrites them in the background, row by
///   row, each update guarded by the value it read so a concurrent save is
///   never overwritten. Other nodes pick the new key up within the keyring's
///   refresh interval; a value they write under the old key meanwhile is still
///   readable, and the next pass rewrites it.
/// * **A key-encryption key** is rotated by putting the new one first in the
///   keyring's list and calling [TomFieldKeyring.rewrap]: the data keys are
///   wrapped again under it, and no value is touched.
/// * **The index key** is rotated by [TomFieldKeyring.rotateIndexKey]: rows
///   saved from then on are indexed under the new key, and the pass recomputes
///   the others. A lookup through [TomFieldEncryption.blindIndexCondition]
///   matches every index key meanwhile, so no row goes missing.
///
/// The same pass encrypts a column that held plaintext before it was marked
/// [TomEncrypted] — which is why a plaintext value reads as it is while
/// [TomFieldEncryption.acceptPlaintext] is on — and fills a blind index added
/// later.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart'
    show AEADParameters, AESEngine, GCMBlockCipher, KeyParameter;
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:uuid/v4.dart';

import '../configuration/secrets.dart';
import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../tenancy/tenancy.dart';
import 'annotation_analyzer.dart';
import 'field_encryption_sql.dart';
import 'persistence_annotations.dart';

/// Field-level encryption that cannot proceed.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `field_encryption.not_configured` | An encrypted column was written or read with no keyring installed ([TomFieldEncryption.install]). |
/// | `field_encryption.unknown_key` | A stored value names a data key the keyring's table does not hold. |
/// | `field_encryption.decrypt_failed` | A stored value failed its authentication: it was altered, is malformed, or belongs to another column. |
/// | `field_encryption.plaintext_refused` | An encrypted column held plaintext while [TomFieldEncryption.acceptPlaintext] is off. |
/// | `field_encryption.unknown_kek` | A data key is wrapped under a key-encryption key the keyring was not given. |
/// | `field_encryption.invalid_kek` | A key-encryption key has no id, or is not 32 bytes. |
/// | `field_encryption.config.invalid` | The `fieldEncryption` configuration has the wrong shape. |
/// | `field_encryption.no_datasource` | The data source a [TomSqlDataKeyStore] names is not registered. |
class TomFieldEncryptionException extends TomServerException {
  /// Creates the exception; see [TomServerException] for the fields.
  TomFieldEncryptionException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
  }) : super(clientThrow: false);
}

/// What a data key is for.
enum TomDataKeyPurpose {
  /// Values are encrypted under it.
  encryption,

  /// Blind indexes are computed with it.
  blindIndex,
}

/// Whether a data key is the one new values use.
enum TomDataKeyState {
  /// New values use it; one per purpose.
  active,

  /// Kept so the values written under it still decrypt.
  previous,
}

/// One data key as the data-key table holds it: wrapped.
class TomDataKeyRecord {
  /// A record; see the fields.
  const TomDataKeyRecord({
    required this.id,
    required this.purpose,
    required this.state,
    required this.kekId,
    required this.wrapped,
    required this.createdAt,
  });

  /// The key's id, written into every value encrypted under it.
  final String id;

  /// What the key is for.
  final TomDataKeyPurpose purpose;

  /// Whether new values use it.
  final TomDataKeyState state;

  /// The key-encryption key it is wrapped under.
  final String kekId;

  /// The wrapped key, base64.
  final String wrapped;

  /// When it was created.
  final DateTime createdAt;

  /// This record with [state], [kekId] or [wrapped] replaced.
  TomDataKeyRecord copyWith({
    TomDataKeyState? state,
    String? kekId,
    String? wrapped,
  }) => TomDataKeyRecord(
    id: id,
    purpose: purpose,
    state: state ?? this.state,
    kekId: kekId ?? this.kekId,
    wrapped: wrapped ?? this.wrapped,
    createdAt: createdAt,
  );
}

/// A key-encryption key: what wraps the data keys, and never touches the
/// database.
abstract class TomKeyEncryptionKey {
  /// The key's id, recorded with every data key it wraps.
  String get id;

  /// [dataKey], wrapped; [keyId] is the data key's id, bound into the wrapping
  /// so a wrapped key cannot be passed off as another.
  Future<List<int>> wrap(List<int> dataKey, {required String keyId});

  /// The data key [wrapped] holds; throws when it was not wrapped by this key
  /// for [keyId].
  Future<List<int>> unwrap(List<int> wrapped, {required String keyId});
}

/// A key-encryption key held by the application: a 256-bit AES key, wrapping
/// with AES-GCM.
///
/// The key comes from wherever the deployment keeps secrets — most often a
/// `secret:` reference in the `fieldEncryption` configuration, resolved from
/// Vault, AWS Secrets Manager or Azure Key Vault before the server starts.
class TomAesKeyEncryptionKey implements TomKeyEncryptionKey {
  /// The key [key] (32 bytes), known as [id].
  TomAesKeyEncryptionKey(this.id, List<int> key)
    : _key = Uint8List.fromList(key) {
    if (id.isEmpty || id.length > 128 || _key.length != 32) {
      throw TomFieldEncryptionException(
        'field_encryption.invalid_kek',
        'A key-encryption key needs an id of 1 to 128 characters and 32 key '
            'bytes; got an id of ${id.length} characters and ${_key.length} '
            'bytes.',
        parameters: {'id': id},
      );
    }
  }

  /// The key whose 32 bytes [base64Key] encodes.
  factory TomAesKeyEncryptionKey.base64(String id, String base64Key) {
    final List<int> bytes;
    try {
      bytes = base64.decode(base64.normalize(base64Key.trim()));
    } on FormatException catch (error) {
      throw TomFieldEncryptionException(
        'field_encryption.invalid_kek',
        "The key-encryption key '$id' is not base64.",
        parameters: {'id': id},
        rootException: error,
      );
    }
    return TomAesKeyEncryptionKey(id, bytes);
  }

  @override
  final String id;

  final Uint8List _key;

  static String _aad(String keyId) => 'tom-data-key:$keyId';

  @override
  Future<List<int>> wrap(List<int> dataKey, {required String keyId}) async =>
      TomAesGcm.seal(_key, dataKey, _aad(keyId));

  @override
  Future<List<int>> unwrap(List<int> wrapped, {required String keyId}) async =>
      TomAesGcm.open(_key, wrapped, _aad(keyId));
}

/// AES-256-GCM with a random 96-bit nonce prepended to the sealed bytes — the
/// cipher of field encryption, of data-key wrapping and of the per-subject
/// sealing of audit values.
abstract final class TomAesGcm {
  static final Random _random = Random.secure();

  /// [plaintext] sealed under the 32-byte [key], [aad] authenticated with it:
  /// nonce, ciphertext and tag.
  static Uint8List seal(List<int> key, List<int> plaintext, String aad) {
    final nonce = Uint8List.fromList([
      for (var i = 0; i < 12; i++) _random.nextInt(256),
    ]);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(Uint8List.fromList(key)),
          128,
          nonce,
          Uint8List.fromList(utf8.encode(aad)),
        ),
      );
    final sealed = cipher.process(Uint8List.fromList(plaintext));
    return Uint8List.fromList([...nonce, ...sealed]);
  }

  /// The plaintext [sealed] holds. Throws [ArgumentError] (pointycastle's
  /// `InvalidCipherTextException` included) when [sealed] does not
  /// authenticate under [key] and [aad].
  static Uint8List open(List<int> key, List<int> sealed, String aad) {
    if (sealed.length < 12 + 16) {
      // throws-outside-family: programmer error — the caller turns it into
      // field_encryption.decrypt_failed with the value it was reading.
      throw ArgumentError('A sealed value is at least 28 bytes.');
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(Uint8List.fromList(key)),
          128,
          Uint8List.fromList(sealed.sublist(0, 12)),
          Uint8List.fromList(utf8.encode(aad)),
        ),
      );
    return cipher.process(Uint8List.fromList(sealed.sublist(12)));
  }
}

/// Where the wrapped data keys are kept.
abstract class TomDataKeyStore {
  /// Makes the store ready — creates its table — for the data source the
  /// current context resolves. Called outside any transaction.
  Future<void> prepare();

  /// What the current context's keys belong to: one data source's keys are
  /// not another's. The memory store answers itself.
  Object get scope;

  /// Every data key of [scope].
  Future<List<TomDataKeyRecord>> all();

  /// Stores [record]; answers `false` when its id is taken.
  Future<bool> insert(TomDataKeyRecord record);

  /// Replaces the stored record of [record]'s id.
  Future<void> update(TomDataKeyRecord record);
}

/// Data keys in memory: for tests, and for a single process whose encrypted
/// data is in memory too.
class TomMemoryDataKeyStore implements TomDataKeyStore {
  final Map<String, TomDataKeyRecord> _records = {};

  @override
  Future<void> prepare() async {}

  @override
  Object get scope => this;

  @override
  Future<List<TomDataKeyRecord>> all() async => List.of(_records.values);

  @override
  Future<bool> insert(TomDataKeyRecord record) async {
    if (_records.containsKey(record.id)) return false;
    _records[record.id] = record;
    return true;
  }

  @override
  Future<void> update(TomDataKeyRecord record) async =>
      _records[record.id] = record;
}

/// Data keys in a SQL data source, resolved by name on every call — so under
/// tenancy each tenant's data source holds its own keys.
class TomSqlDataKeyStore implements TomDataKeyStore {
  /// A store in [table] of the data source registered as [datasourceName].
  ///
  /// With [createSchema] (the default) the table is created on first use in
  /// each data source; a deployment whose user may not run DDL applies the
  /// shipped migration and passes `false`.
  TomSqlDataKeyStore(
    String this.datasourceName, {
    this.table = defaultEncryptionKeyTable,
    this.createSchema = true,
  }) : _fixed = null;

  /// A store in [table] of [datasource] itself, resolved once.
  TomSqlDataKeyStore.over(
    TomDataSource datasource, {
    this.table = defaultEncryptionKeyTable,
    this.createSchema = true,
  }) : datasourceName = null,
       _fixed = datasource;

  /// The registered name of the data source, or `null` for a store built
  /// [TomSqlDataKeyStore.over] one.
  final String? datasourceName;

  final TomDataSource? _fixed;

  /// The table's name.
  final String table;

  /// Whether the table is created on first use.
  final bool createSchema;

  late final TomFrameworkTable _table = encryptionKeyTable(table);
  final Expando<TomSchemaProvisioning> _schemas = Expando();

  TomDataSource _resolve() {
    final fixed = _fixed;
    if (fixed != null) return fixed;
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName!);
    if (info == null) {
      throw TomFieldEncryptionException(
        'field_encryption.no_datasource',
        "The data-key store's data source '$datasourceName' is not "
            'registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return info.datasource;
  }

  @override
  Object get scope => _resolve();

  @override
  Future<void> prepare() async {
    if (!createSchema) return;
    final ds = _resolve();
    await (_schemas[ds] ??= TomSchemaProvisioning()).ensure(
      () => _table.create(ds),
    );
  }

  static Map<String, Object?> _bind(TomDataKeyRecord r) => {
    'id': r.id,
    'purpose': r.purpose.name,
    'state': r.state.name,
    'kek': r.kekId,
    'wrapped': r.wrapped,
    'created': sqlInstant(r.createdAt),
  };

  @override
  Future<List<TomDataKeyRecord>> all() async {
    final rows = await _resolve().executeQuery<TomDataKeyRow>(
      'SELECT key_id, purpose, state, kek_id, wrapped_key, created_at '
      'FROM $table',
    );
    return [for (final row in rows) row.toRecord()];
  }

  @override
  Future<bool> insert(TomDataKeyRecord record) async {
    final ds = _resolve();
    final inserted = await ds.executeCommand(
      _table.insertRow(ds.sqlDialect, const {
        'key_id': ':id',
        'purpose': ':purpose',
        'state': ':state',
        'kek_id': ':kek',
        'wrapped_key': ':wrapped',
        'created_at': ':created',
      }, ignoreConflict: true),
      _bind(record),
    );
    return inserted != BigInt.zero;
  }

  @override
  Future<void> update(TomDataKeyRecord record) async {
    await _resolve().executeCommand(
      'UPDATE $table SET state = :state, kek_id = :kek, '
      'wrapped_key = :wrapped WHERE key_id = :id',
      _bind(record),
    );
  }

  /// Empties the table of the data source this context resolves. For tests.
  Future<void> deleteAll() async {
    await prepare();
    await _resolve().executeCommand('DELETE FROM $table');
  }
}

/// One row of the data-key table, as [TomSqlDataKeyStore] reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["keyId"],
)
class TomDataKeyRow {
  /// The key's id.
  @TomDbColumn(columnName: "key_id")
  String keyId = "";

  /// The purpose's name.
  @TomDbColumn(columnName: "purpose")
  String purpose = "";

  /// The state's name.
  @TomDbColumn(columnName: "state")
  String state = "";

  /// The wrapping key-encryption key.
  @TomDbColumn(columnName: "kek_id")
  String kekId = "";

  /// The wrapped key, base64.
  @TomDbColumn(columnName: "wrapped_key")
  String wrappedKey = "";

  /// When it was created, as stored UTC text.
  @TomDbColumn(columnName: "created_at")
  String createdAt = "";

  /// The record this row stores.
  TomDataKeyRecord toRecord() => TomDataKeyRecord(
    id: keyId,
    purpose: TomDataKeyPurpose.values.byName(purpose),
    state: TomDataKeyState.values.byName(state),
    kekId: kekId,
    wrapped: wrappedKey,
    createdAt: parseSqlInstant(createdAt),
  );
}

/// The data keys of one scope as a keyring last read them.
class _TomKeyringScope {
  String? activeEncryption;
  String? activeIndex;

  /// Every index key of the scope, the active one first.
  List<String> indexKeys = const [];
  DateTime loadedAt = DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);
}

/// The data keys, unwrapped and cached — see the library documentation.
class TomFieldKeyring {
  /// A keyring over [store], whose data keys are wrapped under [keys]: the
  /// first wraps every new data key and every [rewrap]; the others only
  /// unwrap, so a rotated-out key-encryption key stays in the list until
  /// [rewrap] has run.
  ///
  /// Every [refreshInterval] the keyring reads the table again, which is how a
  /// node learns of a data key another node rotated in.
  TomFieldKeyring({
    required this.store,
    required List<TomKeyEncryptionKey> keys,
    this.refreshInterval = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : keys = List.unmodifiable(keys),
       _clock = clock ?? DateTime.now {
    if (this.keys.isEmpty) {
      throw TomFieldEncryptionException(
        'field_encryption.invalid_kek',
        'A keyring needs at least one key-encryption key.',
      );
    }
  }

  /// Where the wrapped data keys are kept.
  final TomDataKeyStore store;

  /// The key-encryption keys; the first is the primary.
  final List<TomKeyEncryptionKey> keys;

  /// How long the keyring trusts what it read.
  final Duration refreshInterval;

  final DateTime Function() _clock;

  /// The unwrapped keys, by scope and id: an index key's id (`index-1`) is
  /// the same in every data source, and each data source's key is its own.
  final Map<(Object, String), Uint8List> _material = {};
  final Map<Object, _TomKeyringScope> _scopes = {};
  static final Random _random = Random.secure();

  /// The id of the first index key, the same in every scope: two nodes
  /// creating it at once insert one row, and every blind index is computed
  /// with one key. [rotateIndexKey] numbers its successors the same way.
  static const String indexKeyId = 'index-1';

  /// Reads the data keys of the current context's scope and unwraps the ones
  /// not yet cached; creates the first encryption key and the index key when
  /// the scope has none.
  Future<void> load() async {
    await store.prepare();
    var records = await store.all();
    var created = false;
    if (!records.any(
      (r) =>
          r.purpose == TomDataKeyPurpose.encryption &&
          r.state == TomDataKeyState.active,
    )) {
      created |= await _create(TomDataKeyPurpose.encryption, _newId());
    }
    if (!records.any((r) => r.purpose == TomDataKeyPurpose.blindIndex)) {
      created |= await _create(TomDataKeyPurpose.blindIndex, indexKeyId);
    }
    if (created) records = await store.all();
    final scope = store.scope;
    final state = _scopes[scope] ??= _TomKeyringScope();
    for (final r in records) {
      _material[(scope, r.id)] ??= await _unwrap(r);
    }
    state
      ..activeEncryption = _newestActive(records, TomDataKeyPurpose.encryption)
      ..activeIndex = _newestActive(records, TomDataKeyPurpose.blindIndex)
      ..indexKeys = [
        for (final r in [
          ...records,
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          if (r.purpose == TomDataKeyPurpose.blindIndex) r.id,
      ]
      ..loadedAt = _clock().toUtc();
    final active = state.activeIndex;
    if (active != null) {
      state.indexKeys = [active, ...state.indexKeys.where((k) => k != active)];
    }
  }

  static String? _newestActive(
    List<TomDataKeyRecord> records,
    TomDataKeyPurpose purpose,
  ) {
    final active = [
      for (final r in records)
        if (r.purpose == purpose && r.state == TomDataKeyState.active) r,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (active.isNotEmpty) return active.first.id;
    // An index key never retires, but a scope whose only key is `previous`
    // still has one to use.
    final any = [
      for (final r in records)
        if (r.purpose == purpose) r,
    ];
    return any.isEmpty ? null : any.first.id;
  }

  String _newId() => const UuidV4().generate();

  Future<bool> _create(TomDataKeyPurpose purpose, String id) async {
    final material = [for (var i = 0; i < 32; i++) _random.nextInt(256)];
    final primary = keys.first;
    return store.insert(
      TomDataKeyRecord(
        id: id,
        purpose: purpose,
        state: TomDataKeyState.active,
        kekId: primary.id,
        wrapped: base64.encode(await primary.wrap(material, keyId: id)),
        createdAt: _clock().toUtc(),
      ),
    );
  }

  Future<Uint8List> _unwrap(TomDataKeyRecord record) async {
    final kek = keys.where((k) => k.id == record.kekId).firstOrNull;
    if (kek == null) {
      throw TomFieldEncryptionException(
        'field_encryption.unknown_kek',
        "The data key '${record.id}' is wrapped under the key-encryption key "
            "'${record.kekId}', which this keyring was not given.",
        parameters: {'key': record.id, 'kek': record.kekId},
      );
    }
    try {
      return Uint8List.fromList(
        await kek.unwrap(base64.decode(record.wrapped), keyId: record.id),
      );
    } catch (error) {
      throw TomFieldEncryptionException(
        'field_encryption.unknown_kek',
        "The data key '${record.id}' does not unwrap under the key-encryption "
            "key '${record.kekId}': it is not the key that wrapped it.",
        parameters: {'key': record.id, 'kek': record.kekId},
        rootException: error,
      );
    }
  }

  Future<_TomKeyringScope> _current() async {
    final state = _scopes[store.scope];
    if (state == null ||
        _clock().toUtc().difference(state.loadedAt) >= refreshInterval) {
      await load();
    }
    return _scopes[store.scope]!;
  }

  /// The id of the data key new values in the current context are encrypted
  /// under.
  Future<String> activeKeyId() async => (await _current()).activeEncryption!;

  /// The id of the index key of the current context.
  Future<String> indexKeyIdInUse() async => (await _current()).activeIndex!;

  /// Every index key of the current context, the active one first: what a
  /// lookup matches while an index-key rotation is being rewritten.
  Future<List<String>> indexKeyIds() async => (await _current()).indexKeys;

  /// The unwrapped key [id] of the current context's scope, or `null` when it
  /// is not cached.
  Uint8List? materialOf(String id) => _material[(store.scope, id)];

  /// Makes sure every key in [ids] is cached, reading the table again when one
  /// is not; answers the ids that are still unknown.
  Future<Set<String>> ensure(Iterable<String> ids) async {
    final missing = {
      for (final id in ids)
        if (materialOf(id) == null) id,
    };
    if (missing.isEmpty) return const {};
    await load();
    return {
      for (final id in missing)
        if (materialOf(id) == null) id,
    };
  }

  /// The data keys of the current context, as stored.
  Future<List<TomDataKeyRecord>> records() async {
    await store.prepare();
    return store.all();
  }

  /// Creates a data key and makes it the active encryption key of the current
  /// context; the key it replaces stays, for reading. Answers the new key's
  /// id. New values use it at once; a [TomFieldReencryption] pass moves the
  /// old ones over.
  Future<String> rotateDataKey() async {
    await store.prepare();
    final id = _newId();
    await _create(TomDataKeyPurpose.encryption, id);
    for (final r in await store.all()) {
      if (r.id != id &&
          r.purpose == TomDataKeyPurpose.encryption &&
          r.state == TomDataKeyState.active) {
        await store.update(r.copyWith(state: TomDataKeyState.previous));
      }
    }
    await load();
    return id;
  }

  /// Creates the next index key (`index-2`, `index-3`, …) and makes it the
  /// active one of the current context; answers its id. The numbering makes
  /// two nodes rotating at once create one key, not two.
  ///
  /// New and saved rows are indexed under it at once; a [TomFieldReencryption]
  /// pass recomputes the rest. Until it has, a lookup matches every index key
  /// — [TomFieldEncryption.blindIndexCondition] — so nothing goes missing.
  Future<String> rotateIndexKey() async {
    await store.prepare();
    final records = await store.all();
    var highest = 0;
    for (final r in records) {
      if (r.purpose != TomDataKeyPurpose.blindIndex) continue;
      final n = int.tryParse(r.id.replaceFirst('index-', '')) ?? 0;
      if (n > highest) highest = n;
    }
    final id = 'index-${highest + 1}';
    await _create(TomDataKeyPurpose.blindIndex, id);
    for (final r in await store.all()) {
      if (r.id != id &&
          r.purpose == TomDataKeyPurpose.blindIndex &&
          r.state == TomDataKeyState.active) {
        await store.update(r.copyWith(state: TomDataKeyState.previous));
      }
    }
    await load();
    return id;
  }

  /// Wraps every data key of the current context under the primary
  /// key-encryption key that is not wrapped under it yet; answers how many it
  /// re-wrapped. The rotation of a key-encryption key: no value is touched.
  /// The privacy module's subject keys, wrapped under the same keys, are
  /// re-wrapped by `TomSubjectKeys.rewrap`.
  Future<int> rewrap() async {
    await load();
    final primary = keys.first;
    var count = 0;
    for (final r in await store.all()) {
      if (r.kekId == primary.id) continue;
      final material = materialOf(r.id)!;
      await store.update(
        r.copyWith(
          kekId: primary.id,
          wrapped: base64.encode(await primary.wrap(material, keyId: r.id)),
        ),
      );
      count++;
    }
    return count;
  }
}

/// The isolate's field encryption: the installed keyring, and what the
/// repository and the data source call — see the library documentation.
abstract final class TomFieldEncryption {
  /// What every stored ciphertext starts with.
  static const String prefix = 'tomenc:v1:';

  /// What an audit record holds for an encrypted field or a blind index, in
  /// place of its value.
  static const String redacted = '[encrypted]';

  /// The configuration key of the settings — see [configure].
  static const String configurationKey = 'fieldEncryption';

  static TomFieldKeyring? _keyring;

  /// The installed keyring, or `null`.
  static TomFieldKeyring? get keyring => _keyring;

  /// Whether a value of an encrypted column that is not ciphertext reads as
  /// it is. On by default, so a column marked [TomEncrypted] after it held
  /// data keeps reading until a [TomFieldReencryption] pass has encrypted it;
  /// turn it off once every column is encrypted, and a plaintext value then
  /// fails the read (`field_encryption.plaintext_refused`).
  static bool acceptPlaintext = true;

  static final Object _rawKey = Object();

  /// Loads [keyring]'s keys for the current context and installs it.
  static Future<void> install(TomFieldKeyring keyring) async {
    // Loaded first: a keyring whose keys do not unwrap is not installed.
    await keyring.load();
    _keyring = keyring;
  }

  /// Removes the keyring and restores the defaults. For tests.
  static void reset() {
    _keyring = null;
    acceptPlaintext = true;
  }

  /// Installs a keyring from [settings], the `fieldEncryption` configuration
  /// map:
  ///
  /// | Key | Meaning |
  /// | --- | ------- |
  /// | `datasource` | the data source of the data-key table (required) |
  /// | `table` | the table's name; default `tom_encryption_key` |
  /// | `createSchema` | create the table on first use; default `true` |
  /// | `keys` | the key-encryption keys, primary first: a list of `{id, key}`, `key` the base64 of 32 bytes or a `secret:` reference to it, resolved here through `TomSecrets` (required) |
  /// | `refreshSeconds` | how often a node reads the keys again; default 300 |
  /// | `acceptPlaintext` | [acceptPlaintext]; default `true` |
  ///
  /// Throws `field_encryption.config.invalid` for a value of the wrong shape.
  static Future<void> configure(Object? settings) async {
    Never invalid(String why) => throw TomFieldEncryptionException(
      'field_encryption.config.invalid',
      'The $configurationKey configuration is invalid: $why.',
    );
    if (settings is! Map) invalid('it is not a map');
    final datasource = settings['datasource'];
    if (datasource is! String || datasource.isEmpty) {
      invalid('`datasource` names no data source');
    }
    final table = settings['table'] ?? defaultEncryptionKeyTable;
    if (table is! String) invalid('`table` is not a string');
    final createSchema = settings['createSchema'] ?? true;
    if (createSchema is! bool) invalid('`createSchema` is not a boolean');
    final refresh = settings['refreshSeconds'] ?? 300;
    if (refresh is! int || refresh < 1) {
      invalid('`refreshSeconds` is not a positive whole number');
    }
    final accept = settings['acceptPlaintext'] ?? true;
    if (accept is! bool) invalid('`acceptPlaintext` is not a boolean');
    final rawKeys = settings['keys'];
    if (rawKeys is! List || rawKeys.isEmpty) {
      invalid('`keys` lists no key-encryption key');
    }
    final keys = <TomKeyEncryptionKey>[];
    for (final entry in rawKeys) {
      if (entry is! Map || entry['id'] is! String || entry['key'] is! String) {
        invalid('every entry of `keys` needs an `id` and a `key`');
      }
      // A `secret:` reference is resolved here, through the registered
      // providers, whether or not the configuration was substituted before.
      final key = entry['key'] as String;
      keys.add(
        TomAesKeyEncryptionKey.base64(
          entry['id'] as String,
          TomSecretReference.isReference(key)
              ? await TomSecrets.resolve(key)
              : key,
        ),
      );
    }
    acceptPlaintext = accept;
    await install(
      TomFieldKeyring(
        store: TomSqlDataKeyStore(
          datasource,
          table: table,
          createSchema: createSchema,
        ),
        keys: keys,
        refreshInterval: Duration(seconds: refresh),
      ),
    );
  }

  static TomFieldKeyring _require() =>
      _keyring ??
      (throw TomFieldEncryptionException(
        'field_encryption.not_configured',
        'An encrypted column was used with no keyring installed; call '
            'TomFieldEncryption.install or configure `$configurationKey`.',
      ));

  /// Runs [body] with decryption off: the data source maps an encrypted
  /// column's stored value as it is, and loads no references. What a
  /// [TomFieldReencryption] pass reads through.
  static R raw<R>(R Function() body) =>
      runZoned(body, zoneValues: {_rawKey: true});

  /// Whether the current zone reads raw.
  static bool get isRaw => Zone.current[_rawKey] == true;

  /// Whether [stored] is ciphertext of this format.
  static bool isCiphertext(String? stored) =>
      stored != null && stored.startsWith(prefix);

  /// The data key id [stored] was encrypted under, or `null` for plaintext.
  static String? keyIdOf(String? stored) {
    if (!isCiphertext(stored)) return null;
    final end = stored!.indexOf(':', prefix.length);
    return end < 0 ? null : stored.substring(prefix.length, end);
  }

  /// How many characters a stored value of [plaintextBytes] UTF-8 bytes takes:
  /// what an encrypted column's width must allow.
  static int storedLength(int plaintextBytes) =>
      prefix.length + 36 + 1 + ((12 + plaintextBytes + 16) * 4 / 3).ceil();

  static String _aad(TomColumnInformation column) =>
      '${column.table.table}.${column.field}';

  /// [plaintext] encrypted for [column] under the active data key of the
  /// current context; `null` stays `null`.
  static Future<String?> encrypt(
    TomColumnInformation column,
    String? plaintext,
  ) async {
    if (plaintext == null) return null;
    final keyring = _require();
    final keyId = await keyring.activeKeyId();
    final sealed = TomAesGcm.seal(
      keyring.materialOf(keyId)!,
      utf8.encode(plaintext),
      _aad(column),
    );
    return '$prefix$keyId:${base64Url.encode(sealed).replaceAll('=', '')}';
  }

  /// Loads the data keys the ciphertexts among [stored] name, so [decrypt]
  /// finds them. Called by the data source before it maps a result.
  static Future<void> prepareRead(Iterable<String?> stored) async {
    final ids = {for (final value in stored) ?keyIdOf(value)};
    if (ids.isEmpty) return;
    await _require().ensure(ids);
  }

  /// The plaintext of [stored], read from [column]; `null` stays `null`.
  ///
  /// The data key must be cached — [prepareRead] makes it so. A value that is
  /// not ciphertext reads as it is while [acceptPlaintext] is on.
  static String? decrypt(TomColumnInformation column, String? stored) {
    if (stored == null) return null;
    if (!isCiphertext(stored)) {
      if (acceptPlaintext) return stored;
      throw TomFieldEncryptionException(
        'field_encryption.plaintext_refused',
        '${column.tableType}.${column.declaredName} holds a value that is not '
            'encrypted, and plaintext is not accepted.',
        parameters: {'entity': '${column.tableType}', 'field': column.field},
      );
    }
    final keyring = _require();
    final keyId = keyIdOf(stored);
    final key = keyId == null ? null : keyring.materialOf(keyId);
    if (key == null) {
      throw TomFieldEncryptionException(
        'field_encryption.unknown_key',
        '${column.tableType}.${column.declaredName} holds a value encrypted '
            "under the data key '$keyId', which the keyring does not hold.",
        parameters: {'entity': '${column.tableType}', 'key': keyId},
      );
    }
    try {
      final body = stored.substring(prefix.length + keyId!.length + 1);
      final sealed = base64Url.decode(base64Url.normalize(body));
      return utf8.decode(TomAesGcm.open(key, sealed, _aad(column)));
    } catch (error) {
      throw TomFieldEncryptionException(
        'field_encryption.decrypt_failed',
        '${column.tableType}.${column.declaredName} holds a value that does '
            'not decrypt: it was altered, or belongs to another column.',
        parameters: {'entity': '${column.tableType}', 'field': column.field},
        rootException: error,
      );
    }
  }

  static String _normalize(String value, TomBlindIndexNormalization how) =>
      switch (how) {
        TomBlindIndexNormalization.exact => value,
        TomBlindIndexNormalization.trim => value.trim(),
        TomBlindIndexNormalization.trimLowercase => value.trim().toLowerCase(),
      };

  /// The blind index of [plaintext] for the index column [indexColumn], under
  /// the index key [keyId] — the active one unless given; `null` stays `null`.
  static Future<String?> blindIndex(
    TomColumnInformation indexColumn,
    String? plaintext, {
    String? keyId,
  }) async {
    final index = indexColumn.blindIndex!;
    if (plaintext == null) return null;
    final keyring = _require();
    final key = keyring.materialOf(keyId ?? await keyring.indexKeyIdInUse())!;
    final digest = Hmac(sha256, key).convert(
      utf8.encode(
        '${indexColumn.table.table}.${index.field}\u0000'
        '${_normalize(plaintext, index.normalization)}',
      ),
    );
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static TomColumnInformation _indexColumn(Type entity, String field) {
    final column = TomAnnotationAnalyzer.blindIndexColumns(
      entity,
    ).where((c) => c.blindIndex!.field == field).firstOrNull;
    if (column == null) {
      // throws-outside-family: programmer error — the entity declares no such
      // index; the analyzer knows its fields.
      throw ArgumentError.value(
        field,
        'field',
        '$entity has no @TomBlindIndex for this field',
      );
    }
    return column;
  }

  /// The value [entity]'s blind index of the encrypted field [field] holds for
  /// [plaintext] under the active index key.
  ///
  /// Enough while no index-key rotation is being rewritten; a lookup that must
  /// hold through one uses [blindIndexCondition].
  static Future<String?> blindIndexOf(
    Type entity,
    String field,
    String? plaintext,
  ) async => blindIndex(_indexColumn(entity, field), plaintext);

  /// The values [entity]'s blind index of [field] may hold for [plaintext]:
  /// one per index key of the current context, the active one first. After an
  /// index-key rotation, a row not yet rewritten holds a value under a
  /// previous key.
  static Future<List<String>> blindIndexCandidates(
    Type entity,
    String field,
    String plaintext,
  ) async {
    final column = _indexColumn(entity, field);
    return [
      for (final keyId in await _require().indexKeyIds())
        (await blindIndex(column, plaintext, keyId: keyId))!,
    ];
  }

  /// A query-sentence condition finding the rows whose [field] is
  /// [plaintext] — `<index field> is in ( :<index field>0 , … )` — with its
  /// parameters, matching every index key so it holds through an index-key
  /// rotation.
  ///
  /// ```dart
  /// final c = await TomFieldEncryption.blindIndexCondition(
  ///   Customer,
  ///   'email',
  ///   email,
  /// );
  /// final rows = await customers.findByQuerySentence(
  ///   'find by ${c.condition}',
  ///   c.params,
  /// );
  /// ```
  static Future<({String condition, Map<String, Object?> params})>
  blindIndexCondition(Type entity, String field, String plaintext) async {
    final name = _indexColumn(entity, field).declaredName;
    final values = await blindIndexCandidates(entity, field, plaintext);
    return (
      condition:
          '$name is in ( '
          '${[for (var i = 0; i < values.length; i++) ':$name$i'].join(' , ')} )',
      params: {for (final (i, v) in values.indexed) '$name$i': v},
    );
  }

  /// [image] — an audit record's field values — with the encrypted fields and
  /// blind indexes of [entity] replaced by [redacted]: an audit trail must not
  /// become a plaintext copy of what the table encrypts.
  static Map<String, Object?> redact(Type entity, Map<String, Object?> image) {
    final hidden = {
      for (final c
          in TomAnnotationAnalyzer.getPersistentColumns(entity) ??
              const <TomColumnInformation>[])
        if (c.encrypted != null || c.blindIndex != null) c.declaredName,
    };
    if (hidden.isEmpty || !image.keys.any(hidden.contains)) return image;
    return {
      for (final e in image.entries)
        e.key: hidden.contains(e.key) && e.value != null ? redacted : e.value,
    };
  }
}

/// What a [TomFieldReencryption] pass did.
class TomReencryptionReport {
  /// A report; see the fields.
  const TomReencryptionReport({
    this.examined = 0,
    this.rewritten = 0,
    this.conflicts = 0,
    this.failures = const [],
  });

  /// Rows read.
  final int examined;

  /// Rows written: a value moved to the active key, plaintext encrypted, or a
  /// blind index filled.
  final int rewritten;

  /// Rows a concurrent save changed between the read and the write; the next
  /// pass looks at them again.
  final int conflicts;

  /// Rows whose values could not be decrypted, one line each.
  final List<String> failures;

  /// This report and [other] summed.
  TomReencryptionReport operator +(TomReencryptionReport other) =>
      TomReencryptionReport(
        examined: examined + other.examined,
        rewritten: rewritten + other.rewritten,
        conflicts: conflicts + other.conflicts,
        failures: [...failures, ...other.failures],
      );

  /// The report as JSON-native values.
  Map<String, Object?> toJson() => {
    'examined': examined,
    'rewritten': rewritten,
    'conflicts': conflicts,
    'failures': failures,
  };

  @override
  String toString() =>
      'TomReencryptionReport(examined $examined, rewritten $rewritten, '
      'conflicts $conflicts, failures ${failures.length})';
}

/// The default name of the re-encryption job.
const String tomReencryptionJobName = 'object_persistence.reencrypt';

/// Rewrites what is not yet stored the way the keyring wants it: values under
/// a previous data key, plaintext in an encrypted column, blind indexes that
/// are missing or stale — see the library documentation.
class TomFieldReencryption {
  /// A pass over [entities] — by default every reflected entity with an
  /// encrypted column — reading [batchSize] rows at a time.
  TomFieldReencryption({Iterable<Type>? entities, this.batchSize = 200})
    : entities = List.unmodifiable(entities ?? _encryptedEntities());

  /// The entities the pass covers.
  final List<Type> entities;

  /// Rows read per statement.
  final int batchSize;

  /// Every reflected `@TomDbTable` class declaring a `@TomEncrypted` field,
  /// found from the metadata alone — the analyzer, which refuses a misdeclared
  /// entity, is only asked about those.
  static List<Type> _encryptedEntities() => [
    for (final mirror in tomReflector.annotatedClasses)
      if (mirror.metadata.any((m) => m is TomDbTable) &&
          mirror.declarations.values.any(
            (d) => d.metadata.any((m) => m is TomEncrypted),
          ))
        mirror.reflectedType,
  ];

  /// Runs one pass over every entity, in the current context and — when a
  /// [TomTenancy] is installed — in every tenant's.
  Future<TomReencryptionReport> run() async {
    var report = await _runHere();
    final tenancy = TomTenancy.current;
    if (tenancy != null) {
      for (final tenant in List.of(tenancy.tenants.keys)) {
        if (tenant == TomTenantContext.currentId) continue;
        report += await TomTenantContext.run(tenant, _runHere);
      }
    }
    return report;
  }

  Future<TomReencryptionReport> _runHere() async {
    var report = const TomReencryptionReport();
    for (final entity in entities) {
      report += await _entity(entity);
    }
    return report;
  }

  Future<TomReencryptionReport> _entity(Type entity) async {
    final encrypted = TomAnnotationAnalyzer.encryptedColumns(entity);
    final indexes = TomAnnotationAnalyzer.blindIndexColumns(entity);
    if (encrypted.isEmpty) return const TomReencryptionReport();
    final info = TomAnnotationAnalyzer.analysePersistentType(entity);
    final table = info.table;
    final ds = TomDataSourceInfo.getDataSourceInfo(table.datasource);
    if (ds == null) {
      throw TomFieldEncryptionException(
        'field_encryption.no_datasource',
        "The data source '${table.datasource}' of $entity is not registered.",
        parameters: {'datasource': table.datasource},
      );
    }
    final keys = [
      for (final f in table.primaryKeyFields)
        TomAnnotationAnalyzer.determineColumn(f, [info]),
    ];
    final keyring = TomFieldEncryption._require();
    final active = await keyring.activeKeyId();
    final selected = [...keys, ...encrypted, ...indexes];
    final order = keys.map((k) => k.getQueryFieldName()).join(', ');
    var examined = 0, rewritten = 0, conflicts = 0;
    final failures = <String>[];
    for (var offset = 0; ; offset += batchSize) {
      final rows = await TomFieldEncryption.raw(
        () => ds.datasource.executeQuery<Object>(
          'SELECT ${selected.map((c) => c.getQueryFieldName()).join(', ')} '
          'FROM ${table.table} ORDER BY $order '
          'LIMIT $batchSize OFFSET $offset',
          const {},
          entity,
        ),
      );
      if (rows.isEmpty) break;
      await TomFieldEncryption.prepareRead([
        for (final row in rows)
          for (final c in encrypted) c.getVariableValue(row) as String?,
      ]);
      for (final row in rows) {
        examined++;
        final writes = <TomColumnInformation, String?>{};
        final plaintexts = <String, String?>{};
        try {
          for (final c in encrypted) {
            final stored = c.getVariableValue(row) as String?;
            final plain = TomFieldEncryption.decrypt(c, stored);
            plaintexts[c.declaredName] = plain;
            if (stored != null &&
                TomFieldEncryption.keyIdOf(stored) != active) {
              writes[c] = await TomFieldEncryption.encrypt(c, plain);
            }
          }
          for (final c in indexes) {
            final wanted = await TomFieldEncryption.blindIndex(
              c,
              plaintexts[c.blindIndex!.field],
            );
            if (c.getVariableValue(row) != wanted) writes[c] = wanted;
          }
        } on TomFieldEncryptionException catch (error) {
          failures.add(
            '$entity ${[for (final k in keys) k.getVariableValue(row)]}: '
            '${error.key}',
          );
          continue;
        }
        if (writes.isEmpty) continue;
        final params = <String, Object?>{};
        final guards = <String>[];
        for (final (i, k) in keys.indexed) {
          final value = k.getVariableValue(row);
          params['k$i'] = k.column?.toDbConverter?.call(value) ?? value;
          guards.add('${k.getQueryFieldName()} = :k$i');
        }
        final sets = <String>[];
        for (final (i, MapEntry(key: c, value: next))
            in writes.entries.indexed) {
          final old = c.getVariableValue(row) as String?;
          params['n$i'] = next;
          sets.add('${c.getQueryFieldName()} = :n$i');
          if (old == null) {
            guards.add('${c.getQueryFieldName()} IS NULL');
          } else {
            params['o$i'] = old;
            guards.add('${c.getQueryFieldName()} = :o$i');
          }
        }
        final updated = await ds.datasource.executeCommand(
          'UPDATE ${table.table} SET ${sets.join(', ')} '
          'WHERE ${guards.join(' AND ')}',
          params,
        );
        if (updated == BigInt.zero) {
          conflicts++;
        } else {
          rewritten++;
        }
      }
      if (rows.length < batchSize) break;
    }
    return TomReencryptionReport(
      examined: examined,
      rewritten: rewritten,
      conflicts: conflicts,
      failures: failures,
    );
  }

  /// A scheduler job running a pass on [schedule].
  ///
  /// The body uses the isolate's keyring, so register the job on a scheduler
  /// with a `TomInlineJobDispatcher`; a worker isolate has no keyring.
  TomJobDefinition job({
    required TomSchedule schedule,
    String name = tomReencryptionJobName,
    Duration timeout = const Duration(hours: 1),
  }) => TomJobDefinition(
    name: name,
    schedule: schedule,
    body: (_) => _TomReencryptionCommand(this),
    timeout: timeout,
    // A pass rewrites under guards and can always run again.
    requestsRecovery: true,
  );
}

class _TomReencryptionCommand extends TomCommand {
  _TomReencryptionCommand(this._pass);

  final TomFieldReencryption _pass;

  @override
  Future<Object?> execute() async => (await _pass.run()).toJson();
}
