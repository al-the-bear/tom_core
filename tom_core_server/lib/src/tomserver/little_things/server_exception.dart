import 'dart:isolate';

import 'package:tom_core_server/src/tomserver/server/server.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Base class for every exception raised by `tom_core_server`.
///
/// [TomServerException] extends the kernel's [TomException] with two
/// server-specific concerns:
///
/// - **Isolate attribution** — it captures [isolateName] at construction so a
///   logged or serialized error identifies the worker that produced it (server
///   work is spread across an isolate pool, so the bare message alone is
///   ambiguous).
/// - **Request correlation** — if the surrounding zone carries a
///   [TomRequestId] (set by the endpoints pipeline for the lifetime of a
///   request), the constructor copies its UUID into [TomException.requestUuid],
///   linking the error to the request that triggered it without the call site
///   having to thread the id through.
///
/// Every server exception type (for example `TomEndpointHandlerException`,
/// `TomCacheException`, `MariadbMigrationException`) subtypes this class, so a
/// `catch (e) on TomServerException` reaches all of them.
class TomServerException extends TomException {
  /// The debug name of the isolate that constructed this exception.
  ///
  /// Resolved from `Isolate.current.debugName` at construction time, falling
  /// back to `"unnamed isolate"` when the current isolate has no debug name.
  String isolateName = Isolate.current.debugName ?? "unnamed isolate";

  /// Whether this exception is safe to propagate to the client.
  ///
  /// When `true` (the default) the endpoints pipeline may surface the
  /// exception's user message to the caller; when `false` it should be treated
  /// as internal and masked behind a generic error response.
  bool clientThrow;

  /// Creates a server exception.
  ///
  /// [key] is the stable error code and [defaultUserMessage] the human-readable
  /// message; both are forwarded to [TomException]. Set [clientThrow] to `false`
  /// for errors that must not leak to the client.
  ///
  /// If a [TomRequestId] is present in the current zone, its UUID is copied into
  /// [TomException.requestUuid] so the error is correlated with the active
  /// request.
  TomServerException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    this.clientThrow = true,
  }) {
    TomRequestId? requestId = getFromCurrentZone<TomRequestId>();
    if (requestId != null) {
      requestUuid = requestId.uuid;
    }
  }

  /// Returns the base [TomException] string extended with the originating
  /// [isolateName], the [clientThrow] flag, and the correlated request UUID.
  @override
  String toString() =>
      "${super.toString()} $isolateName client-throw: $clientThrow $requestUuid";
}

/// A server-side login failure.
///
/// Thrown by a `TomAuthenticationService`, a `Tom2FAService`, or their helpers
/// when a login cannot succeed — unknown client/user, invalid credentials, no
/// enrolled second factor, an expired challenge. Carries the [TomServerException]
/// payload (`key`, user message, `parameters`, `stack`, `rootException`,
/// `autoLog`); `TomAuthenticationServer` catches it and turns its `key` into a
/// failed `TomAuthenticationResult` rather than propagating.
///
/// It lives here, next to the exception base, rather than beside the
/// authentication server, so that the 2FA subsystem can throw it without
/// importing the server that consumes it.
class LoginException extends TomServerException {
  /// Creates a login failure with a resource [key] and a default user message.
  LoginException(
    super.key,
    super.userMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}
