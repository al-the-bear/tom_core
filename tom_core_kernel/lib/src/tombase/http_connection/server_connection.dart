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
import 'package:tom_core_kernel/tom_core_kernel.dart';

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

  /// HTTP headers to include in the request.
  final Map<String, String>? headers;

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
    int? contentLength,
    this.followRedirects,
    this.headers = const {},
    this.maxRedirects,
    this.persistentConnection,
    this.includeBearerAuthentication = true,
    this.requestEncoding,
    this.fallbackResponseEncoding,
    this.timeout,
  });
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
/// Only one type of body can be set at a time.
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
  /// The Content-Type header value.
  final String? contentType;

  /// Character encoding for the body.
  final Encoding? encoding;

  /// Content-Length header value.
  int? contentLength;

  /// String body content (mutually exclusive with [byteBody] and [bodyFields]).
  String? stringBody;

  /// Binary body content (mutually exclusive with [stringBody] and [bodyFields]).
  Uint8List? byteBody;

  /// Form field body (mutually exclusive with [stringBody] and [byteBody]).
  Map<String, String>? bodyFields;

  /// Creates a new request payload.
  ///
  /// Only one of [stringBody], [byteBody], or [bodyFields] may be set.
  /// Setting multiple will throw [TomServerConnectionException].
  TomServerCallLoad({
    this.stringBody,
    this.byteBody,
    this.bodyFields,
    this.contentType,
    this.encoding,
    this.contentLength,
  }) {
    TomServerCall._bodyTest(stringBody, byteBody, bodyFields);
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
  static const noResponseError = 2;

  /// Internal error code for general server errors.
  static const serverError = 2;

  /// The HTTP status code from the server.
  int statusCode;

  /// The raw response body as a string.
  String? response;

  /// Deserialized response object for non-200 status codes.
  Object? statusCodeResponse;

  /// Internal error code (0 = no internal error).
  int internalError;

  /// Response headers from the server.
  Map<String, Object> headers = {};

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
    this.headers = const {},
    this.isRedirect = false,
    this.reasonPhrase,
    this.exception,
    this.stackTrace,
    this.statusCodeResponse,
  }) {
    if (headers["x-tom-error"] == "true" && response != null) {
      var body = jsonDecode(response!);
      autoLog = body.get("autoLog");
      clientRethrow = body.get("clientRethrow");
      errorKey = body.get("errorKey");
      uuid = body.get("uuid");
      requestUuid = body.get("requestUuid");
    }
  }

  /// Whether this represents an error condition.
  ///
  /// Returns `true` if the status code is outside the 2xx success range
  /// (so 201/202/204 are *not* errors) or there's an internal error.
  bool get hasError =>
      statusCode < 200 || statusCode >= 300 || internalError != 0;

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
    if (specs.headers != null) {
      for (var name in specs.headers!.keys) {
        abortableRequest.headers[name] = specs.headers![name]!;
      }
    }
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
  void applyLoadValues(TomServerCallLoad load) {
    if (load.encoding != null) abortableRequest.encoding = load.encoding!;
    if (load.contentLength != null) {
      abortableRequest.contentLength = load.contentLength!;
    }
    if (load.stringBody != null) abortableRequest.body = load.stringBody!;
    if (load.byteBody != null) abortableRequest.bodyBytes = load.byteBody!;
    if (load.bodyFields != null) abortableRequest.bodyFields = load.bodyFields!;
  }

  /// Validates that only one type of body is provided.
  static bool _bodyTest(
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
    return true;
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
  /// Both rejections — an already-sent call and a [load] carrying more than one
  /// body — happen before anything is applied, so a refused `send` leaves the
  /// request describing what was actually sent. A rejection that still mutated
  /// would leave the object describing a request that never happened, which a
  /// caller inspecting it after the throw, or a later [reset], would read back
  /// as real.
  ///
  /// Throws [TomServerConnectionException] if called more than once, or if
  /// [load] sets more than one body.
  TomServerCall send(TomServerCallLoad load) {
    if (response != null) {
      throw TomServerConnectionException(
        "server.send.illegal_state_only_send_once",
        "There is already a response. You may only call send() once. Reset the ServerCall first if you want to repeat.",
      );
    }
    // Re-checked here even though the load validates itself on construction:
    // its body fields are mutable, so the value that arrives need not be the
    // value that was built.
    _bodyTest(load.stringBody, load.byteBody, load.bodyFields);
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
  static void initialize([TomHttpClientFactory? defaultFactory]) {
    if (_initialized == false) {
      _defaultHttpClientFactory = defaultFactory ?? _defaultHttpClientFactory;
      _globalClientFactory = _defaultHttpClientFactory;
      _initialized = true;
    }
  }

  /// Creates a new HTTP client factory.
  TomHttpClientFactory();

  /// Instance-specific client factory override.
  TomHttpClientFactory? instanceClientFactory;

  @override
  Client getClient() {
    if (instanceClientFactory == null) {
      initialize();
      instanceClientFactory = _globalClientFactory;
    }
    return instanceClientFactory!.getClient();
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
  /// - [load]: The request object to send
  /// - [responseObject]: Optional pre-created response object to populate
  Future<(R result, TomServerCallError? ts)> send(
    T load, [
    R? responseObject,
  ]) async {
    R response = responseObject ?? tomReflectionInfo.createInstance<R>();
    String json = tomReflectionInfo.convertToJsonString(load);
    TomServerCall serverCall = channel.prepareCall(specs);

    String result = await serverCall
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

    if (serverCall.serverResponse == null) {
      return (
        response,
        TomServerCallError(internalError: TomServerCallError.noResponseError),
      );
    }

    TomServerCallError? error;
    try {
      Object? statusCodeResponse;
      if (serverCall.serverResponse!.statusCode != 200 &&
          statusCodeResponseTypes != null) {
        Type? responseType =
            statusCodeResponseTypes![serverCall.serverResponse!.statusCode];
        if (responseType != null && responseType != R) {
          statusCodeResponse = tomReflectionInfo.createInstance(responseType);
          statusCodeResponse = tomReflectionInfo.convertFromJsonString(
            statusCodeResponse,
            result,
          );
        }
        error = TomServerCallError(
          statusCode: serverCall.serverResponse!.statusCode,
          response: result,
          headers: serverCall.serverResponse!.headers,
          isRedirect: serverCall.serverResponse!.isRedirect,
          reasonPhrase: serverCall.serverResponse!.reasonPhrase,
          statusCodeResponse: statusCodeResponse,
        );
      } else {
        response = tomReflectionInfo.convertFromJsonString<R>(response, result);
        error = TomServerCallError(
          statusCode: serverCall.serverResponse!.statusCode,
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
        statusCode: serverCall.serverResponse!.statusCode,
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
  /// - [apiEndpoint]: The endpoint definition from a [TomApi]
  /// - [specs]: Optional custom call specs
  /// - [channel]: Optional custom server channel
  /// - [baseUri]: Optional base URI override
  static TomServerEndpoint<requestType, responseType> createApiServerEndpoint<
    requestType extends Object,
    responseType extends Object
  >(
    TomApiEndpoint apiEndpoint, {
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
    Uri callUri = baseUri ?? TomClientRemoteContext.current!.authenticationUri;
    TomServerChannel callChannel =
        channel ??
        TomServerChannel(callUri.host, callUri.hasPort ? callUri.port : 80);
    TomServerCallSpecs callSpecs =
        specs ??
        TomServerCallSpecs(
          apiEndpoint.method.name,
          Uri(
            scheme: callUri.scheme,
            path:
                "${callUri.path}${removeLeadingSlash(apiEndpoint.api.uri ?? '')}${apiEndpoint.uri ?? ''}",
            host: callUri.host,
            port: callUri.hasPort
                ? callUri.port
                : callUri.scheme == "https"
                ? 443
                : 80,
          ),
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

  /// Removes a leading slash from a string if present.
  static String removeLeadingSlash(String s) {
    if (s.startsWith("/")) {
      return s.substring(1);
    }
    return s;
  }
}
