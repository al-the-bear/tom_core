/// Crypto-shredding: personal values in the audit trail, sealed under a key
/// per data subject, made unreadable by deleting the key.
///
/// The audit trail is append-only and hash-chained: an entry cannot be edited
/// without the chain showing it, which is the point of it. Erasing a person's
/// data from it by rewriting entries would therefore either break the chain or
/// require rebuilding it — and a rebuilt chain proves nothing. So the values
/// are never written in the clear in the first place: a `@TomPersonal` field's
/// before and after values are sealed (AES-256-GCM) under a key of the row's
/// subject, and the chain hashes the sealed text. Erasing the subject deletes
/// the key. The entries stay, the chain still verifies, and the values can no
/// longer be read by anyone.
///
/// Each subject key is wrapped under the key-encryption keys of the installed
/// field-encryption keyring, as data keys are, so a database dump reads nothing.
/// [TomSubjectKeys.reveal] opens a record's sealed values for an auditor while
/// the key exists, and shows [TomSubjectKeys.erasedPlaceholder] once it does
/// not.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../audit/audit_record.dart';
import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../object_persistence/field_encryption.dart';
import '../object_persistence/persistence_annotations.dart';
import 'personal_data.dart';
import 'subject_keys_sql.dart';

/// One subject key as a store holds it: wrapped.
class TomSubjectKeyRecord {
  /// A record; see the fields.
  const TomSubjectKeyRecord({
    required this.subject,
    required this.kekId,
    required this.wrapped,
    required this.createdAt,
  });

  /// The subject's id.
  final String subject;

  /// The key-encryption key it is wrapped under.
  final String kekId;

  /// The wrapped key, base64.
  final String wrapped;

  /// When it was created.
  final DateTime createdAt;
}

/// Where subject keys are kept. Every operation works in the tenant in
/// context.
abstract class TomSubjectKeyStore {
  /// Makes the store ready — creates its table — for the data source the
  /// current context resolves. Called outside any transaction.
  Future<void> prepare();

  /// What the current context's keys belong to.
  Object get scope;

  /// The key of [subject], or `null`.
  Future<TomSubjectKeyRecord?> find(String subject);

  /// Stores [record]; answers `false` when the subject has a key already.
  Future<bool> insert(TomSubjectKeyRecord record);

  /// Deletes the key of [subject]; answers whether there was one.
  Future<bool> delete(String subject);

  /// Every key of the tenant in context.
  Future<List<TomSubjectKeyRecord>> all();

  /// Replaces the stored key of [record]'s subject — a re-wrap.
  Future<void> update(TomSubjectKeyRecord record);
}

String get _tenant => TomTenantContext.currentId ?? '';

/// Subject keys in memory: for tests.
class TomMemorySubjectKeyStore implements TomSubjectKeyStore {
  final Map<(String, String), TomSubjectKeyRecord> _records = {};

  @override
  Future<void> prepare() async {}

  @override
  Object get scope => this;

  @override
  Future<TomSubjectKeyRecord?> find(String subject) async =>
      _records[(_tenant, subject)];

  @override
  Future<bool> insert(TomSubjectKeyRecord record) async {
    final key = (_tenant, record.subject);
    if (_records.containsKey(key)) return false;
    _records[key] = record;
    return true;
  }

  @override
  Future<bool> delete(String subject) async =>
      _records.remove((_tenant, subject)) != null;

  @override
  Future<List<TomSubjectKeyRecord>> all() async => [
    for (final e in _records.entries)
      if (e.key.$1 == _tenant) e.value,
  ];

  @override
  Future<void> update(TomSubjectKeyRecord record) async =>
      _records[(_tenant, record.subject)] = record;
}

/// Subject keys in a SQL data source, resolved by name on every call — so
/// under tenancy each tenant's data source holds its own subjects' keys.
class TomSqlSubjectKeyStore implements TomSubjectKeyStore {
  /// A store in [table] of the data source registered as [datasourceName].
  ///
  /// With [createSchema] (the default) the table is created on first use in
  /// each data source; a deployment whose user may not run DDL applies the
  /// shipped migration and passes `false`.
  TomSqlSubjectKeyStore(
    String this.datasourceName, {
    this.table = defaultSubjectKeyTable,
    this.createSchema = true,
  }) : _fixed = null;

  /// A store in [table] of [datasource] itself, resolved once.
  TomSqlSubjectKeyStore.over(
    TomDataSource datasource, {
    this.table = defaultSubjectKeyTable,
    this.createSchema = true,
  }) : datasourceName = null,
       _fixed = datasource;

  /// The registered name of the data source, or `null` for a store built
  /// [TomSqlSubjectKeyStore.over] one.
  final String? datasourceName;

  final TomDataSource? _fixed;

  /// The table's name.
  final String table;

  /// Whether the table is created on first use.
  final bool createSchema;

  late final TomFrameworkTable _table = subjectKeyTable(table);
  final Expando<TomSchemaProvisioning> _schemas = Expando();

