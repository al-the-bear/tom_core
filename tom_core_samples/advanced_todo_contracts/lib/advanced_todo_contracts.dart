/// Shared wire contracts for the advanced Tom Core full-stack sample.
///
/// The `@tomService` endpoint interfaces (`AuthApiService`, `AdminApiService`,
/// `AppApiService`) and the JSON DTOs the servers implement and the clients
/// call. Importing this barrel gives both tiers the same, single definition of
/// the wire surface.
///
/// The interfaces, DTOs, and reflection seed are added in steps 4–5 of the
/// implementation plan; this barrel is the stable public entry point.
library;
