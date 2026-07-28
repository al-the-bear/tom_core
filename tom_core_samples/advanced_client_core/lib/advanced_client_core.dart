/// Flutter-free `dart:io` client core for the advanced Tom Core full-stack
/// sample.
///
/// The authenticated HTTP layer shared by both Flutter clients: login + token
/// storage, bearer-header injection with refresh-on-401, and typed JSON↔DTO
/// parsers over the app and admin APIs. Nothing here imports Flutter, so the
/// parsers are unit-testable headless.
///
/// It exports the authenticated HTTP stack — `AuthClient`, `AuthorizedHttp`,
/// `AppApiClient`, `AdminApiClient` — plus [ioFileTransferClient] for the byte
/// half (uploads/downloads against a server's file endpoint) and
/// [AdvancedClientConfig], the config bean that supplies the server URLs both
/// Flutter clients target in their default (run-against-real-servers) mode.
/// This barrel is their stable public entry point.
library;

export 'src/api/admin_api_client.dart';
export 'src/api/app_api_client.dart';
export 'src/auth/auth_client.dart';
export 'src/config/client_config.dart';
export 'src/http/authorized_http.dart';
export 'src/http/file_transfer.dart';
export 'src/http/json_transport.dart';
