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
/// Run with `dart run example/server/server_example.dart`. Every step checks
/// its own result and the run fails when one does not hold, so a green run is a
/// verification and not just a transcript. The same behaviour is covered by
/// `test/server_test.dart`.
library;

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

Future<void> run() async {
  // 1. Logging state defaults to "should be logged, not yet logged".
  final logInfo = TomRequestLogInfo();
  print('1. $logInfo (key="${TomRequestLogInfo.contextName}")');
  check(logInfo.shouldBeLogged == true, 'a fresh request is one to log');
  check(logInfo.hasBeenLogged == false, 'and has not been written out yet');

  // 2. A request without an Authorization header yields no credentials.
  final plain = Request('GET', Uri.parse('http://localhost/resource'));
  final (principal, token) = extractAuthentication(plain);
  print('2. no auth header -> principal=$principal token=$token');
  check(
    principal == null && token == null,
    'a request with no Authorization header carries no credentials at all',
  );

  // 3. A non-bearer scheme is also treated as "no credentials".
  final basic = Request(
    'GET',
    Uri.parse('http://localhost/resource'),
    headers: {'authorization': 'Basic dXNlcjpwYXNz'},
  );
  final (p2, t2) = extractAuthentication(basic);
  print('3. Basic auth header -> principal=$p2 token=$t2');
  check(
    p2 == null && t2 == null,
    'only the bearer scheme is read, so Basic yields no credentials either',
  );

  // 4. noopHandler ignores the request and returns the fixed status code.
  final handler = noopHandler('demo', 204);
  final response = await handler(plain);
  print('4. noopHandler(204) -> ${response.statusCode}');
  check(
    response.statusCode == 204,
    'the placeholder handler answers with the status it was built for',
  );

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
  check(
    seen == 'demoValue',
    'the seeded entries reach the inner handler through the request context',
  );

  print('\nServer example completed.');
}

void main() => run();
