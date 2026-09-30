/// How the client core addresses a call: by registry endpoint, never by path.
///
/// Every route, method and URL parameter the three servers answer on is
/// declared once, in `advanced_todo_contracts`' `authApi` / `adminApi` /
/// `appApi`, and the servers bind to that declaration by API id. A client that
/// wrote `'/auth/login'` or `'/items/${id}'` itself would agree with the
/// servers only by inspection: renaming a route in the registry moves both
/// servers and leaves such a client addressing a route that no longer exists,
/// with nothing in its own suite noticing. So each client names the endpoint
/// and this resolves it, through the kernel's `TomApiEndpoint.resolveUri` — the
/// client-side inverse of the server pipeline's URL-parameter binding.
///
/// `test/registry_routes_test.dart` holds all three clients to it by moving
/// each route in the registry and requiring the request to follow.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The HTTP method and URL of [endpointId] in [api], rooted at [baseUri].
///
/// [parameters] are keyed by request-DTO field name, as
/// `TomApiEndpoint.resolveUri` takes them: a path capture binds through the
/// endpoint's `urlParameterMapping` (or its own name), and a mapped query
/// parameter is appended when its field has a value.
///
/// The endpoint is looked up on every call rather than captured once, so what
/// is sent is always what the registry declares now.
({String method, Uri uri}) registryRoute(
  TomApi api,
  String endpointId,
  Uri baseUri, {
  Map<String, Object?> parameters = const {},
}) {
  final endpoint = api[endpointId];
  return (
    method: endpoint.method.name,
    uri: endpoint.resolveUri(baseUri, parameters: parameters),
  );
}
