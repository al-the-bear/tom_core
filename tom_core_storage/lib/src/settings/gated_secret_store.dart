/// A device secret released only after the operating system's own check.
library;

import 'package:meta/meta.dart';

/// What gates a [TomGatedSecretStore]'s items on this device now.
enum TomGatedAvailability {
  /// No OS check can gate an item: no secure lock screen, no biometrics set
  /// up, a remote session the check does not reach (Screen Sharing, RDP),
  /// or a platform without one (Linux). The caller asks for the password.
  none,

  /// The item is released only after a biometric check (Touch ID, Face ID,
  /// a fingerprint, Windows Hello): bound to a key the OS uses only after
  /// the check.
  biometric,

  /// The item is released only after the device passcode or login password
  /// (no biometrics enrolled), bound as [biometric] is.
  passcode,

  /// The OS check guards the read, but nothing binds the item to it: a
  /// process of the same user that reads the item's store directly gets it
  /// without the check. The weaker form, named as such where the user
  /// chooses it (an ad-hoc signed macOS app, which cannot use the
  /// data-protection keychain).
  gateOnly,
}

/// How long a [TomGatedSecretStore] item is meant to live. The store keeps
/// both alike; the caller deletes a [session] item when the session ends.
enum TomGatedLifetime {
  /// Until the session that wrote it ends (a service stop, "lock
  /// completely").
  session,

  /// Until the user turns it off, or the key it holds changes.
  saved,
}

/// Why a [TomGatedSecretStore] call failed.
enum TomGatedSecretErrorKind {
  /// The user cancelled the OS prompt.
  cancelled,

  /// Too many failed attempts: the OS has locked the check out for now.
  lockedOut,

  /// The item can no longer be released: the enrolment changed (a new
  /// fingerprint or face, biometrics removed, Hello reset). Write it again
  /// after the password.
  invalidated,

  /// The check cannot run now ([TomGatedAvailability.none]).
  unavailable,

  /// Anything else the platform reported.
  failed,
}

/// A [TomGatedSecretStore] call that did not succeed. A failure is not a
/// miss (a miss reads null), and it never carries the secret; [code] is the
/// platform's own code, logged with [kind] and nothing else.
class TomGatedSecretStoreException implements Exception {
  /// A failure of [kind], with the platform's [code].
  const TomGatedSecretStoreException(this.kind, {this.code});

  /// Why it failed.
  final TomGatedSecretErrorKind kind;

  /// The platform's code (an `OSStatus`, an `HRESULT`, a plugin code), or
  /// null.
  final String? code;

  @override
  String toString() =>
      'TomGatedSecretStoreException(${kind.name}${code == null ? '' : ', $code'})';
}

/// Device secrets released only after the OS's own check: Touch ID, Face
/// ID, a fingerprint, Windows Hello, the device passcode. The OS unlock of
/// an app keeps its unlock bundle here (part-os-unlock).
///
/// Like `TomSecretStore`, a handle is an identifier, not a secret. Unlike
/// it, every [read] may show the OS prompt with a reason text, and
/// [availability] says what the gate is before an item is written.
abstract interface class TomGatedSecretStore {
  /// What gates an item on this device now; [TomGatedAvailability.none]
  /// when nothing can.
  Future<TomGatedAvailability> availability();

  /// Stores [secret] under [handle], replacing any current value. A store
  /// whose key exists only after the check (Windows Hello) shows the prompt
  /// with [reason] here too. Throws [TomGatedSecretStoreException].
  Future<void> write(
    String handle,
    String secret, {
    TomGatedLifetime lifetime = TomGatedLifetime.saved,
    String? reason,
  });

  /// The secret under [handle] after the OS check, which shows [reason];
  /// null when nothing is stored there (no prompt then). Throws
  /// [TomGatedSecretStoreException] when the check fails or is cancelled.
  Future<String?> read(String handle, {required String reason});

  /// Forgets the secret at [handle], if any, without a prompt.
  Future<void> delete(String handle);
}

/// A [TomGatedSecretStore] in memory, for tests: [availability] as set,
/// every read answered or failed as [nextFailure] says, and the prompts it
/// would have shown kept in [prompts].
@visibleForTesting
class TomInMemoryGatedSecretStore implements TomGatedSecretStore {
  /// A store of [available].
  TomInMemoryGatedSecretStore({
    this.available = TomGatedAvailability.biometric,
  });

  /// What [availability] answers.
  TomGatedAvailability available;

  /// The failure the next prompting call throws (then cleared), or null.
  TomGatedSecretErrorKind? nextFailure;

  /// The reasons of the prompts shown, in order.
  final List<String> prompts = [];

  final Map<String, ({String secret, TomGatedLifetime lifetime})> _items = {};

  /// The lifetime [handle] was written with, or null.
  TomGatedLifetime? lifetimeOf(String handle) => _items[handle]?.lifetime;

  /// The handles stored.
  Iterable<String> get handles => _items.keys;

  void _prompt(String reason) {
    if (available == TomGatedAvailability.none) {
      throw const TomGatedSecretStoreException(
        TomGatedSecretErrorKind.unavailable,
      );
    }
    prompts.add(reason);
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw TomGatedSecretStoreException(failure);
    }
  }

  @override
  Future<TomGatedAvailability> availability() async => available;

  @override
  Future<void> write(
    String handle,
    String secret, {
    TomGatedLifetime lifetime = TomGatedLifetime.saved,
    String? reason,
  }) async {
    if (available == TomGatedAvailability.none) {
      throw const TomGatedSecretStoreException(
        TomGatedSecretErrorKind.unavailable,
      );
    }
    _items[handle] = (secret: secret, lifetime: lifetime);
  }

  @override
  Future<String?> read(String handle, {required String reason}) async {
    final item = _items[handle];
    if (item == null) return null;
    _prompt(reason);
    return item.secret;
  }

  @override
  Future<void> delete(String handle) async => _items.remove(handle);
}
