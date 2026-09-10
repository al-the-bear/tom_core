/// Carries a *declared* endpoint all the way to a real call: the declaration
/// resolves its own URL, and [TomServerEndpoint] serializes the request DTO,
/// sends it, and deserializes the answer.
///
/// `04_api_endpoint_definition_example.dart` stops at the declaration. This is
/// the other half — the reason the declaration exists at all:
///
/// * [TomApiEndpoint.resolveUri] builds the address from the same template the
///   server binds *from*, substituting path captures and appending mapped query
///   parameters, so no client ever concatenates a URL by hand;
/// * [TomServerEndpoint.createApiServerEndpoint] turns that declaration into a
///   callable endpoint;
/// * [TomServerEndpoint.send] returns a `(result, error)` record rather than
///   throwing, because a 4xx is frequently an expected outcome.
///
/// The server is a real `HttpServer` on the loopback interface, bound to port
/// 0 so the operating system picks a free one. Nothing here reaches the
/// network, and the transport is the genuine one rather than a mock — which is
/// what makes the resolved URL observable: the assertions read the path the
/// server actually received.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/http_connection/07_endpoint_call_example.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// The DTOs the endpoint is declared with
// ============================================================================

/// What a caller sends when creating a track.
@tomReflector
class TrackRequest {
  /// The track's title.
  String title = '';

  /// Creates an empty request.
  TrackRequest();
}

/// What the server answers with on success.
@tomReflector
class TrackResponse {
  /// The identifier the server assigned.
  String id = '';

  /// The stored title, echoed back.
  String title = '';

  /// Creates an empty response.
  TrackResponse();
}

/// What a `409 Conflict` body carries instead.
///
/// Declared through `statusCodeResponseTypes`, so the failing status arrives
/// typed rather than as raw text the caller has to parse itself.
@tomReflector
class TrackConflict {
  /// Why the server refused.
  String reason = '';

  /// Creates an empty conflict.
  TrackConflict();
}

// ============================================================================
// The declaration
// ============================================================================

/// One API, one endpoint, addressed as `/api/v1/tracks/{id}`.
///
/// `urlParameterMapping` binds each URL name to a *request-DTO field name*:
/// `{id}` takes `parameters['trackId']`, and `lang` is appended as a query
/// parameter when `parameters['language']` has a value. The asymmetry is
/// deliberate — a path capture falls back to its own name, a query parameter
/// must be mapped explicitly — so a DTO field is never leaked into a URL by
/// accident.
TomApi buildTrackApi() => TomApi(
  id: 'trackApi',
  uri: '/api/v1/tracks',
  endpoints: [
    TomApiEndpoint<TrackRequest, TrackResponse>(
      id: 'store',
      uri: '/{id}',
      method: TomHttpMethod.post,
      urlParameterMapping: const {'id': 'trackId', 'lang': 'language'},
    ),
  ],
);

// ============================================================================
// The server
// ============================================================================

/// A loopback server that answers the one declared endpoint.
///
/// It records what it was asked for, which is how the example shows that the
/// *resolved* address is what reached the wire.
class TrackServer {
  TrackServer._(this._server);

  /// Binds to a free loopback port and starts serving.
  static Future<TrackServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = TrackServer._(server);
    instance._serve();
    return instance;
  }

  final HttpServer _server;

  /// Every request line the server saw, as `METHOD path?query`.
  final List<String> seen = [];

  /// The request bodies the server read, in order.
  final List<String> bodies = [];

  /// When set, the next answer is a `409` carrying a [TrackConflict] body.
  bool refuseNext = false;

  /// Where a client should address this server.
  Uri get baseUri => Uri.parse('http://127.0.0.1:${_server.port}');

  void _serve() async {
    await for (final request in _server) {
      final query = request.uri.query;
      seen.add(
        '${request.method} ${request.uri.path}${query.isEmpty ? '' : '?$query'}',
      );
      bodies.add(await utf8.decoder.bind(request).join());

      final response = request.response;
      response.headers.contentType = ContentType.json;
      if (refuseNext) {
        refuseNext = false;
        response.statusCode = HttpStatus.conflict;
        response.write(jsonEncode({'reason': 'a track with that id exists'}));
      } else {
        final decoded = jsonDecode(bodies.last) as Map<String, dynamic>;
        response.statusCode = HttpStatus.created;
        response.write(
          jsonEncode({
            'id': request.uri.pathSegments.last,
            'title': decoded['title'],
          }),
        );
      }
      await response.close();
    }
  }

  /// Stops serving.
  Future<void> stop() => _server.close(force: true);
}

// ============================================================================
// Example class
// ============================================================================

class EndpointCallExample {
  // Captured results, asserted at the end of [run].
  static late Uri resolved;
  static late Uri resolvedWithoutQuery;
  static late TrackResponse created;
  static late TomServerCallError? createdError;
  static late TomServerCallError refusedError;
  static late String requestedPath;
  static late String sentBody;

