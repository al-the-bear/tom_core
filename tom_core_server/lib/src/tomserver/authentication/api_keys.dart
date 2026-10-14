/// Service accounts, and the API keys they authenticate with.
///
/// A **service account** is a non-human caller — a nightly import, another
/// service, a partner's integration — with its own roles. It signs in with an
/// **API key** presented in the `X-API-Key` header instead of a bearer token;
/// the request then runs as an authenticated principal holding the key's
/// roles, so every access rule (`TomAuthenticatedAccess`, `TomRoleAccess`, row
/// and column grades) applies to it exactly as to a user.
///
/// ## A key is shown once
///
/// [TomApiKeys.issue] answers the key as `tomk.<keyId>.<secret>` once; the
/// store keeps the key id and a SHA-256 hash of the secret, never the secret.
/// A key is 32 random bytes, so a fast hash is the right one — a slow password
/// hash exists to protect guessable secrets, and nothing about 256 random bits
/// is guessable. A lost key is replaced, not recovered.
///
/// ## Scoped roles
///
/// A key may carry fewer roles than its account: its effective roles are the
/// intersection of the two, so an account's roles bound every key it issues,
/// and narrowing an account narrows its keys at once. A key with no roles of
/// its own carries the account's.
///
/// ## Rotation and revocation
///
/// [TomApiKeys.rotate] issues a successor with the same account and roles and
/// lets the old key live on for an overlap — zero by default, so rotating is
/// revoking the old key — giving a deployment time to swap the value it holds.
/// [TomApiKeys.revoke] ends a key at once. Both reach every node: a node
/// caches the keys it has looked up, and both operations drop the entry
/// through `TomCacheInvalidator`, so on a cluster with a shared invalidation
/// channel no node serves a revoked key from its cache. The cache keeps an
/// entry for [TomApiKeys.lookupCacheSeconds] at most, which bounds the
/// staleness on a deployment without one.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../cache/cache_invalidation.dart';
import '../cache/server_cache.dart';
import '../little_things/server_exception.dart';

/// A failure of the API-key subsystem, keyed `api_key.<area>.<condition>`.
class TomApiKeyException extends TomServerException {
  /// A failure with [key] and [defaultUserMessage].
  TomApiKeyException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.clientThrow = false,
  });
}

/// A non-human caller with its own roles.
class TomServiceAccount {
  /// The account's id — stable, and how keys refer to it.
  final String id;

  /// A human-readable name for the account.
  final String name;

  /// The roles the account holds; every key's roles are bounded by them.
  final List<String> roles;

  /// The tenant the account belongs to, or `null` outside tenancy.
  final String? tenant;

  /// The organization the account acts in, or `null`.
  final String? organization;

  /// Whether the account is disabled: a disabled account's keys authenticate
  /// nothing, without having to revoke them one by one.
  final bool disabled;

  /// An account.
  const TomServiceAccount({
    required this.id,
    required this.name,
    this.roles = const [],
    this.tenant,
    this.organization,
    this.disabled = false,
  });

  /// This account with [disabled] set.
  TomServiceAccount withDisabled(bool disabled) => TomServiceAccount(
    id: id,
    name: name,
    roles: roles,
    tenant: tenant,
    organization: organization,
    disabled: disabled,
  );

  /// This account with [roles] replaced.
  TomServiceAccount withRoles(List<String> roles) => TomServiceAccount(
    id: id,
    name: name,
    roles: roles,
    tenant: tenant,
    organization: organization,
    disabled: disabled,
  );
}

/// The stored record of one API key — everything but its secret.
class TomApiKey {
  /// The key's public id, the middle part of the presented key.
  final String id;

  /// The account the key authenticates as.
  final String accountId;

  /// The SHA-256 hash of the secret, hex-encoded.
  final String secretHash;

  /// The roles the key is scoped to, or empty for the account's roles.
  final List<String> roles;

  /// A label saying what the key is for.
  final String label;

  /// When the key was issued.
  final DateTime createdAt;

  /// When the key stops working by itself, or `null` for never.
  final DateTime? expiresAt;

  /// When the key was revoked, or `null`.
  final DateTime? revokedAt;

  /// When the key last authenticated a request, recorded at most once a
  /// minute per node, or `null`.
  final DateTime? lastUsedAt;

  /// A key record.
  const TomApiKey({
    required this.id,
    required this.accountId,
    required this.secretHash,
    this.roles = const [],
    this.label = '',
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
    this.lastUsedAt,
  });