  TomDataSource _resolve() {
    final fixed = _fixed;
    if (fixed != null) return fixed;
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName!);
    if (info == null) {
      throw TomPrivacyException(
        'privacy.no_datasource',
        "The subject-key store's data source '$datasourceName' is not "
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

  @override
  Future<TomSubjectKeyRecord?> find(String subject) async {
    final rows = await _resolve().executeQuery<TomSubjectKeyRow>(
      'SELECT subject_id, kek_id, wrapped_key, created_at FROM $table '
      'WHERE tenant = :tenant AND subject_id = :subject',
      {'tenant': _tenant, 'subject': subject},
    );
    return rows.isEmpty ? null : rows.single.toRecord();
  }

  @override
  Future<bool> insert(TomSubjectKeyRecord record) async {
    final ds = _resolve();
    final inserted = await ds.executeCommand(
      _table.insertRow(ds.sqlDialect, const {
        'tenant': ':tenant',
        'subject_id': ':subject',
        'kek_id': ':kek',
        'wrapped_key': ':wrapped',
        'created_at': ':created',
      }, ignoreConflict: true),
      {
        'tenant': _tenant,
        'subject': record.subject,
        'kek': record.kekId,
        'wrapped': record.wrapped,
        'created': sqlInstant(record.createdAt),
      },
    );
    return inserted != BigInt.zero;
  }

  @override
  Future<bool> delete(String subject) async {
    final removed = await _resolve().executeCommand(
      'DELETE FROM $table WHERE tenant = :tenant AND subject_id = :subject',
      {'tenant': _tenant, 'subject': subject},
    );
    return removed != BigInt.zero;
  }

  @override
  Future<List<TomSubjectKeyRecord>> all() async {
    final rows = await _resolve().executeQuery<TomSubjectKeyRow>(
      'SELECT subject_id, kek_id, wrapped_key, created_at FROM $table '
      'WHERE tenant = :tenant',
      {'tenant': _tenant},
    );
    return [for (final row in rows) row.toRecord()];
  }

  @override
  Future<void> update(TomSubjectKeyRecord record) async {
    await _resolve().executeCommand(
      'UPDATE $table SET kek_id = :kek, wrapped_key = :wrapped '
      'WHERE tenant = :tenant AND subject_id = :subject',
      {
        'tenant': _tenant,
        'subject': record.subject,
        'kek': record.kekId,
        'wrapped': record.wrapped,
      },
    );
  }

  /// Empties the table of the data source this context resolves. For tests.
  Future<void> deleteAll() async {
    await prepare();
    await _resolve().executeCommand('DELETE FROM $table');
  }
}

/// One row of the subject-key table, as [TomSqlSubjectKeyStore] reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["subjectId"],
)
class TomSubjectKeyRow {
  /// The subject's id.
  @TomDbColumn(columnName: "subject_id")
  String subjectId = "";

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
  TomSubjectKeyRecord toRecord() => TomSubjectKeyRecord(
    subject: subjectId,
    kekId: kekId,
    wrapped: wrappedKey,
    createdAt: parseSqlInstant(createdAt),
  );
}

/// The subject keys: sealing a personal value for one subject, opening it while
/// their key exists, and shredding the key — see the library documentation.
class TomSubjectKeys {
  /// Keys kept in [store], wrapped under [keys] — the first wraps new keys,
  /// every one may unwrap. Without [keys], the key-encryption keys of the
  /// installed field-encryption keyring are used, read when a key is needed.
  TomSubjectKeys({
    required this.store,
    List<TomKeyEncryptionKey>? keys,
    DateTime Function()? clock,
  }) : _keys = keys == null ? null : List.unmodifiable(keys),
       _clock = clock ?? DateTime.now;

  /// Where the wrapped keys are kept.
  final TomSubjectKeyStore store;

  final List<TomKeyEncryptionKey>? _keys;
  final DateTime Function() _clock;

  /// Unwrapped keys by scope, tenant and subject — used for sealing, which
  /// happens on every audited write. Opening never trusts it: see [open].
  final Map<(Object, String, String), Uint8List> _cache = {};
  static final Random _random = Random.secure();

  /// What every sealed value starts with.
  static const String prefix = 'tomsubj:v1:';

  /// What [reveal] shows for a value whose subject's key is gone.
  static const String erasedPlaceholder = '[erased]';

  List<TomKeyEncryptionKey> get _kek {
    final keys = _keys ?? TomFieldEncryption.keyring?.keys;
    if (keys == null || keys.isEmpty) {
      throw TomPrivacyException(
        'privacy.no_subject_keys',
        'Subject keys need key-encryption keys: give them, or install a '
            'field-encryption keyring.',
      );
    }
    return keys;
  }

  /// Whether [value] is a sealed value.
  static bool isSealed(Object? value) =>
      value is String && value.startsWith(prefix);

  /// The subject a sealed [value] belongs to, or `null`.
  static String? subjectOf(Object? value) {
    if (!isSealed(value)) return null;
    final text = value as String;
    final end = text.indexOf(':', prefix.length);
    if (end < 0) return null;
    return utf8.decode(
      base64Url.decode(base64Url.normalize(text.substring(prefix.length, end))),
    );
  }

