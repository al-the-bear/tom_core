/// The server-side store for per-principal preferences (C-13): typed reads and
/// writes of [TomUserPreference] rows for *the caller*.
///
/// ## Why a service rather than a repository
///
/// [TomUserPreferenceRepository] persists rows; this persists *values*. Every
/// consumer of a preference wants a `String` timezone or a reflected settings
/// object, not a row carrying JSON text plus a type name — and if each of them
/// did the encode/decode itself, each would decide independently whether a
/// `DateTime` is written local or UTC and whether a mismatched read is an error
/// or a coercion. [TomUserPreferenceCodec] makes that decision once; this
/// service is what makes the codec unavoidable.
///
/// ## The caller is the zone, not an argument
///
/// [get] and [set] take no principal. They read the one in the request zone —
/// the same principal `@TomDbScope(field: 'principal_id', scope: 'owner')`
/// resolves against — so the value a handler stores and the row the repository
/// permits it to store can never disagree. An API that took a principal would
/// invite a handler to pass one it read off the request, which is precisely the
/// parameter the endpoints deliberately do not have.
///
/// [getFor] is the exception, and exists for one reason: the authentication
/// path needs a preference *before* a request zone exists. It installs the
/// principal and delegates, so even that path reaches the same scoped query.
///
/// ## Why the lookups name the principal anyway
///
/// The scope already confines every statement to the caller, so
/// `FIND BY preference_key = :key` would be correct in a request. The queries
/// below still say `principal_id = :principalId` because
/// [TomDataScope.runUnscoped] exists: inside an administrative bypass the scope
/// deliberately filters nothing, and a lookup that relied on it would then find
/// — and [set] would then overwrite — some other principal's row. Naming the
/// principal keeps the *lookup* meaning "mine" under every scope state. It is
/// not a second copy of the authorization: the scope still decides what may be
/// written, and it is the scope that rejects an attempt to write elsewhere.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../object_persistence/crud_repository.dart';
import 'user_preference.dart';

/// Raised when a preference operation cannot identify the caller.
class TomUserPreferenceException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomUserPreferenceException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
    super.clientThrow,
  });
}

/// Typed access to the calling principal's server-stored preferences.
///
/// Installed as a bean so an application can substitute its own implementation
/// (a caching one, a read-only one) without any consumer changing:
///
/// ```dart
/// TomBean.withType(TomUserPreferences, TomUserPreferences(TomUserPreferenceRepository()));
/// final timezone = await TomUserPreferences.resolve()?.get<String>(
///   TomUserPreferenceKeys.timezone,
/// );
/// ```
class TomUserPreferences {
  /// The repository preference rows are read and written through.
  final TomSqlDatasourceRepository<TomUserPreference, int> repository;

  /// Creates the service over [repository].
  const TomUserPreferences(this.repository);

  /// The installed [TomUserPreferences] bean, or `null` when none is
  /// registered.
  ///
  /// `null` rather than a throw, because a preference is optional by nature: a
  /// deployment that has not created `tom_user_preference` should fall back to
  /// whatever the caller used before, not fail.
  static TomUserPreferences? resolve() {
    final installed = TomBean.getBeanByType(TomUserPreferences);
    return installed is TomUserPreferences ? installed : null;
  }

  /// Every preference of the calling principal, in storage order.
  Future<List<TomUserPreferenceDto>> all() async {
    final rows = await repository.findByQuerySentence(
      'FIND BY principal_id = :principalId',
      {'principalId': _requirePrincipal().id},
    );
    return List.unmodifiable(rows.map((row) => row.toDto()));
  }

  /// The calling principal's preference stored under [key], or `null` when it
  /// has never been written.
  Future<TomUserPreferenceDto?> read(String key) async {
    final row = await _rowFor(key);
    return row?.toDto();
  }

  /// The calling principal's preference stored under [key], decoded as a [T].
  ///
  /// `null` when the preference does not exist. Throws a
  /// [TomUserPreferenceCodecException] when it exists but was written as a
  /// different type — see [TomUserPreferenceCodec.decode].
  Future<T?> get<T extends Object>(String key) async {
    final dto = await read(key);
    return dto == null ? null : TomUserPreferenceCodec.decode<T>(dto);
  }

