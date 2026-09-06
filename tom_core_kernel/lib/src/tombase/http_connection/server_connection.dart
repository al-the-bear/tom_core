/// Server connection and HTTP client module.
///
/// This library provides a comprehensive HTTP client infrastructure for making
/// server requests. It includes:
///
/// - [TomServerCall] - Low-level HTTP request handling with abort support
/// - [TomServerChannel] - HTTP client management with connection pooling
/// - [TomServerEndpoint] - Type-safe endpoint execution with serialization
/// - [TomHttpClientFactory] - Pluggable HTTP client creation
///
/// ## Example
///
/// ```dart
/// // Create a channel to a server
/// final channel = TomServerChannel('api.example.com', 443);
///
/// // Create and execute a server call
/// final call = channel.prepareCall(TomServerCallSpecs(
///   'POST',
///   Uri.parse('https://api.example.com/users'),
/// ));
///
/// call.send(TomServerCallLoad(
///   stringBody: '{"name": "John"}',
///   contentType: 'application/json',
/// ));
///
/// final response = await call.readAsString(utf8);
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:tom_basics/tom_basics.dart';

import '../little_things/exception_base.dart';
import '../reflection/reflection.dart';
import '../security/bearer_authentication.dart';
import 'endpoints_apis.dart';
import 'headers.dart';
import 'mimetypes.dart';
import 'remote_context.dart';

// =============================================================================
// EXCEPTIONS
// =============================================================================

/// Exception thrown when a server connection error occurs.
///
/// This includes errors such as:
/// - Invalid request state (e.g., calling send twice)
/// - Reading before sending
/// - Network errors
class TomServerConnectionException extends TomException {
  TomServerConnectionException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.requestUuid,
    super.uuid,
    super.serverCallError,
  });
}

/// Exception thrown when a request is aborted.
///
/// This can occur when [TomServerCall.abort] is called during a pending request.
class TomRequestAbortedException extends TomException {
  TomRequestAbortedException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.requestUuid,
  });
}

/// Exception thrown when a request outlives its [TomServerCallSpecs.timeout].
///
/// Deliberately *not* a subtype of [TomRequestAbortedException], even though a
/// timeout aborts the request on its way out: the two mean opposite things to
/// the caller. An abort is this application's own decision and repeating it
/// would be pointless; a timeout is the server failing to answer in time, which
/// is the textbook case for a retry. A caller that wants to treat them alike can
/// catch [TomException]; one that wants to retry only timeouts could not
/// separate them again if this were a subclass.
class TomRequestTimeoutException extends TomException {
  TomRequestTimeoutException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.requestUuid,
  });
}

// =============================================================================
// SERVER CALL CONFIGURATION
// =============================================================================

/// Specification for an HTTP server call.
///
/// Contains all the configuration needed to make an HTTP request,
/// including method, URL, headers, and connection settings.
///
/// ## Example
///
/// ```dart
/// final specs = TomServerCallSpecs(
///   'POST',
///   Uri.parse('https://api.example.com/users'),
///   headers: {'Content-Type': 'application/json'},
///   followRedirects: true,
/// );
/// ```
class TomServerCallSpecs {
  /// The HTTP method (GET, POST, PUT, DELETE, etc.).
  final String method;

  /// The full URL for the request.
  final Uri url;

  /// Whether to automatically follow HTTP redirects.
  final bool? followRedirects;

  /// HTTP headers to include in the request, empty when the caller named none.
  ///
  /// Non-null and mutable, on the same terms as [TomServerCallError.headers]:
  /// the constructor copies what it is given, so the map is this spec's own and
  /// writing to it always works. It was previously nullable with a `const {}`
  /// default, which meant it was never actually null — every `!= null` test
  /// against it was true — while every write to it threw.
  final Map<String, String> headers;

  /// Maximum number of redirects to follow.
  final int? maxRedirects;

  /// Whether to keep the connection alive for reuse.
  final bool? persistentConnection;

  /// Whether to include Bearer authentication token.
  final bool includeBearerAuthentication;

  /// Encoding for the request body.
  final Encoding? requestEncoding;

  /// Fallback encoding for parsing response body.
  final Encoding? fallbackResponseEncoding;

  /// How long [TomServerCall.read] may wait before giving up, or `null` for no
  /// deadline.
  ///
  /// The budget covers the whole exchange — waiting for the response and
  /// draining its body — rather than restarting per stage, because a server
  /// that sends headers promptly and then stalls mid-body hangs the caller just
  /// as effectively as one that never answers.
  ///
  /// `null` by default: a deadline that suits a JSON call would truncate a long
  /// upload, and this type cannot tell which it is being used for. The caller
  /// knows, so the caller states it.
  final Duration? timeout;

