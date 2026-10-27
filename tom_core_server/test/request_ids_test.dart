/// Which request id a request runs under — the caller's trace, a trusted
/// proxy's header, or one of its own — and the ids of work that is not a
/// request: a socket message read through `serve`. Job runs are covered by
/// the kernel's request-id suite, where the scheduler lives.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _traceId = '4bf92f3577b34da6a3ce929d0e0e4736';
const _traceparent = '00-$_traceId-00f067aa0ba902b7-01';

/// The connection information shelf's adapter puts on a request.
class _Peer implements HttpConnectionInfo {
  _Peer(String address) : remoteAddress = InternetAddress(address);

  @override
  final InternetAddress remoteAddress;

  @override
  int get remotePort => 50000;

  @override
  int get localPort => 8080;
}

Request _request({Map<String, String> headers = const {}, String? peer}) =>
    Request(
      'GET',
      Uri.parse('http://localhost/a'),
      headers: headers,
      context: {
        if (peer != null) TomClientAddress.connectionInfoKey: _Peer(peer),
      },
    );

/// A channel delivering [incoming] and accepting whatever is sent.
class _Channel implements WebSocketChannel {
  _Channel(List<String> incoming) : stream = Stream.fromIterable(incoming);

  @override
  final Stream<dynamic> stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  late TomRequestIdPolicy previous;
  setUp(() => previous = TomRequestIdPolicy.current);
  tearDown(() => TomRequestIdPolicy.current = previous);

  /// Serves [request] through the request-context middleware, answering what
  /// the handler saw.
  Future<(Response, String, TomTraceContext)> serve(
    Request request, {
    TomRequestIdPolicy? policy,
    FutureOr<void> Function()? inHandler,
  }) async {
    late String id;
    late TomTraceContext trace;
    final response = await const Pipeline()
        .addMiddleware(tomRequestContextMiddleware(policy: policy))
        .addHandler((_) async {
          id = TomRequestId.current!.value;
          trace = TomTraceContext.current!;
          await inHandler?.call();
          return Response.ok('ok');
        })(request);
    return (response, id, trace);
  }

  group('an incoming traceparent', () {
    test('becomes the request id, on both sides of the call', () async {
      final (response, id, trace) = await serve(
        _request(headers: {'traceparent': _traceparent}),
      );
      expect(id, _traceId);
      expect(trace.traceId, _traceId);
      expect(response.headers[tomRequestIdHeader], _traceId);
      expect(response.headers['traceparent'], trace.traceparent);
    });

    test('a malformed one is replaced by an id of its own', () async {
      for (final bad in [
        'not-a-traceparent',
        '00-${'0' * 32}-00f067aa0ba902b7-01',
        '00-4BF92F3577B34DA6A3CE929D0E0E4736-00f067aa0ba902b7-01',
        '$_traceparent\nX-Injected: 1',
      ]) {
        final (response, id, trace) = await serve(
          _request(headers: {'traceparent': bad}),
        );
        expect(id, isNot(_traceId), reason: bad);
        expect(id, trace.traceId, reason: 'the new trace names the request');
        expect(trace.parentSpanId, isNull, reason: bad);
        expect(response.headers[tomRequestIdHeader], id);
      }
    });

    test('its tracestate travels on the calls the handler makes', () async {
      final sent = <http.BaseRequest>[];
      final client = TomResilientClient(
        MockClient((request) async {
          sent.add(request);
          return http.Response('', 200);
        }),
        const TomHttpResiliencePolicy(retry: TomHttpRetryPolicy.none),
      );
      final (_, id, _) = await serve(
        _request(
          headers: {
            'traceparent': _traceparent,
            'tracestate': 'congo=t61rcWkgMzE',
          },
        ),
        inHandler: () => client.get(Uri.parse('https://downstream/x')),
      );
      final carried = TomTraceContext.parse(sent.single.headers['traceparent']);
      expect(carried!.traceId, id, reason: 'the callee takes the same id');
      expect(sent.single.headers['tracestate'], 'congo=t61rcWkgMzE');
    });
  });

