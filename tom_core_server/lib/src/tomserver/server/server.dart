import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:uuid/v4.dart';
import '../little_things/server_exception.dart';
import '../configuration/base_server_configuration.dart';
import '../endpoints/endpoint_pipeline.dart';
import '../authorization/authorization_cache.dart';

/// this middleware does nothing or just adds the provided context to the inner handler

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

class TomRequestId {
  late final String uuid;
  TomRequestId() {
      var generator = UuidV4();
      uuid = generator.generate();
  }

  @override
  String toString() => "TomRequestId: $uuid";
}

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
        TomRequestId: TomRequestId()
      });
      zoneValues[TomZoneValues] = zoneValues;
      return runZoned<FutureOr<Response>>(
        zoneValues: zoneValues.zoneValues,
        () => innerHandler(newRequest),
      );
    }).then((response) {
      return response;
    });
  };
};

Middleware tomLoggingMiddleware() => (innerHandler) {
  // FutureOr<Response> Function(Request request)
  return (request) {
    TomRequestLogInfo? logInfo =
        request.context[TomRequestLogInfo.contextName] as TomRequestLogInfo;
    return Future.sync(() => innerHandler(request)).then((response) {
      if ((logInfo.shouldBeLogged == true && logInfo.hasBeenLogged == false)) {
        tomLog.info(
          "HTTP/${request.protocolVersion} [${request.method}] /${request.url} ${request.requestedUri} ${response.statusCode} ${response.encoding}",
        );
        logInfo.hasBeenLogged = true;
      }
      return response;
    });
  };
};

Handler noopHandler(String id, int statusCode) {
  return (Request r) {
    tomLog.trace("noopHandler $id");
    return Response(statusCode);
  };
}

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

class TomRequestLogInfo {
  static const String contextName = "loggingInfo";
  bool hasBeenLogged = false;
  bool shouldBeLogged = true;

  @override
  String toString() =>
      "TomRequestLogInfo should=$shouldBeLogged has=$hasBeenLogged";
}

class TomServer {
  TomBaseServerConfiguration configuration;
  SecurityContext? securityContext;
  Router? router;

  Response? Function(Request, Object, StackTrace) errorHandler =
      (request, error, stacktrace) {
        Map<String, Object?> body = {"errorType": error.runtimeType.toString()};
        if (error is TomException) {
          body = {
            ...body,
            "errorKey": error.key,
            "uuid": error.uuid,
            "autoLog": error.autoLog,
            "requestUuid" : error.requestUuid,
          };
        }
        if (error is TomServerException) {
          body["clientThrow"] = error.clientThrow;
        }
        Map<String, String> headers = {"x-tom-error": "true"};
        return Response.internalServerError(
          body: jsonEncode(body),
          headers: headers,
        );
      };

  Response? Function(Request, Object, StackTrace)? authenticationErrorHandler;

  late Middleware loggingMiddleware;

  TomServer(this.configuration) {
    errorHandler = configuration.errorHandler ?? errorHandler;
    authenticationErrorHandler =
        configuration.authenticationErrorHandler ?? errorHandler;
    loggingMiddleware = configuration.loggingMiddleware;
  }

  void start() async {
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

    // TODO: check for GZIP compression and meaning of this autoCompress flag
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
}
