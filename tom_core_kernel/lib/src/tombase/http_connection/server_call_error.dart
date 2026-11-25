/// The error details of a server call: status, body, headers and the
/// framework's own error fields. A value type with no dependency, apart from
/// the connection that produces it, so an exception can carry one without
/// importing the HTTP client.
library;

import 'dart:convert';

/// Represents an error or response status from a server call.
///
/// Contains detailed information about the server response including:
/// - HTTP status code
/// - Response body
/// - Headers
/// - Error details from Tom server errors
///
/// ## Example
///
/// ```dart
/// final (response, error) = await endpoint.send(request);
/// if (error?.hasError ?? false) {
///   print('Error: ${error!.statusCode} - ${error.reasonPhrase}');
/// }
/// ```
class TomServerCallError {
  /// Internal error code for JSON decoding failures.
  static const jsonDecodingError = 1;

  /// Internal error code when no response was received.
  ///
  /// Raised by [TomServerEndpoint.send] when the request never produced a
  /// response — a refused connection, an expired deadline, an aborted request.
  /// Such an error carries no status (`statusCode` is 0) and no body; the
  /// underlying failure is in [exception].
  static const noResponseError = 2;

  /// Internal error code for general server errors.
  ///
  /// Distinct from [noResponseError] because the two are different answers to
  /// the same question: this one means the server replied and the reply was a
  /// failure, that one means there was no reply to read. A caller switching on
  /// [internalError] has to be able to tell "the service said no" from "the
  /// service was not reachable" — they call for different handling and
  /// different retries.
  static const serverError = 3;

  /// The HTTP status code from the server.
  int statusCode;

  /// The raw response body as a string.
  String? response;

  /// The deserialized body, whichever type it was read as.
  ///
  /// On a success this is the same object [TomServerEndpoint.send] returns as
  /// its result. On a failure whose status has an entry in the endpoint's
  /// `statusCodeResponseTypes` it is an instance of *that* type; on a failure
  /// with no entry it stays null.
  Object? statusCodeResponse;

  /// Internal error code (0 = no internal error).
  int internalError;

  /// Response headers from the server, empty when there were none.
  ///
  /// Always a mutable map belonging to this error. The constructor copies what
  /// it is given rather than keeping the caller's map, for two reasons: a
  /// response that carried no headers supplies a `const {}` that would reject
  /// every write, and [TomServerEndpoint.send] hands over the live response
  /// header map, which annotating an error would otherwise rewrite in place.
  Map<String, Object> headers;

  /// Whether the response was a redirect.
  bool isRedirect = false;

  /// The reason phrase from the HTTP response (e.g., "OK", "Not Found").
  String? reasonPhrase;

  /// Whether to automatically log this error.
  bool? autoLog;

  /// Whether the client should rethrow this as an exception.
  bool? clientRethrow;

  /// Error key from Tom server error response.
  String? errorKey;

  /// Unique identifier for this error.
  String? uuid;

  /// The exception that caused this error (if any).
  Object? exception;

  /// Request UUID for tracing.
  String? requestUuid;

  /// Stack trace from the error.
  StackTrace? stackTrace;

  /// Creates a new server call error/response object.
  TomServerCallError({
    this.statusCode = 200,
    this.response,
    this.internalError = 0,
    Map<String, Object>? headers,
    this.isRedirect = false,
    this.reasonPhrase,
    this.exception,
    this.stackTrace,
    this.statusCodeResponse,
  }) : headers = {...?headers} {
    // `this.` is load-bearing: the constructor parameter shadows the field, and
    // the parameter is the nullable one the caller passed, not the copy.
    if (this.headers["x-tom-error"] == "true" && response != null) {
      // Read the body defensively on both counts. It arrives as `dynamic` from
      // `jsonDecode`, so nothing here is checked at compile time — an earlier
      // version called a `get` method no map has and threw NoSuchMethodError
      // out of the constructor on every Tom error response, silently, because
      // `dynamic` hid it from the analyzer.
      //
      // And the header is only a claim. A truncated response or an
      // intermediary's error page still carries it, so a body that will not
      // decode, or decodes to something other than an object, must leave these
      // fields null rather than raise a second failure on top of the HTTP one
      // this object exists to report.
      Object? body;
      try {
        body = jsonDecode(response!);
      } on FormatException {
        body = null;
      }
      if (body is Map) {
        autoLog = body["autoLog"] as bool?;
        clientRethrow = body["clientRethrow"] as bool?;
        errorKey = body["errorKey"] as String?;
        uuid = body["uuid"] as String?;
        requestUuid = body["requestUuid"] as String?;
      }
    }
  }

  /// Whether [statusCode] is in the HTTP 2xx success range.
  ///
  /// The one definition of "the server accepted this" in the module. Both
  /// [hasError] and the response handling in [TomServerEndpoint.send] read it,
  /// because when each spelled the test for itself they disagreed: `send`
  /// treated anything other than exactly 200 as a failure, so a `201 Created`
  /// was routed away from the deserializer while `hasError` went on reporting
  /// no error.
  static bool isSuccessStatusCode(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  /// Whether a response with [statusCode] is defined to carry no body.
  ///
  /// `204 No Content` and `205 Reset Content` have no payload by definition
  /// (RFC 9110 §15.3.5–6), so for those an empty body is the expected shape and
  /// there is nothing to deserialize — as opposed to a status that promised a
  /// body and sent none, which stays a failure to parse.
  static bool isNoContentStatusCode(int statusCode) =>
      statusCode == 204 || statusCode == 205;

  /// Whether this represents an error condition.
  ///
  /// Returns `true` if the status code is outside the 2xx success range
  /// (so 201/202/204 are *not* errors) or there's an internal error.
  bool get hasError => !isSuccessStatusCode(statusCode) || internalError != 0;

  @override
  String toString() =>
      "TomServerCallError HasError $hasError Status: $statusCode Internal: $internalError Response: $response";
}
