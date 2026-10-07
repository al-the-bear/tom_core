import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../authentication/jwt_signing.dart';
import '../authentication/server_self_login.dart';
import '../little_things/request_id.dart';
import '../little_things/server_exception.dart';
import '../configuration/base_server_configuration.dart';
import '../configuration/runtime_environment.dart';
import '../endpoints/endpoint_pipeline.dart';
import '../authorization/authorization_cache.dart';
import '../transactions/transaction_manager.dart';

/// A pass-through shelf [Middleware] that seeds the request [Request.context].
///
/// If [context] is supplied, its entries are merged into a copy of the
/// incoming request's context before the inner handler runs; otherwise the
/// request is forwarded unchanged. [id] is a label for tracing. The default
/// pipeline uses it to attach a fresh [TomRequestLogInfo] under
/// [TomRequestLogInfo.contextName] (see [TomServer.start]).
Middleware contextSetupMiddleware(String id, [Map<String, Object>? context]) =>
    (innerHandler) {
      // FutureOr<Response> Function(Request request)
      return (request) {
        Request newRequest = request;
        if (context != null) {
          Map<String, Object> newContext = Map.from(request.context);
          newContext.addAll(context);
          newRequest = request.change(context: newContext);
        }
        return Future.sync(() => innerHandler(newRequest)).then((response) {
          return response;
        });
      };
    };

/// Why a request carries the credentials it does — the third element of
/// [extractAuthentication]'s result.
///
/// The first two elements cannot say. A `null` principal and a `null` token is
/// the answer to four different requests: one that sent no `Authorization`
/// header, one that sent a scheme this server does not speak, one whose bearer
/// token failed verification, and one whose verified token yielded no
/// principal. Those are an anonymous caller, a misconfigured client, a rotated
/// signing key and a malformed claim set respectively, and an operator who
/// cannot tell them apart cannot act on any of them.
///
/// The distinction is for the *reader of this function*, not for the HTTP
/// client. All four still receive the same answer over the wire — see
/// `doc/server.md`, "Not Yet Implemented" — because a client able to tell "your
/// signature was wrong" from "you sent nothing" is an attacker able to tell
/// whether they guessed.
enum TomCredentialOutcome {
  /// The request had no `Authorization` header — an ordinary anonymous caller.
  noCredentials,

  /// The header named a scheme other than `Bearer`, or had no scheme at all.
  ///
  /// Nothing was read from it. A `Basic` header against a Tom server is a
  /// client configured for a different service, not an attack.
  unsupportedScheme,

  /// The header carried a bearer token that [verifyBearerToken] refused.
  ///
  /// A wrong signature, a token this deployment's key cannot check, a body
  /// that would not decode, or an empty one. This is the outcome a key
  /// rotation that missed an issuer produces, for every request from every
  /// client of that issuer.
  unreadableToken,

  /// The token verified, but no [TomPrincipal] could be built from it.
  ///
  /// The token is this deployment's own — it carries a signature this server
  /// can check — and it is handed back with the outcome: a refresh endpoint is
  /// reached with exactly it.
  ///
  /// The ordinary cause is a token that is **not live**: expired, without a
  /// readable `exp`, or with a `validUntil` that disagrees with its `exp`.
  /// [TomBearerAuthentication.convertTokenPayloadToPrincipal] refuses to build
  /// a principal from such a token (`TomTokenLifetimeException`), because
  /// signature verification deliberately does not check the lifetime.
  noPrincipal,

  /// The token verified and yielded a principal.
  authenticated,
}

/// [value] shortened to a length an access log can carry.
///
/// What is truncated here is client-supplied, and a client can supply
/// kilobytes of it.
String _forTheLog(String value) =>
    value.length <= 20 ? value : '${value.substring(0, 20)}…';

