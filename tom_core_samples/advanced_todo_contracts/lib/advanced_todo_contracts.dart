/// Shared wire contracts for the advanced Tom Core full-stack sample.
///
/// The single definition of the over-the-wire surface, depended on by both
/// servers (which implement it) and the shared client core (which calls it):
///
/// - the JSON DTOs (`src/dtos.dart`) — reflection-first wire shapes
///   (`@tomReflector`, plain non-`final` fields, no hand-written
///   `toJson`/`fromJson`), serialized through the kernel reflection path;
/// - the typed service interfaces (`src/api_services.dart`) —
///   `AuthApiService`, `AdminApiService`, `AppApiService`, the implementation
///   seam shared by the servers and the client core;
/// - the wire registry (`src/api_registry.dart`) — each endpoint's URI, HTTP
///   method, request/response types (`authApi`/`adminApi`/`appApi`) and its
///   per-endpoint four-state access policy declared directly on the endpoint
///   (`TomApiEndpoint.access`, G-API-3), plus `registerAdvancedTodoApis()`.
///
/// Importing this barrel gives both tiers the same, single definition of the
/// wire surface. The package depends only on `tom_core_kernel` + the domain
/// model so it stays consumable by the Flutter-free client core.
library;

export 'src/api_registry.dart';
export 'src/api_services.dart';
export 'src/dtos.dart';
