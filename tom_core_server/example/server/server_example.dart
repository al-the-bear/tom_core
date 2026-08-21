/// Executable example for the server module of `tom_core_server`.
///
/// `TomServer.start()` binds a real socket and needs a reflected
/// `TomConfiguration` plus TLS material, so the full server is covered by
/// `doc/server.md` rather than run here. This example exercises the
/// socket-free surface the server is composed from: the per-request value
/// objects (`TomRequestId`, `TomRequestLogInfo`), the credential reader
/// (`extractAuthentication`), and two of the pipeline middlewares
/// (`contextSetupMiddleware`, `noopHandler`).
///
/// Run with `dart run example/server/server_example.dart`. The same behaviour
/// is covered by `test/server_test.dart`.
library;

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> run() async {
  // 1. Each request gets a unique v4-UUID correlation id.
  final id1 = TomRequestId();
  final id2 = TomRequestId();
  print(
    '1. ${id1.uuid != id2.uuid ? 'distinct' : 'SAME'} request ids; '
    'toString="${id1}"',
  );
  assert(id1.uuid != id2.uuid);
  assert(id1.toString().startsWith('TomRequestId: '));

  // 2. Logging state defaults to "should be logged, not yet logged".
  final logInfo = TomRequestLogInfo();
  print('2. $logInfo (key="${TomRequestLogInfo.contextName}")');
  assert(logInfo.shouldBeLogged == true);
  assert(logInfo.hasBeenLogged == false);

  // 3. A request without an Authorization header yields no credentials.
  final plain = Request('GET', Uri.parse('http://localhost/resource'));
  final (principal, token) = extractAuthentication(plain);
  print('3. no auth header -> principal=$principal token=$token');
  assert(principal == null && token == null);

  // 4. A non-bearer scheme is also treated as "no credentials".
  final basic = Request(
    'GET',
    Uri.parse('http://localhost/resource'),
    headers: {'authorization': 'Basic dXNlcjpwYXNz'},
  );
  final (p2, t2) = extractAuthentication(basic);
  print('4. Basic auth header -> principal=$p2 token=$t2');
  assert(p2 == null && t2 == null);

  // 5. noopHandler ignores the request and returns the fixed status code.
  final handler = noopHandler('demo', 204);
  final response = await handler(plain);
  print('5. noopHandler(204) -> ${response.statusCode}');
  assert(response.statusCode == 204);

  // 6. contextSetupMiddleware merges entries into the request context.
  Object? seen;
  final wrapped = contextSetupMiddleware('seed', {'demoKey': 'demoValue'})((
    req,
  ) {
    seen = req.context['demoKey'];
    return Response.ok('handled');
  });
  await wrapped(plain);
  print('6. contextSetupMiddleware injected demoKey=$seen');
  assert(seen == 'demoValue');

  print('\nServer example completed.');
}

void main() => run();
