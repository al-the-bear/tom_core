/// The one place a *device* holds a secret.
library;

import 'package:meta/meta.dart';
import '../../tom_core_storage.dart';

/// Reads and writes device-local secrets by opaque handle.
///
/// A device keeps one secret here — the key of its encrypted settings
/// container — and everything else that is a secret lives *inside* that
/// container, so a device that loses this store loses only its settings.
///
/// A *handle* is not a secret and not a name the user chose; it is an
/// identifier recorded in device settings so a later launch can find the value
/// again. It says nothing about what it unlocks, which is why it may be written
/// to a plaintext file.
///
/// The backing store is a platform fact — Keychain, libsecret, Credential
/// Manager — so the composition root supplies an implementation.
abstract interface class TomSecretStore implements TomCacheKeyStore {
  /// The secret stored under [handle], or null when nothing is.
  ///
  /// A miss is an ordinary answer, not an error: a wiped keychain, a restored
  /// machine and a first run are all the same situation here.
  @override
  Future<String?> read(String handle);

  /// Stores [secret] under [handle], replacing any current value.
  @override
  Future<void> write(String handle, String secret);

  /// Forgets the secret at [handle], if any.
  Future<void> delete(String handle);
}

/// Which call on a [TomSecretStore] failed.
enum TomSecretStoreStep { read, write }

/// A platform secret store that could not answer.
///
/// Raised in place of whatever the store threw — a locked or denied keychain,
/// a missing entitlement, a platform channel that errored — so a host can tell
/// a *store that failed* from a container that would not open, and from a
/// miss, which is an ordinary answer. The [cause] is the store's own
/// exception, kept for its type and any platform code; it is never a secret,
/// and a host logs those two and nothing else of it.
class TomSecretStoreException implements Exception {
  /// The call that failed.
  final TomSecretStoreStep step;

  /// What the store threw.
  final Object cause;

  const TomSecretStoreException(this.step, this.cause);

  @override
  String toString() =>
      'TomSecretStoreException(${step.name}: ${cause.runtimeType})';
}

/// Volatile [TomSecretStore] — secrets live only for the session.
///
/// A run against it mints a new settings key every launch, and the *existing*
/// settings container then refuses to open, which is exactly what a lost
/// device secret means.
@visibleForTesting
class TomInMemorySecretStore implements TomSecretStore {
  final Map<String, String> _secrets = {};

  @override
  Future<String?> read(String handle) async => _secrets[handle];

  @override
  Future<void> write(String handle, String secret) async =>
      _secrets[handle] = secret;

  @override
  Future<void> delete(String handle) async => _secrets.remove(handle);

  /// Forgets everything — the wiped-keychain case.
  Future<void> clear() async => _secrets.clear();
}
