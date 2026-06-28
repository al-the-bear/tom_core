/// Flutter-free `dart:io` client core for the advanced Tom Core full-stack
/// sample.
///
/// The authenticated HTTP layer shared by both Flutter clients: login + token
/// storage, bearer-header injection with refresh-on-401, and typed JSON↔DTO
/// parsers over the app and admin APIs. Nothing here imports Flutter, so the
/// parsers are unit-testable headless.
///
/// `AuthClient` (step 22) lands first; `AuthorizedHttp`, `AppApiClient`, and
/// `AdminApiClient` follow in steps 23–25 of the implementation plan. This
/// barrel is their stable public entry point.
library;

export 'src/auth/auth_client.dart';
export 'src/http/authorized_http.dart';
export 'src/http/json_transport.dart';
