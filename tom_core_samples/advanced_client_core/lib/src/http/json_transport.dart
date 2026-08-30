/// The one HTTP seam the whole client core talks to the servers through.
///
/// Reducing a request/response to "a method, a URI, some headers and a JSON
/// string" keeps every client (`AuthClient`, `AuthorizedHttp`, `AppApiClient`
/// and `AdminApiClient`) unit-testable against a fake transport — no sockets in
/// tests — while the live [IoJsonTransport] backs them at runtime.
library;

import 'dart:convert';
import 'dart:io';

/// One HTTP response reduced to what the clients need: the [statusCode] and the
/// raw UTF-8 [body]. A test can hand back a canned instance without a socket.
class HttpJsonResponse {
  /// The HTTP status code.
  final int statusCode;

  /// The response body, decoded as UTF-8 text (empty for a bodyless response).
  final String body;

  /// Creates a response from its [statusCode] and [body].
  const HttpJsonResponse(this.statusCode, this.body);

  /// Whether [statusCode] is a 2xx success.
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// The body parsed as a JSON object, or an empty map when blank / not an
  /// object. Throws [FormatException] on malformed JSON.
  Map<String, Object?> get jsonObject {
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    return decoded is Map ? decoded.cast<String, Object?>() : const {};
  }

  /// The body parsed as a JSON array, or empty when blank / not an array.
  /// Throws [FormatException] on malformed JSON.
  List<Object?> get jsonArray {
    if (body.isEmpty) return const [];
    final decoded = jsonDecode(body);
    return decoded is List ? decoded : const [];
  }
}

/// A single JSON-over-HTTP round trip, decoupled from `dart:io`.
abstract class JsonTransport {
  /// Sends [method] to [uri] with [headers] and an optional JSON [body], and
  /// completes with the response. Implementations set the JSON content type
  /// when a [body] is present.
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers,
    String? body,
  });
}

/// The live `dart:io` transport backing the clients at runtime.
///
/// Wraps a single [HttpClient]; remember to [close] it when the owning client
/// is disposed.
class IoJsonTransport implements JsonTransport {
  final HttpClient _client;

  /// Builds the transport over an optional pre-configured [client] (the default
  /// is a fresh [HttpClient]).
  IoJsonTransport({HttpClient? client}) : _client = client ?? HttpClient();

  @override
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final request = await _client.openUrl(method, uri);
    headers.forEach((name, value) => request.headers.set(name, value));
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return HttpJsonResponse(response.statusCode, text);
  }

  /// Closes the underlying [HttpClient] and its idle connections.
  void close() => _client.close(force: true);
}