/// Extracts the bearer credentials from a request's `Authorization` header.
///
/// Reads the `Authorization` header and, when it carries a `Bearer <jwt>`
/// token, **verifies its signature** with [verifyBearerToken] and derives the
/// [TomPrincipal] via [TomBearerAuthentication.convertTokenPayloadToPrincipal].
/// Returns a record `(principal, token, outcome)`. The first two elements are
/// `null` whenever the request is not authenticated; [TomCredentialOutcome]
/// says which of the four ways that happened.
///
/// It never raises and never refuses: an unusable credential is treated as "no
/// credentials", because an endpoint marked `@TomPublicAccess()` has to be
/// servable through this same pipeline. Authorization decisions are made
/// downstream. Every refusal is *recorded*, though, at warning level and
/// without the credential in it — see "What reaches the log" below.
///
/// ## Why the signature is checked here
///
/// A JWT's public payload is plain base64: a client can edit any claim in it
/// and re-send it, and nothing about decoding notices. Everything this request
/// is then judged by is reconstructed from that payload — the principal, its
/// roles, and the 2FA claims whose own documentation says a client "achieves
/// nothing" by editing them. That sentence is only true if somebody checks the
/// signature, and this is the only inbound path where a client-supplied token
/// enters the server, so this is where it is checked.
///
/// The check is not conditional and there is no opt-out. A flag permitting an
/// unverified token would be the same exposure with a name, and the one
/// deployment shape that might have wanted it — a server running the
/// framework's bundled sample keys — is already refused at boot by
/// [installJwtSigning] outside a development or test environment.
///
/// ## What reaches the log
///
/// Never the credential. A token this server cannot read may still be a live
/// credential somewhere else — the commonest reason it is unreadable is that it
/// was minted for a different deployment — and an access log is the least
/// protected place it could end up.
///
/// So a refused bearer token is described by its *reason* (from
/// [verifyBearerToken]) and a refused header by its *scheme*, and a header with
/// no scheme at all is reported as having none rather than by quoting what the
/// client sent in its place. `test/server_test.dart` holds the battery that
/// checks a presented token never appears in any line the module writes.
(TomPrincipal?, TomClientJwtToken?, TomCredentialOutcome) extractAuthentication(
  Request req,
) {
  final String? header = req.headers["authorization"];
  if (header == null) return (null, null, TomCredentialOutcome.noCredentials);

  // RFC 7235 §2.1: the scheme is a token, separated from the credentials by a
  // space, and matched **case-insensitively**. Reading it case-sensitively
  // turned every request from a conformant client that spells it `bearer` into
  // an anonymous one, and said nothing anywhere.
  final space = header.indexOf(' ');
  final scheme = space < 0 ? header : header.substring(0, space);
  if (scheme.toLowerCase() != "bearer") {
    tomLog.warn(
      'Ignored an Authorization header this server cannot read: '
      '${space < 0 ? 'it names no scheme' : 'scheme "${_forTheLog(scheme)}"'}. '
      'The request proceeds unauthenticated.',
    );
    return (null, null, TomCredentialOutcome.unsupportedScheme);
  }

  // Verification and decoding in one call: a token that fails the signature
  // check never becomes a `TomClientJwtToken` here at all, so there is no
  // window in which an unverified one is in hand. `verifyBearerToken` has
  // already logged the reason it refused.
  final token = verifyBearerToken(
    space < 0 ? "" : header.substring(space + 1).trim(),
  );
  if (token == null) return (null, null, TomCredentialOutcome.unreadableToken);

  try {
    return (
      TomBearerAuthentication.convertTokenPayloadToPrincipal(token),
      token,
      TomCredentialOutcome.authenticated,
    );
  } catch (e) {
    // A verified token whose payload will not yield a principal is a genuine
    // oddity — the token is ours, so the claims are malformed rather than
    // forged — and the request proceeds anonymously either way. Reported for
    // the same reason the signature rejection is: a credential that was
    // refused and said nothing is the one an operator cannot investigate. The
    // token itself is kept: it is still this deployment's, and a refresh
    // endpoint is reached with exactly it.
    tomLog.warn('Bearer token verified but yielded no principal: $e');
    return (null, token, TomCredentialOutcome.noPrincipal);
  }
}

