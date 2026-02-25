import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';



abstract class TomErrorHandler {

  const TomErrorHandler();

  Response handleInvocationError(Object error, Object stacktrace, Request r) {
    return handleErrorDefault(error, stacktrace, r, null);
  }

  Response handleConversionError(
    Object error,
    Object stacktrace,
    Request r,
    Object? result,
  ) {
    return handleErrorDefault(error, stacktrace, r, result);
  }

  Response handleUnknowResultTypeError(
    Object error,
    Object stacktrace,
    Request r,
    Object? result,
  ) {
    return handleErrorDefault(error, stacktrace, r, result);
  }

  Response handleErrorDefault(
    Object error,
    Object stacktrace,
    Request r,
    Object? result,
  );
}

class TomDefaultErrorHandler extends TomErrorHandler {

  const TomDefaultErrorHandler();

  @override
  Response handleErrorDefault(
    Object error,
    Object stacktrace,
    Request r,
    Object? result,
  ) {
    Map<String, Object> headers = {
      TomHeader.contentType: TomMimeType.plainText.toHeaderValue(),
    };

    return Response.internalServerError(
      body: "Internal server error",
      headers: headers,
      encoding: Encoding.getByName("UTF-8"),
    );
  }
}

const _tomDefaultErrorHandler = TomDefaultErrorHandler();

class TomService {
  const TomService();
}

const tomService = TomService();
class TomApiImplementation extends TomService {

  final String apiId;
  final TomErrorHandler? errorHandler;
  final bool logRequestsDefault;

  const TomApiImplementation({
    required this.apiId,
    this.errorHandler,
    this.logRequestsDefault = true,
  });

}
abstract class TomEndpointBase<requestType extends Object, resultType extends Object> {
    TomEndpoint<requestType, resultType> convertToTomEndpoint();

}
class TomApiEndpointImplementation<requestType extends Object, resultType extends Object> implements TomEndpointBase<requestType, resultType> {

  final String apiId;
  final String endpointId;
  final TomErrorHandler? errorHandler;
  final bool? logRequests;
  final String? corsAllowedOrigins;
  final String? corsAllowedMethods;
  final String? corsAllowedHeaders;

  const TomApiEndpointImplementation({
    required this.apiId,
    required this.endpointId,
    this.errorHandler,
    this.logRequests,
    this.corsAllowedOrigins,
    this.corsAllowedMethods,
    this.corsAllowedHeaders,
  });

  @override
  TomEndpoint<requestType, resultType> convertToTomEndpoint() {
    TomApiEndpoint<requestType, resultType> endpoint =
        tomRemoteApis[apiId][endpointId] as TomApiEndpoint<requestType, resultType>;
    return TomEndpoint<requestType, resultType>(
      methods: endpoint.methods ?? [endpoint.method],
      formFields: endpoint.formFields,
      uri: (endpoint.api.uri ?? "") + (endpoint.uri ?? ""),
      consumes: endpoint.consumes,
      produces: endpoint.produces,
      contentDisposition: endpoint.contentDisposition,
      errorHandler: errorHandler ?? _tomDefaultErrorHandler,
      logRequests: logRequests,
      headers: endpoint.requestHeaders,
      corsAllowedOrigins: corsAllowedOrigins,
      corsAllowedMethods: corsAllowedMethods,
      corsAllowedHeaders: corsAllowedHeaders,
    );
  }

}

// TODO: add escape directives
// TODO: double check that all options have been implemented
// TODO: add redirect option
// TODO: implement use of form fields
// TODO: implement use of file upload fields
class TomEndpoint<requestType extends Object, resultType extends Object> implements TomEndpointBase<requestType, resultType> {
  // Samples:
  // consumes = "application/x-www-form-urlencoded",
  // produces = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;charset=utf-8"

  final List<TomHttpMethod> methods;
  final List<String> formFields;
  final String uri;
  final TomMimeType consumes;
  final TomMimeType produces;
  final String? contentDisposition;
  final TomErrorHandler? errorHandler;
  final bool? logRequests;
  final Map<String, String> headers;
  final String? corsAllowedOrigins;
  final String? corsAllowedMethods;
  final String? corsAllowedHeaders;

  const TomEndpoint({
    this.methods = const [TomHttpMethod.get],
    this.formFields = const [],
    this.uri = "",
    this.consumes = TomMimeType.json,
    this.produces = TomMimeType.json,
    this.contentDisposition,
    this.errorHandler = _tomDefaultErrorHandler,
    this.logRequests,
    this.headers = const {},
    this.corsAllowedOrigins,
    this.corsAllowedMethods,
    this.corsAllowedHeaders,
  });

  @override
  TomEndpoint<requestType, resultType> convertToTomEndpoint() {
    return this;
  }
  
  @override
  String toString() =>
      "$uri $methods $consumes $produces $contentDisposition $errorHandler $logRequests $formFields";
}

class TomComponentReference {
  final String? componentName;
  final Type? referencedType;

  const TomComponentReference({this.componentName, this.referencedType});
}

class TomTransactional {
  final bool isTransactional;
  final bool isReadOnly;

  const TomTransactional({
    this.isReadOnly = false,
    this.isTransactional = true,
  });
}
