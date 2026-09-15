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
  /// The debug name of the isolate that **raised** this exception.
  ///
  /// Resolved from `Isolate.current.debugName` at construction time, falling
  /// back to `"unnamed isolate"` when the current isolate has no debug name.
  ///
  /// **It names the origin and is deliberately never updated.** An exception
  /// raised inside a pool worker and re-thrown in the main isolate still names
  /// the worker, which is the whole point: the server spreads work across
  /// identical isolates, so "which worker" is the question the message alone
  /// cannot answer, and "which isolate is reading this" is the one question
  /// whose answer is never useful. Resolving the name lazily would give exactly
  /// that useless answer.
  ///
  /// So the value answers *where this failed*, not *where this surfaced*. A
  /// reader wanting the latter has to record it at the rethrow site; nothing
  /// here tracks a hop, because a trail would need every rethrow site to
  /// cooperate and rethrow sites are where the least work is done.
  ///
  /// The name travels however the exception does. Within one isolate group —
  /// which is what `Isolate.spawn`, `Isolate.run` and the server's isolate
  /// pooling create — an exception handed over a `SendPort` arrives with this
  /// field intact, so a worker's failure is still attributed to the worker
  /// after the hand-off. That is measured rather than assumed:
  /// `little_things_test.dart` sends one and reads it back.
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
  ///
  /// Read it through [clientMessage] rather than by hand. The flag binds the
  /// *value*, not the handler: a response built from `defaultUserMessage`
  /// directly shows the message of an exception marked `false` and nothing
  /// complains, which is a leak by omission rather than by decision.
  final bool clientThrow;

  /// Creates a server exception.
  ///
  /// [key] is the stable error code and [defaultUserMessage] the human-readable
  /// message; both are forwarded to [TomException]. Set [clientThrow] to `false`
  /// for errors that must not leak to the client.
  ///
  /// **The kernel's whole parameter list is forwarded**, including the three
  /// that identify an exception rather than describe it — `uuid`, `requestUuid`
  /// and `serverCallError`. Every one of the package's exception types chains
  /// through here, so a parameter missing from this list is missing from all of
  /// them; the three were, and each had a case that could not be expressed:
  ///
  ///  * `uuid` is generated when omitted, which is right for a failure raised
  ///    here and wrong for one *reconstructed* from a wire representation — a
  ///    fresh identity cannot be matched to the log line written where the
  ///    failure actually happened.
  ///  * `requestUuid` was reachable by one route only, the zone lookup below.
  ///    A worker isolate handed the request id as a plain string, or a
  ///    deserialiser holding it as a field, had no way to say which request the
  ///    failure belongs to — which is the correlation this module exists for.
  ///  * `serverCallError` is the kernel's slot for "this came from an HTTP
  ///    call", and the server package is the one most likely to make outbound
  ///    calls. [TomServerSelfLoginException] is the first to fill it.
  ///
  /// **An explicitly supplied [requestUuid] wins over the ambient one.** The
  /// zone lookup runs only when the caller did not say, because a caller that
  /// names a request is reconstructing or relaying a failure from elsewhere and
  /// knows something the surrounding zone does not — overwriting it would
  /// re-label another request's failure with this one's id, which is worse than
  /// no correlation at all.
  ///
  /// Otherwise, if a [TomRequestId] is present in the current zone, its UUID is
  /// copied into [TomException.requestUuid] so the error is correlated with the
  /// active request.
  TomServerException(
    super.key,
    super.defaultUserMessage, {
    super.uuid,
    super.requestUuid,
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.serverCallError,
    this.clientThrow = true,
  }) {
    if (requestUuid != null) return;
    TomRequestId? requestId = getFromCurrentZone<TomRequestId>();
    if (requestId != null) {
      requestUuid = requestId.uuid;
    }
  }

  /// The message this exception may be shown to a client as: its
  /// [TomException.defaultUserMessage] when [clientThrow] is true, and
  /// [maskedFallback] when it is not.
  ///
  /// **Every response that carries a message reads it from here.** The flag is
  /// a promise the thrower makes about its own text — five types in the package
  /// default it to `false` because their messages describe server internals, an
  /// unreachable data source, a failed audit write, a misconfigured identity
  /// provider — and a handler that reads `defaultUserMessage` directly breaks
  /// that promise by *omission* rather than by decision. Nothing in the type
  /// system can stop it; what this does is make the correct call shorter than
  /// the wrong one, and give a reviewer one name to search for.
  ///
  /// [maskedFallback] is required and has no default, because the framework
  /// does not own the text a deployment shows in place of a hidden one: text
  /// belongs to the rendering tier, reached through a resource key, and a
  /// generic English sentence baked in here would be the framework putting
  /// words in a client's mouth.
  ///
  /// Only the *message* is masked. [TomException.key] stays on the wire for
  /// every exception — `tomErrorEnvelope` reports it unconditionally — because
  /// it is a stable code a client resolves against its own resources, not free
  /// text an author wrote for a person.
  ///
  /// ```dart
  /// return Response(403, body: error.clientMessage('Request refused.'));
  /// ```
  String clientMessage(String maskedFallback) =>
      clientThrow ? defaultUserMessage : maskedFallback;

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
///  * `clientThrow` — for a [TomServerException], the masking flag;
///  * `loginFailure` — for a [TomLoginException], the closed-set reason.
///
/// A field is **absent rather than null** when the error does not carry it, so
/// its presence means something: a body with no `errorKey` came from something
/// that is not a Tom error at all, and one with no `clientThrow` came from
/// outside the server package (the kernel raises plain [TomException]s), and one
/// with no `loginFailure` is not a login failure. Padding the shape out with
/// defaults would make every body look like a server error and cost a client the
/// distinction.
///
/// `loginFailure` is the field that makes a login failure actionable without
/// string-matching: a client shows "try the code again" for
/// [TomLoginFailure.secondFactorInvalid] and "start the login over" for
/// [TomLoginFailure.rateLimited] by switching on a closed set, where before it
/// had to recognise `key` values that no type enumerated.
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
  if (error is TomLoginException) {
    envelope['loginFailure'] = error.reason.name;
  }
  return envelope;
}