/// Resolves the effective [TomPrincipal] for a request from its credentials.
///
/// Two answers are available: what [TomAuthorizationCache] holds for
/// [clientToken], and [tokenPrincipal] — the one [extractAuthentication]
/// derived from the token itself. A cache hit wins; a cache miss, and a request
/// with no token at all, fall back to the token principal.
///
/// An expired cache entry is neither, and resolves to `null` — the same answer
/// a request bearing no credentials gets. That is deliberate and is the reason
/// this lives in its own function:
///
/// - It must not throw. The expiry is raised as a distinct exception type
///   precisely because it is a prompt to re-authorize rather than a failure, so
///   letting it escape would hand the client whatever the generic error handler
///   makes of an unrecognised exception (an HTTP 500, by default) instead of an
///   answer it can act on.
/// - It must not fall back to [tokenPrincipal]. The cache entry's lifetime *is*
///   the token's — `TomAuthorizationCache` reads it from the token's `exp`
///   claim — so an expired entry means *this token* has expired, and
///   [extractAuthentication] has already declined to build a principal from
///   it: [TomBearerAuthentication.convertTokenPayloadToPrincipal] enforces the
///   token's lifetime whether or not anything was cached. Serving an expired
///   entry's principal would be the one path around that check.
///
/// Resolving to no principal keeps the cache from changing the answer in the
/// dangerous direction: a protected endpoint refuses the request through the
/// ordinary access-denied path, while an unauthenticated one — a refresh or
/// re-login endpoint, say — is still reachable, and still receives the token
/// itself from the request zone.
Future<TomPrincipal?> _resolveRequestPrincipal(
  TomClientJwtToken? clientToken,
  TomPrincipal? tokenPrincipal,
) async {
  if (clientToken == null) return tokenPrincipal;
  try {
    return await TomAuthorizationCache.getPrincipal(clientToken) ??
        tokenPrincipal;
  } on TomAuthorizationCacheException catch (e) {
    // Logged at info, not warning: an aged-out session is the cache working,
    // not a fault. It is worth a line because the request that follows will be
    // refused for a reason the endpoint cannot name — from there it looks like
    // an unauthenticated caller, which is exactly what it now is.
    tomLog.info(
      "Cached principal for the presented token has expired (${e.key}); "
      "the request proceeds unauthenticated",
    );
    return null;
  }
}

/// The default authentication [Middleware] of a [TomServer].
///
/// For each request it:
/// 1. extracts bearer credentials with [extractAuthentication];
/// 2. resolves the effective [TomPrincipal] — preferring a principal cached for
///    the client token by [TomAuthorizationCache], falling back to the one
///    derived directly from the token, and resolving to *no* principal when the
///    cache reports the entry expired (see [_resolveRequestPrincipal]);
/// 3. runs the inner handler inside a [runZoned] scope whose [TomZoneValues]
///    expose the shelf [Request], the ambient [TomExecutionContext], the
///    resolved [TomPrincipal], the [TomClientJwtToken], and a fresh
///    [TomRequestId] — making them recoverable anywhere in the request via
///    `getFromCurrentZone` — and inside a
///    [TomTransactionManager.runInTransactionScope], giving the request its own
///    current transaction.
///
/// [id] labels the middleware for tracing; the optional [context] is merged
/// into the request context before handling. Replace it via
/// `TomBaseServerConfiguration.authenticationMiddleware` to customise
/// authentication.
Middleware tomDefaultAuthenticationMiddleware(
  String id, [
  Map<String, Object>? context,
]) => (innerHandler) {
  // FutureOr<Response> Function(Request request)
  return (request) {
    Request newRequest = request;
    if (context != null) {
      Map<String, Object> newContext = Map.from(request.context);
      newContext.addAll(context);
      newRequest = request.change(context: newContext);
    }
    return Future<Response>.sync(() async {
      var (
        TomPrincipal? callPrincipal,
        TomClientJwtToken? clientToken,
        TomCredentialOutcome outcome,
      ) = extractAuthentication(
        request,
      );
      // The outcome leads, because it is the part the other two cannot express:
      // an anonymous request and one whose token this deployment could not read
      // both interpolate as "null and null".
      tomLog.trace(
        "${outcome.name}: extracted $callPrincipal and $clientToken from incoming request to ${request.requestedUri}",
      );
      var principal = await _resolveRequestPrincipal(
        clientToken,
        callPrincipal,
      );
      TomZoneValues zoneValues = TomZoneValues({
        Request: request,
        TomExecutionContext: tomExecutionContext,
        TomPrincipal: principal,
        TomClientJwtToken: clientToken,
        TomRequestId: TomRequestId(),
      });
      zoneValues[TomZoneValues] = zoneValues;
      // Each request also gets its own current transaction, for the same reason
      // it gets its own principal: two requests interleaving in one isolate must
      // not be able to see — let alone commit or roll back — each other's work.
      return TomTransactionManager.runInTransactionScope(
        () => runZoned<FutureOr<Response>>(
          zoneValues: zoneValues.zoneValues,
          () => innerHandler(newRequest),
        ),
      );
    }).then((response) {
      return response;
    });
  };
};

