/// Four-state authorization for the todo-item fields.
///
/// The server stores per-`(role, resourceKey)` grants as [TomResourceGrant]
/// rows (table `tom_resource_grant`, seeded by migration `[001]`). At request
/// time we fold the grants for the principal's role into a
/// [TomGradedAccessControlInformation] and resolve the effective
/// [TomAuthState] for each field's resource key. The four states the UI
/// distinguishes map straight through:
///
/// | [TomAuthState] | UI rendering              |
/// | -------------- | ------------------------- |
/// | `full`         | editable                  |
/// | `read`         | shown, read-only          |
/// | `disabled`     | shown, greyed-out         |
/// | `none`         | hidden                    |
///
/// This is the server half of the four-state story (item 17 + item 18): the
/// server decides the grade, the client renders it.
library;

// tom_core_server re-exports tom_core_kernel, so `TomAuthState` and the graded
// authorization types both resolve through this single barrel.
import 'package:tom_core_server/tom_core_server.dart';

/// Stable resource keys for the gradable [TodoItem] fields. They match the
/// `resource_key` values seeded by migration `[001]-todo_authz_grants.sql`.
class TodoItemResourceKeys {
  const TodoItemResourceKeys._();

  /// Resource key for the item title field.
  static const String title = 'todo.item.title';

  /// Resource key for the done/complete toggle.
  static const String done = 'todo.item.done';

  /// Resource key for the priority field.
  static const String priority = 'todo.item.priority';

  /// Resource key for the assignee field.
  static const String assigneeId = 'todo.item.assigneeId';

  /// Every gradable key, in display order.
  static const List<String> all = [title, done, priority, assigneeId];
}

/// Resolves the effective [TomAuthState] for todo-item fields, for one role.
///
/// Construct it once per request from the grants loaded for the principal's
/// role (typically via the grant repository), then query [stateOf] per field.
/// Grades are merged most-permissively when several grants touch the same key
/// (see [TomGradedAccessControlInformation.fromGrants]).
class TodoFieldAuthorizer {
  final TomGradedAccessControlInformation _graded;

  /// Wraps a prepared graded view.
  TodoFieldAuthorizer(this._graded);

  /// Builds an authorizer from the [grants] that apply to a principal's role.
  factory TodoFieldAuthorizer.fromGrants(Iterable<TomResourceGrant> grants) =>
      TodoFieldAuthorizer(
        TomGradedAccessControlInformation.fromGrants(grants),
      );

  /// The effective state for [resourceKey] (defaults to [TomAuthState.none]
  /// — hidden — for an ungranted key, the closed-safe default).
  TomAuthState stateOf(String resourceKey) => _graded.resolveState(resourceKey);

  /// The effective state for every [TodoItemResourceKeys] field.
  Map<String, TomAuthState> get fieldStates => {
        for (final key in TodoItemResourceKeys.all) key: stateOf(key),
      };

  /// Whether [resourceKey] is editable (`full`) for this role.
  bool canEdit(String resourceKey) =>
      stateOf(resourceKey) == TomAuthState.full;

  /// Whether [resourceKey] is at least visible (`read` / `disabled` / `full`,
  /// i.e. not `none`).
  bool canSee(String resourceKey) => stateOf(resourceKey) != TomAuthState.none;
}