  /// Creates a new server call specification.
  TomServerCallSpecs(
    this.method,
    this.url, {
    this.followRedirects,
    Map<String, String>? headers,
    this.maxRedirects,
    this.persistentConnection,
    this.includeBearerAuthentication = true,
    this.requestEncoding,
    this.fallbackResponseEncoding,
    this.timeout,
  }) : headers = {...?headers};
}

// =============================================================================
// REQUEST PAYLOAD
// =============================================================================

/// Payload data for an HTTP request.
///
/// Supports three types of body content:
/// - [stringBody] - Text content (JSON, XML, etc.)
/// - [byteBody] - Binary content (files, images, etc.)
/// - [bodyFields] - Form fields for URL-encoded requests
///
/// Only one type of body can be set at a time, and a load never changes after
/// it is built: every field is final, so the constructor's check is a promise
/// about the whole object rather than about one moment in its life. A load that
/// exists describes exactly one request body — no consumer has to re-check it.
///
/// ## Example
///
/// ```dart
/// // JSON body
/// final jsonLoad = TomServerCallLoad(
///   stringBody: '{"name": "John"}',
///   contentType: 'application/json',
///   encoding: utf8,
/// );
///
/// // Form data
/// final formLoad = TomServerCallLoad(
///   bodyFields: {'username': 'john', 'password': 'secret'},
/// );
/// ```
class TomServerCallLoad {
  /// The `Content-Type` header value, or `null` to let the body choose one.
  ///
  /// Applied to the request ahead of the body, so `package:http` labels the
  /// bytes with what the caller named. Left `null`, the body picks the default
  /// its own shape implies: `text/plain` for [stringBody] and
  /// `application/x-www-form-urlencoded` for [bodyFields], both carrying the
  /// [encoding]'s charset. [byteBody] implies nothing and stays unlabelled.
  ///
  /// There is deliberately no `contentLength` beside this. A `Content-Type` is
  /// the caller's to state — the bytes do not say what they mean — whereas a
  /// `Content-Length` is a fact about the body that the request measures for
  /// itself, and that this module's non-streaming request refuses to be told.
  /// Streaming uploads, where the length genuinely is unknown until it is
  /// declared, go through [TomHttpFileTransferClient] rather than through a
  /// load.
  final String? contentType;

  /// Character encoding for the body.
  final Encoding? encoding;

  /// String body content (mutually exclusive with [byteBody] and [bodyFields]).
  final String? stringBody;

  /// Binary body content (mutually exclusive with [stringBody] and [bodyFields]).
  final Uint8List? byteBody;

  /// Form field body (mutually exclusive with [stringBody] and [byteBody]).
  ///
  /// A copy of what the constructor was given, so later edits to the caller's
  /// map cannot add a body to a load that was built without one.
  final Map<String, String>? bodyFields;

  /// Creates a new request payload.
  ///
  /// Only one of [stringBody], [byteBody], or [bodyFields] may be set; supplying
  /// more than one throws [TomServerConnectionException]. Because the fields are
  /// final, passing that check is the only way a load can come into existence.
  ///
  /// A [bodyFields] body must also be labelled as a form, but that check is not
  /// here: the label can equally come from [TomServerCallSpecs.headers], which
  /// a load never sees. It is made once, against the request's effective
  /// content type, in [TomServerCall.applyLoadValues].
  TomServerCallLoad({
    this.stringBody,
    this.byteBody,
    Map<String, String>? bodyFields,
    this.contentType,
    this.encoding,
    // Null must survive the copy: an empty map is a body, and turning "no form
    // fields" into "an empty form" would both change the body count and make
    // applyLoadValues write form fields nobody asked for.
  }) : bodyFields = bodyFields == null ? null : {...bodyFields} {
    _bodyTest(stringBody, byteBody, this.bodyFields);
  }

  /// Validates that at most one type of body is provided.
  static void _bodyTest(
    String? string,
    Uint8List? byte,
    Map<String, String>? fields,
  ) {
    if (_bodyCount(string, byte, fields) > 1) {
      throw TomServerConnectionException(
        "server.connect.only_one_type_of_body_possible",
        "You may set only one of stringBody, byteBody or bodyFields",
      );
    }
  }

  /// Counts how many body types are set.
  static int _bodyCount(
    String? string,
    Uint8List? byte,
    Map<String, String>? fields,
  ) {
    return (byte == null ? 0 : 1) +
        (string == null ? 0 : 1) +
        (fields == null ? 0 : 1);
  }
}

// =============================================================================
// SERVER CALL ERROR
// =============================================================================

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
  static const serverError = 2;

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

// =============================================================================
// SERVER CALL
// =============================================================================

/// Handles a single HTTP request/response cycle.
///
/// Provides methods to send a request, read the response, and abort
/// pending requests. Each instance can only be used once - call [reset]
/// to reuse.
///
/// ## Example
///
/// ```dart
/// final client = Client();
/// final specs = TomServerCallSpecs('GET', Uri.parse('https://api.example.com/data'));
/// final call = TomServerCall(client, specs);
///
/// call.send(TomServerCallLoad());
/// final bytes = await call.read();
/// final response = utf8.decode(bytes);
/// ```
class TomServerCall {
  /// The HTTP client used for the request.
  Client client;

