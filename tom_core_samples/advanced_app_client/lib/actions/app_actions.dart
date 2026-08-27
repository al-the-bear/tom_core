/// The end-user app's mutating operations, modelled as `TomAction`s with
/// action-level authorization (step 27, G-ACT-1/2).
///
/// Every write the app performs — saving an item, posting a comment, adding or
/// ticking a checklist step, sharing a project — runs through a [TomAction] here
/// rather than an inline screen callback. Two things fall out of that:
///
/// - **Action-level authorization.** Each action carries a [canonicalPath]
///   (`<controllerId>.<actionId>`, e.g. `todo.item.save`), and its
///   [TomAction.authorizer] resolves that path through the global
///   [TomAuthorization]. The screen hands the button that same authorizer, so
///   the control's enablement is driven by the action's grant, not by ad-hoc
///   screen logic. The adapter the session installs at login
///   (`AppResourceRoleAdapter`) gates only `<type>:<id>` resource keys, and an
///   action path is dotted — so these paths take its permissive branch
///   (`full`), and field-level presence gating (which the item screen drives
///   via per-field grades) owns visibility.
/// - **A single async bridge.** [TomAction.execute] is synchronous, but the
///   backend seam is `Future`-based. Each action launches its guarded async op
///   inside the synchronous [TomSimpleAction.executeSimple] and completes the
///   context's [AppActionContext.result] when it lands (null = success, a
///   message = a surfaced [AppBackendException]). [runAppAction] drives one
///   action through a committed transaction and returns that future, so the
///   screens keep their existing busy/error/navigation chrome by awaiting it.
library;

import 'dart:async';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../app/app_session.dart';
import '../backend/backend.dart';

// =============================================================================
// Contexts
// =============================================================================

/// Base context for the app's actions: the [AppSession] every write is guarded
/// through, plus the async-bridge [result] the action completes.
///
/// The action runs synchronously and launches its guarded backend call
/// fire-and-forget; when that call settles it completes [result] — `null` on
/// success, the [AppBackendException.message] on a surfaced failure. The screen
/// awaits [runAppAction]'s return (this same future) to restore its busy/error
/// state and navigate.
abstract class AppActionContext extends TomActionContext {
  /// Creates the context over the guarded [session].
  AppActionContext(this.session);

  /// The session whose [AppSession.guard] wraps every backend call, so a dead
  /// session logs out uniformly (the action never re-implements that).
  final AppSession session;

  final Completer<String?> _result = Completer<String?>();

  /// Completes with `null` on success or the failure message on error.
  Future<String?> get result => _result.future;

  /// Marks the action's work done successfully.
  void completeOk() {
    if (!_result.isCompleted) _result.complete(null);
  }

  /// Marks the action's work failed, carrying [message] back to the screen.
  void completeError(String message) {
    if (!_result.isCompleted) _result.complete(message);
  }
}

/// Context for [SaveItemAction]: the [TodoItem] to persist (already written back
/// from the bound form).
class SaveItemContext extends AppActionContext {
  /// Creates the context for saving [item] over [session].
  SaveItemContext(super.session, this.item);

  /// The item to persist; only its `full`-graded fields carry edits.
  final TodoItem item;
}

/// Context for [AddCommentAction]: the target item id and the composed body.
class AddCommentContext extends AppActionContext {
  /// Creates the context for commenting on [itemId] over [session].
  AddCommentContext(super.session, this.itemId, this.body);

  /// The item the comment attaches to.
  final String itemId;

  /// The (non-empty, trimmed) comment text.
  final String body;
}

/// Context for [AddSubtaskAction]: the parent item id and the step's title.
class AddSubtaskContext extends AppActionContext {
  /// Creates the context for adding a step to [itemId] over [session].
  AddSubtaskContext(super.session, this.itemId, this.title);

  /// The item the subtask becomes part of.
  final String itemId;

  /// The (non-empty, trimmed) step title.
  final String title;
}

/// Context for [ToggleSubtaskAction]: the stored subtask and its new `done`.
///
/// Carries the whole [Subtask] rather than just its id because the update is a
/// full-row write: the server keeps `id` and `itemId` (it re-stamps the parent
/// link from storage), and `title`/`position` must round-trip unchanged or
/// toggling a checkbox would silently blank the step's title.
class ToggleSubtaskContext extends AppActionContext {
  /// Creates the context for setting [subtask]'s `done` to [done].
  ToggleSubtaskContext(super.session, this.subtask, this.done);

  /// The subtask as last read from the backend.
  final Subtask subtask;

  /// The state the checkbox was moved to.
  final bool done;
}

/// Context for [ShareProjectAction]: the project and the grant to make.
class ShareProjectContext extends AppActionContext {
  /// Creates the context for sharing [projectId] with [granteeUserId] at [role].
  ShareProjectContext(super.session, this.projectId, this.granteeUserId, this.role);

  /// The project being shared.
  final String projectId;

  /// The user id receiving the grant.
  final String granteeUserId;

  /// The role granted to the grantee.
  final ProjectRole role;
}

// =============================================================================
// Actions
// =============================================================================

/// Persists the bound item through the backend seam.
class SaveItemAction extends TomSimpleAction<SaveItemContext> {
  /// Registers the action under `todo.item.save`.
  SaveItemAction(TomActionController controller)
      : super(actionId: 'save', controller: controller);

  @override
  void executeSimple(SaveItemContext context, TomActionTransaction tx) {
    context.session
        .guard((b) => b.saveItem(context.item))
        .then((_) => context.completeOk())
        .catchError(
          (Object e) => context.completeError((e as AppBackendException).message),
          test: (e) => e is AppBackendException,
        );
  }
}