/// The default request-logging [Middleware] of a [TomServer].
///
/// After the inner handler produces a response, it emits a single
/// `[<appId>] HTTP/<version> [<method>] <url> ... <status>` info line — but only
/// when the request's [TomRequestLogInfo] (read from the request context) has
/// `shouldBeLogged == true` and has not already been logged, after which it
/// marks `hasBeenLogged`. This one-shot guard prevents duplicate lines when the
/// pipeline retries or re-enters. It is the default value of
/// `TomBaseServerConfiguration.loggingMiddleware`.
///
/// The line opens with [tomAppId] so a deployment that runs several servers can
/// tell their access logs apart once collected in one place — the requested URI
/// carries a port, but that only separates them while they are separate ports
/// on one host. The prefix is omitted entirely when no application id is
/// configured, so a single-server deployment sees the line unchanged.
///
/// **It logs a response, not an outcome.** [TomServer.start] places it above
/// both error layers precisely so that a request rejected during authentication
/// has been turned into a response before it arrives here — which is what makes
/// a rejection appear in the access log at all. The one case still absent is an
/// error that escapes *both* layers, because no response was produced and there
/// is no status to write; `_handleError` logs that error itself, and shelf
/// answers the client.
Middleware tomLoggingMiddleware() => (innerHandler) {
  // FutureOr<Response> Function(Request request)
  return (request) {
    TomRequestLogInfo? logInfo =
        request.context[TomRequestLogInfo.contextName] as TomRequestLogInfo;
    return Future.sync(() => innerHandler(request)).then((response) {
      if ((logInfo.shouldBeLogged == true && logInfo.hasBeenLogged == false)) {
        final appId = tomAppId;
        tomLog.info(
          "${appId.isEmpty ? "" : "[$appId] "}HTTP/${request.protocolVersion} [${request.method}] /${request.url} ${request.requestedUri} ${response.statusCode} ${response.encoding}",
        );
        logInfo.hasBeenLogged = true;
      }
      return response;
    });
  };
};

/// A [Handler] that ignores the request and always replies with [statusCode].
///
/// Useful as a terminal handler or a placeholder in a [Cascade]; [id] labels it
/// for tracing.
Handler noopHandler(String id, int statusCode) {
  return (Request r) {
    tomLog.trace("noopHandler $id");
    return Response(statusCode);
  };
}

/// Wraps the inner handler so thrown errors are routed to [errorHandler].
///
/// When the inner handler throws, the error and stack trace are logged and
/// passed to [errorHandler]; a non-null result becomes the response, otherwise
/// the error is rethrown to the next outer handler. [id] labels the layer for
/// tracing. The pipeline installs two layers — an outer one (using the
/// authentication error handler) and an inner one (using the main error
/// handler) — see [TomServer.start].
Middleware _handleError(
  Response? Function(Request, Object, StackTrace) errorHandler,
  String id,
) => (innerHandler) {
  // FutureOr<Response> Function(Request request)
  return (request) {
    tomLog.trace("handleError $id before passing through");
    return Future.sync(() => innerHandler(request)).then(
      (response) {
        // no error
        tomLog.trace("passed through handleError $id without error...");
        return response;
      },
      onError: (Object error, StackTrace stacktrace) {
        tomLog.error("handleError $id caught error... $error");
        tomPrintStackTrace(stacktrace);
        Response? errorResult = errorHandler(request, error, stacktrace);
        if (errorResult != null) {
          return errorResult;
        }
        throw error;
      },
    );
  };
};

/// Per-request logging state carried in the shelf request context.
///
/// [contextSetupMiddleware] seeds one instance under [contextName] at the start
/// of the pipeline; [tomLoggingMiddleware] reads it to decide whether to emit
/// the access-log line and to mark it as logged. Set [shouldBeLogged] to
/// `false` (e.g. for health checks) to suppress the line.
class TomRequestLogInfo {
  /// The request-context key under which the [TomRequestLogInfo] is stored.
  static const String contextName = "loggingInfo";

  /// Whether the access-log line for this request has already been emitted.
  bool hasBeenLogged = false;

  /// Whether this request should produce an access-log line at all.
  bool shouldBeLogged = true;

  @override
  String toString() =>
      "TomRequestLogInfo should=$shouldBeLogged has=$hasBeenLogged";
}

