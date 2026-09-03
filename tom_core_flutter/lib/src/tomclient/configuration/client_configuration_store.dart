import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/client_exceptions.dart';

/// A failure raised by the client-configuration module.
///
/// A thin semantic subtype of [TomClientException] so a caller can tell a
/// configuration failure (no store wired, a stored value of the wrong type, a
/// duplicate key) from any other client-side error with a single `is` check.
/// The `key` is a stable dotted code — `client_configuration.store.not_configured`,
/// `client_configuration.value.type_mismatch`,
/// `client_configuration.key.duplicate`,
/// `client_configuration.key.unknown`,
/// `client_configuration.store.unsupported_platform`,
/// `client_configuration.store.invalid_content` — so callers branch on the code
/// rather than on message text.
class TomClientConfigurationException extends TomClientException {
  /// Creates a client-configuration exception. See [TomException] for the
  /// meaning of each argument.
  TomClientConfigurationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Where a client install's configuration **overrides** are persisted.
///
/// Deliberately the narrowest interface the holder needs: read the override
/// map back, write it. There is no `exists`, no per-key accessor and no
/// `clear` — writing an empty map *is* clearing, so a third method would be a
/// second way to say the same thing. Two methods is also the whole cost of
/// adapting a new backend (`shared_preferences`, browser local storage, a
/// platform keychain): implement them and pass the instance to the holder.
///
/// **Only overrides are stored, never the full value set.** A value the install
/// never changed is resolved from the shipped config resources at every start,
/// so shipping a new default in an app update actually reaches installs that
/// never touched that key. Persisting every value would freeze the shipped
/// defaults at the moment of the first save.
///
/// The scope is the **(client app, machine)** pair — there is no user parameter
/// anywhere in this interface, by design (see [TomBaseClientConfiguration]).
abstract class TomClientConfigurationStore {
  /// Allows `const` implementations.
  const TomClientConfigurationStore();

  /// Reads the persisted override map.
  ///
  /// Returns an empty map when nothing has been persisted yet — absence is not
  /// an error. Implementations that find unreadable content throw
  /// `client_configuration.store.invalid_content` rather than silently
  /// returning empty, because a corrupt store that looks empty would be
  /// overwritten by the next [write] and lose the install's settings.
  Future<Map<String, Object?>> read();

  /// Replaces the persisted override map with [values].
  ///
  /// A write must be **all-or-nothing**: a failure part-way through must leave
  /// the previously readable content intact rather than a truncated map. An
  /// empty [values] clears the store.
  Future<void> write(Map<String, Object?> values);
}

/// An in-memory [TomClientConfigurationStore].
///
/// Works on every platform and persists nothing beyond the process, which
/// makes it the right store for tests, for examples, and for a client that
/// deliberately keeps no machine-local state. Because it forgets on exit it is
/// *not* a fallback to reach for when a platform has no real backend — a store
/// that silently forgets is worse than a loud one.
class TomMemoryClientConfigurationStore extends TomClientConfigurationStore {
  /// Creates an empty store, optionally pre-seeded with [initialValues].
  TomMemoryClientConfigurationStore([Map<String, Object?>? initialValues])
    : _values = {...?initialValues};

  Map<String, Object?> _values;

  @override
  Future<Map<String, Object?>> read() async => {..._values};

  @override
  Future<void> write(Map<String, Object?> values) async {
    _values = {...values};
  }
}
