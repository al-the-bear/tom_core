/// Flutter-free `dart:io` client core for the advanced Tom Core full-stack
/// sample.
///
/// The authenticated HTTP layer shared by both Flutter clients: login + token
/// storage, bearer-header injection with refresh-on-401, and typed JSON↔DTO
/// parsers over the app and admin APIs. Nothing here imports Flutter, so the
/// parsers are unit-testable headless.
///
/// `AuthClient` (step 22), `AuthorizedHttp` (step 23), `AppApiClient` (step 24)
/// and `AdminApiClient` (step 25) have landed. This barrel is their stable
/// public entry point — the client core is complete.
library;

export 'src/api/admin_api_client.dart';
export 'src/api/app_api_client.dart';
export 'src/auth/auth_client.dart';
export 'src/http/authorized_http.dart';
export 'src/http/json_transport.dart';
