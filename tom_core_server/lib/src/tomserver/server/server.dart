import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../authentication/server_self_login.dart';
import '../little_things/request_id.dart';
import '../little_things/server_exception.dart';
import '../configuration/base_server_configuration.dart';
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

/// Extracts the bearer credentials from a request's `Authorization` header.
///
/// Reads the `Authorization` header and, when it carries a `Bearer <jwt>`
/// token, parses it into a [TomClientJwtToken] and derives the [TomPrincipal]
/// via [TomBearerAuthentication.convertTokenPayloadToPrincipal]. Returns a
/// record `(principal, token)`; either element is `null` when the header is
/// absent, not a bearer token, or fails to parse. Parsing/derivation errors are
/// swallowed (the corresponding element stays `null`) so an invalid token is
/// treated as "no credentials" rather than raising — authorization decisions
/// are made downstream.
(TomPrincipal?, TomClientJwtToken?) extractAuthentication(Request req) {
  TomPrincipal? resultA;
  TomClientJwtToken? resultB;
  String? header = req.headers["authorization"];
  if (header != null) {
    if (header.startsWith("Bearer ")) {
      try {
        resultB = TomClientJwtToken(header.substring(7));
      } catch (e) {
        // resultB remains null
      }
      try {
        if (resultB != null) {
          resultA = TomBearerAuthentication.convertTokenPayloadToPrincipal(
            resultB,
          );
        }
      } catch (e) {
        // resultA remains null
      }
    }
  }
  return (resultA, resultB);
}

/// The default authentication [Middleware] of a [TomServer].
///
/// For each request it:
/// 1. extracts bearer credentials with [extractAuthentication];
/// 2. resolves the effective [TomPrincipal] — preferring a principal cached for
///    the client token by [TomAuthorizationCache], falling back to the one
///    derived directly from the token;
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
      var (TomPrincipal? callPrincipal, TomClientJwtToken? clientToken) =
          extractAuthentication(request);
      tomLog.trace(
        "extracted $callPrincipal and $clientToken from incoming request to ${request.requestedUri}",
      );
      var principal =
          (clientToken != null
              ? await TomAuthorizationCache.getPrincipal(clientToken)
              : null) ??
          callPrincipal;
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

  /// The TLS security context, built from the configuration when SSL is on.
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

  /// Initialises the router, composes the pipeline, and binds the socket.
  ///
  /// Builds the TLS [SecurityContext] (unless `noSsl`), resolves the listen
  /// address (`host`, or any-IPv4 when empty or `listenToAnyIP`), optionally
  /// wraps the router in a [Cascade] with the configuration's pre/post handlers,
  /// then serves the assembled pipeline on the configured port (with `shared`
  /// sockets when running multiple isolates). Fire-and-forget: it starts
  /// listening and logs the bound address; it does not return the [HttpServer].
  ///
  /// When the configuration carries a service credential, the deployment first
  /// logs *itself* in and installs its own principal — see [_installServerPrincipal].
  void start() async {
    await _installServerPrincipal();

    SecurityContext? securityContext;

    if (!configuration.noSsl) {
      securityContext = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(configuration.certificateChain))
        ..usePrivateKeyBytes(utf8.encode(configuration.privateKey));
    }

    var ip = (configuration.host).isEmpty
        ? InternetAddress.anyIPv4
        : configuration.host;

    if (configuration.listenToAnyIP == true) {
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
    final handler = Pipeline()
        .addMiddleware(
          contextSetupMiddleware("Setup context", {
            TomRequestLogInfo.contextName: TomRequestLogInfo(),
          }),
        )
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
        .addMiddleware(loggingMiddleware)
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
  }

  /// Logs the deployment in as itself, before the socket is bound.
  ///
  /// The ordering is load-bearing. The server principal caps every user's
  /// grants (`min(user, server)`), so binding the socket first would open a
  /// window in which requests are served *uncapped* — the one direction in which
  /// getting it wrong grants access rather than denying it.
  ///
  /// Does nothing when the deployment configured no service credential, which is
  /// the default and keeps every pre-existing server behaving exactly as before.
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
