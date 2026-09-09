import 'dart:isolate';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'request_id.dart';

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
///   [TomRequestId] (seeded by `tomDefaultAuthenticationMiddleware` for the
///   lifetime of a request), the constructor copies its UUID into
///   [TomException.requestUuid],
///   linking the error to the request that triggered it without the call site
///   having to thread the id through.
///
/// Every server exception type (for example `TomEndpointHandlerException`,
/// `TomCacheException`, `MariadbMigrationException`) subtypes this class, so a
/// single `on TomServerException catch (e)` clause reaches all of them.
///
/// That sentence is a rule, not an observation: `server_exception_family_test`
/// scans every class declaration under `lib/src/tomserver/` and fails on one
/// that reaches [TomException] without passing through this class. A type
/// outside the family escapes the endpoints pipeline's classification, cannot
/// report [clientThrow] through `tomErrorEnvelope`, and arrives naming neither
/// its isolate nor its request.
///
/// **This class is also raised directly, and only for one thing.** Five
/// `.named(...)` constructors — the audit sink, the OAuth state store, the job
/// store, the lease lock and the scheduler roll call — resolve a data source
/// out of `TomDataSourceInfo` and refuse when the registry has no such name.
/// Each throws this class with a key ending `.unknown_datasource` and the
/// offending name in `parameters['datasource']`.
///
/// They are the exception to "name a subtype", and the reason they are is that
/// there is nothing for a subtype to add. All five happen at construction,
/// before a connection is opened and before any request is served, so a
/// deployment meets them as a failed start-up rather than as something a
/// `catch` clause discriminates: the operator's next act is to fix one name in
/// one configuration file, which the key and the parameter already say. A type
/// declared so a `catch` clause could name it, in a place no `catch` clause
/// runs, would be four declarations differing only in spelling.
///
/// The set is closed rather than open-ended. `server_exception_family_test`
/// pins these five sites by file and key, so a sixth direct raise has to be
/// argued for rather than merely written — which is what keeps the rule from
/// eroding into "the base class is fine anywhere". Anywhere else, name a
/// subtype.
class TomServerException extends TomException {
  /// The debug name of the isolate that constructed this exception.
  ///
  /// Resolved from `Isolate.current.debugName` at construction time, falling
  /// back to `"unnamed isolate"` when the current isolate has no debug name.
  ///
  /// Final, so the attribution can be trusted: the isolate named here is the
  /// one that raised the error, not one that later handled it.
  final String isolateName = Isolate.current.debugName ?? "unnamed isolate";

  /// Whether this exception is safe to propagate to the client.
  ///
  /// When `true` (the default) the endpoints pipeline may surface the
  /// exception's user message to the caller; when `false` it should be treated
  /// as internal and masked behind a generic error response.
  ///
  /// Final, so this is a property of the exception *type*, fixed where the
  /// error is raised and by the party that knows what the message contains. A
  /// catch site that decides a particular failure must not leave the server
  /// masks it in the response it builds; it does not rewrite the error.
  final bool clientThrow;

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
  /// [isolateName], the [clientThrow] flag, and — for an exception raised
  /// inside a request — a labelled `request: <uuid>` segment.
  ///
  /// The request segment is omitted entirely when [TomException.requestUuid] is
  /// null. An exception raised outside a request has no correlation to report,
  /// and the base already contributes three unset fields of its own; a fourth,
  /// trailing and unlabelled, reads as a stray value rather than as data.
  ///
  /// The segment is not redundant with the base string. [TomException] leads
  /// with the composite token `<exception-uuid>-<request-uuid>`, and because v4
  /// UUIDs themselves contain hyphens that token cannot be split back into its
  /// two ids by eye or by a simple pattern — the labelled trailing copy is what
  /// makes the correlation greppable in a log.
  @override
  String toString() {
    String request = requestUuid == null ? "" : " request: $requestUuid";
    return "${super.toString()} $isolateName client-throw: $clientThrow$request";
  }
}

/// Renders [error] into the framework's wire error envelope.
///
/// This is the single definition of what a Tom error looks like on the wire.
/// The body is built in layers, each one reporting only what the error actually
/// carries:
///
///  * `errorType` — always, because every failure has a runtime type and a
///    client that recognises nothing else can still log something specific;
///  * `errorKey`, `uuid`, `autoLog`, `requestUuid` — for a [TomException],
///    which is what a client branches on;
///  * `clientThrow` — for a [TomServerException], the masking flag.
///
/// A field is **absent rather than null** when the error does not carry it, so
/// its presence means something: a body with no `errorKey` came from something
/// that is not a Tom error at all, and one with no `clientThrow` came from
/// outside the server package (the kernel raises plain [TomException]s). Padding
/// the shape out with defaults would make every body look like a server error
/// and cost a client the distinction.
///
/// It lives here, beside [TomServerException], because [TomServerException] is
/// what decides the one conditional field and because this module is the one
/// every other server module already depends on — so both error handlers reach
/// it without either reaching the other.
///
/// **Every error response body in the package comes from here.** It was written
/// out by hand twice — once in `TomServer.errorHandler` and once in
/// `TomUserPreferencesErrorHandler` — and the copies had already drifted: the
/// preferences `404` reported no `clientThrow`, although every error it
/// translates is a [TomServerException] and carries one. A wire shape with two
/// authors has no shape.
Map<String, Object?> tomErrorEnvelope(Object error) {
  final envelope = <String, Object?>{'errorType': error.runtimeType.toString()};
  if (error is TomException) {
    envelope['errorKey'] = error.key;
    envelope['uuid'] = error.uuid;
    envelope['autoLog'] = error.autoLog;
    envelope['requestUuid'] = error.requestUuid;
  }
  if (error is TomServerException) {
    envelope['clientThrow'] = error.clientThrow;
  }
  return envelope;
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
class TomLoginException extends TomServerException {
  /// Creates a login failure with a resource [key] and a default user message.
  TomLoginException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}
