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
/// The two data endpoints return **reflection-first wire DTOs** (G-DTO):
/// `/todos` a `List<TodoItemDto>` and `/todos/field-states` a
/// `TodoFieldMatrixDto`. The endpoint pipeline serializes the returned DTO(s)
/// through the kernel reflection path — no hand-written `toJson` and no ad-hoc
/// `Map` projection. `/health` stays a plain status `Map` (a liveness probe, not
/// a data shape). The service is split into a `@tomService` interface and a
/// `@tomComponent` implementation — the codebase convention the endpoint router
/// resolves: the router finds the component bean implementing the annotated
/// interface, which is why `initializeBeanContext()` must run before the server
/// starts.
library;

// tom_core_server re-exports tom_core_kernel, so the endpoint annotations, the
// access controls, `TomResourceGrant`, and the repository base all resolve
// through this single barrel.
import 'package:tom_core_server/tom_core_server.dart';
// The reflection-first wire DTOs and the shared todo enums live in the domain
// package; reflecting them for this server is what lets the pipeline serialize
// the endpoint results.
import 'package:todo_domain/todo_domain.dart';

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

  /// Every persisted todo item as a reflection-first [TodoItemDto]; the pipeline
  /// serializes the list to a JSON array.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/todos',
    produces: TomMimeType.json,
    logRequests: true,
  )
  Future<List<TodoItemDto>> listTodos();

  /// The four-state field-authorization matrix, resolved from the seeded
  /// `tom_resource_grant` rows — one row per `(role, field)` state per role —
  /// as a reflection-first [TodoFieldMatrixDto].
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/todos/field-states',
    produces: TomMimeType.json,
    logRequests: true,
  )
  Future<TodoFieldMatrixDto> fieldStates();
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
  Future<List<TodoItemDto>> listTodos() async {
    final items = await todoItemRepository.findAll();
    return [for (final record in items) _recordToDto(record)];
  }

  @override
  Future<TodoFieldMatrixDto> fieldStates() async {
    final grants = await todoGrantRepository.findAll();

    // Group the flat grant rows by role, then resolve each role's per-field
    // state through the same four-state authorizer the unit tests exercise.
    final grantsByRole = <String, List<TomResourceGrant>>{};
    for (final grant in grants) {
      grantsByRole.putIfAbsent(grant.roleName, () => []).add(grant);
    }

    final matrix = <String, Map<String, TomAuthState>>{};
    for (final entry in grantsByRole.entries) {
      matrix[entry.key] = TodoFieldAuthorizer.fromGrants(entry.value).fieldStates;
    }
    return TodoFieldMatrixDto(matrix);
  }
}

/// Projects a persistence [TodoItemRecord] into the reflection-first
/// [TodoItemDto] wire shape: the surrogate/foreign keys become strings, the
/// enums travel as their stored `.name` token, and the due date as an ISO-8601
/// string (empty when unset).
TodoItemDto _recordToDto(TodoItemRecord record) => TodoItemDto(
      id: record.id?.toString() ?? '',
      title: record.title ?? '',
      description: record.description ?? '',
      done: record.done ?? false,
      priority: record.priority ?? TodoPriority.medium.name,
      label: record.label ?? TodoLabel.feature.name,
      assigneeId: record.assigneeId?.toString() ?? '',
      dueDate: record.dueDate?.toIso8601String() ?? '',
      listId: record.listId?.toString() ?? '',
    );