/// The HTTP entry point of a Tom server application.
///
/// Built from a [TomBaseServerConfiguration], a [TomServer] assembles a shelf
/// [Pipeline] — context setup, error handling, authentication, logging — in
/// front of the endpoint [Router] and binds it to a socket in [start]. TLS,
/// host/port, isolate sharing, compression, and the powered-by / server headers
/// all come from the configuration. The error and authentication-error handlers
/// translate thrown exceptions into JSON error responses and default to
/// [errorHandler] unless overridden on the configuration.
class TomServer {
  /// The configuration that drives binding, TLS, and pipeline composition.
  TomBaseServerConfiguration configuration;

  /// The TLS context this server is serving with, or `null` when it is serving
  /// plaintext.
  ///
  /// Built by [start] from the configuration's certificate chain and private
  /// key, and left `null` when `noSsl` is set — so, like [router], this is a
  /// handle that only means anything *after* the server has been started, and
  /// reads `null` on one that has not been. A caller asking beforehand whether
  /// TLS was *requested* wants `configuration.noSsl`; this answers what the
  /// bound socket actually ended up with.
  SecurityContext? securityContext;

  /// The endpoint router, initialised during [start].
  Router? router;

  /// Maps a thrown error to a JSON error response (HTTP 500).
  ///
  /// The body is [tomErrorEnvelope] — the package's single definition of the
  /// wire error shape, which this handler renders and does not define. Every
  /// response carries the `x-tom-error: true` header and declares
  /// `application/json`. Overridden by
  /// `TomBaseServerConfiguration.errorHandler` when provided.
  ///
  /// It carries **no message**, which is also what makes it safe: the envelope
  /// reports `errorKey` for a client to resolve against its own resources and
  /// never `defaultUserMessage`, so no exception's text can escape through it.
  /// A replacement that adds a message takes on the obligation the envelope
  /// avoids, and must read it through [TomServerException.clientMessage] rather
  /// than from the field — `clientThrow` binds the value, not the handler.
  Response? Function(Request, Object, StackTrace) errorHandler =
      (request, error, stacktrace) {
        // The media type is part of the contract, not decoration: the body is
        // an envelope a client is expected to decode and branch on, so it has
        // to be declared as one. Shelf adds no default here, and an undeclared
        // body leaves a client with only `x-tom-error` to guess from.
        Map<String, String> headers = {
          "x-tom-error": "true",
          TomHeader.contentType: TomMimeType.json.toHeaderValue(),
        };
        return Response.internalServerError(
          body: jsonEncode(tomErrorEnvelope(error)),
          headers: headers,
        );
      };

  /// Error handler applied by the outer pipeline layer (authentication phase).
  ///
  /// Defaults to the configuration's `authenticationErrorHandler`, falling back
  /// to [errorHandler].
  Response? Function(Request, Object, StackTrace)? authenticationErrorHandler;

  /// The middleware that emits the per-request access log; from the
  /// configuration (defaults to [tomLoggingMiddleware]).
  late Middleware loggingMiddleware;

  /// Creates a server from [configuration], wiring the error, authentication-
  /// error, and logging handlers from it (falling back to the defaults).
  TomServer(this.configuration) {
    errorHandler = configuration.errorHandler ?? errorHandler;
    authenticationErrorHandler =
        configuration.authenticationErrorHandler ?? errorHandler;
    loggingMiddleware = configuration.loggingMiddleware;
  }

