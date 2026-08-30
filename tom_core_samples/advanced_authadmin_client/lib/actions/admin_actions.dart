/// The admin console's mutating operations, modelled as `TomAction`s with
/// action-level authorization (G-ACT-1/2).
///
/// Every write the console performs — creating, editing, or deleting a user,
/// role, or group; assigning a role/group; saving the grant matrix — runs
/// through a [TomAction] here rather than an inline screen callback. Two things
/// fall out of that:
///
/// - **Action-level authorization.** Each action carries a [canonicalPath]
///   (`admin.<entity>.<verb>`, e.g. `admin.users.create`), and its
///   [TomAction.authorizer] resolves that path through the installed
///   authorization system. The console installs no adapter, so these paths
///   resolve to the kernel's permissive `full` default — an installed adapter
///   could grade `admin.*` to disable a control without touching the screens.
/// - **A single async bridge.** [TomAction.execute] is synchronous, but the
///   backend seam is `Future`-based. Each action launches its guarded async op
///   inside the synchronous [TomSimpleAction.executeSimple] and completes the
///   context's [AdminActionContext.result] when it lands (null = success, a
///   message = a surfaced [AdminBackendException]). [runAdminAction] drives one
///   action through a committed transaction and returns that future, so the
///   editor's `submit` contract (null saved / message inline error) is exactly
///   what the runner yields.
library;

import 'dart:async';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../app/admin_session.dart';
import '../backend/backend.dart';

// =============================================================================
// Contexts
// =============================================================================

/// Base context for the console's actions: the [AdminSession] every write is
/// guarded through, plus the async-bridge [result] the action completes.
///
/// [run] is the shared bridge every concrete action uses: it runs the guarded
/// backend call fire-and-forget and completes [result] with `null` on success
/// or the [AdminBackendException.message] on a surfaced failure. The screen
/// awaits [runAdminAction]'s return (this same future).
abstract class AdminActionContext extends TomActionContext {
  /// Creates the context over the guarded [session].
  AdminActionContext(this.session);

  /// The session whose [AdminSession.guard] wraps every backend call, so a dead
  /// session logs out uniformly (the action never re-implements that).
  final AdminSession session;

  final Completer<String?> _result = Completer<String?>();

  /// Completes with `null` on success or the failure message on error.
  Future<String?> get result => _result.future;

  /// Runs [op] through [AdminSession.guard], completing [result] with `null` on
  /// success or the [AdminBackendException.message] on failure.
  void run<T>(Future<T> Function(AdminBackend backend) op) {
    session.guard<T>(op).then(
      (_) {
        if (!_result.isCompleted) _result.complete(null);
      },
    ).catchError(
      (Object e) {
        if (!_result.isCompleted) {
          _result.complete((e as AdminBackendException).message);
        }
      },
      test: (e) => e is AdminBackendException,
    );
  }
}

/// Context for [CreateUserAction]: the request the account is created from.
class CreateUserContext extends AdminActionContext {
  /// Creates the context for [request] over [session].
  CreateUserContext(super.session, this.request);

  /// The account to create (the one place a password crosses the seam).
  final CreateUserRequest request;
}

/// Context for [UpdateUserAction]: the account id and its updated projection.
class UpdateUserContext extends AdminActionContext {
  /// Creates the context for updating account [id] over [session].
  UpdateUserContext(super.session, this.id, this.user);

  /// The stable account id.
  final String id;

  /// The updated profile + status (username is the stable key, unchanged).
  final UserDto user;
}

/// Context for [DeleteUserAction]: the account id to remove.
class DeleteUserContext extends AdminActionContext {
  /// Creates the context for deleting account [id] over [session].
  DeleteUserContext(super.session, this.id);

  /// The account id to remove.
  final String id;
}

/// Context for [CreateRoleAction]: the role to create.
class CreateRoleContext extends AdminActionContext {
  /// Creates the context for [role] over [session].
  CreateRoleContext(super.session, this.role);

  /// The role to create.
  final RoleDto role;
}

/// Context for [UpdateRoleAction]: the role key and its renamed projection.
class UpdateRoleContext extends AdminActionContext {
  /// Creates the context for updating role [key] over [session].
  UpdateRoleContext(super.session, this.key, this.role);

  /// The stable role key.
  final String key;

  /// The updated role (only the human-facing name changes).
  final RoleDto role;
}