/// Posts a new comment on an item through the backend seam.
class AddCommentAction extends TomSimpleAction<AddCommentContext> {
  /// Registers the action under `todo.item.comment`.
  AddCommentAction(TomActionController controller)
      : super(actionId: 'comment', controller: controller);

  @override
  void executeSimple(AddCommentContext context, TomActionTransaction tx) {
    final comment = TodoComment()
      ..itemId.set(context.itemId)
      ..authorId.set(context.session.user?.id ?? '')
      ..body.set(context.body);
    context.session
        .guard((b) => b.addComment(context.itemId, comment))
        .then((_) => context.completeOk())
        .catchError(
          (Object e) => context.completeError((e as AppBackendException).message),
          test: (e) => e is AppBackendException,
        );
  }
}

/// Adds a checklist step to an item through the backend seam.
class AddSubtaskAction extends TomSimpleAction<AddSubtaskContext> {
  /// Registers the action under `todo.item.addSubtask`.
  AddSubtaskAction(TomActionController controller)
      : super(actionId: 'addSubtask', controller: controller);

  @override
  void executeSimple(AddSubtaskContext context, TomActionTransaction tx) {
    // `position` is left at its default: the server appends, and a client that
    // computed one from the list it happens to hold would fight any concurrent
    // insert. `id` and `itemId` are stamped server-side from the addressed item.
    final subtask = Subtask()..title.set(context.title);
    context.session
        .guard((b) => b.addSubtask(context.itemId, subtask))
        .then((_) => context.completeOk())
        .catchError(
          (Object e) => context.completeError((e as AppBackendException).message),
          test: (e) => e is AppBackendException,
        );
  }
}

/// Flips a checklist step's `done` through the backend seam.
class ToggleSubtaskAction extends TomSimpleAction<ToggleSubtaskContext> {
  /// Registers the action under `todo.item.toggleSubtask`.
  ToggleSubtaskAction(TomActionController controller)
      : super(actionId: 'toggleSubtask', controller: controller);

  @override
  void executeSimple(ToggleSubtaskContext context, TomActionTransaction tx) {
    final source = context.subtask;
    // A copy, not a mutation of the bound row: the screen keeps rendering the
    // list it read until the refresh lands, so a rejected write must leave the
    // visible checkbox where the server still has it.
    final edited = Subtask()
      ..id.set(source.id.get())
      ..itemId.set(source.itemId.get())
      ..title.set(source.title.get())
      ..position.set(source.position.get())
      ..done.set(context.done);
    context.session
        .guard((b) => b.updateSubtask(edited))
        .then((_) => context.completeOk())
        .catchError(
          (Object e) => context.completeError((e as AppBackendException).message),
          test: (e) => e is AppBackendException,
        );
  }
}

/// Grants another user a role on a project through the backend seam.
class ShareProjectAction extends TomSimpleAction<ShareProjectContext> {
  /// Registers the action under `board.share`.
  ShareProjectAction(TomActionController controller)
      : super(actionId: 'share', controller: controller);

  @override
  void executeSimple(ShareProjectContext context, TomActionTransaction tx) {
    context.session
        .guard((b) => b.share(ShareRequest(
              resourceType: 'project',
              resourceId: context.projectId,
              granteeUserId: context.granteeUserId,
              projectRole: context.role,
            )))
        .then((_) => context.completeOk())
        .catchError(
          (Object e) => context.completeError((e as AppBackendException).message),
          test: (e) => e is AppBackendException,
        );
  }
}

// =============================================================================
// Controllers
// =============================================================================

/// The item detail screen's actions, prefixed `todo.item`.
class ItemActionsController extends TomActionController {
  /// Creates the controller (canonical prefix `todo.item`).
  ItemActionsController() : super(controllerId: 'todo.item');

  /// Persist the bound item (`todo.item.save`).
  late final SaveItemAction save = SaveItemAction(this);

  /// Post a comment (`todo.item.comment`).
  late final AddCommentAction comment = AddCommentAction(this);

  /// Add a checklist step (`todo.item.addSubtask`).
  late final AddSubtaskAction addSubtask = AddSubtaskAction(this);

  /// Toggle a checklist step (`todo.item.toggleSubtask`).
  late final ToggleSubtaskAction toggleSubtask = ToggleSubtaskAction(this);
}

/// The board screen's actions, prefixed `board`.
class BoardActionsController extends TomActionController {
  /// Creates the controller (canonical prefix `board`).
  BoardActionsController() : super(controllerId: 'board');

  /// Share the selected project (`board.share`).
  late final ShareProjectAction share = ShareProjectAction(this);
}

/// The app's item actions — a process-wide controller the screens read.
final ItemActionsController itemActions = ItemActionsController();

/// The app's board actions — a process-wide controller the screens read.
final BoardActionsController boardActions = BoardActionsController();

// =============================================================================
// Runner
// =============================================================================

/// Drives [action] through a committed [TomActionTransaction] over [context] and
/// returns the context's async result (`null` = success, a message = failure).
///
/// This is the one place the synchronous action lifecycle is joined to the
/// asynchronous backend seam: the action launches its guarded op inside the
/// synchronous execute and completes [AppActionContext.result] when it settles;
/// the screen awaits the future this returns.
Future<String?> runAppAction<C extends AppActionContext>(
  TomSimpleAction<C> action,
  C context,
) {
  final tx = TomActionTransaction(label: action.label);
  action.execute(context, tx);
  tx.commit();
  return context.result;
}