  /// The specification for this call.
  TomServerCallSpecs specs;

  /// Creates a new server call.
  TomServerCall(this.client, this.specs) {
    abortableRequest = AbortableRequest(
      specs.method,
      specs.url,
      abortTrigger: abortTrigger.future,
    );
    applySpecValues();
  }

  /// Applies specification values to the request.
  void applySpecValues() {
    if (specs.followRedirects != null) {
      abortableRequest.followRedirects = specs.followRedirects!;
    }
    abortableRequest.headers.addAll(specs.headers);
    // The header is omitted rather than written as "Bearer null" when no one has
    // signed in: an absent credential is a clean 401, a malformed one is the
    // same rejection dressed as a parse failure.
    final token = TomBearerAuthentication.token;
    if (specs.includeBearerAuthentication && token != null) {
      abortableRequest.headers["Authorization"] = "Bearer $token";
    }
    if (specs.maxRedirects != null) {
      abortableRequest.maxRedirects = specs.maxRedirects!;
    }
    if (specs.persistentConnection != null) {
      abortableRequest.persistentConnection = specs.persistentConnection!;
    }
  }

  /// Applies payload values to the request.
  ///
  /// Writes whichever body [load] carries. It carries at most one — the type
  /// checks that when it is built and cannot be changed afterwards — so nothing
  /// is re-checked here. Were two ever to arrive, the fields would be applied in
  /// order and `package:http` would reject the second against the content type
  /// the first had already set, leaving the request half-written.
  ///
  /// The order of the two lines that precede the body is load-bearing, because
  /// `package:http` reads both back when the body is assigned. The encoding is
  /// the charset the body is encoded with, and the content type is the header
  /// that charset is then written into; a type applied *after* the body would
  /// be a type the body never saw, replacing the labelling `package:http` had
  /// just derived and dropping the charset with it.
  void applyLoadValues(TomServerCallLoad load) {
    if (load.bodyFields != null) {
      // Checked before anything is written, so a refused load leaves the
      // request as it was rather than half-labelled.
      _requireFormContentType(
        load.contentType ?? abortableRequest.headers[TomHeader.contentType],
      );
    }
    if (load.encoding != null) abortableRequest.encoding = load.encoding!;
    if (load.contentType != null) {
      abortableRequest.headers[TomHeader.contentType] = load.contentType!;
    }
    if (load.stringBody != null) abortableRequest.body = load.stringBody!;
    if (load.byteBody != null) abortableRequest.bodyBytes = load.byteBody!;
    if (load.bodyFields != null) abortableRequest.bodyFields = load.bodyFields!;
  }

  /// Refuses a form body that [contentType] labels as something else.
  ///
  /// `package:http` encodes form fields as `application/x-www-form-urlencoded`
  /// and rejects any other declared type — with a bare `StateError` that names
  /// neither the call nor the setting that disagreed, raised partway through
  /// writing the request.
  ///
  /// The check belongs here rather than on [TomServerCallLoad] because the
  /// label has two sources: the load's own `contentType` and the spec's
  /// `headers`. Only the request has seen both, so a constructor check would
  /// pass every load whose spec carried the offending header — a guard that
  /// reads as complete and is not.
  ///
  /// A type that merely carries parameters — `...urlencoded; charset=utf-8` —
  /// is the same type, so the media types are compared rather than the strings.
  /// An unparseable value is left alone: `package:http` reports a malformed
  /// content type in its own terms, and guessing here would name the wrong
  /// fault.
  static void _requireFormContentType(String? contentType) {
    if (contentType == null) return;
    final TomMimeType declared;
    try {
      declared = TomMimeType.parse(contentType);
    } on TomMimeTypeException {
      return;
    }
    if (declared.isEqualType(TomMimeType.urlEncoded)) return;
    throw TomServerConnectionException(
      "server.connect.form_body_needs_form_content_type",
      "bodyFields is sent as "
          "${TomMimeType.urlEncoded.primaryType}/"
          "${TomMimeType.urlEncoded.subType}, so it cannot be labelled "
          "'$contentType'. Drop the content type, or encode the body yourself "
          "into stringBody if it needs that one.",
    );
  }

  /// Completer used to trigger request abort.
  Completer<void> abortTrigger = Completer();

  /// The underlying abortable HTTP request.
  late AbortableRequest abortableRequest;

  /// The pending response future.
  Future<StreamedResponse>? response;

  /// The received server response.
  StreamedResponse? serverResponse;

  bool _read = false;