/// Why a login could not succeed, as a closed set a caller can switch on.
///
/// The set is deliberately **coarser than the framework's own knowledge**. A
/// login failure carries two audiences with opposite needs: the server, which
/// wants every distinction it can get for its logging and its lockout logic,
/// and the client, which must not be told more than it has earned. This enum
/// serves the client, and the `key` — free-form, and as specific as the throw
/// site likes — still serves the server.
///
/// That is why there is no `badCredentials`, no `unknownUser` and no
/// `accountLocked`: all three are [accountProblem]. Telling a caller which of
/// the three it hit is a **user-enumeration oracle** — "unknown user" and "wrong
/// password" as separate answers let anyone confirm which accounts exist, and
/// "locked" confirms it a second way. One value, and the account's owner learns
/// the detail through a channel that already knows who they are.
///
/// The rest are separated because a client can act on each differently and
/// none of them says anything about whether an account exists.
enum TomLoginFailure {
  /// The account cannot authenticate: no such account, wrong credentials, or
  /// the account is locked. One value for the three on purpose — see above.
  accountProblem,

  /// The first factor was accepted and a second one is needed that the caller
  /// has not supplied or not enrolled. The remedy is to complete or begin
  /// enrolment; the credentials themselves were not refused.
  secondFactorRequired,

  /// A second factor was supplied and is not usable: the wrong code, an expired
  /// challenge, one already answered, or one this token does not carry. The
  /// remedy is to try the factor again.
  secondFactorInvalid,

  /// The attempts for this challenge or enrolment are spent. Distinct from
  /// [secondFactorInvalid] because the remedy differs: trying the same factor
  /// again cannot succeed, and the caller has to start the login over.
  rateLimited,

  /// The failure is on the deployment's side rather than the caller's: an
  /// identity provider refused or is unreachable, a one-time code could not be
  /// delivered, or the configuration names a mechanism nothing implements.
  /// Retrying the same credentials may well work once the cause is fixed, and
  /// nothing the caller did is wrong.
  providerError,
}

/// A server-side login failure.
///
/// Thrown by a `TomAuthenticationService`, a `Tom2FAService`, or their helpers
/// when a login cannot succeed — unknown client/user, invalid credentials, no
/// enrolled second factor, an expired challenge. Carries the [TomServerException]
/// payload (`key`, user message, `parameters`, `stack`, `rootException`,
/// `autoLog`) plus a [reason]; `TomAuthenticationServer` catches it and turns
/// its `key` into a failed `TomAuthenticationResult` rather than propagating.
///
/// It lives here, next to the exception base, rather than beside the
/// authentication server, so that the 2FA subsystem can throw it without
/// importing the server that consumes it.
class TomLoginException extends TomServerException {
  /// Which closed-set failure this is.
  ///
  /// Required, and required rather than defaulted, because a default would be
  /// a classification nobody made: every new throw site would silently join
  /// whichever value was chosen as the default, and the value a client branches
  /// on would quietly stop meaning anything. The compiler asking the question
  /// at each site is the whole mechanism.
  ///
  /// It does not replace [TomException.key]. The key stays as specific as the
  /// throw site can make it and is what the server logs and what a message
  /// catalogue looks up; the reason is the coarse, closed set a client switches
  /// on without matching strings no type enumerates.
  final TomLoginFailure reason;

  /// Creates a login failure with a resource [key], a default user message and
  /// the closed-set [reason] a caller branches on.
  TomLoginException(
    super.key,
    super.defaultUserMessage, {
    required this.reason,
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });

  /// The base string extended with the [reason], so a log line carries the
  /// classification beside the key it was classified from.
  @override
  String toString() => '${super.toString()} login-failure: ${reason.name}';
}