/// Context for [DeleteRoleAction]: the role key to remove.
class DeleteRoleContext extends AdminActionContext {
  /// Creates the context for deleting role [key] over [session].
  DeleteRoleContext(super.session, this.key);

  /// The role key to remove.
  final String key;
}

/// Context for [CreateGroupAction]: the group (name + membership) to create.
class CreateGroupContext extends AdminActionContext {
  /// Creates the context for [group] over [session].
  CreateGroupContext(super.session, this.group);

  /// The group to create.
  final GroupDto group;
}

/// Context for [UpdateGroupAction]: the group id and its updated projection.
class UpdateGroupContext extends AdminActionContext {
  /// Creates the context for updating group [id] over [session].
  UpdateGroupContext(super.session, this.id, this.group);

  /// The stable group id.
  final String id;

  /// The updated group (name + membership).
  final GroupDto group;
}

/// Context for [DeleteGroupAction]: the group id to remove.
class DeleteGroupContext extends AdminActionContext {
  /// Creates the context for deleting group [id] over [session].
  DeleteGroupContext(super.session, this.id);

  /// The group id to remove.
  final String id;
}

/// Context for [AssignAction]: the role/group assignment to post.
class AssignContext extends AdminActionContext {
  /// Creates the context for [request] over [session].
  AssignContext(super.session, this.request);

  /// The role and/or group assignment to add to an account.
  final AssignmentRequest request;
}

/// Context for [PutGrantsAction]: the full grant matrix to persist.
class PutGrantsContext extends AdminActionContext {
  /// Creates the context for [matrix] over [session].
  PutGrantsContext(super.session, this.matrix);

  /// The whole edited `(role, resourceKey) → TomAuthState` matrix.
  final GrantMatrixDto matrix;
}

// =============================================================================
// Actions
// =============================================================================

/// Creates an account (`admin.users.create`).
class CreateUserAction extends TomSimpleAction<CreateUserContext> {
  /// Registers the action.
  CreateUserAction(TomActionController controller)
      : super(actionId: 'users.create', controller: controller);

  @override
  void executeSimple(CreateUserContext context, TomActionTransaction tx) {
    context.run((b) => b.createUser(context.request));
  }
}

/// Updates an account (`admin.users.update`).
class UpdateUserAction extends TomSimpleAction<UpdateUserContext> {
  /// Registers the action.
  UpdateUserAction(TomActionController controller)
      : super(actionId: 'users.update', controller: controller);

  @override
  void executeSimple(UpdateUserContext context, TomActionTransaction tx) {
    context.run((b) => b.updateUser(context.id, context.user));
  }
}

/// Deletes an account (`admin.users.delete`).
class DeleteUserAction extends TomSimpleAction<DeleteUserContext> {
  /// Registers the action.
  DeleteUserAction(TomActionController controller)
      : super(actionId: 'users.delete', controller: controller);

  @override
  void executeSimple(DeleteUserContext context, TomActionTransaction tx) {
    context.run((b) => b.deleteUser(context.id));
  }
}

/// Creates a role (`admin.roles.create`).
class CreateRoleAction extends TomSimpleAction<CreateRoleContext> {
  /// Registers the action.
  CreateRoleAction(TomActionController controller)
      : super(actionId: 'roles.create', controller: controller);

  @override
  void executeSimple(CreateRoleContext context, TomActionTransaction tx) {
    context.run((b) => b.createRole(context.role));
  }
}

/// Updates a role (`admin.roles.update`).
class UpdateRoleAction extends TomSimpleAction<UpdateRoleContext> {
  /// Registers the action.
  UpdateRoleAction(TomActionController controller)
      : super(actionId: 'roles.update', controller: controller);

  @override
  void executeSimple(UpdateRoleContext context, TomActionTransaction tx) {
    context.run((b) => b.updateRole(context.key, context.role));
  }
}

/// Deletes a role (`admin.roles.delete`).
class DeleteRoleAction extends TomSimpleAction<DeleteRoleContext> {
  /// Registers the action.
  DeleteRoleAction(TomActionController controller)
      : super(actionId: 'roles.delete', controller: controller);

  @override
  void executeSimple(DeleteRoleContext context, TomActionTransaction tx) {
    context.run((b) => b.deleteRole(context.key));
  }
}