  /// Resets the call for reuse with new body content.
  ///
  /// Clears the response and creates a new abortable request.
  void reset({
    String? stringBody,
    Uint8List? byteBody,
    Map<String, String>? bodyFields,
  }) {
    response = null;
    serverResponse = null;
    _read = false;
    abortTrigger = Completer();
    abortableRequest = AbortableRequest(
      specs.method,
      specs.url,
      abortTrigger: abortTrigger.future,
    );
    applySpecValues();
    // Apply any new body supplied to reset(). TomServerCallLoad validates that
    // at most one body type is set.
    if (stringBody != null || byteBody != null || bodyFields != null) {
      applyLoadValues(
        TomServerCallLoad(
          stringBody: stringBody,
          byteBody: byteBody,
          bodyFields: bodyFields,
        ),
      );
    }
  }

  /// Sends the request with the given payload.
  ///
  /// Can only be called once per call instance (use [reset] to retry).
  /// Returns this instance for method chaining.
  ///
  /// The rejection of an already-sent call happens before anything is applied,
  /// so a refused `send` leaves the request describing what was actually sent. A
  /// rejection that still mutated would leave the object describing a request
  /// that never happened, which a caller inspecting it after the throw, or a
  /// later [reset], would read back as real.
  ///
  /// [load] needs no check here: it is immutable and validated its single body
  /// on construction, so the value that arrives is the value that was built.
  ///
  /// Throws [TomServerConnectionException] if called more than once.
  TomServerCall send(TomServerCallLoad load) {
    if (response != null) {
      throw TomServerConnectionException(
        "server.send.illegal_state_only_send_once",
        "There is already a response. You may only call send() once. Reset the ServerCall first if you want to repeat.",
      );
    }
    applyLoadValues(load);
    final tempResponse = client.send(abortableRequest);
    response = tempResponse;
    return this;
  }

  /// Awaits the in-flight response, throwing [TomServerConnectionException] with
  /// the caller-supplied [key]/[message] when no request has been sent yet.
  ///
  /// Centralises the "you must send before you can read this" guard shared by
  /// every response accessor so each one states only its own error wording.
  Future<StreamedResponse> _requireSentResponse(
    String key,
    String message,
  ) async {
    if (response == null) {
      throw TomServerConnectionException(key, message);
    }
    return await response!;
  }

  /// Guards against reading the response more than once, throwing
  /// [TomServerConnectionException] when the body has already been consumed.
  ///
  /// The key lives here rather than at each reader: there is one "already
  /// consumed" condition, so it has to raise one key. Letting each caller pass
  /// its own turned a single condition into a contract that could drift — and
  /// it did, one reader having spelled the key `read_only_once`.
  void _ensureNotYetRead() {
    if (_read) {
      throw TomServerConnectionException(
        "server.send.illegal_state_only_read_once",
        "You can only read the call once.",
      );
    }
  }

  /// Reads the response body as bytes.
  ///
  /// Can only be called once after [send] — the body is a stream, and draining
  /// it leaves nothing for a second reader. Every reader reaches the body
  /// through here, so all of them refuse a second read under the one key
  /// `server.send.illegal_state_only_read_once`.
  ///
  /// Throws [TomServerConnectionException] if called before send or more than once.
  /// Throws [TomRequestAbortedException] if the request was aborted.
  Future<Uint8List> read() async {
    _ensureNotYetRead();
    if (response == null) {
      throw TomServerConnectionException(
        "server.send.illegal_state_read_must_be_after_send",
        "You need to send before you read.",
      );
    }
    _read = true;
    final transfer = _awaitTransfer();
    final deadline = specs.timeout;
    if (deadline == null) return transfer;
    return transfer.timeout(
      deadline,
      onTimeout: () {
        // Abort as well as stop waiting. Giving up on our side alone would
        // leave the request in flight and its connection tied up; a client that
        // honours the trigger tears it down instead.
        abort();
        throw TomRequestTimeoutException(
          "server.send.request_timeout",
          "The server did not answer within ${deadline.inMilliseconds}ms.",
          parameters: {
            "url": specs.url.toString(),
            "timeoutMs": deadline.inMilliseconds,
          },
        );
      },
    );
  }

  /// Awaits the response and drains its body, translating an abort raised by
  /// either stage into [TomRequestAbortedException].
  ///
  /// Split out of [read] so that a single deadline can be placed around both
  /// stages at once, and so that an abort arriving *before* the headers do is
  /// reported the same way as one arriving mid-body.
  Future<Uint8List> _awaitTransfer() async {
    BytesBuilder builder = BytesBuilder();
    try {
      serverResponse = await response!;
      await serverResponse!.stream.listen((data) {
        builder.add(data);
        // consume response bytes
      }).asFuture<void>();
    } on RequestAbortedException catch (e, s) {
      throw TomRequestAbortedException(
        "server.send.request_aborted",
        "The request was aborted before the response was fully read.",
        rootException: e,
        stack: s,
      );
    }
    Uint8List bytes = builder.takeBytes();
    return bytes;
  }

