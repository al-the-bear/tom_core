/// Flutter-free `dart:io` client core for the advanced Tom Core full-stack
/// sample.
///
/// The authenticated HTTP layer shared by both Flutter clients: login + token
/// storage, bearer-header injection with refresh-on-401, and typed JSON↔DTO
/// parsers over the app and admin APIs. Nothing here imports Flutter, so the
/// parsers are unit-testable headless.
///
/// `AuthClient`, `AuthorizedHttp`, `AppApiClient`, and `AdminApiClient` are
/// added in steps 22–25 of the implementation plan; this barrel is their stable
/// public entry point.
library;