  /// Logs the deployment in, initialises the router, composes the pipeline, and
  /// binds the socket.
  ///
  /// The login comes first: when the configuration carries a service
  /// credential, [TomServerSelfLogin.loginAndInstall] installs the deployment's
  /// own principal before anything is bound, so no request is ever served with
  /// user grants uncapped. A configured deployment that cannot log in has the
  /// error logged and rethrown and **no socket is bound**; one that configured
  /// no credential skips the login and is unaffected.
  ///
  /// The rest builds the TLS [SecurityContext] (unless `noSsl`), resolves the
  /// listen address (`host`, or any-IPv4 when empty or `listenToAnyIp`),
  /// optionally wraps the router in a [Cascade] with the configuration's
  /// pre/post handlers, then serves the assembled pipeline on the configured
  /// port (with `shared` sockets when running multiple isolates).
  ///
  /// Returns the bound [HttpServer], so the future completes **when the socket
  /// is listening** and not before. Three things follow, and each was missing
  /// while this returned `void`:
  ///
  ///  * a bind failure — a port already in use, an unreadable certificate, a
  ///    malformed private key — rejects the returned future instead of
  ///    surfacing as an unhandled asynchronous error from a future nobody
  ///    holds;
  ///  * a caller can tell *listening* from *called*, which is what a test or a
  ///    supervisor needs before it sends the first request;
  ///  * the socket can be closed, so a server can be shut down by whoever
  ///    started it rather than only by ending the process.
  ///
  /// Awaiting is optional and nothing about the old shape is lost: a caller
  /// that ignores the future gets exactly the fire-and-forget behaviour it had,
  /// because the bound socket keeps the isolate alive on its own. What changes
  /// is that ignoring it is now a choice rather than the only option.
  Future<HttpServer> start() async {
    await _installServerPrincipal();
    warnOnUnenforcedResourceKeys();

    if (!configuration.noSsl) {
      warnOnDevelopmentTlsMaterial();
      securityContext = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(configuration.certificateChain))
        ..usePrivateKeyBytes(utf8.encode(configuration.privateKey));
    }

    var ip = (configuration.host).isEmpty
        ? InternetAddress.anyIPv4
        : configuration.host;

    if (configuration.listenToAnyIp == true) {
      ip = InternetAddress.anyIPv4;
    }

    String? poweredByHeader = ((configuration.poweredByHeader).isEmpty)
        ? null
        : configuration.poweredByHeader;

    // let the router be set up...
    router = TomEndpointRouting().initializeRouter();

    // setup cascade if pre- or postExecutionHandler are present
    Handler routerHandler = router!.call;

    if (configuration.preExecutionHandler != null ||
        configuration.postExecutionHandler != null) {
      Cascade handlerCascade = Cascade();
      if (configuration.preExecutionHandler != null) {
        handlerCascade = handlerCascade.add(configuration.preExecutionHandler!);
      }
      handlerCascade = handlerCascade.add(routerHandler);
      if (configuration.postExecutionHandler != null) {
        handlerCascade = handlerCascade.add(
          configuration.postExecutionHandler!,
        );
      }
      routerHandler = handlerCascade.handler;
    }

    // Configure a pipeline that handles errors and logs requests.
    //
    // The logging middleware sits **above both error layers**, and that
    // placement is the whole of what makes the access log complete. Shelf
    // applies middleware in the order it is added, so "earlier" is "closer to
    // the client": logging here wraps the error layers, which means a request
    // that fails while its principal is being established — an expired token, a
    // token signed by the wrong key, an authorization cache that cannot be
    // reached — has already been turned into a response by the time logging
    // sees it, and is logged like any other.
    //
    // Below them it could not be. The error layer converts a throw into a
    // response, so anything further in never runs for a rejected request; the
    // operator read a quiet server for exactly the requests worth reading
    // about, while `_handleError`'s own error line named neither method, path,
    // status nor protocol version and so could be correlated with nothing.
    final handler = Pipeline()
        .addMiddleware(
          contextSetupMiddleware("Setup context", {
            TomRequestLogInfo.contextName: TomRequestLogInfo(),
          }),
        )
        .addMiddleware(loggingMiddleware)
        .addMiddleware(
          _handleError(
            authenticationErrorHandler ?? errorHandler,
            "OuterErrorHandler",
          ),
        )
        .addMiddleware(
          configuration.authenticationMiddleware ??
              tomDefaultAuthenticationMiddleware(
                "tomDefaultAuthenticationMiddleware",
              ),
        )
        .addMiddleware(_handleError(errorHandler, "InnerErrorHandler"))
        .addHandler(routerHandler);

    // For running in containers, we respect the PORT environment variable.
    final port = configuration.port;
    HttpServer server = switch (configuration.noSsl) {
      true => await serve(
        handler,
        ip,
        port,
        poweredByHeader: poweredByHeader,
        shared: configuration.isolateCount > 1,
      ),
      false => await serve(
        handler,
        ip,
        port,
        securityContext: securityContext,
        poweredByHeader: poweredByHeader,
        shared: configuration.isolateCount > 1,
      ),
    };

    if (configuration.autoCompress) {
      server.autoCompress = true;
    }