  /// Reads the response body as a string with the given encoding.
  ///
  /// Can only be called once after [send], and refuses a second read exactly as
  /// [read] does — it *is* [read], with a decode on the end, so it carries no
  /// guard of its own.
  Future<String> readAsString(Encoding ec) async {
    return ec.decoder.convert(await read());
  }

  /// Gets the response headers after sending.
  ///
  /// Throws [TomServerConnectionException] if called before send.
  Future<Map<String, String>> getResponseHeaders() async {
    final sent = await _requireSentResponse(
      "server.send.illegal_state_read_headers_only_after_sending",
      "You can only read out response headers after you send/read ",
    );
    return sent.headers;
  }

  /// Gets the HTTP status code after sending.
  ///
  /// Throws [TomServerConnectionException] if called before send.
  Future<int> getResponseStatusCode() async {
    final sent = await _requireSentResponse(
      "server.send.illegal_state_read_status_code_only_after_sending",
      "You can only read out response status code after you send/read ",
    );
    return sent.statusCode;
  }

  /// Gets the response content length after sending.
  ///
  /// Throws [TomServerConnectionException] if called before send.
  Future<int?> getResponseContentLength() async {
    final sent = await _requireSentResponse(
      "server.send.illegal_state_read_content_length_only_after_sending",
      "You can only read out response content length after you send/read ",
    );
    return sent.contentLength;
  }

  /// Checks if the response is a redirect after sending.
  ///
  /// Throws [TomServerConnectionException] if called before send.
  Future<bool> getResponseIsRedirect() async {
    final sent = await _requireSentResponse(
      "server.send.illegal_state_check_for_redirect_only_after_sending",
      "You can only read out response redirect info after you send/read ",
    );
    return sent.isRedirect;
  }

  /// Gets the reason phrase after sending (e.g., "OK", "Not Found").
  ///
  /// Throws [TomServerConnectionException] if called before send.
  Future<String?> getResponseReasonPhrase() async {
    final sent = await _requireSentResponse(
      "server.send.illegal_state_read_reason_phrase_only_after_sending",
      "You can only read out reason phrase after you send/read ",
    );
    return sent.reasonPhrase;
  }

  /// Gets the original request from the response after sending.
  ///
  /// Throws [TomServerConnectionException] if called before send.
  Future<BaseRequest?> getResponseRequest() async {
    final sent = await _requireSentResponse(
      "server.send.illegal_state_read_response_request_only_after_sending",
      "You can only read out response request re after you send/read ",
    );
    return sent.request;
  }

  /// Aborts the pending request.
  ///
  /// Causes [read] to throw [TomRequestAbortedException].
  void abort() {
    abortTrigger.complete();
  }
}

// =============================================================================
// SERVER CHANNEL
// =============================================================================

/// Manages HTTP client connections to a server.
///
/// Provides client pooling and call preparation for a specific host.
///
/// ## Example
///
/// ```dart
/// final channel = TomServerChannel('api.example.com', 443);
/// final call = channel.prepareCall(specs);
/// // ... use call ...
/// channel.close(); // Close when done
/// ```
class TomServerChannel {
  /// The cached HTTP client.
  Client? client;

  /// The server hostname.
  String host;

  /// The server port.
  int port;

  /// Factory for creating HTTP clients.
  late TomHttpClientFactory clientFactory;

  /// Creates a new server channel.
  ///
  /// - [host]: The server hostname
  /// - [port]: The server port
  /// - [clientFactory]: Optional custom client factory
  TomServerChannel(
    this.host,
    this.port, {
    TomHttpClientFactory? clientFactory,
  }) {
    if (clientFactory != null) {
      this.clientFactory = clientFactory;
    } else {
      this.clientFactory =
          TomHttpClientFactory(); // ultimately fall back to TomDefaultHttpClientFactory
    }
  }

  /// Prepares a new server call with the given specification.
  TomServerCall prepareCall(TomServerCallSpecs spec) {
    return TomServerCall(getClient(), spec);
  }

  /// Gets or creates the HTTP client.
  Client getClient() {
    if (client != null) {
      return client!;
    }
    client = clientFactory.getClient();
    return client!;
  }

  /// Closes the HTTP client connection.
  void close() {
    client?.close();
    client = null;
  }
}

// =============================================================================
// HTTP CLIENT FACTORY
// =============================================================================

/// Factory for creating HTTP clients.
///
/// Supports global configuration and per-instance overrides.
/// Uses [TomDefaultHttpClientFactory] if no custom factory is set.
///
/// ## Example
///
/// ```dart
/// // Set a custom global factory
/// TomHttpClientFactory.setGlobalHttpClientFactory(MyCustomFactory());
///
/// // Or initialize with default
/// TomHttpClientFactory.initialize();
/// ```
class TomHttpClientFactory implements TomHttpClientAbstractFactory {
  static bool _initialized = false;

