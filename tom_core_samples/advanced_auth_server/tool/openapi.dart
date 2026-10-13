/// Writes and checks this server's OpenAPI document.
///
///     dart run tool/openapi.dart :document           # write openapi/openapi.json
///     dart run tool/openapi.dart :document --check   # fail when it is stale
///     dart run tool/openapi.dart :validate           # meta-schema + references
///
/// The document is read off the endpoint annotations through this server's
/// own reflection seed, which is why the tool runs here rather than as a
/// standalone binary: the seed, and the API registrations the boot performs,
/// are what make the endpoints visible.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_openapi/tom_core_openapi.dart';

import '../bin/auth_server_start.reflection.dart';

Future<void> main(List<String> args) => runTomOpenApiTool(
  args,
  prepare: () {
    registerAdvancedTodoApis();
    initializeReflection();
  },
  title: 'Advanced Auth Server',
  description:
      'Credential login, token lifecycle and the role-gated administration '
      'API of the advanced sample.',
  servers: const ['http://localhost:8081'],
);
