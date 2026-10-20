/// Idempotency keys: a `POST` the client retries with the same
/// `Idempotency-Key` runs once, and the retry gets the first response.
///
/// An endpoint opts in with `@TomIdempotent()`, and the pipeline then sends
/// each of its requests through `TomIdempotency.handle`. This program calls
/// `handle` directly, with a handler standing in for the endpoint, so it needs
/// neither a server nor reflection. It runs over the default store,
/// `TomMemoryIdempotencyStore`, which keeps the same contract as the
/// `TomSqlIdempotencyStore` a cluster uses — see "Idempotency Keys" in
/// `doc/endpoints.md`.
///
/// A key belongs to an authenticated principal, so every request runs in a
/// zone carrying one, the way the authentication middleware runs a request.
///
/// Run with `dart run example/endpoints/idempotency_example.dart`. Every step
/// checks its own result and the run fails when one does not hold.
/// `test/idempotency_test.dart` covers the same behaviour.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// The orders the stand-in endpoint placed.
final orders = <String>[];

/// The stand-in for `POST /orders`: places an order and answers `201`.
Future<Response> placeOrder(Request request) async {
  final item = (jsonDecode(await request.readAsString()) as Map)['item'];
  orders.add('$item');
  return Response(
    201,
    body: jsonEncode({'order': orders.length, 'item': item}),
    headers: {'content-type': 'application/json'},
  );
}

/// A principal the authentication middleware would have put in the zone.
TomPrincipal user(String id) => TomPrincipal(
  user: TomUser(id: id, username: id),
  authenticated: true,
);

/// Sends `POST /orders` with [body] as [principal], with the key [key].
Future<Response> send(String body, {String? key, TomPrincipal? principal}) =>
    runZoned(
      () => TomIdempotency.handle(
        Request(
          'POST',
          Uri.parse('http://localhost/orders'),
          body: body,
          headers: {TomIdempotency.header: ?key},
        ),
        'POST /orders',
        const TomIdempotent(),
        placeOrder,
      ),
      zoneValues: {TomPrincipal: principal ?? user('alice')},
    );

Future<void> main() async {
  var now = DateTime.utc(2026, 10, 20, 9);
  TomIdempotency.reset();
  TomIdempotency.clock = () => now;

  // 1. The first request with a key runs, and its response is stored.
  final first = await send('{"item":"book"}', key: 'order-7f3a');
  final firstBody = await first.readAsString();
  print('1. first request: ${first.statusCode} $firstBody');
  check(first.statusCode == 201, 'the first request runs');
  check(orders.length == 1, 'one order is placed');

  // 2. The client lost the answer and retries with the same key: the stored
  //    response comes back, marked as a replay, and nothing runs again.
  final retry = await send('{"item":"book"}', key: 'order-7f3a');
  final retryBody = await retry.readAsString();
  print(
    '2. retry: ${retry.statusCode} $retryBody, '
    '${TomIdempotency.replayedHeader}: '
    '${retry.headers[TomIdempotency.replayedHeader]}',
  );
  check(retryBody == firstBody, 'the retry gets the first response');
  check(
    retry.headers[TomIdempotency.replayedHeader] == 'true',
    'the replay is marked',
  );
  check(orders.length == 1, 'the handler did not run a second time');

  // 3. The same key for a different request is refused: a key names one
  //    request, not a slot to reuse.
  final reused = await send('{"item":"lamp"}', key: 'order-7f3a');
  final reusedError = (jsonDecode(await reused.readAsString()) as Map)['error'];
  print('3. same key, other body: ${reused.statusCode} $reusedError');
  check(reused.statusCode == 422, 'a reused key answers 422');
  check(
    reusedError == 'endpoint.idempotency.key_reused',
    'with endpoint.idempotency.key_reused',
  );

  // 4. A key is the caller's: another principal with the same key is a
  //    different request, and runs.
  final bob = await send(
    '{"item":"book"}',
    key: 'order-7f3a',
    principal: user('bob'),
  );
  print('4. bob, same key: ${bob.statusCode}, orders $orders');
  check(bob.statusCode == 201, "bob's request runs");
  check(orders.length == 2, 'and places his own order');

  // 5. Without a key the endpoint runs on every request, as without the
  //    annotation.
  await send('{"item":"pen"}');
  await send('{"item":"pen"}');
  print('5. two requests without a key: orders $orders');
  check(orders.length == 4, 'both ran');

  // 6. After the retention — 24 hours unless the annotation names one — the
  //    record has expired, and the key runs as new.
  now = now.add(const Duration(hours: 25));
  final later = await send('{"item":"book"}', key: 'order-7f3a');
  print(
    '6. 25 hours later: ${later.statusCode}, replayed: '
    '${later.headers[TomIdempotency.replayedHeader] ?? 'no'}',
  );
  check(later.statusCode == 201, 'an expired key runs as new');
  check(
    later.headers[TomIdempotency.replayedHeader] == null,
    'and is not a replay',
  );
  check(orders.length == 5, 'placing an order');

  TomIdempotency.reset();
}