  static TomHttpClientFactory? _defaultHttpClientFactory =
      TomDefaultHttpClientFactory();

  static TomHttpClientFactory? _globalClientFactory;

  /// Sets the global HTTP client factory.
  ///
  /// This factory will be used by all [TomHttpClientFactory] instances
  /// that don't have a custom instance factory set.
  static void setGlobalHttpClientFactory(TomHttpClientFactory factory) {
    _globalClientFactory = factory;
    _initialized = true;
  }

  /// Initializes the factory system.
  ///
  /// If not already initialized, sets the global factory to the
  /// provided factory or the default.
  ///
  /// Deliberately one-shot: the first caller in a process wins, so a library
  /// initializing on the way past cannot displace the host's choice. The
  /// consequence is that [defaultFactory] is *ignored* once anything has
  /// initialized — call [resetGlobalHttpClientFactory] first if you need a
  /// second initialization to take effect.
  static void initialize([TomHttpClientFactory? defaultFactory]) {
    if (_initialized == false) {
      _defaultHttpClientFactory = defaultFactory ?? _defaultHttpClientFactory;
      _globalClientFactory = _defaultHttpClientFactory;
      _initialized = true;
    }
  }

  /// Returns the factory system to its unconfigured state, so a later
  /// [initialize] or [setGlobalHttpClientFactory] takes effect again.
  ///
  /// The global factory is process-wide state and [initialize] is one-shot, so
  /// without this a test suite would be stuck with whatever the first test
  /// installed, and every test after it would silently share that decision.
  ///
  /// Only the statics are restored. A [TomHttpClientFactory] that has already
  /// resolved keeps the delegate it cached in [instanceClientFactory]; discard
  /// such instances rather than expecting this to reach them.
  static void resetGlobalHttpClientFactory() {
    _initialized = false;
    _globalClientFactory = null;
    _defaultHttpClientFactory = TomDefaultHttpClientFactory();
  }

  /// Creates a new HTTP client factory.
  TomHttpClientFactory();

  /// Instance-specific client factory override.
  TomHttpClientFactory? instanceClientFactory;

  /// Whether this instance is part of a delegation currently in progress.
  ///
  /// Reading it inside [getClient] is what turns a delegation cycle into an
  /// error. Safe as plain instance state because [getClient] is synchronous:
  /// no other call can interleave between setting and clearing it.
  bool _resolvingClient = false;

  /// Resolves a client, delegating to [instanceClientFactory] — or, if none was
  /// set, to the global factory.
  ///
  /// This class creates no clients of its own; it only forwards. A subclass
  /// that overrides this method is what eventually produces one. Delegation
  /// therefore has to end somewhere, and it does not when the chain leads back
  /// to a factory already in it — most easily by registering a plain
  /// `TomHttpClientFactory` as the global, which then forwards to itself.
  ///
  /// Such a chain used to recurse until the stack ran out, reporting a wiring
  /// mistake as a `StackOverflowError` that named neither the factory nor the
  /// registration. It is now refused under
  /// `server.connect.client_factory_delegation_cycle`.
  @override
  Client getClient() {
    if (_resolvingClient) {
      throw TomServerConnectionException(
        "server.connect.client_factory_delegation_cycle",
        "This HTTP client factory delegates back to itself, so it can never "
            "produce a client. The usual cause is registering a plain "
            "TomHttpClientFactory as the global factory: it creates no clients, "
            "so it forwards to the global — which is itself. Register a factory "
            "that overrides getClient(), such as TomDefaultHttpClientFactory.",
      );
    }
    if (instanceClientFactory == null) {
      initialize();
      instanceClientFactory = _globalClientFactory;
    }
    _resolvingClient = true;
    try {
      return instanceClientFactory!.getClient();
    } finally {
      // Cleared even when the delegate throws, so one refused resolution does
      // not leave this factory permanently refusing.
      _resolvingClient = false;
    }
  }
}

/// Abstract base class for HTTP client factories.
class TomHttpClientAbstractFactory {
  const TomHttpClientAbstractFactory._();

  /// Creates and returns an HTTP client.
  Client getClient() {
    throw UnimplementedError();
  }
}

/// Default HTTP client factory using platform-specific clients.
class TomDefaultHttpClientFactory extends TomHttpClientFactory {
  @override
  Client getClient() {
    return TomPlatformUtils.current.httpClient();
  }
}

// =============================================================================
// SERVER ENDPOINT
// =============================================================================