  static String _aad(String subject, String field) =>
      'tom-audit:$subject:$field';

  Future<Uint8List?> _key(
    String subject, {
    required bool create,
    bool fresh = false,
  }) async {
    await store.prepare();
    final cacheKey = (store.scope, _tenant, subject);
    final cached = fresh ? null : _cache[cacheKey];
    if (cached != null) return cached;
    var record = await store.find(subject);
    if (record == null && create) {
      final material = [for (var i = 0; i < 32; i++) _random.nextInt(256)];
      final primary = _kek.first;
      await store.insert(
        TomSubjectKeyRecord(
          subject: subject,
          kekId: primary.id,
          wrapped: base64.encode(
            await primary.wrap(material, keyId: 'subject:$subject'),
          ),
          createdAt: _clock().toUtc(),
        ),
      );
      // Re-read: of two writers creating one subject's key, one row won.
      record = await store.find(subject);
    }
    if (record == null) return null;
    final kek = _kek.where((k) => k.id == record!.kekId).firstOrNull;
    if (kek == null) {
      throw TomFieldEncryptionException(
        'field_encryption.unknown_kek',
        "The key of subject '$subject' is wrapped under the key-encryption "
            "key '${record.kekId}', which was not given.",
        parameters: {'kek': record.kekId},
      );
    }
    final material = Uint8List.fromList(
      await kek.unwrap(
        base64.decode(record.wrapped),
        keyId: 'subject:$subject',
      ),
    );
    return _cache[cacheKey] = material;
  }

  /// [value] of [field], sealed under [subject]'s key, which is created on
  /// first use. `null` stays `null`.
  Future<Object?> seal(String subject, String field, Object? value) async {
    if (value == null) return null;
    final key = (await _key(subject, create: true))!;
    final sealed = TomAesGcm.seal(
      key,
      utf8.encode(jsonEncode(value)),
      _aad(subject, field),
    );
    final id = base64Url.encode(utf8.encode(subject)).replaceAll('=', '');
    return '$prefix$id:${base64Url.encode(sealed).replaceAll('=', '')}';
  }

  /// The value [sealed] holds for [field], or [erasedPlaceholder] when its
  /// subject's key is gone. A value that is not sealed is answered as it is.
  ///
  /// The key is read from the store every time, never from the cache: a key
  /// another node has shredded must stop opening here at once, not when this
  /// process next restarts.
  Future<Object?> open(Object? sealed, String field) async {
    final subject = subjectOf(sealed);
    if (subject == null) return sealed;
    final key = await _key(subject, create: false, fresh: true);
    if (key == null) return erasedPlaceholder;
    final text = sealed as String;
    final body = text.substring(text.indexOf(':', prefix.length) + 1);
    try {
      final plain = TomAesGcm.open(
        key,
        base64Url.decode(base64Url.normalize(body)),
        _aad(subject, field),
      );
      return jsonDecode(utf8.decode(plain));
    } catch (error) {
      throw TomPrivacyException(
        'privacy.seal.invalid',
        "A sealed value of '$field' does not open under its subject's key: it "
            'was altered, or belongs to another field.',
        parameters: {'field': field},
      );
    }
  }

  /// Whether [subject] has a key, as the store says now.
  Future<bool> has(String subject) async =>
      (await _key(subject, create: false, fresh: true)) != null;

  /// Deletes [subject]'s key: every value sealed under it is unreadable from
  /// now on. Answers whether there was one.
  Future<bool> shred(String subject) async {
    await store.prepare();
    _cache.remove((store.scope, _tenant, subject));
    return store.delete(subject);
  }

  /// Wraps every subject key of the tenant in context that is not wrapped
  /// under the primary key-encryption key under it, and answers how many it
  /// re-wrapped — the subject-key half of rotating a key-encryption key
  /// (`TomFieldKeyring.rewrap` is the data-key half). No sealed value changes.
  Future<int> rewrap() async {
    await store.prepare();
    final primary = _kek.first;
    var count = 0;
    for (final record in await store.all()) {
      if (record.kekId == primary.id) continue;
      final material = (await _key(
        record.subject,
        create: false,
        fresh: true,
      ))!;
      await store.update(
        TomSubjectKeyRecord(
          subject: record.subject,
          kekId: primary.id,
          wrapped: base64.encode(
            await primary.wrap(material, keyId: 'subject:${record.subject}'),
          ),
          createdAt: record.createdAt,
        ),
      );
      count++;
    }
    return count;
  }

  /// [record] with its sealed values opened — what an auditor reads.
  Future<TomAuditRecord> reveal(TomAuditRecord record) async {
    Future<Map<String, Object?>> openAll(Map<String, Object?> values) async => {
      for (final e in values.entries) e.key: await open(e.value, e.key),
    };
    return TomAuditRecord(
      id: record.id,
      timestamp: record.timestamp,
      actor: record.actor,
      action: record.action,
      target: record.target,
      targetKey: record.targetKey,
      outcome: record.outcome,
      requestId: record.requestId,
      before: await openAll(record.before),
      after: await openAll(record.after),
      detail: record.detail,
    );
  }
}
