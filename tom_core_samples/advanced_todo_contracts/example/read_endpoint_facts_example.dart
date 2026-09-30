/// Reading an endpoint's facts from the registry instead of spelling them.
///
/// The registry in `lib/src/api_registry.dart` is where an endpoint's route,
/// method and access policy are declared. The servers bind their handlers to it
/// by API id — `@TomApiImplementation(apiId: 'app')` — so the route a server
/// answers on is the one declared here. A caller reads the same facts by
/// endpoint id, `tomRemoteApis['auth'].endpoints['authLogin']`, and
/// `resolveUri` builds the URL from the same declaration, joining the API's
/// base path to the endpoint's, instead of spelling `'/auth/login'` and
/// `'POST'` a second time. That is how `advanced_client_core` addresses every
/// call, so all three tiers — both servers and the client core — take a route
/// from this one declaration.
///
/// This prints a few of those facts, including the two access decisions a
/// reader most often gets wrong: `authSecondFactor` is public although its
/// caller holds a token (the interim token authenticates nobody), and the
/// admin endpoints require the `admin` role.
///
/// ## Running it
///
/// No infrastructure — the registry is plain data:
///
/// ```sh
/// dart run example/read_endpoint_facts_example.dart
/// ```
library;

import 'dart:io';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // Once at startup, on every tier: publishes `auth`, `admin` and `app` into
  // the kernel's process-wide registry.
  registerAdvancedTodoApis();

  // The server each API is served from; only the path is the contract's.
  final servers = {
    'auth': Uri.parse('http://localhost:8081'),
    'admin': Uri.parse('http://localhost:8081'),
    'app': Uri.parse('http://localhost:8080'),
  };

  const wanted = {
    'auth': ['authLogin', 'authSecondFactor', 'authMe'],
    'admin': ['adminListUsers', 'adminPutGrants'],
    'app': ['appHealth', 'appListItems'],
  };

  for (final MapEntry(key: apiId, value: endpointIds) in wanted.entries) {
    final api = tomRemoteApis[apiId];
    for (final id in endpointIds) {
      final endpoint = api.endpoints[id]!;
      final url = endpoint.resolveUri(servers[apiId]!);
      stdout.writeln(
        '${'$apiId.$id'.padRight(22)} '
        '${endpoint.method.name.toUpperCase().padRight(6)} '
        '${url.toString().padRight(40)} '
        '${describeAccess(endpoint.access)}',
      );
    }
  }
}

/// A one-word reading of an endpoint's access policy.
String describeAccess(TomAccessControl? access) => switch (access) {
  TomPublicAccess() => 'public',
  TomAuthenticatedAccess() => 'authenticated',
  TomRoleAccess(:final roles) => 'role ${roles.join('|')}',
  null => 'undeclared',
  _ => access.runtimeType.toString(),
};
