/// Flutter-free `dart:io` client core for the advanced Tom Core full-stack
/// sample.
///
/// The authenticated HTTP layer shared by both Flutter clients: login + token
/// storage, bearer-header injection with refresh-on-401, and typed JSON↔DTO
/// parsers over the app and admin APIs. Nothing here imports Flutter, so the
/// parsers are unit-testable headless.
///
/// `AuthClient` (step 22), `AuthorizedHttp` (step 23) and `AppApiClient`
/// (step 24) have landed; `AdminApiClient` follows in step 25. This barrel is
/// their stable public entry point.
library;

export 'src/api/app_api_client.dart';
export 'src/auth/auth_client.dart';
export 'src/http/authorized_http.dart';
export 'src/http/json_transport.dart';