  /// Whether the key authenticates at [now]: not revoked and not expired.
  bool isLiveAt(DateTime now) =>
      revokedAt == null && (expiresAt == null || now.isBefore(expiresAt!));

  /// This record with the given fields replaced.
  TomApiKey copyWith({
    DateTime? expiresAt,
    DateTime? revokedAt,
    DateTime? lastUsedAt,
  }) => TomApiKey(
    id: id,
    accountId: accountId,
    secretHash: secretHash,
    roles: roles,
    label: label,
    createdAt: createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    revokedAt: revokedAt ?? this.revokedAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );
}

/// A key as issued: the record, and the one time the full key is visible.
class TomIssuedApiKey {
  /// The stored record.
  final TomApiKey record;

  /// The key to hand over — `tomk.<keyId>.<secret>`. Not stored anywhere.
  final String value;

  /// An issued key.
  const TomIssuedApiKey(this.record, this.value);
}

/// The service account and key a request authenticated with, in the request
/// zone — what a rate limit keyed per API key reads.
class TomApiKeyIdentity {
  /// The key's id.
  final String keyId;

  /// The account's id.
  final String accountId;

  /// An identity.
  const TomApiKeyIdentity(this.keyId, this.accountId);
}

/// Where service accounts and key records live.
///
/// [TomMemoryApiKeyStore] keeps them in this process; `TomSqlApiKeyStore`
/// keeps them in a data source every node shares.
abstract class TomApiKeyStore {
  /// Stores [account], replacing one with its id.
  Future<void> saveAccount(TomServiceAccount account);

  /// The account [id], or `null`.
  Future<TomServiceAccount?> findAccount(String id);

  /// Every account.
  Future<List<TomServiceAccount>> accounts();

  /// Stores [key], replacing one with its id.
  Future<void> saveKey(TomApiKey key);

  /// The key [id], or `null`.
  Future<TomApiKey?> findKey(String id);

  /// The keys of account [accountId], live or not.
  Future<List<TomApiKey>> keysOf(String accountId);

  /// Records that key [keyId] was used [at] — that field only.
  ///
  /// Never a whole-record write: the caller holds the record as a node cached
  /// it, and writing that back could restore a revocation another node made
  /// since.
  Future<void> touch(String keyId, DateTime at);
}

/// The default store: maps in this process.
///
/// Right for a single node and for tests. A cluster shares a store, or each
/// node would know only the keys issued on it.
class TomMemoryApiKeyStore implements TomApiKeyStore {
  final Map<String, TomServiceAccount> _accounts = {};
  final Map<String, TomApiKey> _keys = {};

  @override
  Future<void> saveAccount(TomServiceAccount account) async =>
      _accounts[account.id] = account;

  @override
  Future<TomServiceAccount?> findAccount(String id) async => _accounts[id];

  @override
  Future<List<TomServiceAccount>> accounts() async => _accounts.values.toList();

  @override
  Future<void> saveKey(TomApiKey key) async => _keys[key.id] = key;

  @override
  Future<TomApiKey?> findKey(String id) async => _keys[id];

  @override
  Future<List<TomApiKey>> keysOf(String accountId) async => [
    for (final key in _keys.values)
      if (key.accountId == accountId) key,
  ];

  @override
  Future<void> touch(String keyId, DateTime at) async {
    final key = _keys[keyId];
    if (key != null) _keys[keyId] = key.copyWith(lastUsedAt: at);
  }
}

/// Issues, rotates, revokes and checks API keys.
///
/// ```dart
/// final keys = TomApiKeys(store: TomMemoryApiKeyStore());
/// TomApiKeys.install(keys);
/// await keys.saveAccount(
///   const TomServiceAccount(id: 'importer', name: 'Nightly import',
///       roles: ['import', 'read']),
/// );
/// final issued = await keys.issue('importer', roles: ['import']);
/// // Hand issued.value over once; the store keeps only its hash.
/// ```
class TomApiKeys {
  /// The request header a key is presented in.
  static const String header = 'x-api-key';

  /// The prefix of every key, which tells a key from any other secret in a
  /// configuration file or a log line.
  static const String prefix = 'tomk';

  /// The cache the keys a node has looked up are held in.
  static const String lookupCacheName = 'tom.apiKeys';

  /// How long a looked-up key stays cached on a node at most.
  static const int lookupCacheSeconds = 60;

  /// How often a key's [TomApiKey.lastUsedAt] is written, at most.
  static const Duration touchInterval = Duration(minutes: 1);