  // -------------------------------------------------------------------------
  // Example 1: the declaration resolves its own address
  // -------------------------------------------------------------------------
  static void example1ResolveUri() {
    print('1. resolveUri builds the address from the declaration:');

    final endpoint = buildTrackApi()['store'];

    resolved = endpoint.resolveUri(
      Uri.parse('https://api.example.com'),
      parameters: {'trackId': 'a-42', 'language': 'de'},
    );
    print('   - with a language: $resolved');

    // A query parameter is optional: omit its value and it is simply not
    // appended. A *path capture* with no value is an error instead, because
    // the URL would address a different route.
    resolvedWithoutQuery = endpoint.resolveUri(
      Uri.parse('https://api.example.com'),
      parameters: {'trackId': 'a-42'},
    );
    print('   - without one:     $resolvedWithoutQuery');
  }

  // -------------------------------------------------------------------------
  // Example 2: the declaration performs the call
  // -------------------------------------------------------------------------
  static Future<void> example2SendThroughTheDeclaration(
    TrackServer server,
  ) async {
    print('\n2. The same declaration, called:');

    final endpoint =
        TomServerEndpoint.createApiServerEndpoint<TrackRequest, TrackResponse>(
          buildTrackApi()['store'],
          baseUri: server.baseUri,
          parameters: {'trackId': 'a-42', 'language': 'de'},
        );

    print('   - channel : ${endpoint.channel.host}:${endpoint.channel.port}');
    print('   - address : ${endpoint.specs.url}');

    final (response, error) = await endpoint.send(
      TrackRequest()..title = 'Prelude',
    );
    createdError = error;
    created = response;
    requestedPath = server.seen.last;
    sentBody = server.bodies.last;

    print('   - server saw: $requestedPath');
    print('   - request body: $sentBody');
    print('   - response: id=${response.id} title="${response.title}"');
  }

  // -------------------------------------------------------------------------
  // Example 3: a failure arrives typed, not thrown
  // -------------------------------------------------------------------------
  static Future<void> example3TypedFailure(TrackServer server) async {
    print('\n3. A refusal comes back through the record:');

    server.refuseNext = true;
    final endpoint =
        TomServerEndpoint.createApiServerEndpoint<TrackRequest, TrackResponse>(
          buildTrackApi()['store'],
          baseUri: server.baseUri,
          parameters: {'trackId': 'a-42'},
        );
    // Failing statuses only: consulted when the answer is not a 2xx, so
    // declaring entries never diverts a success away from TrackResponse.
    endpoint.statusCodeResponseTypes = const {409: TrackConflict};

    final (_, error) = await endpoint.send(TrackRequest()..title = 'Prelude');
    refusedError = error!;

    print('   - hasError  : ${error.hasError}');
    print('   - status    : ${error.statusCode}');
    print(
      '   - typed body: '
      '"${(error.statusCodeResponse! as TrackConflict).reason}"',
    );
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static Future<void> run() async {
    print('=== 07: Endpoint Call Example ===\n');

    final server = await TrackServer.start();
    try {
      example1ResolveUri();
      await example2SendThroughTheDeclaration(server);
      await example3TypedFailure(server);
    } finally {
      await server.stop();
    }

    // Assertions
    assert(
      resolved.toString() ==
          'https://api.example.com/api/v1/tracks/a-42?lang=de',
      'The capture should be substituted and the mapped query appended',
    );
    assert(
      resolvedWithoutQuery.toString() ==
          'https://api.example.com/api/v1/tracks/a-42',
      'A query parameter with no value should be omitted, not left empty',
    );
    assert(
      requestedPath == 'POST /api/v1/tracks/a-42?lang=de',
      'The resolved address is what reaches the wire',
    );
    assert(
      sentBody == '{"title":"Prelude"}',
      'The request DTO should travel as JSON',
    );
    assert(
      !(createdError?.hasError ?? false),
      'A 201 is a success, not a failure',
    );
    assert(created.id == 'a-42', 'The response DTO should be deserialized');
    assert(created.title == 'Prelude', '…including every member of it');
    assert(refusedError.hasError, 'A 409 is a failure');
    assert(refusedError.statusCode == 409, 'The status should be reported');
    assert(
      refusedError.statusCodeResponse is TrackConflict,
      'A declared failure type should arrive as that type',
    );
    assert(
      (refusedError.statusCodeResponse! as TrackConflict).reason ==
          'a track with that id exists',
      'and carrying what the server wrote',
    );

    print('\n=== Endpoint Call Example Complete ===\n');
  }
}

/// Runs this example.
Future<void> run() => EndpointCallExample.run();

Future<void> main() async {
  bootstrapSamples();
  await run();
}