/// Creates a group (`admin.groups.create`).
class CreateGroupAction extends TomSimpleAction<CreateGroupContext> {
  /// Registers the action.
  CreateGroupAction(TomActionController controller)
      : super(actionId: 'groups.create', controller: controller);

  @override
  void executeSimple(CreateGroupContext context, TomActionTransaction tx) {
    context.run((b) => b.createGroup(context.group));
  }
}

/// Updates a group (`admin.groups.update`).
class UpdateGroupAction extends TomSimpleAction<UpdateGroupContext> {
  /// Registers the action.
  UpdateGroupAction(TomActionController controller)
      : super(actionId: 'groups.update', controller: controller);

  @override
  void executeSimple(UpdateGroupContext context, TomActionTransaction tx) {
    context.run((b) => b.updateGroup(context.id, context.group));
  }
}

/// Deletes a group (`admin.groups.delete`).
class DeleteGroupAction extends TomSimpleAction<DeleteGroupContext> {
  /// Registers the action.
  DeleteGroupAction(TomActionController controller)
      : super(actionId: 'groups.delete', controller: controller);

  @override
  void executeSimple(DeleteGroupContext context, TomActionTransaction tx) {
    context.run((b) => b.deleteGroup(context.id));
  }
}

/// Assigns a role and/or group to an account (`admin.assignments.assign`).
class AssignAction extends TomSimpleAction<AssignContext> {
  /// Registers the action.
  AssignAction(TomActionController controller)
      : super(actionId: 'assignments.assign', controller: controller);

  @override
  void executeSimple(AssignContext context, TomActionTransaction tx) {
    context.run((b) => b.assign(context.request));
  }
}

/// Persists the whole grant matrix (`admin.grants.save`).
class PutGrantsAction extends TomSimpleAction<PutGrantsContext> {
  /// Registers the action.
  PutGrantsAction(TomActionController controller)
      : super(actionId: 'grants.save', controller: controller);

  @override
  void executeSimple(PutGrantsContext context, TomActionTransaction tx) {
    context.run((b) => b.putGrants(context.matrix));
  }
}

// =============================================================================
// Controller
// =============================================================================

/// The console's mutating actions, all prefixed `admin`.
class AdminActionsController extends TomActionController {
  /// Creates the controller (canonical prefix `admin`).
  AdminActionsController() : super(controllerId: 'admin');

  /// Create an account (`admin.users.create`).
  late final CreateUserAction createUser = CreateUserAction(this);

  /// Update an account (`admin.users.update`).
  late final UpdateUserAction updateUser = UpdateUserAction(this);

  /// Delete an account (`admin.users.delete`).
  late final DeleteUserAction deleteUser = DeleteUserAction(this);

  /// Create a role (`admin.roles.create`).
  late final CreateRoleAction createRole = CreateRoleAction(this);

  /// Update a role (`admin.roles.update`).
  late final UpdateRoleAction updateRole = UpdateRoleAction(this);

  /// Delete a role (`admin.roles.delete`).
  late final DeleteRoleAction deleteRole = DeleteRoleAction(this);

  /// Create a group (`admin.groups.create`).
  late final CreateGroupAction createGroup = CreateGroupAction(this);

  /// Update a group (`admin.groups.update`).
  late final UpdateGroupAction updateGroup = UpdateGroupAction(this);

  /// Delete a group (`admin.groups.delete`).
  late final DeleteGroupAction deleteGroup = DeleteGroupAction(this);

  /// Assign a role/group (`admin.assignments.assign`).
  late final AssignAction assign = AssignAction(this);

  /// Save the grant matrix (`admin.grants.save`).
  late final PutGrantsAction putGrants = PutGrantsAction(this);
}

/// The console's mutating actions — a process-wide controller the screens read.
final AdminActionsController adminActions = AdminActionsController();

// =============================================================================
// Runner
// =============================================================================

/// Drives [action] through a committed [TomActionTransaction] over [context] and
/// returns the context's async result (`null` = success, a message = failure).
///
/// This is the one place the synchronous action lifecycle is joined to the
/// asynchronous backend seam. Its `Future<String?>` return is exactly the
/// editor's `submit` contract, so a screen can hand it straight back.
Future<String?> runAdminAction<C extends AdminActionContext>(
  TomSimpleAction<C> action,
  C context,
) {
  final tx = TomActionTransaction(label: action.label);
  action.execute(context, tx);
  tx.commit();
  return context.result;
}
