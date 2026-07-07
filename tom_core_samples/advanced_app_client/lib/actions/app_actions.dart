/// The end-user app's mutating operations, modelled as `TomAction`s with
/// action-level authorization (step 27, G-ACT-1/2).
///
/// Every write the app performs — saving an item, posting a comment, sharing a
/// project — runs through a [TomAction] here rather than an inline screen
/// callback. Two things fall out of that:
///
/// - **Action-level authorization.** Each action carries a [canonicalPath]
///   (`<controllerId>.<actionId>`, e.g. `todo.item.save`), and its
///   [TomAction.authorizer] resolves that path through the global
///   [TomAuthorization]. The screen hands the button that same authorizer, so
///   the control's enablement is driven by the action's grant, not by ad-hoc
///   screen logic. No authorization adapter is installed, so these action paths
///   resolve to the framework's permissive default (`full`) — field-level
///   presence gating (which the item screen drives via per-field grades) owns
///   visibility.
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
