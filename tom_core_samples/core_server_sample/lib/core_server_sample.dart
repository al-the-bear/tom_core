/// Tom Core sample backend — public surface.
///
/// The persistence + authorization core re-exported here is database-free and
/// unit-tested: relational [TodoItemRecord]-style records, the domain ↔ record
/// mapping, and the four-state [TodoFieldAuthorizer]. The HTTP [TodoApiService]
/// that binds these to `tom_core_server` is also exported; its server boot lives
/// in `bin/server_start.dart` and runs against the bundled Docker MariaDB (see
/// `README.md`).
library;

export 'src/auth/todo_authorization.dart';
export 'src/endpoints/todo_endpoints.dart';
export 'src/persistence/todo_mapping.dart';
export 'src/persistence/todo_records.dart';