/// Type-safe API endpoint executor with automatic serialization.
///
/// Handles the complete request/response cycle for a typed endpoint:
/// - Serializes request objects to JSON
/// - Sends HTTP requests
/// - Deserializes response objects
/// - Handles error responses
///
/// ## Example
///
/// ```dart
/// final endpoint = TomServerEndpoint.createApiServerEndpoint<
///   CreateUserRequest,
///   UserResponse
/// >(userApi['createUser']);
///
/// final (response, error) = await endpoint.send(CreateUserRequest(name: 'John'));
/// if (error?.hasError ?? false) {
///   print('Error: ${error!.errorKey}');
/// } else {
///   print('Created user: ${response.id}');
/// }
/// ```
class TomServerEndpoint<T extends Object, R extends Object> {
  /// The server channel for HTTP communication.
  TomServerChannel channel;

  /// The call specification.
  TomServerCallSpecs specs;

  /// Maps status codes to response types for error handling.
  Map<int, Type>? statusCodeResponseTypes;

  /// Creates a new server endpoint.
  TomServerEndpoint(this.channel, this.specs, {this.statusCodeResponseTypes});

  /// Sends a request and returns the typed response.
  ///
  /// Returns a tuple of (response, error). Check [TomServerCallError.hasError]
  /// to determine if the request succeeded.
  ///
  /// Every way a call can fail reaches the caller through that tuple, including
  /// the ones where no response arrives at all — a refused connection, an
  /// expired deadline, an aborted request all come back as
  /// [TomServerCallError.noResponseError] with the underlying failure in
  /// `exception`, not as a throw past the tuple. The one exception is a server
  /// error that asks the client to rethrow, which raises
  /// [TomServerConnectionException] by request of the server.
  ///
  /// - [load]: The request object to send
  /// - [responseObject]: Optional pre-created response object to populate
  Future<(R result, TomServerCallError? ts)> send(
    T load, [
    R? responseObject,
  ]) async {
    R response = responseObject ?? tomReflectionInfo.createInstance<R>();
    String json = tomReflectionInfo.convertToJsonString(load);
    TomServerCall serverCall = channel.prepareCall(specs);

    final String result;
    try {
      result = await serverCall
          .send(
            TomServerCallLoad(
              stringBody: json,
              contentType: "application/json",
              encoding: specs.requestEncoding ?? Encoding.getByName("utf-8"),
            ),
          )
          .readAsString(
            specs.fallbackResponseEncoding ?? Encoding.getByName("utf-8")!,
          );
    } catch (ex, stack) {
      // No response arrived at all — the connection was refused, the deadline
      // expired, or the request was aborted. [TomServerCall] reports each of
      // those by throwing, which is its own contract; this endpoint's contract
      // is the `(response, error)` tuple, so it translates instead of letting
      // the exception past. The original stays reachable through [exception]
      // for a caller that needs to know which way the connection failed.
      //
      // The test has to be here, around the call. Placing it *after* the read
      // and asking whether `serverCall.serverResponse` is null cannot work:
      // the read dereferences that same field non-null on its way to producing
      // a body, so the condition can never hold where it is asked and the
      // failure it names surfaces as a raw throw instead of [noResponseError].
      return (
        response,
        TomServerCallError(
          // There is no status and no body to report: leaving the status at its
          // 200 default would describe a success that never happened.
          statusCode: 0,
          internalError: TomServerCallError.noResponseError,
          exception: ex,
          stackTrace: stack,
        ),
      );
    }

    // Reaching here means the body was read, and reading it required a
    // response, so [serverResponse] is non-null from this point on.
    final int statusCode = serverCall.serverResponse!.statusCode;

    TomServerCallError? error;
    try {
      Object? statusCodeResponse;
      // Which branch a response takes turns on whether the server accepted it,
      // not on whether it answered with exactly 200. `statusCodeResponseTypes`
      // describes the *failure* bodies an endpoint can return, so consulting it
      // for a 201 or a 204 sent an ordinary success down the failure branch —
      // which never deserializes into [R], leaving the caller a default-valued
      // response beside an error that reports no error.
      if (!TomServerCallError.isSuccessStatusCode(statusCode) &&
          statusCodeResponseTypes != null) {
        Type? responseType = statusCodeResponseTypes![statusCode];
        if (responseType != null && responseType != R) {
          statusCodeResponse = tomReflectionInfo.createInstance(responseType);
          statusCodeResponse = tomReflectionInfo.convertFromJsonString(
            statusCodeResponse,
            result,
          );
        }
        error = TomServerCallError(
          statusCode: statusCode,
          response: result,
          headers: serverCall.serverResponse!.headers,
          isRedirect: serverCall.serverResponse!.isRedirect,
          reasonPhrase: serverCall.serverResponse!.reasonPhrase,
          statusCodeResponse: statusCodeResponse,
        );
      } else {
        // A no-content status has no body by definition, so there is nothing to
        // deserialize and [response] keeps its defaults. Every other status is
        // parsed as before — a body that was promised and not sent stays a
        // parse failure rather than becoming a silent empty result.
        if (!TomServerCallError.isNoContentStatusCode(statusCode)) {
          response = tomReflectionInfo.convertFromJsonString<R>(
            response,
            result,
          );
        }
        error = TomServerCallError(
          statusCode: statusCode,
          response: result,
          headers: serverCall.serverResponse!.headers,
          isRedirect: serverCall.serverResponse!.isRedirect,
          reasonPhrase: serverCall.serverResponse!.reasonPhrase,
          statusCodeResponse: response,
        );
      }
    } catch (ex, stack) {
      error = TomServerCallError(
        internalError: TomServerCallError.serverError,
        response: result,
        statusCode: statusCode,
        headers: serverCall.serverResponse!.headers,
        isRedirect: serverCall.serverResponse!.isRedirect,
        reasonPhrase: serverCall.serverResponse!.reasonPhrase,
        exception: ex,
        stackTrace: stack,
      );
    }

    if (error.clientRethrow != null && error.clientRethrow!) {
      throw TomServerConnectionException(
        error.errorKey ?? "error.unknown_server_error",
        error.errorKey ?? "error.unknown_server_error",
        uuid: error.uuid,
        requestUuid: error.requestUuid,
        autoLog: error.autoLog ?? true,
        serverCallError: error,
        parameters: {"response": response},
      );
    }

    return (response, error);
  }

