/// Shared wire contracts for the advanced Tom Core full-stack sample.
///
/// The `@tomService` endpoint interfaces (`AuthApiService`, `AdminApiService`,
/// `AppApiService`) and the JSON DTOs the servers implement and the clients
/// call. Importing this barrel gives both tiers the same, single definition of
/// the wire surface.
///
/// The DTOs are defined in step 4; the `@tomService` interfaces and reflection
/// seed are added in step 5. This barrel is the stable public entry point.
library;

export 'src/dtos.dart';
