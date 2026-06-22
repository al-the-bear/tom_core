/// The HTTP API surface of the sample backend.
///
/// Three public, unauthenticated `GET` endpoints — deliberately the smallest
/// set that proves the whole stack end-to-end against the bundled MariaDB:
///
/// | Method & URI            | Proves                                          |
/// | ----------------------- | ----------------------------------------------- |
/// | `GET /health`           | the server booted and is serving (no DB)        |
/// | `GET /todos`            | a real persistence round-trip (reads `todo_items`) |
/// | `GET /todos/field-states` | four-state authorization resolved from DB grants |
///
/// Each endpoint returns a JSON-friendly `Map` (the endpoint pipeline
/// `jsonEncode`s `Map`/`List` results directly), so the records are projected
/// to plain maps rather than returned raw. The service is split into a
/// `@tomService` interface and a `@tomComponent` implementation — the codebase
/// convention the endpoint router resolves: the router finds the component bean
/// implementing the annotated interface, which is why `initializeBeanContext()`
/// must run before the server starts.
library;

// tom_core_server re-exports tom_core_kernel, so the endpoint annotations, the
// access controls, `TomResourceGrant`, and the repository base all resolve
// through this single barrel.
import 'package:tom_core_server/tom_core_server.dart';

import '../auth/todo_authorization.dart';
import '../persistence/todo_records.dart';

/// Repository for the framework's graded-authorization grants.
///
/// `TomResourceGrant` is bound to the `main` datasource by the framework; the
/// sample registers `main` against the same physical MariaDB database as
/// `todo_db` (see `assets/datasources_default.yaml`), so one database backs both
/// the application data and the authorization store.
class TodoGrantRepository
    extends TomSqlDatasourceRepository<TomResourceGrant, int> {}

/// Process-wide singleton grant repository.
final todoGrantRepository = TodoGrantRepository();

/// The todo-management API contract.
@tomReflector
@tomService
abstract class TodoApiService {
  /// Liveness probe — confirms the server is up without touching the database.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/health',
    produces: TomMimeType.json,
    logRequests: true,
  )
  Future<Map<String, Object>> health();

  /// Every persisted todo item, projected to JSON.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/todos',
    produces: TomMimeType.json,
    logRequests: true,
  )
  Future<Map<String, Object>> listTodos();

  /// The four-state field-authorization matrix, resolved from the seeded
  /// `tom_resource_grant` rows — one row per `(role, field)` state per role.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/todos/field-states',
    produces: TomMimeType.json,
    logRequests: true,
  )
  Future<Map<String, Object>> fieldStates();
}

/// Live implementation of [TodoApiService] backed by the sample repositories.
@tomReflector
@tomComponent
class TodoApiServer implements TodoApiService {
  @override
  Future<Map<String, Object>> health() async => <String, Object>{
        'status': 'ok',
        'app': 'Tom Core — Todo API',
      };

  @override
  Future<Map<String, Object>> listTodos() async {
    final items = await todoItemRepository.findAll();
    return <String, Object>{
      'items': [for (final record in items) _itemToJson(record)],
    };
  }

  @override
  Future<Map<String, Object>> fieldStates() async {
    final grants = await todoGrantRepository.findAll();

    // Group the flat grant rows by role, then resolve each role's per-field
    // state through the same four-state authorizer the unit tests exercise.
    final grantsByRole = <String, List<TomResourceGrant>>{};
    for (final grant in grants) {
      grantsByRole.putIfAbsent(grant.roleName, () => []).add(grant);
    }

    final result = <String, Object>{};
    for (final entry in grantsByRole.entries) {
      final authorizer = TodoFieldAuthorizer.fromGrants(entry.value);
      result[entry.key] = {
        for (final state in authorizer.fieldStates.entries)
          state.key: state.value.name,
      };
    }
    return result;
  }
}

/// Projects a [TodoItemRecord] to a plain JSON map (the pipeline `jsonEncode`s
/// the enclosing `Map`/`List`, so values must be JSON primitives).
Map<String, Object?> _itemToJson(TodoItemRecord record) => {
      'id': record.id,
      'title': record.title,
      'description': record.description,
      'done': record.done,
      'priority': record.priority,
      'label': record.label,
      'assigneeId': record.assigneeId,
      'dueDate': record.dueDate?.toIso8601String(),
      'listId': record.listId,
    };