  /// Creates a server endpoint from an API endpoint definition.
  ///
  /// Automatically configures the channel, specs, and error handling
  /// based on the [TomApiEndpoint] configuration.
  ///
  /// The address comes from [TomApiEndpoint.resolveUri], so this factory
  /// addresses exactly the route the declaration describes: path captures are
  /// substituted and mapped query parameters appended under the endpoint's
  /// own [TomApiEndpoint.urlParameterMapping]. Joining the templates here
  /// instead would make the declarative half of the contract unreachable
  /// through the very API that exists to build a call from it.
  ///
  /// - [apiEndpoint]: The endpoint definition from a [TomApi]
  /// - [parameters]: Values for the endpoint's URL parameters, keyed by
  ///   **request-DTO field name** — see [TomApiEndpoint.resolveUri] for how the
  ///   two kinds bind. Ignored when [specs] names the address itself.
  /// - [specs]: Optional custom call specs. Supplying these bypasses
  ///   resolution: the caller has then named the address outright.
  /// - [channel]: Optional custom server channel
  /// - [baseUri]: Where to address the call, defaulting to
  ///   [TomClientRemoteContext.baseUri] — the API server. An authentication
  ///   endpoint passes [TomClientRemoteContext.authenticationUri] here
  ///   explicitly; that URI addresses the authentication server and nothing
  ///   else, and the two differ only in a split deployment, so a call that
  ///   named the wrong one would look correct on a single host.
  ///
  /// Throws [TomEndpointException] when [apiEndpoint] does not match the type
  /// arguments, or when one of its path captures has no answering entry in
  /// [parameters].
  static TomServerEndpoint<requestType, responseType> createApiServerEndpoint<
    requestType extends Object,
    responseType extends Object
  >(
    TomApiEndpoint apiEndpoint, {
    Map<String, Object?> parameters = const {},
    TomServerCallSpecs? specs,
    TomServerChannel? channel,
    Uri? baseUri,
  }) {
    if (apiEndpoint is! TomApiEndpoint<requestType, responseType>) {
      throw TomEndpointException(
        "apis.endpoint.invalid_type_parameters",
        "The provided endpoint does not match the required type parameters for response and request types.",
      );
    }
    Uri callUri = baseUri ?? TomClientRemoteContext.current!.baseUri;
    TomServerChannel callChannel =
        channel ??
        TomServerChannel(callUri.host, callUri.hasPort ? callUri.port : 80);
    TomServerCallSpecs callSpecs =
        specs ??
        TomServerCallSpecs(
          apiEndpoint.method.name,
          apiEndpoint.resolveUri(callUri, parameters: parameters),
          followRedirects: apiEndpoint.followRedirects,
          headers: apiEndpoint.requestHeaders,
          maxRedirects: apiEndpoint.maxRedirects,
          persistentConnection: apiEndpoint.persistentConnection,
          includeBearerAuthentication: apiEndpoint.includeBearerAuthentication,
          timeout: apiEndpoint.timeout,
          requestEncoding:
              apiEndpoint.requestEncoding ??
              (apiEndpoint.api.requestEncoding ?? Encoding.getByName("utf-8")),
          fallbackResponseEncoding:
              apiEndpoint.responseEncoding ??
              (apiEndpoint.api.responseEncoding ?? Encoding.getByName("utf-8")),
        );
    return TomServerEndpoint<requestType, responseType>(
      callChannel,
      callSpecs,
      statusCodeResponseTypes:
          apiEndpoint.statusCodeResponseTypes ??
          apiEndpoint.api.statusCodeResponseTypes,
    );
  }
}
