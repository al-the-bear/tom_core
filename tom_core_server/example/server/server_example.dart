/// Executable example for the server module of `tom_core_server`.
///
/// `TomServer.start()` binds a real socket and needs a reflected
/// `TomConfiguration` plus TLS material, so the full server is covered by
/// `doc/server.md` rather than run here. This example exercises the
/// socket-free surface the server is composed from: the per-request log state
/// (`TomRequestLogInfo`), the credential reader (`extractAuthentication`), and
/// two of the pipeline middlewares (`contextSetupMiddleware`, `noopHandler`).
/// The correlation id the authentication middleware seeds into the request zone
/// is `TomRequestId`, which belongs to the little-things module — see
/// `example/little_things/little_things_example.dart`.
///
/// Run with `dart run example/server/server_example.dart`. The same behaviour
/// is covered by `test/server_test.dart`.
library;

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> run() async {
  // 1. Logging state defaults to "should be logged, not yet logged".
  final logInfo = TomRequestLogInfo();
  print('1. $logInfo (key="${TomRequestLogInfo.contextName}")');
  assert(logInfo.shouldBeLogged == true);
  assert(logInfo.hasBeenLogged == false);

  // 2. A request without an Authorization header yields no credentials.
  final plain = Request('GET', Uri.parse('http://localhost/resource'));
  final (principal, token) = extractAuthentication(plain);
  print('2. no auth header -> principal=$principal token=$token');
  assert(principal == null && token == null);

  // 3. A non-bearer scheme is also treated as "no credentials".
  final basic = Request(
    'GET',
    Uri.parse('http://localhost/resource'),
    headers: {'authorization': 'Basic dXNlcjpwYXNz'},
  );
  final (p2, t2) = extractAuthentication(basic);
  print('3. Basic auth header -> principal=$p2 token=$t2');
  assert(p2 == null && t2 == null);

  // 4. noopHandler ignores the request and returns the fixed status code.
  final handler = noopHandler('demo', 204);
  final response = await handler(plain);
  print('4. noopHandler(204) -> ${response.statusCode}');
  assert(response.statusCode == 204);

  // 5. contextSetupMiddleware merges entries into the request context.
  Object? seen;
  final wrapped = contextSetupMiddleware('seed', {'demoKey': 'demoValue'})((
    req,
  ) {
    seen = req.context['demoKey'];
    return Response.ok('handled');
  });
  await wrapped(plain);
  print('5. contextSetupMiddleware injected demoKey=$seen');
  assert(seen == 'demoValue');

  print('\nServer example completed.');
}

void main() => run();