  /// Where the accounts and keys live.
  final TomApiKeyStore store;

  final DateTime Function() _clock;
  final Random _random;

  /// When this node last recorded each key's use — kept apart from the cached
  /// record, which is never written back.
  final Map<String, DateTime> _touchedAt = {};

  /// A key service over [store]; [clock] and [random] are injectable for
  /// tests.
  TomApiKeys({required this.store, DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random.secure();

  static TomApiKeys? _current;

  /// The installed service, or `null` — a server with none installed reads no
  /// `X-API-Key` header.
  static TomApiKeys? get current => _current;

  /// Installs [keys] as the service the request pipeline authenticates with,
  /// and registers the node's lookup cache.
  static void install(TomApiKeys keys) {
    _current = keys;
    if (TomCacheManager.getCache(lookupCacheName) == null) {
      TomCacheManager.addCache(
        TomCache(
          lookupCacheName,
          deleteEntriesAfterSeconds: lookupCacheSeconds,
          deletionIntervalSeconds: lookupCacheSeconds,
        ),
      );
    }
  }

  /// Uninstalls the service and drops the lookup cache. Test-support, and a
  /// server's shutdown.
  static void reset() {
    _current = null;
    final cache = TomCacheManager.getCache(lookupCacheName);
    if (cache != null) {
      TomCacheManager.removeCache(lookupCacheName);
      cache.stopTimers();
    }
  }

  DateTime _now() => _clock().toUtc();

  /// Stores [account], replacing one with its id. A change to its roles or to
  /// [TomServiceAccount.disabled] takes effect on the next request.
  Future<void> saveAccount(TomServiceAccount account) =>
      store.saveAccount(account);

  /// Issues a key for account [accountId], scoped to [roles] (empty for the
  /// account's), expiring after [expiresIn] (never when `null`).
  ///
  /// Throws `api_key.issue.unknown_account` for an account that does not
  /// exist, and `api_key.issue.role_not_held` for a role the account does not
  /// hold — a key cannot carry more than its account.
  Future<TomIssuedApiKey> issue(
    String accountId, {
    List<String> roles = const [],
    String label = '',
    Duration? expiresIn,
  }) async {
    final account = await store.findAccount(accountId);
    if (account == null) {
      throw TomApiKeyException(
        'api_key.issue.unknown_account',
        'There is no service account "$accountId".',
        parameters: {'account': accountId},
      );
    }
    final excess = roles.where((r) => !account.roles.contains(r)).toList();
    if (excess.isNotEmpty) {
      throw TomApiKeyException(
        'api_key.issue.role_not_held',
        'A key cannot carry roles its account does not hold: '
            '${excess.join(', ')}.',
        parameters: {'account': accountId, 'roles': excess},
      );
    }
    final id = _randomHex(8);
    final secret = base64Url.encode(_randomBytes(32)).replaceAll('=', '');
    final now = _now();
    final record = TomApiKey(
      id: id,
      accountId: accountId,
      secretHash: hashSecret(secret),
      roles: List.unmodifiable(roles),
      label: label,
      createdAt: now,
      expiresAt: expiresIn == null ? null : now.add(expiresIn),
    );
    await store.saveKey(record);
    return TomIssuedApiKey(record, '$prefix.$id.$secret');
  }

  /// Issues a successor to key [keyId] — same account, roles and label — and
  /// ends the old key after [overlap]: at once by default, so a rotation is a
  /// revocation of the old key unless a grace period is asked for.
  Future<TomIssuedApiKey> rotate(
    String keyId, {
    Duration overlap = Duration.zero,
    Duration? expiresIn,
  }) async {
    final old = await _requireKey(keyId, 'rotate');
    final successor = await issue(
      old.accountId,
      roles: old.roles,
      label: old.label,
      expiresIn: expiresIn,
    );
    final now = _now();
    await store.saveKey(
      overlap == Duration.zero
          ? old.copyWith(revokedAt: now)
          : old.copyWith(expiresAt: _earlier(old.expiresAt, now.add(overlap))),
    );
    await _forget(keyId);
    return successor;
  }

  /// Revokes key [keyId] at once, on every node.
  Future<void> revoke(String keyId) async {
    final key = await _requireKey(keyId, 'revoke');
    if (key.revokedAt == null) {
      await store.saveKey(key.copyWith(revokedAt: _now()));
    }
    await _forget(keyId);
  }

  /// The keys of account [accountId], live or not — never their secrets.
  Future<List<TomApiKey>> keysOf(String accountId) => store.keysOf(accountId);

  /// The principal [presented] authenticates as, with the identity of its key,
  /// or `null` when it authenticates nothing.
  ///
  /// `null` for every reason alike — malformed, unknown, wrong secret,
  /// revoked, expired, account disabled or gone — so a caller probing keys
  /// learns nothing from the answer. The reason is logged, never the key.
  Future<(TomPrincipal, TomApiKeyIdentity)?> authenticate(
    String presented,
  ) async {
    final parts = presented.trim().split('.');
    if (parts.length != 3 || parts[0] != prefix || parts[2].isEmpty) {
      tomLog.warn('An X-API-Key header did not have the shape of a key.');
      return null;
    }
    final key = await _lookup(parts[1]);
    final now = _now();
    if (key == null || !_sameHash(key.secretHash, hashSecret(parts[2]))) {
      tomLog.warn('An API key was refused: unknown key or wrong secret.');
      return null;
    }
    if (!key.isLiveAt(now)) {
      tomLog.info('API key ${key.id} was refused: revoked or expired.');
      return null;
    }
    final account = await store.findAccount(key.accountId);
    if (account == null || account.disabled) {
      tomLog.info(
        'API key ${key.id} was refused: its account is disabled or gone.',
      );
      return null;
    }
    await _touch(key, now);
    final roles = key.roles.isEmpty
        ? account.roles
        : [
            for (final role in key.roles)
              if (account.roles.contains(role)) role,
          ];
    final principal = TomPrincipal(
      user: TomUser(username: 'service:${account.id}'),
      aci: TomAccessControlInformation(roles: roles),
      authenticated: true,
      tenant: account.tenant,
      organization: account.organization,
      context: {'serviceAccount': account.id, 'apiKey': key.id},
    );
    return (principal, TomApiKeyIdentity(key.id, account.id));
  }

  /// The hex SHA-256 of [secret] — what a store keeps in place of it.
  static String hashSecret(String secret) =>
      sha256.convert(utf8.encode(secret)).toString();

  /// The key [keyId], from this node's lookup cache when it holds it.
  Future<TomApiKey?> _lookup(String keyId) => _outsideTenants(() async {
    final cached = _cached
        ? await TomCache.fromNameCache<TomApiKey>(lookupCacheName, keyId)
        : null;
    if (cached != null) return cached;
    final key = await store.findKey(keyId);
    if (key != null && _cached) {
      await TomCache.toNameCache(lookupCacheName, keyId, key);
    }
    return key;
  });

  /// Runs [body] with no tenant in context.
  ///
  /// The lookup cache is keyed by key id alone: a key belongs to its account,
  /// not to the tenant a request is in, and the authentication middleware
  /// looks keys up before the request enters its tenant. A drop raised from
  /// inside a tenant — a revocation from an administration endpoint — would
  /// otherwise be qualified by that tenant and miss the entry it means.
  static Future<T> _outsideTenants<T>(Future<T> Function() body) =>
      TomTenantContext.run(null, body);

  /// Whether the lookup cache is registered — it is once [install] ran.
  static bool get _cached => TomCacheManager.getCache(lookupCacheName) != null;

  Future<void> _forget(String keyId) async {
    if (!_cached) return;
    await _outsideTenants(
      () => TomCacheInvalidator.invalidateCacheEntry(lookupCacheName, keyId),
    );
  }

  Future<void> _touch(TomApiKey key, DateTime now) async {
    final last = _touchedAt[key.id] ?? key.lastUsedAt;
    if (last != null && now.difference(last) < touchInterval) return;
    _touchedAt[key.id] = now;
    await store.touch(key.id, now);
  }

  Future<TomApiKey> _requireKey(String keyId, String operation) async {
    final key = await store.findKey(keyId);
    if (key == null) {
      throw TomApiKeyException(
        'api_key.$operation.unknown_key',
        'There is no API key "$keyId".',
        parameters: {'key': keyId},
      );
    }
    return key;
  }

  static DateTime _earlier(DateTime? a, DateTime b) =>
      a == null || b.isBefore(a) ? b : a;

  /// Compares two hashes in time independent of where they differ.
  static bool _sameHash(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  List<int> _randomBytes(int count) => [
    for (var i = 0; i < count; i++) _random.nextInt(256),
  ];

  String _randomHex(int bytes) => [
    for (final b in _randomBytes(bytes)) b.toRadixString(16).padLeft(2, '0'),
  ].join();
}
