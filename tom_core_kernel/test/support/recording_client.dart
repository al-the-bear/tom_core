/// A stubbed HTTP client for exercising a documented wire exchange.
///
/// A module that declares an endpoint and never sends over one has no artifact
/// a wrong transport could contradict: an invented API is detectable only by
/// reading, an executed one by running. This is what lets a suite run the
/// exchange its documentation shows, over a client that answers from the test
/// rather than from a server.
///
/// It lives here because it is now wanted by more than one suite. The settings
/// suite built it, the preferences, security and logging suites need the same
/// thing, and a fourth hand-written copy would be four places for a fix to
/// fail to reach. `http_connection_test.dart` keeps its own `_MockClient`:
/// that suite tests the transport itself and needs to provoke failures this
/// one deliberately cannot express.
library;

import 'dart:convert';

import 'package:http/http.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A [BaseClient] that answers from [handler] and remembers the last request,
/// so a test can assert what actually went onto the wire.
class RecordingClient extends BaseClient {
  RecordingClient(this.handler);

  /// Answers a request. Build the response with [jsonResponse] unless the test
  /// is about something the helper cannot express.
  final Future<StreamedResponse> Function(BaseRequest request) handler;

  /// The last request [send] was given, or `null` before the first call.
  ///
  /// The single most useful assertion a wire test makes is *what went out* —
  /// a round trip that only checks the decoded answer passes just as well when
  /// the request went to the wrong place.
  BaseRequest? lastRequest;

  /// Every request, in order, for an exchange that sends more than one.
  final List<BaseRequest> requests = [];

  /// Called after each request is recorded.
  ///
  /// For an exchange the caller does not await — a fire-and-forget log
  /// delivery, say — this is the only point at which a test can know the send
  /// happened without polling for it.
  void Function()? onSend;

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    lastRequest = request;
    requests.add(request);
    final answer = handler(request);
    onSend?.call();
    return answer;
  }
}

/// Hands a `TomServerChannel` the one [RecordingClient] under test.
class RecordingClientFactory implements TomHttpClientAbstractFactory {
  RecordingClientFactory(this._client);

  final RecordingClient _client;

  @override
  RecordingClient getClient() => _client;
}

/// A [StreamedResponse] carrying [body] with [statusCode].
///
/// Free-standing rather than a method on the client, because a handler that
/// answers differently per request needs it per branch.
StreamedResponse jsonResponse(
  BaseRequest request,
  String body, {
  int statusCode = 200,
}) {
  final bytes = utf8.encode(body);
  return StreamedResponse(
    Stream<List<int>>.value(bytes),
    statusCode,
    contentLength: bytes.length,
    request: request,
  );
}