    String? serverHeader = ((configuration.serverHeader).isEmpty)
        ? null
        : configuration.serverHeader;
    if (serverHeader != null) {
      server.serverHeader = serverHeader;
    }

    tomLog.info(
      'Server listening on port ${server.port} ${server.address} ${securityContext != null ? "SSL" : "no SSL"} at ${DateTime.now()}',
    );
    return server;
  }

  /// Warns when this server is about to serve TLS with the checked-in
  /// development pair.
  ///
  /// The pair stays a field default — a development machine has to be able to
  /// speak HTTPS without a certificate authority — so the boot says so instead,
  /// every time, rather than serving a published key in silence. Nothing
  /// refuses to start: an opt-in flag would cost every local TLS run an extra
  /// setting, and a deployment that reads its logs has been told.
  ///
  /// Silent when [TomBaseServerConfiguration.noSsl] is set, because nothing is
  /// served over TLS and a warning that does not apply is the kind that teaches
  /// an operator to ignore the ones that do.
  ///
  /// Public and separate from [start] for the reason the rest of `start()` is
  /// not tested here: it binds a socket and returns nothing, so a property of
  /// the boot is otherwise unobservable. This one can be asked directly.
  void warnOnDevelopmentTlsMaterial() {
    if (configuration.noSsl) return;
    if (!configuration.usesDevelopmentTlsMaterial()) return;

    final defaulted = <String>[
      if (configuration.certificateChain ==
          TomBaseServerConfiguration.developmentCertificateChain)
        'certificate chain',
      if (configuration.privateKey ==
          TomBaseServerConfiguration.developmentPrivateKey)
        'private key',
    ];

    tomLog.warn(
      'TLS is enabled and the ${defaulted.join(' and the ')} is still the '
      'development pair committed to tom_core_server. Its private key is '
      'published, so this server authenticates itself with a key anyone can '
      'read. Set certificateChain and privateKey for any deployment that is '
      'not a local development machine.',
    );
  }

  /// Warns when this server is about to serve with resource-key grants
  /// unenforced, outside a development or test environment.
  ///
  /// Enforcement ([TomResourceKeyProtection.globalSettingProtectionDefault],
  /// setting `tom.protection.resourceKeys`) is off by default, deliberately:
  /// turning it on refuses every endpoint without an access declaration and
  /// blanks every protected value nobody holds a grant for, which an
  /// application that has not configured grants yet cannot survive. The cost
  /// of that default is a production deployment that never switches it on, and
  /// whose grants are therefore decorative. The boot says so instead of
  /// refusing: nothing changes, and a deployment that reads its logs has been
  /// told which setting to change.
  ///
  /// Silent in a development or test environment, where the open default is
  /// the point, and when enforcement is on.
  ///
  /// Public and separate from [start] for the reason
  /// [warnOnDevelopmentTlsMaterial] is: `start()` binds a socket and returns
  /// nothing observable about its boot.
  void warnOnUnenforcedResourceKeys() {
    if (TomResourceKeyProtection.globalSettingProtectionDefault) return;
    if (isDevelopmentOrTestRuntime()) return;
    tomLog.warn(
      'Resource-key grants are not enforced: '
      'tom.protection.resourceKeys is off, so every endpoint without an access '
      'declaration is open and every protected value is shown, whatever the '
      'caller holds. Set tom.protection.resourceKeys=true (a define or an '
      'argument) once grants are configured, or run under a development or '
      'test environment to silence this warning.',
    );
  }

  /// Logs the deployment in as itself, before the socket is bound.
  ///
  /// The ordering is load-bearing. The server principal caps every user's
  /// grants (`min(user, server)`), so binding the socket first would open a
  /// window in which requests are served *uncapped* — the one direction in which
  /// getting it wrong grants access rather than denying it.
  ///
  /// Does nothing when the deployment configured no service credential, which
  /// is the default: such a server binds with no principal installed and caps
  /// nothing.
  /// A *configured* deployment that cannot log in aborts the start: the error is
  /// logged and rethrown, so the socket is never bound. Starting anyway would
  /// mean running uncapped after explicitly asking to be capped.
  Future<void> _installServerPrincipal() async {
    try {
      await TomServerSelfLogin.loginAndInstall(configuration);
    } on TomServerSelfLoginException catch (e) {
      tomLog.error(
        'Server self-login failed — refusing to bind the socket: '
        '${e.defaultUserMessage}',
      );
      rethrow;
    }
  }
}