  /// [get], with [fallback] for a preference that has never been written.
  ///
  /// A type *mismatch* still throws: an unwritten preference is an ordinary
  /// state that a default answers, while a preference stored as the wrong type
  /// is a bug, and silently answering [fallback] would hide it.
  Future<T> getOr<T extends Object>(String key, T fallback) async =>
      await get<T>(key) ?? fallback;

  /// Writes [value] as the calling principal's preference under [key],
  /// replacing any previous value, and returns the stored DTO.
  ///
  /// Scalars and `DateTime`s are written by [TomUserPreferenceCodec]; anything
  /// else must be a `@tomReflector` class, which is what makes a preference a
  /// typed object rather than a stringly-typed blob.
  ///
  /// `async` for the encoding step, which can throw: every other failure of this
  /// service arrives as a rejected future, and one method that throws
  /// synchronously instead would be caught by a `try` the caller wrote around
  /// the `await` and missed by everything else.
  Future<TomUserPreferenceDto> set<T extends Object>(String key, T value) async {
    return _write(
      key,
      TomUserPreferenceCodec.typeNameOf(value, key),
      TomUserPreferenceCodec.encodeValue(value, key),
    );
  }

  /// [set], for a value that arrives already encoded.
  ///
  /// The endpoint's write path: a request carries [valueType] and [valueJson]
  /// as text, so there is no Dart value to take the type from. The pair is
  /// validated before it is stored ([TomUserPreferenceCodec.validateEncoded]),
  /// because a mismatch written here is one every later read of the key — on
  /// every device — would fail on.
  Future<TomUserPreferenceDto> setEncoded(
    String key, {
    required String valueType,
    required String valueJson,
  }) async {
    TomUserPreferenceCodec.validateEncoded(valueType, valueJson, key: key);
    return _write(key, valueType, valueJson);
  }

  /// Upserts the calling principal's row under [key].
  Future<TomUserPreferenceDto> _write(
    String key,
    String valueType,
    String valueJson,
  ) async {
    final principal = _requirePrincipal();
    final existing = await _rowFor(key);

    // Reuse the found row rather than inserting a second: the repository takes
    // its UPDATE path exactly when the surrogate key is set, so carrying the id
    // over is what makes this an upsert — and the table's unique key on
    // (principal_id, preference_key) would reject the alternative anyway.
    final row = existing ?? TomUserPreference();
    row.principalId = principal.id;
    row.preferenceKey = key;
    row.valueType = valueType;
    row.valueJson = valueJson;
    // The server's clock, not the caller's: when a preference was written is
    // the server's answer (which is why the write DTO carries no timestamp).
    row.updatedAt = DateTime.now().toUtc();

    final saved = await repository.save(row);
    return saved.toDto();
  }

  /// Deletes the calling principal's preference under [key].
  ///
  /// Answers whether a row was removed, so a caller can tell "deleted" from
  /// "was never there" without a second read.
  Future<bool> remove(String key) async {
    final row = await _rowFor(key);
    if (row == null) return false;
    await repository.deleteById(row.id);
    return true;
  }

  /// [get], for a [principal] that is not the one in the current zone.
  ///
  /// For the authentication path, which needs a user's stored preference at a
  /// point where the request zone carries no principal yet — the principal only
  /// exists once the credentials have been accepted. Installing it and
  /// delegating keeps that path on the same scoped query as every other read,
  /// instead of giving login its own unscoped lookup.
  Future<T?> getFor<T extends Object>(TomPrincipal principal, String key) {
    return runZoned(
      () => get<T>(key),
      zoneValues: <Object, Object?>{TomPrincipal: principal},
    );
  }

  /// The calling principal's row under [key], or `null`.
  Future<TomUserPreference?> _rowFor(String key) async {
    final matches = await repository.findByQuerySentence(
      'FIND BY principal_id = :principalId AND preference_key = :key',
      {'principalId': _requirePrincipal().id, 'key': key},
    );
    return matches.isEmpty ? null : matches.first;
  }

  /// The principal in the current zone.
  ///
  /// Throws rather than returning `null`: without a principal there is no row
  /// to read and no owner to write, and the alternative — an unowned row — is
  /// one the scope would reject on the next read anyway, having already been
  /// stored.
  TomPrincipal _requirePrincipal() {
    final principal = getFromCurrentZone<TomPrincipal>();
    if (principal == null) {
      throw TomUserPreferenceException(
        'preferences.no_principal',
        'A user preference can only be read or written for a known principal; '
            'none is present in the current zone.',
        clientThrow: false,
      );
    }
    return principal;
  }
}