  group('a request-id header', () {
    const supplied = 'gateway-7f3a9c21';
    final trusting = TomRequestIdPolicy(trustedProxies: {'10.0.0.2'});

    test('is believed from a trusted proxy', () async {
      final (response, id, _) = await serve(
        _request(
          headers: {tomRequestIdHeader: supplied, 'traceparent': _traceparent},
          peer: '10.0.0.2',
        ),
        policy: trusting,
      );
      expect(id, supplied);
      expect(response.headers[tomRequestIdHeader], supplied);
    });

    test('is ignored from anyone else', () async {
      for (final (policy, peer) in [
        (const TomRequestIdPolicy(), '10.0.0.2'),
        (trusting, '203.0.113.9'),
        (trusting, null),
      ]) {
        final (_, id, trace) = await serve(
          _request(headers: {tomRequestIdHeader: supplied}, peer: peer),
          policy: policy,
        );
        expect(id, isNot(supplied), reason: '$peer');
        expect(id, trace.traceId);
      }
    });

    test('is replaced when malformed, even from a trusted proxy', () async {
      for (final bad in ['short', 'bad id with spaces', 'x' * 129, 'a"b<c>d']) {
        final (_, id, _) = await serve(
          _request(
            headers: {tomRequestIdHeader: bad, 'traceparent': _traceparent},
            peer: '10.0.0.2',
          ),
          policy: trusting,
        );
        expect(id, _traceId, reason: bad);
      }
    });

    test('takes the configured name, and the response echoes it', () async {
      TomRequestIdPolicy.configure({
        'header': 'X-Correlation-Id',
        'trustedProxies': ['10.0.0.2', '::1'],
      });
      expect(TomRequestIdPolicy.current.trustedProxies, {'10.0.0.2', '::1'});
      final (response, id, _) = await serve(
        _request(headers: {'x-correlation-id': supplied}, peer: '::1'),
      );
      expect(id, supplied);
      expect(response.headers['x-correlation-id'], supplied);
      expect(response.headers.keys, isNot(contains('x-request-id')));
    });
  });

  group('the requestIds configuration', () {
    Matcher invalid() => throwsA(
      isA<TomRequestIdException>().having(
        (e) => e.key,
        'key',
        'server.request_ids.config.invalid',
      ),
    );

    test('refuses a value of the wrong shape, applying nothing', () {
      for (final bad in <Object?>[
        'X-Request-Id',
        {'header': 'X Request Id'},
        {'header': 7},
        {'trustedProxies': '10.0.0.2'},
        {
          'trustedProxies': ['10.0.0.300'],
        },
        {'trustedProxy': <String>[]},
      ]) {
        expect(
          () => TomRequestIdPolicy.configure(bad),
          invalid(),
          reason: '$bad',
        );
      }
      expect(TomRequestIdPolicy.current, same(previous));
    });

    test('is read from the server configuration at start', () {
      TomServer.configureRequestIds(
        TomServerConfigResourceProvider.from({
          'requestIds': {
            'trustedProxies': ['10.0.0.9'],
          },
        }),
      );
      expect(TomRequestIdPolicy.current.trustedProxies, {'10.0.0.9'});
      expect(TomRequestIdPolicy.current.header, tomRequestIdHeader);
    });
  });

  group('a socket message read through serve', () {
    test('runs under an id of its own in the connection\'s trace', () async {
      final connection = TomWebSocketConnection()
        ..attachChannel(_Channel(['one', 'two']));
      final seen = <(String, String, TomTraceContext)>[];
      final upgrade = TomTraceContext.parse(_traceparent)!;
      await TomTraceContext.run(
        upgrade,
        () => TomRequestId.run(
          TomRequestId.of(_traceId),
          () => connection.serve((message) {
            seen.add((
              '$message',
              TomRequestId.current!.value,
              TomTraceContext.current!,
            ));
          }),
        ),
      );
      expect(seen.map((s) => s.$1), ['one', 'two']);
      for (final (_, id, trace) in seen) {
        expect(trace.traceId, _traceId);
        expect(trace.parentSpanId, upgrade.spanId);
        expect(id, '$_traceId-${trace.spanId}');
      }
      expect(seen[0].$2, isNot(seen[1].$2));
      expect(connection.messagesReceived, 2);
    });
  });
}
