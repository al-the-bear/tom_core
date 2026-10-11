/// Flutter-free client core for the advanced Tom Core full-stack sample,
/// running on every target `package:http` does — the web included.
///
/// The authenticated HTTP layer shared by both Flutter clients: login + token
/// storage, bearer-header injection with refresh-on-401, and typed JSON↔DTO
/// parsers over the app and admin APIs. Nothing here imports Flutter, so the
/// parsers are unit-testable headless.
///
/// It exports the authenticated HTTP stack — `AuthClient`, `AuthorizedHttp`,
/// `AppApiClient`, `AdminApiClient` — plus [authenticatedFileTransferClient] for
/// the byte half (uploads/downloads against a server's file endpoint, on the
/// same bearer and the same refresher the JSON half uses) and
/// [AdvancedClientConfig], the config bean that supplies the server URLs both
/// Flutter clients target in their default (run-against-real-servers) mode.
/// This barrel is their stable public entry point.
library;

// not-exported: reflection_seed.dart — the generated `initializeReflection()`
// assigns the reflection registry rather than adding to it, so exactly one seed
// may run per program. The Flutter apps that consume this package build their
// own combined seed, covering their forms as well; exporting this one from the
// public barrel would put a second `initializeReflection` in their namespace and
// silently decide which of the two they get. The client core's own tests and
// its standalone example import it by path, which is where it is wanted.
// not-exported: src/http/registry_route.dart — how the three clients turn a
// registry endpoint id into a method and URL. It is their shared internal step,
// not a surface: an application addresses the servers through the clients, and
// one that wants a route reads the contracts registry itself.

export 'src/api/admin_api_client.dart';
export 'src/api/app_api_client.dart';
export 'src/auth/auth_client.dart';
export 'src/config/client_config.dart';
export 'src/http/authorized_http.dart';
export 'src/http/file_transfer.dart';
export 'src/http/json_transport.dart';
