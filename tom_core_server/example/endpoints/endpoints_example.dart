/// Executable example for the endpoints module of `tom_core_server`.
///
/// The full pipeline ([TomEndpointRouting] / [TomEndpointHandler]) reflects over
/// annotated service classes and serves live HTTP requests, so it needs a
/// running server and generated reflection — it is described in
/// `doc/endpoints.md` rather than run here. This example shows the
/// reflection-free surface: the endpoint-defining annotations and the default
/// error handler's `Response`.
///
/// Run with `dart run example/endpoints/endpoints_example.dart`.
/// The same behaviour is covered by `test/endpoints_test.dart`.
library;

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

void run() {
  // 1. An inline endpoint declaration. Every field has a default, so a bare
  //    @TomEndpoint() is a JSON GET at "/".
  const endpoint = TomEndpoint(
    uri: '/greet',
    methods: [TomHttpMethod.post, TomHttpMethod.put],
  );
  print('1. endpoint: ${endpoint.uri} ${endpoint.methods}');
  print('   consumes=${endpoint.consumes} produces=${endpoint.produces}');
  assert(endpoint.uri == '/greet');
  assert(endpoint.methods.length == 2);
  assert(endpoint.consumes == TomMimeType.json);
  // convertToTomEndpoint returns the endpoint itself.
  assert(identical(endpoint.convertToTomEndpoint(), endpoint));

  // 2. A registry-bound endpoint only carries implementation-side overrides;
  //    the route comes from tomRemoteApis[apiId][endpointId].
  const apiEndpoint = TomApiEndpointImplementation(
    apiId: 'orders',
    endpointId: 'create',
    logRequests: true,
  );
  print('2. api endpoint: ${apiEndpoint.apiId}.${apiEndpoint.endpointId} '
      'logRequests=${apiEndpoint.logRequests}');
  assert(apiEndpoint.apiId == 'orders');

  // 3. Class-level markers: a service to scan, an API implementation, and a
  //    component reference pointing at the implementing bean.
  const service = tomService;
  const apiImpl = TomApiImplementation(apiId: 'orders');
  const ref = TomComponentReference(componentName: 'orderService');
  print('3. service=$service apiImpl=${apiImpl.apiId} '
      'ref=${ref.componentName} logDefault=${apiImpl.logRequestsDefault}');
  assert(apiImpl.logRequestsDefault == true);
  assert(ref.componentName == 'orderService');

  // 4. A transactional, read-only endpoint directive.
  const tx = TomTransactional(isReadOnly: true);
  print('4. transactional=${tx.isTransactional} readOnly=${tx.isReadOnly}');
  assert(tx.isTransactional == true);
  assert(tx.isReadOnly == true);

  // 5. The default error handler hides the error behind an opaque 500.
  const handler = TomDefaultErrorHandler();
  final response = handler.handleInvocationError(
    StateError('boom'),
    StackTrace.current,
    Request('POST', Uri.parse('http://localhost/greet')),
  );
  print('5. default error handler => HTTP ${response.statusCode}');
  assert(response.statusCode == 500);

  print('\nEndpoints example completed.');
}

void main() {
  run();
}
